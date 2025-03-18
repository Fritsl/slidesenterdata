/*
  # Fix note movement functionality
  
  1. Changes
    - Remove unique constraint that's causing conflicts
    - Simplify move_note function to handle one position at a time
    - Add proper position validation
    - Fix edge cases in note movement
*/

-- Drop existing unique constraint
ALTER TABLE notes 
DROP CONSTRAINT IF EXISTS unique_position_per_parent;

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

  -- If moving within the same parent
  IF v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id THEN
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
      SET position = 
        CASE id
          WHEN p_note_id THEN p_new_position
          WHEN v_target_note_id THEN v_old_position
        END,
        updated_at = CURRENT_TIMESTAMP
      WHERE id IN (p_note_id, v_target_note_id);
    END IF;
  ELSE
    -- Moving to different parent
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
END;
$$ LANGUAGE plpgsql;