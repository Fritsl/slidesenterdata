-- Function to move notes with simple position handling
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_parent_id uuid;
  v_old_position integer;
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, position
  INTO v_project_id, v_old_parent_id, v_old_position
  FROM notes
  WHERE id = p_note_id;

  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  -- If moving within same parent, just update position
  IF v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id THEN
    -- Moving up
    IF p_new_position < v_old_position THEN
      UPDATE notes
      SET position = position + 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND position = p_new_position;
    -- Moving down  
    ELSE
      UPDATE notes
      SET position = position - 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND position = p_new_position;
    END IF;

    -- Update the note's position
    UPDATE notes
    SET position = p_new_position
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
      position = p_new_position
    WHERE id = p_note_id;
  END IF;

  -- Update timestamps
  UPDATE notes
  SET updated_at = CURRENT_TIMESTAMP
  WHERE id = p_note_id;

  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;