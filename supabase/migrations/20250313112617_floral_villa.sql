/*
  # Fix note position handling

  1. Changes
    - Add trigger to maintain positions on insert
    - Improve move_note function to handle root level properly
    - Add function to reorder notes at any level
    - Fix position handling when moving notes

  2. Details
    - Ensures consistent position handling
    - Maintains proper ordering at root level
    - Prevents position conflicts
*/

-- Function to maintain positions on insert
CREATE OR REPLACE FUNCTION maintain_note_positions()
RETURNS TRIGGER AS $$
DECLARE
  v_max_position integer;
BEGIN
  -- Get max position at target level
  SELECT COALESCE(MAX(position), -1)
  INTO v_max_position
  FROM notes
  WHERE project_id = NEW.project_id
  AND parent_id IS NOT DISTINCT FROM NEW.parent_id;
  
  -- Set position to max + 1
  NEW.position := v_max_position + 1;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for new notes
DROP TRIGGER IF EXISTS maintain_positions_trigger ON notes;
CREATE TRIGGER maintain_positions_trigger
BEFORE INSERT ON notes
FOR EACH ROW
EXECUTE FUNCTION maintain_note_positions();

-- Improved move_note function
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

  -- Validate parent if not moving to root
  IF p_new_parent_id IS NOT NULL THEN
    -- Check parent exists and is in same project
    IF NOT EXISTS (
      SELECT 1 FROM notes 
      WHERE id = p_new_parent_id 
      AND project_id = v_project_id
    ) THEN
      RAISE EXCEPTION 'Invalid parent note';
    END IF;
    
    -- Check for circular reference
    IF p_new_parent_id = p_note_id OR EXISTS (
      WITH RECURSIVE descendants AS (
        SELECT id FROM notes WHERE parent_id = p_note_id
        UNION ALL
        SELECT n.id FROM notes n
        INNER JOIN descendants d ON n.parent_id = d.id
      )
      SELECT 1 FROM descendants WHERE id = p_new_parent_id
    ) THEN
      RAISE EXCEPTION 'Circular reference detected';
    END IF;
  END IF;

  -- Lock the notes table to prevent concurrent modifications
  LOCK TABLE notes IN EXCLUSIVE MODE;

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

-- Function to reorder notes at any level
CREATE OR REPLACE FUNCTION reorder_notes(
  p_project_id uuid,
  p_parent_id uuid DEFAULT NULL
) RETURNS void AS $$
DECLARE
  v_position integer := 0;
  v_note_id uuid;
BEGIN
  -- Lock the notes table
  LOCK TABLE notes IN EXCLUSIVE MODE;
  
  FOR v_note_id IN (
    SELECT id
    FROM notes
    WHERE project_id = p_project_id
    AND parent_id IS NOT DISTINCT FROM p_parent_id
    ORDER BY position, created_at, id
  ) LOOP
    UPDATE notes
    SET position = v_position
    WHERE id = v_note_id;
    
    v_position := v_position + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Reorder all existing notes
DO $$
DECLARE
  v_project_id uuid;
  v_parent_id uuid;
BEGIN
  -- First reorder root level notes for each project
  FOR v_project_id IN (SELECT DISTINCT project_id FROM notes) LOOP
    PERFORM reorder_notes(v_project_id, NULL);
    
    -- Then reorder each parent's children
    FOR v_parent_id IN (
      SELECT DISTINCT id 
      FROM notes 
      WHERE project_id = v_project_id 
      AND EXISTS (
        SELECT 1 FROM notes 
        WHERE parent_id = notes.id
      )
    ) LOOP
      PERFORM reorder_notes(v_project_id, v_parent_id);
    END LOOP;
  END LOOP;
END $$;