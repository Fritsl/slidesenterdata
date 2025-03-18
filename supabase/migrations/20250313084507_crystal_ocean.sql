/*
  # Fix note sequences and triggers

  1. Changes
    - Add note_sequences table if it doesn't exist
    - Add function to maintain sequences
    - Add trigger only if it doesn't exist
    - Add indexes for performance

  2. Details
    - Prevents duplicate trigger error
    - Maintains data integrity
    - Improves query performance
*/

-- Create note_sequences table if it doesn't exist
CREATE TABLE IF NOT EXISTS note_sequences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES settings(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES notes(id) ON DELETE CASCADE,
  note_id uuid NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  sequence integer NOT NULL,
  UNIQUE (project_id, parent_id, sequence),
  UNIQUE (note_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS note_sequences_note_id_idx ON note_sequences(note_id);
CREATE INDEX IF NOT EXISTS note_sequences_parent_id_idx ON note_sequences(parent_id);
CREATE INDEX IF NOT EXISTS note_sequences_project_id_idx ON note_sequences(project_id);

-- Function to maintain sequences
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

-- Drop trigger if it exists and create it
DO $$
BEGIN
  -- Drop the trigger if it exists
  DROP TRIGGER IF EXISTS maintain_sequences_trigger ON notes;
  
  -- Create the trigger
  CREATE TRIGGER maintain_sequences_trigger
  AFTER INSERT ON notes
  FOR EACH ROW
  EXECUTE FUNCTION maintain_sequences();
END $$;