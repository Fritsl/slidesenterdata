/*
  # Fix note deletion stack overflow

  1. Changes
    - Replace recursive deletion with iterative batch deletion
    - Process deletions in smaller batches to avoid stack overflow
    - Maintain proper project metadata updates
    - Keep existing triggers and constraints

  2. Details
    - Prevents stack depth exceeded errors
    - Maintains data integrity
    - More efficient for deep hierarchies
*/

-- Drop existing function
DROP FUNCTION IF EXISTS delete_note_safely(uuid);

-- Create new iterative deletion function
CREATE OR REPLACE FUNCTION delete_note_safely(note_id uuid)
RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_batch_size integer := 100;
  v_deleted_count integer;
BEGIN
  -- Get project ID for later use
  SELECT project_id INTO v_project_id
  FROM notes
  WHERE id = note_id;

  -- Keep deleting in batches until no more descendants are found
  LOOP
    WITH RECURSIVE tree AS (
      -- Get the next batch of descendants
      SELECT id, 0 as depth
      FROM notes
      WHERE id = note_id
      
      UNION ALL
      
      SELECT child.id, tree.depth + 1
      FROM notes child
      JOIN tree ON child.parent_id = tree.id
      WHERE tree.depth < 2  -- Limit recursion depth per batch
    )
    DELETE FROM notes
    WHERE id IN (
      SELECT id 
      FROM tree 
      LIMIT v_batch_size
    );
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    EXIT WHEN v_deleted_count = 0;
  END LOOP;

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