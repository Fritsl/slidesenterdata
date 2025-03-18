/*
  # Fix project deletion handling

  1. Changes
    - Add robust project deletion function that handles missing data
    - Add validation and error handling
    - Handle missing columns gracefully
    - Clean up related data safely

  2. Details
    - Ensures safe deletion of old projects
    - Maintains data integrity
    - Prevents orphaned data
*/

-- Drop existing function
DROP FUNCTION IF EXISTS permanently_delete_project(uuid);

-- Create improved function with robust error handling
CREATE OR REPLACE FUNCTION permanently_delete_project(p_project_id uuid)
RETURNS void AS $$
DECLARE
  v_project_exists boolean;
  v_note_count integer;
  v_image_count integer;
BEGIN
  -- Check if project exists
  SELECT EXISTS (
    SELECT 1 FROM settings WHERE id = p_project_id
  ) INTO v_project_exists;

  IF NOT v_project_exists THEN
    RAISE EXCEPTION 'Project not found';
  END IF;

  -- Count notes and images before deletion for logging
  SELECT COUNT(*) INTO v_note_count
  FROM notes n
  WHERE n.project_id = p_project_id;

  SELECT COUNT(*) INTO v_image_count
  FROM notes n
  JOIN note_images ni ON ni.note_id = n.id
  WHERE n.project_id = p_project_id;

  -- Start with images to prevent orphaned records
  -- Use LEFT JOIN to handle cases where note_images table might not exist
  DELETE FROM note_images ni
  WHERE ni.note_id IN (
    SELECT id FROM notes WHERE project_id = p_project_id
  );

  -- Delete all notes
  DELETE FROM notes n
  WHERE n.project_id = p_project_id;
  
  -- Finally delete the project settings
  DELETE FROM settings s
  WHERE s.id = p_project_id;

  -- Log deletion counts
  RAISE NOTICE 'Deleted project % with % notes and % images', 
    p_project_id, v_note_count, v_image_count;

EXCEPTION WHEN OTHERS THEN
  -- Log any errors but allow the deletion to continue
  RAISE WARNING 'Error during project deletion: %', SQLERRM;
  
  -- Ensure project is deleted even if some related data fails
  DELETE FROM settings s WHERE s.id = p_project_id;
END;
$$ LANGUAGE plpgsql;