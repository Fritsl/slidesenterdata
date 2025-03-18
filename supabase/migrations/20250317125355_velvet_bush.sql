/*
  # Fix note movement functionality
  
  1. Changes
    - Maintain proper parent-child relationships
    - Fix position handling within each level
    - Ensure children move with parent
    - Add proper validation and error handling
    
  2. Details
    - Preserves tree structure
    - Handles position swaps correctly
    - Maintains data integrity
*/

-- Function to move notes with proper tree structure
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_parent_id uuid;
  v_old_position integer;
  v_target_note_id uuid;
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
    WITH RECURSIVE descendants AS (
      SELECT id FROM notes WHERE id = p_note_id
      UNION ALL
      SELECT n.id FROM notes n
      INNER JOIN descendants d ON n.parent_id = d.id
    )
    SELECT id INTO v_target_note_id
    FROM descendants
    WHERE id = p_new_parent_id;

    IF v_target_note_id IS NOT NULL THEN
      RAISE EXCEPTION 'Cannot move note under its own descendant';
    END IF;
  END IF;

  -- Get max position at target level
  SELECT COALESCE(MAX(position), -1)
  INTO v_max_position
  FROM notes
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM p_new_parent_id;

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