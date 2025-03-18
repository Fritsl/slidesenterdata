/*
  # Remove Note Ordering and Hierarchy
  
  1. Changes
    - Remove position column
    - Remove parent_id column and related constraints
    - Drop move_note function
    - Drop related indexes
    
  2. Details
    - Simplifies notes to flat structure
    - Removes all ordering functionality
    - Maintains basic note storage
*/

-- Drop function first to avoid dependency issues
DROP FUNCTION IF EXISTS move_note CASCADE;

-- Drop indexes
DROP INDEX IF EXISTS notes_parent_project_idx;

-- Remove columns from notes table
ALTER TABLE notes 
DROP COLUMN IF EXISTS position,
DROP COLUMN IF EXISTS parent_id CASCADE;

-- Drop any remaining related tables
DROP TABLE IF EXISTS note_sequences CASCADE;
DROP TABLE IF EXISTS root_notes CASCADE;