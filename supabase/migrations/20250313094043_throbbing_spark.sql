/*
  # Simplify Notes System
  
  1. Changes
    - Remove all ordering and hierarchy
    - Keep only essential note fields
    - Maintain basic note storage functionality
    
  2. Details
    - Removes parent/child relationships
    - Removes position/sequence tracking
    - Simplifies to flat note structure
*/

-- Drop any existing functions that might interfere
DROP FUNCTION IF EXISTS move_note CASCADE;
DROP FUNCTION IF EXISTS maintain_sequences CASCADE;
DROP FUNCTION IF EXISTS initialize_level_sequences CASCADE;

-- Drop any existing triggers
DROP TRIGGER IF EXISTS maintain_sequences_trigger ON notes;
DROP TRIGGER IF EXISTS set_note_sequence_number_trigger ON notes;
DROP TRIGGER IF EXISTS note_sequence_number_trigger ON notes;

-- Drop related tables
DROP TABLE IF EXISTS note_sequences CASCADE;
DROP TABLE IF EXISTS root_notes CASCADE;

-- Remove ordering and hierarchy columns from notes
ALTER TABLE notes 
DROP COLUMN IF EXISTS position CASCADE,
DROP COLUMN IF EXISTS parent_id CASCADE,
DROP COLUMN IF EXISTS sequence_number CASCADE;

-- Drop related indexes
DROP INDEX IF EXISTS notes_parent_project_idx;
DROP INDEX IF EXISTS notes_parent_id_idx;

-- Create index for basic note queries
CREATE INDEX IF NOT EXISTS notes_project_id_idx ON notes(project_id);
CREATE INDEX IF NOT EXISTS notes_user_id_idx ON notes(user_id);
CREATE INDEX IF NOT EXISTS notes_created_at_idx ON notes(created_at);