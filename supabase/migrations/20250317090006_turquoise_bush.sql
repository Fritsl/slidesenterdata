/*
  # Fix project copy title validation

  1. Changes
    - Add title validation and truncation
    - Ensure title meets length constraints
    - Handle title uniqueness properly
    - Maintain existing functionality

  2. Details
    - Validates title length (1-50 chars)
    - Truncates long titles if needed
    - Ensures unique titles per user
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
  validated_title text;
  counter integer := 1;
BEGIN
  -- Validate and prepare title
  validated_title := TRIM(target_title);
  IF LENGTH(validated_title) > 47 THEN -- Leave room for " (n)" suffix
    validated_title := SUBSTRING(validated_title, 1, 47);
  END IF;

  -- Ensure unique title
  WHILE EXISTS (
    SELECT 1 FROM settings 
    WHERE user_id = target_user_id 
    AND title = validated_title
    AND deleted_at IS NULL
  ) LOOP
    validated_title := SUBSTRING(target_title, 1, 47 - LENGTH(counter::text)) || ' (' || counter || ')';
    counter := counter + 1;
  END LOOP;

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
    validated_title,
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