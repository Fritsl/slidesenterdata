-- Function to move notes with simplified position handling
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_parent_id uuid;
BEGIN
  -- Get current note info
  SELECT project_id, parent_id
  INTO v_project_id, v_old_parent_id
  FROM notes
  WHERE id = p_note_id;

  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  -- Make space at target position
  UPDATE notes
  SET position = position + 1
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM p_new_parent_id
  AND position >= p_new_position;

  -- Move note to new position and parent
  UPDATE notes
  SET 
    parent_id = p_new_parent_id,
    position = p_new_position,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_note_id;

  -- Close gaps at old parent
  UPDATE notes
  SET position = position - 1
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM v_old_parent_id
  AND position > (
    SELECT position FROM notes WHERE id = p_note_id
  );

  -- Update project's last modified timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;