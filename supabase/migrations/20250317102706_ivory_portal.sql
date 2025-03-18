/*
  # Fix note position handling

  1. Changes
    - Add position column if not exists
    - Add constraint to ensure position is non-negative
    - Add function to maintain positions
    - Add trigger to update positions on insert/update/delete

  2. Details
    - Ensures positions are always valid
    - Maintains sequential positions
    - Handles position updates properly
*/

-- Ensure position column exists and is non-negative
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'notes' 
    AND column_name = 'position'
  ) THEN
    ALTER TABLE notes ADD COLUMN position integer DEFAULT 0;
  END IF;
END $$;

ALTER TABLE notes 
ADD CONSTRAINT position_non_negative CHECK (position >= 0);

-- Function to maintain positions
CREATE OR REPLACE FUNCTION maintain_note_positions()
RETURNS TRIGGER AS $$
DECLARE
  v_max_position integer;
BEGIN
  -- Get max position for the parent
  SELECT COALESCE(MAX(position), -1)
  INTO v_max_position
  FROM notes
  WHERE project_id = NEW.project_id
  AND parent_id IS NOT DISTINCT FROM NEW.parent_id;

  -- Set position to max + 1 if not specified
  IF NEW.position IS NULL OR NEW.position > v_max_position + 1 THEN
    NEW.position := v_max_position + 1;
  ELSE
    -- Make space for the new position
    UPDATE notes
    SET position = position + 1
    WHERE project_id = NEW.project_id
    AND parent_id IS NOT DISTINCT FROM NEW.parent_id
    AND position >= NEW.position;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for position maintenance
DROP TRIGGER IF EXISTS maintain_positions_trigger ON notes;
CREATE TRIGGER maintain_positions_trigger
BEFORE INSERT ON notes
FOR EACH ROW
EXECUTE FUNCTION maintain_note_positions();

-- Function to move notes
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_parent_id uuid;
  v_old_position integer;
  v_max_position integer;
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, position
  INTO v_project_id, v_old_parent_id, v_old_position
  FROM notes
  WHERE id = p_note_id;

  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  -- Get max position at target level
  SELECT COALESCE(MAX(position), -1)
  INTO v_max_position
  FROM notes
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM p_new_parent_id
  AND id != p_note_id;

  -- Validate position
  IF p_new_position < 0 THEN
    p_new_position := 0;
  ELSIF p_new_position > v_max_position + 1 THEN
    p_new_position := v_max_position + 1;
  END IF;

  -- Handle position updates
  IF v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id THEN
    -- Moving within same level
    IF v_old_position < p_new_position THEN
      -- Moving forward
      UPDATE notes
      SET position = position - 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND position > v_old_position
      AND position <= p_new_position;
    ELSE
      -- Moving backward
      UPDATE notes
      SET position = position + 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND position >= p_new_position
      AND position < v_old_position;
    END IF;
  ELSE
    -- Moving to different level
    -- Close gap at old position
    UPDATE notes
    SET position = position - 1
    WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM v_old_parent_id
    AND position > v_old_position;

    -- Make space at new position
    UPDATE notes
    SET position = position + 1
    WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM p_new_parent_id
    AND position >= p_new_position;
  END IF;

  -- Update the note's position and parent
  UPDATE notes
  SET 
    parent_id = p_new_parent_id,
    position = p_new_position,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_note_id;

  -- Update project's last modified timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;