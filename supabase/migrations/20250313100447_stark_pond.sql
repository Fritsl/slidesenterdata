/*
  # Add note hierarchy support

  1. Changes
    - Add parent_id to notes table
    - Add position column for ordering
    - Add move_note function
    - Add indexes for performance

  2. Details
    - Enables parent-child relationships
    - Maintains order within each level
    - Handles moves safely
*/

-- Add hierarchy columns to notes
ALTER TABLE notes 
ADD COLUMN parent_id uuid REFERENCES notes(id) ON DELETE CASCADE,
ADD COLUMN position integer DEFAULT 0;

-- Create indexes for performance
CREATE INDEX notes_parent_id_idx ON notes(parent_id);
CREATE INDEX notes_parent_position_idx ON notes(parent_id, position);

-- Function to move notes
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_parent_id uuid;
  v_old_position integer;
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, position
  INTO v_project_id, v_old_parent_id, v_old_position
  FROM notes
  WHERE id = p_note_id;

  -- Validate move
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

  -- Make space at target position
  UPDATE notes
  SET position = position + 1
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM p_new_parent_id
  AND position >= p_new_position;

  -- Move the note
  UPDATE notes
  SET 
    parent_id = p_new_parent_id,
    position = p_new_position,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_note_id;

  -- Close gap at old position
  UPDATE notes
  SET position = position - 1
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM v_old_parent_id
  AND position > v_old_position;

  -- Update project's last modified timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;