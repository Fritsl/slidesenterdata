-- Function to move notes with simplified position handling
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_parent_id uuid;
  v_old_position integer;
  v_swap_note_id uuid;
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, position
  INTO v_project_id, v_old_parent_id, v_old_position
  FROM notes
  WHERE id = p_note_id;

  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  -- If moving within same parent, just swap positions
  IF v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id THEN
    -- Find note to swap with
    SELECT id INTO v_swap_note_id
    FROM notes
    WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM p_new_parent_id
    AND position = p_new_position
    AND id != p_note_id;

    -- If found a note to swap with, do the swap
    IF v_swap_note_id IS NOT NULL THEN
      UPDATE notes
      SET position = CASE
        WHEN id = p_note_id THEN p_new_position
        WHEN id = v_swap_note_id THEN v_old_position
      END
      WHERE id IN (p_note_id, v_swap_note_id);
    END IF;

  -- Moving to different parent
  ELSE
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
      position = p_new_position
    WHERE id = p_note_id;

    -- Close gap at old parent
    UPDATE notes
    SET position = position - 1
    WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM v_old_parent_id
    AND position > v_old_position;
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