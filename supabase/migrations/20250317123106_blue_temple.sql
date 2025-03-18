/*
  # Remove parent-child relationships from notes
  
  1. Changes
    - Modify move_note function to only allow root-level moves
    - Remove parent_id handling
    - Maintain simple position swapping
    
  2. Details
    - Ensures notes stay at root level
    - Preserves order within root level
    - Maintains data integrity
*/

-- Function to move notes with flat structure
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_position integer;
  v_target_note_id uuid;
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

  -- Get max position at root level
  SELECT COALESCE(MAX(position), -1)
  INTO v_max_position
  FROM notes
  WHERE project_id = v_project_id;

  -- Validate position
  IF p_new_position < 0 OR p_new_position > v_max_position THEN
    RETURN; -- Invalid position, do nothing
  END IF;

  -- Find the note at the target position
  SELECT id INTO v_target_note_id
  FROM notes
  WHERE project_id = v_project_id
  AND position = p_new_position
  AND id != p_note_id;

  IF v_target_note_id IS NOT NULL THEN
    -- Simple position swap
    UPDATE notes
    SET position = 
      CASE id
        WHEN p_note_id THEN p_new_position
        WHEN v_target_note_id THEN v_old_position
      END,
      updated_at = CURRENT_TIMESTAMP
    WHERE id IN (p_note_id, v_target_note_id);
  END IF;

  -- Update project's last modified timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;