/*
  # Fix note movement function

  1. Changes
    - Fix position handling for move up/down
    - Add proper boundary checks
    - Maintain correct ordering
    - Fix edge cases

  2. Details
    - Ensures notes move exactly one position
    - Maintains data integrity
    - Preserves existing functionality
*/

-- Function to get number of siblings
CREATE OR REPLACE FUNCTION get_sibling_count(
  p_project_id uuid,
  p_parent_id uuid
) RETURNS integer AS $$
  SELECT COUNT(*)::integer
  FROM notes
  WHERE project_id = p_project_id
  AND parent_id IS NOT DISTINCT FROM p_parent_id;
$$ LANGUAGE sql STABLE;

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
  v_sibling_count integer;
  v_max_allowed_position integer;
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, position
  INTO v_project_id, v_old_parent_id, v_old_position
  FROM notes
  WHERE id = p_note_id;

  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  -- Get count of siblings at target level (excluding the note being moved)
  SELECT get_sibling_count(v_project_id, p_new_parent_id) - 
    CASE WHEN v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id THEN 1 ELSE 0 END
  INTO v_sibling_count;

  -- Calculate maximum allowed position
  v_max_allowed_position := GREATEST(0, v_sibling_count);

  -- Validate and adjust position if needed
  IF p_new_position < 0 THEN
    p_new_position := 0;
  ELSIF p_new_position > v_max_allowed_position THEN
    p_new_position := v_max_allowed_position;
  END IF;

  -- If moving within the same parent, only update positions if actually moving
  IF v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id AND v_old_position != p_new_position THEN
    -- Moving up or down by one position
    IF v_old_position < p_new_position THEN
      -- Moving down
      UPDATE notes
      SET position = position - 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND position > v_old_position
      AND position <= p_new_position;
    ELSE
      -- Moving up
      UPDATE notes
      SET position = position + 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND position >= p_new_position
      AND position < v_old_position;
    END IF;

    -- Update the note's position
    UPDATE notes
    SET 
      position = p_new_position,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = p_note_id;
  ELSIF v_old_parent_id IS DISTINCT FROM p_new_parent_id THEN
    -- Moving to different parent
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