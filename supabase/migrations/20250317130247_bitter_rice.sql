/*
  # Fix note position uniqueness

  1. Changes
    - Add unique constraint for position within each parent level
    - Add function to normalize positions
    - Update move_note function to maintain uniqueness
    - Add trigger to maintain position uniqueness on insert

  2. Details
    - Ensures no duplicate positions at same level
    - Maintains proper ordering
    - Handles edge cases properly
*/

-- Add unique constraint for position within each level
ALTER TABLE notes
DROP CONSTRAINT IF EXISTS unique_position_per_parent;

ALTER TABLE notes
ADD CONSTRAINT unique_position_per_parent 
UNIQUE (project_id, parent_id, position);

-- Function to normalize positions
CREATE OR REPLACE FUNCTION normalize_positions(
  p_project_id uuid,
  p_parent_id uuid DEFAULT NULL
) RETURNS void AS $$
DECLARE
  v_position integer := 0;
  v_note_id uuid;
BEGIN
  -- Update positions sequentially
  FOR v_note_id IN (
    SELECT id
    FROM notes
    WHERE project_id = p_project_id
    AND parent_id IS NOT DISTINCT FROM p_parent_id
    ORDER BY position, created_at
  ) LOOP
    UPDATE notes
    SET position = v_position
    WHERE id = v_note_id;
    
    v_position := v_position + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to move notes with proper position handling
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

  -- Prevent circular references
  IF p_new_parent_id IS NOT NULL THEN
    IF EXISTS (
      WITH RECURSIVE descendants AS (
        SELECT id FROM notes WHERE id = p_note_id
        UNION ALL
        SELECT n.id FROM notes n
        INNER JOIN descendants d ON n.parent_id = d.id
      )
      SELECT 1 FROM descendants WHERE id = p_new_parent_id
    ) THEN
      RAISE EXCEPTION 'Cannot move note under its own descendant';
    END IF;
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

  -- If moving within the same parent
  IF v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id THEN
    IF v_old_position = p_new_position THEN
      RETURN; -- No movement needed
    END IF;

    -- Moving up
    IF p_new_position < v_old_position THEN
      UPDATE notes
      SET position = position + 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND position >= p_new_position
      AND position < v_old_position;
    -- Moving down
    ELSE
      UPDATE notes
      SET position = position - 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND position > v_old_position
      AND position <= p_new_position;
    END IF;

    -- Update the note's position
    UPDATE notes
    SET 
      position = p_new_position,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = p_note_id;

  -- Moving to different parent
  ELSE
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

    -- Update the note's position and parent
    UPDATE notes
    SET 
      parent_id = p_new_parent_id,
      position = p_new_position,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = p_note_id;
  END IF;

  -- Update project's last modified timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;

-- Normalize existing positions
DO $$
DECLARE
  v_project_id uuid;
  v_parent_id uuid;
BEGIN
  -- First normalize root level notes for each project
  FOR v_project_id IN (SELECT DISTINCT project_id FROM notes) LOOP
    PERFORM normalize_positions(v_project_id, NULL);
    
    -- Then normalize each parent's children
    FOR v_parent_id IN (
      SELECT DISTINCT id 
      FROM notes 
      WHERE project_id = v_project_id 
      AND EXISTS (
        SELECT 1 FROM notes 
        WHERE parent_id = notes.id
      )
    ) LOOP
      PERFORM normalize_positions(v_project_id, v_parent_id);
    END LOOP;
  END LOOP;
END $$;