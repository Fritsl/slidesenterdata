/*
  # Fix note ordering in project copy
  
  1. Changes
    - Update copy_project function to preserve note ordering
    - Use WITH RECURSIVE to maintain hierarchy
    - Order notes by position during copy
    - Maintain parent-child relationships
    
  2. Details
    - Ensures notes are copied in correct order
    - Preserves hierarchical structure
    - Maintains position values
*/

-- Drop existing function
DROP FUNCTION IF EXISTS copy_project(uuid, uuid, text);

-- Create improved function with proper note ordering
CREATE OR REPLACE FUNCTION copy_project(
  source_id uuid,
  target_user_id uuid,
  target_title text
) RETURNS uuid AS $$
DECLARE
  new_project_id uuid;
  id_map jsonb := '{}'::jsonb;
  validated_title text;
  base_title text;
  max_suffix_length integer := 10; -- Length of " (Copy 99)"
  max_base_length integer := 185;  -- 200 - max_suffix_length - 5 (safety margin)
  counter integer := 1;
  truncation_point integer;
  v_note_count integer;
BEGIN
  -- Get source project title if target title is null or empty
  IF target_title IS NULL OR TRIM(target_title) = '' THEN
    SELECT title INTO target_title
    FROM settings
    WHERE id = source_id;
  END IF;

  -- Prepare base title
  base_title := TRIM(target_title);
  IF base_title = '' THEN
    base_title := 'New Project';
  END IF;

  -- Smart truncation if needed
  IF LENGTH(base_title) > max_base_length THEN
    -- Try to truncate at a word boundary
    truncation_point := max_base_length;
    WHILE truncation_point > max_base_length - 20 AND -- Look back up to 20 chars
          SUBSTRING(base_title FROM truncation_point FOR 1) != ' ' LOOP
      truncation_point := truncation_point - 1;
    END LOOP;
    
    -- If no word boundary found, use hard truncation
    IF truncation_point <= max_base_length - 20 THEN
      truncation_point := max_base_length;
    END IF;
    
    base_title := TRIM(SUBSTRING(base_title FROM 1 FOR truncation_point));
    
    -- Add ellipsis if we truncated
    IF LENGTH(base_title) < LENGTH(target_title) THEN
      base_title := base_title || '...';
    END IF;
  END IF;

  -- Initial title attempt
  validated_title := base_title || ' (Copy)';
  
  -- Ensure unique title
  WHILE EXISTS (
    SELECT 1 FROM settings 
    WHERE user_id = target_user_id 
    AND title = validated_title
    AND deleted_at IS NULL
  ) LOOP
    validated_title := base_title || ' (Copy ' || counter || ')';
    counter := counter + 1;
  END LOOP;

  -- Get actual note count from source project
  SELECT COUNT(*) INTO v_note_count
  FROM notes
  WHERE project_id = source_id;

  -- Copy project settings with actual note count
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
    v_note_count,
    last_level
  FROM settings
  WHERE id = source_id
  RETURNING id INTO new_project_id;

  -- First pass: Create all notes with new IDs, maintaining hierarchy and order
  WITH RECURSIVE note_hierarchy AS (
    -- Base case: Get root level notes
    SELECT 
      id,
      content,
      parent_id,
      position,
      is_discussion,
      time_set,
      youtube_url,
      url,
      url_display_text,
      0 as level,
      position::text as path
    FROM notes
    WHERE project_id = source_id
    AND parent_id IS NULL
    
    UNION ALL
    
    -- Recursive case: Get child notes
    SELECT 
      c.id,
      c.content,
      c.parent_id,
      c.position,
      c.is_discussion,
      c.time_set,
      c.youtube_url,
      c.url,
      c.url_display_text,
      p.level + 1,
      p.path || '.' || LPAD(c.position::text, 10, '0')
    FROM notes c
    JOIN note_hierarchy p ON c.parent_id = p.id
    WHERE c.project_id = source_id
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
    parent_id,
    new_project_id,
    position,
    is_discussion,
    time_set,
    youtube_url,
    url,
    url_display_text,
    target_user_id
  FROM note_hierarchy
  ORDER BY path -- This ensures correct hierarchical order
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

  -- Copy images, maintaining their order
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
  )
  ORDER BY note_id, position;

  -- Verify note count matches
  IF (
    SELECT COUNT(*) FROM notes WHERE project_id = new_project_id
  ) != v_note_count THEN
    RAISE WARNING 'Note count mismatch after copy';
  END IF;

  RETURN new_project_id;
END;
$$ LANGUAGE plpgsql;