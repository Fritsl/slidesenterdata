-- Function to copy a project with proper time handling
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
  max_suffix_length integer := 10;
  max_base_length integer := 185;
  counter integer := 1;
  truncation_point integer;
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
    truncation_point := max_base_length;
    WHILE truncation_point > max_base_length - 20 AND
          SUBSTRING(base_title FROM truncation_point FOR 1) != ' ' LOOP
      truncation_point := truncation_point - 1;
    END LOOP;
    
    IF truncation_point <= max_base_length - 20 THEN
      truncation_point := max_base_length;
    END IF;
    
    base_title := TRIM(SUBSTRING(base_title FROM 1 FOR truncation_point));
    
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

  -- Copy project settings
  INSERT INTO settings (
    user_id,
    title,
    description,
    last_level
  )
  SELECT 
    target_user_id,
    validated_title,
    description,
    last_level
  FROM settings
  WHERE id = source_id
  RETURNING id INTO new_project_id;

  -- First pass: Copy root level notes
  INSERT INTO notes (
    id,
    content,
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
    new_project_id,
    position,
    is_discussion,
    time_set,  -- Explicitly copy time_set
    youtube_url,
    url,
    url_display_text,
    target_user_id
  FROM notes
  WHERE project_id = source_id
  AND parent_id IS NULL
  ORDER BY position
  RETURNING id, content AS old_id
  INTO id_map;

  -- Second pass: Copy child notes level by level
  WITH RECURSIVE children AS (
    -- Base case: direct children of copied notes
    SELECT 
      n.id,
      n.content,
      n.parent_id,
      n.position,
      n.is_discussion,
      n.time_set,  -- Include time_set
      n.youtube_url,
      n.url,
      n.url_display_text,
      1 as level
    FROM notes n
    WHERE n.project_id = source_id
    AND n.parent_id IN (
      SELECT id FROM notes WHERE project_id = source_id AND parent_id IS NULL
    )
    
    UNION ALL
    
    -- Recursive case: next level of children
    SELECT 
      n.id,
      n.content,
      n.parent_id,
      n.position,
      n.is_discussion,
      n.time_set,  -- Include time_set
      n.youtube_url,
      n.url,
      n.url_display_text,
      c.level + 1
    FROM notes n
    JOIN children c ON n.parent_id = c.id
    WHERE n.project_id = source_id
  )
  INSERT INTO notes (
    id,
    content,
    parent_id,
    project_id,
    position,
    is_discussion,
    time_set,  -- Include time_set in insert
    youtube_url,
    url,
    url_display_text,
    user_id
  )
  SELECT
    gen_random_uuid(),
    c.content,
    (
      SELECT n.id 
      FROM notes n 
      WHERE n.project_id = new_project_id 
      AND n.content = (
        SELECT content 
        FROM notes 
        WHERE id = c.parent_id
      )
      LIMIT 1
    ),
    new_project_id,
    c.position,
    c.is_discussion,
    c.time_set,  -- Copy time_set value
    c.youtube_url,
    c.url,
    c.url_display_text,
    target_user_id
  FROM children c
  ORDER BY c.level, c.parent_id, c.position;

  -- Copy images
  INSERT INTO note_images (
    note_id,
    url,
    storage_path,
    position
  )
  SELECT
    (
      SELECT n.id 
      FROM notes n 
      WHERE n.project_id = new_project_id 
      AND n.content = (
        SELECT content 
        FROM notes 
        WHERE id = note_images.note_id
      )
      LIMIT 1
    ),
    url,
    storage_path,
    position
  FROM note_images
  WHERE note_id IN (
    SELECT id FROM notes WHERE project_id = source_id
  )
  ORDER BY note_id, position;

  RETURN new_project_id;
END;
$$ LANGUAGE plpgsql;