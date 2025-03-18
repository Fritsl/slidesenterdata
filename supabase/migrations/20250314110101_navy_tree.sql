-- Drop existing function
DROP FUNCTION IF EXISTS delete_note_safely(uuid);

-- Create new deletion function with logging
CREATE OR REPLACE FUNCTION delete_note_safely(note_id uuid)
RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_note_count integer;
  v_parent_id uuid;
BEGIN
  -- Log start of deletion
  RAISE NOTICE 'Starting note deletion for note_id: %', note_id;

  -- Get note info for logging
  SELECT project_id, parent_id
  INTO v_project_id, v_parent_id
  FROM notes
  WHERE id = note_id;

  RAISE NOTICE 'Note info - project_id: %, parent_id: %', v_project_id, v_parent_id;

  -- Count children before deletion
  WITH RECURSIVE descendants AS (
    SELECT id FROM notes WHERE id = note_id
    UNION ALL
    SELECT n.id FROM notes n
    INNER JOIN descendants d ON n.parent_id = d.id
  )
  SELECT COUNT(*) INTO v_note_count FROM descendants;

  RAISE NOTICE 'Found % notes to delete (including descendants)', v_note_count;

  -- Delete the note and its descendants
  WITH RECURSIVE descendants AS (
    SELECT id FROM notes WHERE id = note_id
    UNION ALL
    SELECT n.id FROM notes n
    INNER JOIN descendants d ON n.parent_id = d.id
  )
  DELETE FROM notes
  WHERE id IN (SELECT id FROM descendants);

  -- Get number of affected rows
  GET DIAGNOSTICS v_note_count = ROW_COUNT;
  RAISE NOTICE 'Deleted % notes', v_note_count;

  -- Update project metadata
  IF v_project_id IS NOT NULL THEN
    RAISE NOTICE 'Updating project metadata for project_id: %', v_project_id;
    
    UPDATE settings
    SET 
      last_modified_at = CURRENT_TIMESTAMP,
      note_count = (
        SELECT COUNT(*)
        FROM notes
        WHERE project_id = v_project_id
      )
    WHERE id = v_project_id;
    
    RAISE NOTICE 'Project metadata updated';
  END IF;

  RAISE NOTICE 'Note deletion completed successfully';
END;
$$ LANGUAGE plpgsql;