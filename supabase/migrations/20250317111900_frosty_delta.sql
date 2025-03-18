/*
  # Fix note position handling

  1. Changes
    - Fix position handling for moving notes up/down
    - Add proper boundary checks
    - Add logging for debugging
    - Fix edge cases

  2. Details
    - Ensures notes stay in correct order
    - Prevents position conflicts
    - Maintains data integrity
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

  -- Log initial state
  RAISE NOTICE 'Moving note: id=%, old_pos=%, new_pos=%, old_parent=%, new_parent=%',
    p_note_id, v_old_position, p_new_position, v_old_parent_id, p_new_parent_id;

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

  RAISE NOTICE 'Adjusted position: %, max allowed: %', p_new_position, v_max_allowed_position;

  -- If moving within the same parent
  IF v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id THEN
    IF v_old_position = p_new_position THEN
      -- No movement needed
      RAISE NOTICE 'No movement needed - same position';
      RETURN;
    END IF;

    RAISE NOTICE 'Moving within same parent from % to %', v_old_position, p_new_position;

    -- Moving up (to a lower position number)
    IF p_new_position < v_old_position THEN
      RAISE NOTICE 'Moving up - shifting positions % to % up by 1', p_new_position, v_old_position - 1;
      
      UPDATE notes
      SET position = position + 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND position >= p_new_position
      AND position < v_old_position;
    
    -- Moving down (to a higher position number)
    ELSE
      RAISE NOTICE 'Moving down - shifting positions % to % down by 1', v_old_position + 1, p_new_position;
      
      UPDATE notes
      SET position = position - 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND position > v_old_position
      AND position <= p_new_position;
    END IF;

  -- Moving to different parent
  ELSE
    RAISE NOTICE 'Moving to different parent';
    
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

  RAISE NOTICE 'Note updated successfully to position %', p_new_position;

  -- Update project's last modified timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;