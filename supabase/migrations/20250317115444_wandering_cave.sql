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
  v_target_note_id uuid;
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, position
  INTO v_project_id, v_old_parent_id, v_old_position
  FROM notes
  WHERE id = p_note_id;

  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  -- Get count of siblings at current level
  SELECT get_sibling_count(v_project_id, v_old_parent_id)
  INTO v_sibling_count;

  -- Log initial state
  RAISE NOTICE 'Moving note: id=%, old_pos=%, new_pos=%, siblings=%, old_parent=%, new_parent=%',
    p_note_id, v_old_position, p_new_position, v_sibling_count, v_old_parent_id, p_new_parent_id;

  -- If moving within the same parent
  IF v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id THEN
    -- Validate new position
    IF p_new_position < 0 OR p_new_position >= v_sibling_count THEN
      RAISE NOTICE 'Invalid position: %, max allowed: %', p_new_position, v_sibling_count - 1;
      RETURN;
    END IF;

    IF v_old_position = p_new_position THEN
      RAISE NOTICE 'No movement needed - same position';
      RETURN;
    END IF;

    -- Find the note we're swapping with
    SELECT id INTO v_target_note_id
    FROM notes
    WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM p_new_parent_id
    AND position = p_new_position
    AND id != p_note_id;

    IF v_target_note_id IS NOT NULL THEN
      RAISE NOTICE 'Swapping positions between notes % and %', p_note_id, v_target_note_id;
      
      -- Simple position swap
      UPDATE notes n
      SET position = 
        CASE n.id
          WHEN p_note_id THEN p_new_position
          WHEN v_target_note_id THEN v_old_position
        END,
        updated_at = CURRENT_TIMESTAMP
      WHERE n.id IN (p_note_id, v_target_note_id);
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

  RAISE NOTICE 'Note movement completed successfully';
END;
$$ LANGUAGE plpgsql;