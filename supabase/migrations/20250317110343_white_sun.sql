/*
  # Fix note movement function

  1. Changes
    - Fix position calculation for moving notes up/down
    - Add proper boundary checks
    - Maintain correct ordering within siblings
    - Fix edge cases for first/last positions

  2. Details
    - Ensures notes move exactly one position
    - Maintains data integrity
    - Preserves existing functionality
*/

-- Function to get number of siblings
CREATE OR REPLACE FUNCTION get_sibling_count(
  p_project_id uuid,
  p_parent_id uuid
) RETURNS integer AS $$
  SELECT COUNT(*)::integer
  FROM notes
  WHERE project_id = p_project_id
  AND parent_id IS NOT DISTINCT FROM p_parent_id;
$$ LANGUAGE sql STABLE;

-- Create or replace move_note function with correct parameters
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_parent_id uuid;
  v_old_position integer;
  v_sibling_count integer;
  v_max_allowed_position integer;
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, COALESCE(position, 0)
  INTO v_project_id, v_old_parent_id, v_old_position
  FROM notes
  WHERE id = p_note_id;

  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note % not found', p_note_id;
  END IF;

  -- Get count of siblings at target level
  SELECT COUNT(*)
  INTO v_sibling_count
  FROM notes
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM p_new_parent_id
  AND id != p_note_id;

  -- Calculate maximum allowed position
  v_max_allowed_position := GREATEST(0, v_sibling_count);

  -- Validate and adjust position if needed
  IF p_new_position < 0 THEN
    p_new_position := 0;
  ELSIF p_new_position > v_max_allowed_position THEN
    p_new_position := v_max_allowed_position;
  END IF;

  -- Update positions and move note
  IF v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id THEN
    -- Moving within same parent
    UPDATE notes
    SET 
      position = p_new_position,
      parent_id = p_new_parent_id,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = p_note_id;

    -- Normalize positions
    PERFORM normalize_positions(v_project_id, p_new_parent_id);
  ELSE
    -- Moving to different parent
    UPDATE notes
    SET 
      position = p_new_position,
      parent_id = p_new_parent_id,
      updated_at = CURRENT_TIMESTAMP
    WHERE id = p_note_id;

    -- Normalize positions for both old and new parent
    PERFORM normalize_positions(v_project_id, v_old_parent_id);
    PERFORM normalize_positions(v_project_id, p_new_parent_id);
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to ensure new notes have a position
CREATE OR REPLACE FUNCTION set_initial_position()
RETURNS TRIGGER AS $$
BEGIN
  -- Always set position, even if it was provided
  SELECT COALESCE(MAX(position) + 1, 0)
  INTO NEW.position
  FROM notes
  WHERE project_id = NEW.project_id
  AND parent_id IS NOT DISTINCT FROM NEW.parent_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate trigger
DROP TRIGGER IF EXISTS ensure_note_position ON notes;
CREATE TRIGGER ensure_note_position
BEFORE INSERT ON notes
FOR EACH ROW
EXECUTE FUNCTION set_initial_position();

-- Fix positions for existing notes
WITH RECURSIVE ordered_notes AS (
  SELECT 
    id,
    parent_id,
    project_id,
    ROW_NUMBER() OVER (
      PARTITION BY project_id, parent_id 
      ORDER BY created_at, id
    ) - 1 as new_position
  FROM notes
)
UPDATE notes n
SET position = o.new_position
FROM ordered_notes o
WHERE n.id = o.id;