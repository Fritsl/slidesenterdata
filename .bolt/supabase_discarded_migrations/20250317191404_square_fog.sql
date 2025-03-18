-- Function to move notes with sequential position reassignment
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_parent_id uuid;
  v_position integer := 0;
  v_note_id uuid;
BEGIN
  -- Get current note info
  SELECT project_id, parent_id
  INTO v_project_id, v_old_parent_id
  FROM notes
  WHERE id = p_note_id;

  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  -- First update the parent of the moved note
  UPDATE notes
  SET parent_id = p_new_parent_id
  WHERE id = p_note_id;

  -- Then reassign all positions at the target level sequentially
  FOR v_note_id IN (
    SELECT id
    FROM notes
    WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM p_new_parent_id
    ORDER BY 
      CASE 
        WHEN position < p_new_position THEN position -- Keep original order for notes before target
        WHEN id = p_note_id THEN p_new_position -- Place moved note at target position
        ELSE position + 1 -- Shift other notes up by 1
      END
  ) LOOP
    UPDATE notes
    SET position = v_position
    WHERE id = v_note_id;
    
    v_position := v_position + 1;
  END LOOP;

  -- If parent changed, normalize positions at old parent level
  IF v_old_parent_id IS DISTINCT FROM p_new_parent_id THEN
    v_position := 0;
    FOR v_note_id IN (
      SELECT id
      FROM notes
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM v_old_parent_id
      ORDER BY position
    ) LOOP
      UPDATE notes
      SET position = v_position
      WHERE id = v_note_id;
      
      v_position := v_position + 1;
    END LOOP;
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