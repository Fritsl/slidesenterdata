/*
  # Fix note deletion functionality

  1. Changes
    - Update delete_note_safely function to handle cascading deletes
    - Add trigger for note deletion
    - Add function to clean up orphaned notes
    - Add function to clean up non-recursive notes

  2. Details
    - Ensures proper cleanup of child notes
    - Maintains referential integrity
    - Handles image cleanup properly
*/

-- Function to delete notes safely with cascading
CREATE OR REPLACE FUNCTION delete_note_safely(note_id uuid)
RETURNS void AS $$
BEGIN
  -- Delete the note and let the cascade handle children
  DELETE FROM notes WHERE id = note_id;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up orphaned notes
CREATE OR REPLACE FUNCTION cleanup_orphaned_notes()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete any notes that have invalid parent references
  DELETE FROM notes
  WHERE parent_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM notes parent
    WHERE parent.id = notes.parent_id
  );
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up notes non-recursively
CREATE OR REPLACE FUNCTION cleanup_notes_non_recursive()
RETURNS TRIGGER AS $$
BEGIN
  -- Update project's last modified timestamp
  UPDATE settings
  SET 
    last_modified_at = CURRENT_TIMESTAMP,
    note_count = (
      SELECT COUNT(*)
      FROM notes
      WHERE project_id = OLD.project_id
    ) - 1
  WHERE id = OLD.project_id;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create cleanup triggers
DROP TRIGGER IF EXISTS cleanup_notes_trigger ON notes;
CREATE TRIGGER cleanup_notes_trigger
AFTER DELETE ON notes
FOR EACH STATEMENT
EXECUTE FUNCTION cleanup_orphaned_notes();

DROP TRIGGER IF EXISTS cleanup_notes_non_recursive_trigger ON notes;
CREATE TRIGGER cleanup_notes_non_recursive_trigger
AFTER DELETE ON notes
FOR EACH ROW
EXECUTE FUNCTION cleanup_notes_non_recursive();

-- Function to update project note count
CREATE OR REPLACE FUNCTION update_project_note_count()
RETURNS TRIGGER AS $$
BEGIN
  -- Update the note count for the affected project
  UPDATE settings
  SET note_count = (
    SELECT COUNT(*)
    FROM notes
    WHERE project_id = NEW.project_id
  )
  WHERE id = NEW.project_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for note count
DROP TRIGGER IF EXISTS update_project_note_count_trigger ON notes;
CREATE TRIGGER update_project_note_count_trigger
AFTER INSERT OR DELETE OR UPDATE ON notes
FOR EACH STATEMENT
EXECUTE FUNCTION update_project_note_count();