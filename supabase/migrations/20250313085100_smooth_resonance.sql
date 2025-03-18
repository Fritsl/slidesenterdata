/*
  # Populate sequences for existing notes

  1. Changes
    - Add sequences for any existing notes that don't have them
    - Uses created_at timestamp to determine initial ordering
    - Handles both root level and child notes
    - Maintains parent-child relationships

  2. Details
    - Processes notes level by level
    - Assigns sequential numbers starting from 1
    - Preserves existing hierarchical structure
*/

-- Function to populate sequences for a specific level
CREATE OR REPLACE FUNCTION populate_level_sequences(target_project_id uuid, target_parent_id uuid DEFAULT NULL)
RETURNS void AS $$
DECLARE
  note_record RECORD;
  current_seq integer := 1;
BEGIN
  -- Process each note at this level, ordered by creation date
  FOR note_record IN (
    SELECT id
    FROM notes
    WHERE project_id = target_project_id
    AND parent_id IS NOT DISTINCT FROM target_parent_id
    AND NOT EXISTS (
      SELECT 1 FROM note_sequences
      WHERE note_id = notes.id
    )
    ORDER BY created_at ASC
  ) LOOP
    -- Insert sequence for this note
    INSERT INTO note_sequences (
      project_id,
      parent_id,
      note_id,
      sequence
    ) VALUES (
      target_project_id,
      target_parent_id,
      note_record.id,
      current_seq
    );
    
    -- Process children of this note
    PERFORM populate_level_sequences(target_project_id, note_record.id);
    
    current_seq := current_seq + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Populate sequences for all projects
DO $$
DECLARE
  project_record RECORD;
BEGIN
  -- Process each project
  FOR project_record IN SELECT DISTINCT project_id FROM notes LOOP
    -- Populate root level sequences first
    PERFORM populate_level_sequences(project_record.project_id);
  END LOOP;
END $$;