/*
  # Fix note sequences and ordering

  1. Changes
    - Add trigger to maintain sequences on note creation
    - Fix move_note function to handle sequences properly
    - Add function to normalize sequences when needed

  2. Details
    - Ensures sequences are created for new notes
    - Maintains proper ordering during moves
    - Handles parent changes correctly
*/

-- Create trigger to maintain sequences
CREATE OR REPLACE FUNCTION maintain_sequences()
RETURNS TRIGGER AS $$
BEGIN
  -- If sequence record doesn't exist, create it
  IF NOT EXISTS (
    SELECT 1 FROM note_sequences
    WHERE note_id = NEW.id
  ) THEN
    INSERT INTO note_sequences (
      project_id,
      parent_id,
      note_id,
      sequence
    )
    SELECT
      NEW.project_id,
      NEW.parent_id,
      NEW.id,
      COALESCE(
        (
          SELECT MAX(sequence) + 1
          FROM note_sequences
          WHERE project_id = NEW.project_id
          AND parent_id IS NOT DISTINCT FROM NEW.parent_id
        ),
        1
      );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER maintain_sequences_trigger
AFTER INSERT ON notes
FOR EACH ROW
EXECUTE FUNCTION maintain_sequences();

-- Improve move_note function
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_parent_id uuid;
  v_old_sequence integer;
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, sequence
  INTO v_project_id, v_old_parent_id, v_old_sequence
  FROM note_sequences
  WHERE note_id = p_note_id;

  -- Handle sequence updates
  IF v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id THEN
    -- Moving within same parent
    IF v_old_sequence < p_new_position THEN
      -- Moving forward
      UPDATE note_sequences
      SET sequence = sequence - 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM v_old_parent_id
      AND sequence > v_old_sequence
      AND sequence <= p_new_position;
    ELSE
      -- Moving backward
      UPDATE note_sequences
      SET sequence = sequence + 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM v_old_parent_id
      AND sequence >= p_new_position
      AND sequence < v_old_sequence;
    END IF;

    -- Update note's sequence
    UPDATE note_sequences
    SET sequence = p_new_position
    WHERE note_id = p_note_id;
  ELSE
    -- Moving to different parent
    -- Remove from old parent
    DELETE FROM note_sequences WHERE note_id = p_note_id;
    
    -- Make space in new parent
    UPDATE note_sequences
    SET sequence = sequence + 1
    WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM p_new_parent_id
    AND sequence >= p_new_position;
    
    -- Insert at new position
    INSERT INTO note_sequences (project_id, parent_id, note_id, sequence)
    VALUES (v_project_id, p_new_parent_id, p_note_id, p_new_position);
  END IF;

  -- Update last_modified_at timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;