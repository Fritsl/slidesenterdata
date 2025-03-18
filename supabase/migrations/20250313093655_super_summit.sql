/*
  # Simple Hierarchical Notes Structure
  
  1. Tables
    - notes: Core note data with parent-child relationships
      - id (uuid, primary key)
      - content (text)
      - parent_id (uuid, self-referential)
      - project_id (uuid)
      - user_id (uuid)
      - position (integer)
      - created_at (timestamp)
      - updated_at (timestamp)

  2. Features
    - Simple parent-child relationships
    - Basic ordering within each level
    - No complex triggers or sequences
*/

-- Drop any existing related tables to start fresh
DROP TABLE IF EXISTS note_sequences CASCADE;
DROP TABLE IF EXISTS root_notes CASCADE;

-- Ensure notes table has the structure we need
ALTER TABLE notes 
ADD COLUMN IF NOT EXISTS position integer DEFAULT 0;

-- Create index for faster tree traversal
CREATE INDEX IF NOT EXISTS notes_parent_project_idx 
ON notes(parent_id, project_id, position);

-- Function to move notes (simple version)
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
BEGIN
  -- Update the note's parent and position
  UPDATE notes
  SET 
    parent_id = p_new_parent_id,
    position = p_new_position,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_note_id;

  -- Update project's last modified timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = (
    SELECT project_id 
    FROM notes 
    WHERE id = p_note_id
  );
END;
$$ LANGUAGE plpgsql;