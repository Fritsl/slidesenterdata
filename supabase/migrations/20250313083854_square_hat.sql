/*
  # Add note sequence support

  1. New Tables
    - `note_sequences` table to track note ordering
      - `id` (uuid, primary key)
      - `project_id` (uuid, references settings)
      - `parent_id` (uuid, references notes)
      - `note_id` (uuid, references notes)
      - `sequence` (integer)

  2. Functions
    - `move_note`: Handles note movement and reordering
    - `normalize_sequences`: Fixes sequence gaps
*/

-- Create note_sequences table
CREATE TABLE note_sequences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES settings(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES notes(id) ON DELETE CASCADE,
  note_id uuid NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  sequence integer NOT NULL,
  UNIQUE (project_id, parent_id, sequence),
  UNIQUE (note_id)
);

-- Create indexes for performance
CREATE INDEX note_sequences_note_id_idx ON note_sequences(note_id);
CREATE INDEX note_sequences_parent_id_idx ON note_sequences(parent_id);
CREATE INDEX note_sequences_project_id_idx ON note_sequences(project_id);

-- Function to normalize sequences
CREATE OR REPLACE FUNCTION normalize_sequences(target_project_id uuid, target_parent_id uuid DEFAULT NULL)
RETURNS void AS $$
DECLARE
  note_record RECORD;
  current_seq integer := 1;
BEGIN
  FOR note_record IN (
    SELECT note_id
    FROM note_sequences
    WHERE project_id = target_project_id
    AND parent_id IS NOT DISTINCT FROM target_parent_id
    ORDER BY sequence
  ) LOOP
    UPDATE note_sequences
    SET sequence = current_seq
    WHERE note_id = note_record.note_id;
    
    current_seq := current_seq + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to move notes
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

  -- Update parent in notes table
  UPDATE notes
  SET parent_id = p_new_parent_id
  WHERE id = p_note_id;

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