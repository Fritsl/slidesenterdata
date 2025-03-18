/*
  # Implement simple linked list movement
  
  1. Changes
    - Remove complex position handling
    - Use simple parent-child relationships
    - Maintain sequential positions
    - Add proper constraints
    
  2. Details
    - Each note has a parent_id and position
    - Position is unique per parent
    - Simple position swapping for moves
*/

-- Add position constraint if it doesn't exist
ALTER TABLE notes
DROP CONSTRAINT IF EXISTS unique_position_per_parent;

ALTER TABLE notes
ADD CONSTRAINT unique_position_per_parent 
UNIQUE (project_id, parent_id, position);

-- Function to move notes
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
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, position
  INTO v_project_id, v_old_parent_id, v_old_position
  FROM notes
  WHERE id = p_note_id;

  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  -- Find note at target position
  SELECT id INTO v_target_note_id
  FROM notes
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM p_new_parent_id
  AND position = p_new_position
  AND id != p_note_id;

  -- Simple position swap if target exists
  IF v_target_note_id IS NOT NULL THEN
    UPDATE notes
    SET position = 
      CASE id
        WHEN p_note_id THEN p_new_position
        WHEN v_target_note_id THEN v_old_position
      END,
      parent_id = 
      CASE id
        WHEN p_note_id THEN p_new_parent_id
        ELSE parent_id
      END,
      updated_at = CURRENT_TIMESTAMP
    WHERE id IN (p_note_id, v_target_note_id);
  ELSE
    -- Just update position and parent
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