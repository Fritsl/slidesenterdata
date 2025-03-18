/*
  # Fix note movement and sequence handling

  1. Changes
    - Drop existing move_note function
    - Create new move_note function with proper sequence handling
    - Add better error handling and validation
    - Fix sequence conflicts during moves

  2. Details
    - Uses a simpler, more reliable approach to sequence management
    - Handles edge cases properly
    - Maintains data integrity during moves
*/

-- Drop existing move_note function
DROP FUNCTION IF EXISTS move_note;

-- Create improved move_note function
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_parent_id uuid;
  v_old_sequence integer;
  v_max_sequence integer;
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, sequence
  INTO v_project_id, v_old_parent_id, v_old_sequence
  FROM note_sequences
  WHERE note_id = p_note_id;
  
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note % not found', p_note_id;
  END IF;

  -- Get max sequence at target level
  SELECT COALESCE(MAX(sequence), 0)
  INTO v_max_sequence
  FROM note_sequences
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM p_new_parent_id;

  -- Ensure position is valid
  IF p_new_position < 1 THEN
    p_new_position := 1;
  ELSIF p_new_position > v_max_sequence + 1 THEN
    p_new_position := v_max_sequence + 1;
  END IF;

  -- Update parent in notes table
  UPDATE notes
  SET parent_id = p_new_parent_id
  WHERE id = p_note_id;

  -- TWO-PHASE APPROACH:
  -- Phase 1: Remove note from current position completely
  DELETE FROM note_sequences WHERE note_id = p_note_id;
  
  -- Phase 2: Insert at new position
  -- Make space at the target position
  UPDATE note_sequences
  SET sequence = sequence + 1
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM p_new_parent_id
  AND sequence >= p_new_position;
  
  -- Insert the note at the target position
  INSERT INTO note_sequences (project_id, parent_id, note_id, sequence)
  VALUES (v_project_id, p_new_parent_id, p_note_id, p_new_position);

  -- Update last_modified_at timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;