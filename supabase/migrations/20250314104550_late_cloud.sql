/*
  # Fix note deletion stack overflow

  1. Changes
    - Drop existing function first to avoid naming conflicts
    - Create new non-recursive deletion function
    - Use WITH RECURSIVE for efficient descendant fetching
    - Update project metadata after deletion

  2. Details
    - Prevents stack overflow on deep hierarchies
    - Maintains data integrity
    - Preserves existing functionality
*/

-- Drop the existing function first
DROP FUNCTION IF EXISTS delete_note_safely(uuid);

-- Create new non-recursive deletion function
CREATE OR REPLACE FUNCTION delete_note_safely(note_id uuid)
RETURNS void AS $$
DECLARE
  v_project_id uuid;
BEGIN
  -- Get project ID for later use
  SELECT project_id INTO v_project_id
  FROM notes
  WHERE id = note_id;

  -- Delete the note and all its descendants in a single operation
  WITH RECURSIVE descendants AS (
    -- Base case: the note itself
    SELECT id
    FROM notes
    WHERE id = note_id
    
    UNION
    
    -- Recursive case: all children
    SELECT n.id
    FROM notes n
    INNER JOIN descendants d ON n.parent_id = d.id
  )
  DELETE FROM notes
  WHERE id IN (SELECT id FROM descendants);

  -- Update project's last modified timestamp and note count
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