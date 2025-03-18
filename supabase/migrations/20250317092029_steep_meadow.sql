/*
  # Add trash can functionality
  
  1. Changes
    - Add function to restore deleted projects
    - Add function to permanently delete projects
    - Add RLS policy for viewing deleted projects
    
  2. Details
    - Allows viewing soft-deleted projects
    - Enables project restoration
    - Maintains data integrity
*/

-- Add policy to allow viewing deleted projects
CREATE POLICY "Users can view their own deleted projects"
ON settings FOR SELECT
TO authenticated
USING (
  user_id = auth.uid() 
  AND deleted_at IS NOT NULL
);

-- Function to restore a deleted project
CREATE OR REPLACE FUNCTION restore_project(project_id uuid)
RETURNS void AS $$
DECLARE
  v_user_id uuid;
  v_title text;
  v_unique_title text;
  v_counter integer := 1;
BEGIN
  -- Get project info
  SELECT user_id, title INTO v_user_id, v_title
  FROM settings
  WHERE id = project_id;

  -- Prepare unique title
  v_unique_title := v_title;
  WHILE EXISTS (
    SELECT 1 FROM settings
    WHERE user_id = v_user_id
    AND title = v_unique_title
    AND deleted_at IS NULL
  ) LOOP
    v_unique_title := v_title || ' (Restored ' || v_counter || ')';
    v_counter := v_counter + 1;
  END LOOP;

  -- Restore the project
  UPDATE settings
  SET 
    deleted_at = NULL,
    title = v_unique_title,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = project_id;
END;
$$ LANGUAGE plpgsql;

-- Function to permanently delete a project
CREATE OR REPLACE FUNCTION permanently_delete_project(project_id uuid)
RETURNS void AS $$
BEGIN
  -- Delete all notes first (this will cascade to note_images)
  DELETE FROM notes WHERE project_id = project_id;
  
  -- Delete the project settings
  DELETE FROM settings WHERE id = project_id;
END;
$$ LANGUAGE plpgsql;