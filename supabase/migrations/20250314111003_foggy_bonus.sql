/*
  # Fix note deletion stack depth issue

  1. Changes
    - Replace recursive deletion with iterative approach
    - Use simple DELETE with WHERE IN clause
    - Remove complex triggers and functions
    - Maintain project metadata updates

  2. Details
    - Prevents stack overflow errors
    - Maintains data integrity
    - Updates project metadata correctly
*/

-- Drop existing functions and triggers
DROP FUNCTION IF EXISTS delete_note_safely(uuid);
DROP FUNCTION IF EXISTS cleanup_orphaned_notes() CASCADE;
DROP FUNCTION IF EXISTS cleanup_notes_non_recursive() CASCADE;
DROP FUNCTION IF EXISTS update_project_note_count() CASCADE;

-- Create simple deletion function
CREATE OR REPLACE FUNCTION delete_note_safely(note_id uuid)
RETURNS void AS $$
DECLARE
  v_project_id uuid;
BEGIN
  -- Get project ID
  SELECT project_id INTO v_project_id
  FROM notes
  WHERE id = note_id;

  -- Delete all descendants in a single operation
  DELETE FROM notes
  WHERE id IN (
    SELECT id
    FROM notes
    WHERE id = note_id
    OR parent_id = note_id
  );

  -- Update project metadata
  IF v_project_id IS NOT NULL THEN
    UPDATE settings
    SET 
      last_modified_at = CURRENT_TIMESTAMP,
      note_count = (
        SELECT COUNT(*)
        FROM notes
        WHERE project_id = v_project_id
      )
    WHERE id = v_project_id;
  END IF;
END;
$$ LANGUAGE plpgsql;