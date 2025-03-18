
-- Drop existing triggers and functions
DROP TRIGGER IF EXISTS ensure_note_position ON notes;
DROP FUNCTION IF EXISTS set_initial_position();
DROP FUNCTION IF EXISTS move_note();

-- Add position constraints
ALTER TABLE notes ADD CONSTRAINT valid_position CHECK (position >= 0);

-- Create function to handle note movement with proper position management
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_old_parent_id uuid;
  v_old_position integer;
  v_project_id uuid;
BEGIN
  -- Get current note info
  SELECT parent_id, position, project_id 
  INTO v_old_parent_id, v_old_position, v_project_id
  FROM notes 
  WHERE id = p_note_id;

  -- Update positions in old parent
  UPDATE notes 
  SET position = position - 1
  WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM v_old_parent_id
    AND position > v_old_position;

  -- Update positions in new parent
  UPDATE notes 
  SET position = position + 1
  WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM p_new_parent_id
    AND position >= p_new_position;

  -- Move the note
  UPDATE notes 
  SET parent_id = p_new_parent_id,
      position = p_new_position
  WHERE id = p_note_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to maintain positions on delete
CREATE OR REPLACE FUNCTION maintain_positions_on_delete()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE notes 
  SET position = position - 1
  WHERE project_id = OLD.project_id
    AND parent_id IS NOT DISTINCT FROM OLD.parent_id
    AND position > OLD.position;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER maintain_positions_on_delete
BEFORE DELETE ON notes
FOR EACH ROW
EXECUTE FUNCTION maintain_positions_on_delete();
