-- Function to move notes with proper parent handling
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

  -- Get max position at target level
  SELECT COALESCE(MAX(position), -1)
  INTO v_max_position
  FROM notes
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM p_new_parent_id;

  -- Validate position
  IF p_new_position < 0 OR p_new_position > v_max_position + 1 THEN
    RETURN; -- Invalid position, do nothing
  END IF;

  -- Find the note at the target position
  SELECT id INTO v_target_note_id
  FROM notes
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM p_new_parent_id
  AND position = p_new_position
  AND id != p_note_id;

  IF v_target_note_id IS NOT NULL THEN
    -- Simple position swap
    UPDATE notes
    SET 
      position = CASE id
        WHEN p_note_id THEN p_new_position
        WHEN v_target_note_id THEN v_old_position
      END,
      parent_id = CASE id
        WHEN p_note_id THEN p_new_parent_id
        ELSE parent_id
      END,
      updated_at = CURRENT_TIMESTAMP
    WHERE id IN (p_note_id, v_target_note_id);
  ELSE
    -- Moving to an empty position
    UPDATE notes
    SET 
      position = p_new_position,
      parent_id = p_new_parent_id,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = p_note_id;
  END IF;

  -- Update project's last modified timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;