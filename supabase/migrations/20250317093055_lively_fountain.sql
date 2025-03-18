/*
  # Fix project deletion function

  1. Changes
    - Fix ambiguous column reference in permanently_delete_project function
    - Use table aliases to clarify column references
    - Maintain existing functionality

  2. Details
    - Ensures proper cascading deletion
    - Maintains data integrity
    - Fixes SQL error
*/

-- Drop existing function
DROP FUNCTION IF EXISTS permanently_delete_project(uuid);

-- Create improved function with proper column references
CREATE OR REPLACE FUNCTION permanently_delete_project(p_project_id uuid)
RETURNS void AS $$
BEGIN
  -- Delete all notes first (this will cascade to note_images)
  DELETE FROM notes n
  WHERE n.project_id = p_project_id;
  
  -- Delete the project settings
  DELETE FROM settings s
  WHERE s.id = p_project_id;
END;
$$ LANGUAGE plpgsql;