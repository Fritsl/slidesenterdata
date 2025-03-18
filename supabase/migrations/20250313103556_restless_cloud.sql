/*
  # Fix root note movement and ordering

  1. Changes
    - Add proper root note handling
    - Fix position handling for root level notes
    - Add validation to prevent invalid moves
    - Add function to reorder notes at any level

  2. Details
    - Ensures root notes can be moved and reordered
    - Maintains proper ordering at all levels
    - Prevents invalid states
*/

-- Function to move notes with proper root handling
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_parent_id uuid;
  v_old_position integer;
  v_max_position integer;
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, position
  INTO v_project_id, v_old_parent_id, v_old_position
  FROM notes
  WHERE id = p_note_id;

  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note not found';
  END IF;

  -- Get max position at target level
  SELECT COALESCE(MAX(position), -1)
  INTO v_max_position
  FROM notes
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM p_new_parent_id;

  -- Validate position
  IF p_new_position < 0 THEN
    p_new_position := 0;
  ELSIF p_new_position > v_max_position + 1 THEN
    p_new_position := v_max_position + 1;
  END IF;

  -- Validate parent if not moving to root
  IF p_new_parent_id IS NOT NULL THEN
    -- Check parent exists and is in same project
    IF NOT EXISTS (
      SELECT 1 FROM notes 
      WHERE id = p_new_parent_id 
      AND project_id = v_project_id
    ) THEN
      RAISE EXCEPTION 'Invalid parent note';
    END IF;
    
    -- Check for circular reference
    IF p_new_parent_id = p_note_id OR EXISTS (
      WITH RECURSIVE descendants AS (
        SELECT id FROM notes WHERE parent_id = p_note_id
        UNION ALL
        SELECT n.id FROM notes n
        INNER JOIN descendants d ON n.parent_id = d.id
      )
      SELECT 1 FROM descendants WHERE id = p_new_parent_id
    ) THEN
      RAISE EXCEPTION 'Circular reference detected';
    END IF;
  END IF;

  -- Handle position updates
  IF v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id THEN
    -- Moving within same level
    IF v_old_position < p_new_position THEN
      -- Moving forward
      UPDATE notes
      SET position = position - 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND position > v_old_position
      AND position <= p_new_position;
    ELSE
      -- Moving backward
      UPDATE notes
      SET position = position + 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND position >= p_new_position
      AND position < v_old_position;
    END IF;
  ELSE
    -- Moving to different level
    -- Close gap at old position
    UPDATE notes
    SET position = position - 1
    WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM v_old_parent_id
    AND position > v_old_position;

    -- Make space at new position
    UPDATE notes
    SET position = position + 1
    WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM p_new_parent_id
    AND position >= p_new_position;
  END IF;

  -- Update the note's position and parent
  UPDATE notes
  SET 
    parent_id = p_new_parent_id,
    position = p_new_position,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_note_id;

  -- Update project's last modified timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;

-- Function to normalize positions at any level
CREATE OR REPLACE FUNCTION normalize_positions(
  p_project_id uuid,
  p_parent_id uuid DEFAULT NULL
) RETURNS void AS $$
DECLARE
  v_position integer := 0;
  r RECORD;
BEGIN
  FOR r IN (
    SELECT id
    FROM notes
    WHERE project_id = p_project_id
    AND parent_id IS NOT DISTINCT FROM p_parent_id
    ORDER BY position
  ) LOOP
    UPDATE notes
    SET position = v_position
    WHERE id = r.id;
    
    v_position := v_position + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;