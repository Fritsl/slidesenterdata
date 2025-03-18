/*
  # Fix note movement functionality
  
  1. Changes
    - Simplify note movement to handle flat structure
    - Fix position swapping logic
    - Add proper position validation
    - Add logging for debugging
    
  2. Details
    - Maintains sequential positions
    - Handles edge cases properly
    - Prevents invalid moves
*/

-- Function to move notes with proper position handling
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid, -- Kept for API compatibility but ignored
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_position integer;
  v_max_position integer;
BEGIN
  -- Get current note info
  SELECT project_id, position
  INTO v_project_id, v_old_position
  FROM notes
  WHERE id = p_note_id;

  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  -- Get max position
  SELECT COALESCE(MAX(position), -1)
  INTO v_max_position
  FROM notes
  WHERE project_id = v_project_id;

  -- Log initial state
  RAISE NOTICE 'Moving note: id=%, old_pos=%, new_pos=%, max_pos=%',
    p_note_id, v_old_position, p_new_position, v_max_position;

  -- Validate position
  IF p_new_position < 0 THEN
    p_new_position := 0;
  ELSIF p_new_position > v_max_position THEN
    p_new_position := v_max_position;
  END IF;

  -- Skip if no actual movement
  IF v_old_position = p_new_position THEN
    RAISE NOTICE 'No movement needed - same position';
    RETURN;
  END IF;

  -- Moving up
  IF p_new_position < v_old_position THEN
    RAISE NOTICE 'Moving up from % to %', v_old_position, p_new_position;
    UPDATE notes
    SET position = position + 1
    WHERE project_id = v_project_id
    AND position >= p_new_position
    AND position < v_old_position;
  -- Moving down
  ELSE
    RAISE NOTICE 'Moving down from % to %', v_old_position, p_new_position;
    UPDATE notes
    SET position = position - 1
    WHERE project_id = v_project_id
    AND position > v_old_position
    AND position <= p_new_position;
  END IF;

  -- Update the note's position
  UPDATE notes
  SET 
    position = p_new_position,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_note_id;

  -- Update project's last modified timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;

  RAISE NOTICE 'Note movement completed successfully';
END;
$$ LANGUAGE plpgsql;