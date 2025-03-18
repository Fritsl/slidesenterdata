/*
  # Implement decimal position system
  
  1. Changes
    - Change position to decimal type
    - Use midpoint calculation for new positions
    - Maintain proper ordering without running out of space
    
  2. Details
    - Uses decimal positions with 20 decimal places
    - Calculates midpoint between positions for insertion
    - Handles edge cases properly
*/

-- Change position to decimal type
ALTER TABLE notes 
ALTER COLUMN position TYPE decimal(30,20);

-- Function to calculate midpoint position
CREATE OR REPLACE FUNCTION calculate_midpoint(
  p_pos1 decimal,
  p_pos2 decimal
) RETURNS decimal AS $$
BEGIN
  RETURN (p_pos1 + p_pos2) / 2;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to get position for insertion
CREATE OR REPLACE FUNCTION get_insert_position(
  p_project_id uuid,
  p_parent_id uuid,
  p_target_position integer
) RETURNS decimal AS $$
DECLARE
  v_prev_pos decimal;
  v_next_pos decimal;
  v_count integer;
BEGIN
  -- Get count of notes at this level
  SELECT COUNT(*) INTO v_count
  FROM notes
  WHERE project_id = p_project_id
  AND parent_id IS NOT DISTINCT FROM p_parent_id;

  -- Handle empty list or insertion at start
  IF v_count = 0 OR p_target_position = 0 THEN
    RETURN 1000000;
  END IF;

  -- Handle insertion at end
  IF p_target_position >= v_count THEN
    SELECT COALESCE(MAX(position), 0) INTO v_prev_pos
    FROM notes
    WHERE project_id = p_project_id
    AND parent_id IS NOT DISTINCT FROM p_parent_id;
    RETURN v_prev_pos + 1000000;
  END IF;

  -- Get surrounding positions
  SELECT position INTO v_prev_pos
  FROM notes
  WHERE project_id = p_project_id
  AND parent_id IS NOT DISTINCT FROM p_parent_id
  AND position < (
    SELECT position FROM notes
    WHERE project_id = p_project_id
    AND parent_id IS NOT DISTINCT FROM p_parent_id
    ORDER BY position
    OFFSET p_target_position LIMIT 1
  )
  ORDER BY position DESC
  LIMIT 1;

  SELECT position INTO v_next_pos
  FROM notes
  WHERE project_id = p_project_id
  AND parent_id IS NOT DISTINCT FROM p_parent_id
  ORDER BY position
  OFFSET p_target_position LIMIT 1;

  -- If no previous position, use half of next position
  IF v_prev_pos IS NULL THEN
    RETURN v_next_pos / 2;
  END IF;

  -- Calculate midpoint
  RETURN calculate_midpoint(v_prev_pos, v_next_pos);
END;
$$ LANGUAGE plpgsql;

-- Function to move notes
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_target_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_new_position decimal;
BEGIN
  -- Get project ID
  SELECT project_id INTO v_project_id
  FROM notes
  WHERE id = p_note_id;

  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  -- Calculate new position
  SELECT get_insert_position(v_project_id, p_new_parent_id, p_target_position)
  INTO v_new_position;

  -- Update the note
  UPDATE notes
  SET 
    parent_id = p_new_parent_id,
    position = v_new_position,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_note_id;

  -- Update project's last modified timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;

-- Initialize decimal positions for existing notes
DO $$
DECLARE
  v_project_id uuid;
  v_parent_id uuid;
  v_position decimal := 1000000;
BEGIN
  -- Process each project
  FOR v_project_id IN (SELECT DISTINCT project_id FROM notes) LOOP
    -- First handle root level notes
    UPDATE notes n
    SET position = v_position * ROW_NUMBER() OVER (
      ORDER BY position, created_at
    )
    WHERE project_id = v_project_id
    AND parent_id IS NULL;

    -- Then handle each parent's children
    FOR v_parent_id IN (
      SELECT DISTINCT id 
      FROM notes 
      WHERE project_id = v_project_id 
      AND EXISTS (
        SELECT 1 FROM notes 
        WHERE parent_id = notes.id
      )
    ) LOOP
      UPDATE notes n
      SET position = v_position * ROW_NUMBER() OVER (
        ORDER BY position, created_at
      )
      WHERE project_id = v_project_id
      AND parent_id = v_parent_id;
    END LOOP;
  END LOOP;
END $$;