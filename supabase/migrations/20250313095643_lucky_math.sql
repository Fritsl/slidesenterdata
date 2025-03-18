/*
  # Remove hierarchical structure and ordering

  1. Changes
    - Remove all hierarchical columns and relationships
    - Drop all ordering-related functions and tables
    - Create simple flat note structure
    - Update indexes for optimized queries

  2. Details
    - Removes parent-child relationships
    - Removes note ordering/positioning
    - Simplifies note management
*/

-- Drop any remaining functions that might reference hierarchical structure
DROP FUNCTION IF EXISTS move_note CASCADE;
DROP FUNCTION IF EXISTS maintain_sequences CASCADE;
DROP FUNCTION IF EXISTS initialize_level_sequences CASCADE;
DROP FUNCTION IF EXISTS delete_note_safely CASCADE;

-- Drop any remaining triggers
DROP TRIGGER IF EXISTS maintain_sequences_trigger ON notes;
DROP TRIGGER IF EXISTS set_note_sequence_number_trigger ON notes;
DROP TRIGGER IF EXISTS note_sequence_number_trigger ON notes;

-- Drop related tables if they exist
DROP TABLE IF EXISTS note_sequences CASCADE;
DROP TABLE IF EXISTS root_notes CASCADE;

-- Remove any remaining hierarchical columns from notes
ALTER TABLE notes 
DROP COLUMN IF EXISTS position CASCADE,
DROP COLUMN IF EXISTS parent_id CASCADE,
DROP COLUMN IF EXISTS sequence_number CASCADE;

-- Drop related indexes
DROP INDEX IF EXISTS notes_parent_project_idx;
DROP INDEX IF EXISTS notes_parent_id_idx;

-- Create or update indexes for flat note structure
CREATE INDEX IF NOT EXISTS notes_project_id_idx ON notes(project_id);
CREATE INDEX IF NOT EXISTS notes_user_id_idx ON notes(user_id);
CREATE INDEX IF NOT EXISTS notes_created_at_idx ON notes(created_at);

-- Create a simple delete function
CREATE OR REPLACE FUNCTION delete_note_safely(note_id uuid)
RETURNS void AS $$
BEGIN
  DELETE FROM notes WHERE id = note_id;
END;
$$ LANGUAGE plpgsql;