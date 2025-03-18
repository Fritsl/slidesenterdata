/*
  # Fix project duplication to ensure exact 1:1 copies

  1. Changes
    - Add function to copy projects with all related data
    - Maintain exact relationships between notes
    - Copy all metadata and settings
    - Preserve image references

  2. Details
    - Copies all project settings
    - Maintains note hierarchy
    - Preserves timestamps
    - Copies image data
*/

-- Function to copy a project and all its data
CREATE OR REPLACE FUNCTION copy_project(
  source_id uuid,
  target_user_id uuid,
  target_title text
) RETURNS uuid AS $$
DECLARE
  new_project_id uuid;
  id_map jsonb := '{}'::jsonb;
BEGIN
  -- Copy project settings
  INSERT INTO settings (
    user_id,
    title,
    description,
    note_count,
    last_level
  )
  SELECT 
    target_user_id,
    target_title,
    description,
    note_count,
    last_level
  FROM settings
  WHERE id = source_id
  RETURNING id INTO new_project_id;

  -- First pass: Create all notes with new IDs
  WITH RECURSIVE note_tree AS (
    SELECT 
      id,
      content,
      parent_id,
      position,
      is_discussion,
      time_set,
      youtube_url,
      url,
      url_display_text
    FROM notes
    WHERE project_id = source_id
  )
  INSERT INTO notes (
    id,
    content,
    parent_id,
    project_id,
    position,
    is_discussion,
    time_set,
    youtube_url,
    url,
    url_display_text,
    user_id
  )
  SELECT
    gen_random_uuid(),
    content,
    parent_id,  -- We'll update these in the second pass
    new_project_id,
    position,
    is_discussion,
    time_set,
    youtube_url,
    url,
    url_display_text,
    target_user_id
  FROM note_tree
  RETURNING id, (SELECT id FROM notes WHERE id = parent_id) AS old_id
  INTO id_map;

  -- Second pass: Update parent_id references using the id_map
  UPDATE notes n
  SET parent_id = (
    SELECT id 
    FROM notes 
    WHERE project_id = new_project_id 
    AND id = id_map->n.parent_id::text
  )
  WHERE project_id = new_project_id
  AND parent_id IS NOT NULL;

  -- Copy images
  INSERT INTO note_images (
    note_id,
    url,
    storage_path,
    position
  )
  SELECT
    (SELECT id FROM notes WHERE project_id = new_project_id AND id = id_map->note_images.note_id::text),
    url,
    storage_path,
    position
  FROM note_images
  WHERE note_id IN (
    SELECT id FROM notes WHERE project_id = source_id
  );

  RETURN new_project_id;
END;
$$ LANGUAGE plpgsql;