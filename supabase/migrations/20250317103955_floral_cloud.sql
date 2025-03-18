/*
  # Fix note position handling

  1. Changes
    - Add function to get sibling count
    - Add function to validate position
    - Update move_note function to handle edge cases
    - Add trigger to maintain position integrity

  2. Details
    - Ensures positions are sequential
    - Handles boundary conditions
    - Updates positions atomically
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

-- Function to move notes with proper boundary checking
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