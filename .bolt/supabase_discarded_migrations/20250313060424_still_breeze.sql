/*
  # Fix note sequence maintenance

  1. Changes
    - Create new function to properly maintain note sequences
    - Add trigger to ensure sequences stay consistent
    - Fix sequence handling during note movement
    - Prevent reordering on reload

  2. Details
    - Uses transaction-safe operations
    - Maintains proper parent-child relationships
    - Ensures sequences stay sequential and stable
*/

-- Drop existing triggers that might interfere
DROP TRIGGER IF EXISTS maintain_sequences_trigger ON notes;
DROP TRIGGER IF EXISTS maintain_note_positions_trigger ON notes;

-- Create function to normalize sequences for a specific parent
CREATE OR REPLACE FUNCTION normalize_parent_sequences(
  target_project_id uuid,
  target_parent_id uuid DEFAULT NULL
) RETURNS void AS $$
BEGIN
  -- Lock the sequences table to prevent concurrent modifications
  LOCK TABLE note_sequences IN EXCLUSIVE MODE;
  
  -- Update sequences to be sequential starting from 1
  WITH numbered AS (
    SELECT 
      note_id,
      ROW_NUMBER() OVER (
        ORDER BY sequence, note_id -- Include note_id for stable ordering
      ) as new_seq
    FROM note_sequences
    WHERE project_id = target_project_id
    AND parent_id IS NOT DISTINCT FROM target_parent_id
  )
  UPDATE note_sequences ns
  SET sequence = numbered.new_seq
  FROM numbered
  WHERE ns.note_id = numbered.note_id;
END;
$$ LANGUAGE plpgsql;

-- Create improved move_note function
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_parent_id uuid;
  v_old_sequence integer;
BEGIN
  -- Lock tables to prevent concurrent modifications
  LOCK TABLE note_sequences IN EXCLUSIVE MODE;
  LOCK TABLE notes IN SHARE MODE;
  
  -- Get current note info
  SELECT project_id, parent_id, sequence
  INTO v_project_id, v_old_parent_id, v_old_sequence
  FROM note_sequences
  WHERE note_id = p_note_id;
  
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note % not found', p_note_id;
  END IF;

  -- Update parent in notes table
  UPDATE notes
  SET parent_id = p_new_parent_id
  WHERE id = p_note_id;

  -- Remove note from current position
  DELETE FROM note_sequences WHERE note_id = p_note_id;

  -- Make space at new position
  UPDATE note_sequences
  SET sequence = sequence + 1
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM p_new_parent_id
  AND sequence >= p_new_position;

  -- Insert at new position
  INSERT INTO note_sequences (project_id, parent_id, note_id, sequence)
  VALUES (v_project_id, p_new_parent_id, p_note_id, p_new_position);

  -- Normalize sequences for affected parents
  PERFORM normalize_parent_sequences(v_project_id, v_old_parent_id);
  IF v_old_parent_id IS DISTINCT FROM p_new_parent_id THEN
    PERFORM normalize_parent_sequences(v_project_id, p_new_parent_id);
  END IF;

  -- Update last_modified_at timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to maintain sequences
CREATE OR REPLACE FUNCTION maintain_note_sequences()
RETURNS TRIGGER AS $$
DECLARE
  v_project_id uuid;
BEGIN
  -- Get project ID based on operation type
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    v_project_id := NEW.project_id;
  ELSE
    v_project_id := OLD.project_id;
  END IF;

  -- For inserts and updates
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    -- If parent_id changed, normalize sequences for both old and new parents
    IF TG_OP = 'UPDATE' AND OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
      PERFORM normalize_parent_sequences(v_project_id, OLD.parent_id);
      PERFORM normalize_parent_sequences(v_project_id, NEW.parent_id);
    END IF;
  END IF;

  -- For deletes
  IF TG_OP = 'DELETE' THEN
    -- Normalize sequences for the parent that lost a note
    PERFORM normalize_parent_sequences(v_project_id, OLD.parent_id);
  END IF;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to maintain sequences
CREATE TRIGGER maintain_sequences_trigger
  AFTER INSERT OR UPDATE OR DELETE ON notes
  FOR EACH ROW
  EXECUTE FUNCTION maintain_note_sequences();

-- Update cleanup function to use new normalization
CREATE OR REPLACE FUNCTION cleanup_project_sequences(target_project_id uuid)
RETURNS text AS $$
DECLARE
  changes_made text := '';
  orphaned_count integer := 0;
  mismatch_count integer := 0;
  missing_count integer := 0;
BEGIN
  -- Remove orphaned sequences
  WITH deleted AS (
    DELETE FROM note_sequences ns
    WHERE ns.project_id = target_project_id
    AND NOT EXISTS (
      SELECT 1 FROM notes n WHERE n.id = ns.note_id
    )
    RETURNING ns.id
  )
  SELECT COUNT(*) INTO orphaned_count FROM deleted;
  
  IF orphaned_count > 0 THEN
    changes_made := changes_made || format('Removed %s orphaned sequences\n', orphaned_count);
  END IF;

  -- Fix parent mismatches
  WITH updated AS (
    UPDATE note_sequences ns
    SET parent_id = n.parent_id
    FROM notes n
    WHERE ns.project_id = target_project_id
    AND ns.note_id = n.id
    AND ns.parent_id IS DISTINCT FROM n.parent_id
    RETURNING ns.id
  )
  SELECT COUNT(*) INTO mismatch_count FROM updated;
  
  IF mismatch_count > 0 THEN
    changes_made := changes_made || format('Fixed %s parent mismatches\n', mismatch_count);
  END IF;

  -- Add missing sequences
  WITH inserted AS (
    INSERT INTO note_sequences (project_id, parent_id, note_id, sequence)
    SELECT 
      n.project_id,
      n.parent_id,
      n.id,
      COALESCE(
        (
          SELECT MAX(sequence) + 1
          FROM note_sequences
          WHERE project_id = n.project_id
          AND parent_id IS NOT DISTINCT FROM n.parent_id
        ),
        1
      )
    FROM notes n
    WHERE n.project_id = target_project_id
    AND NOT EXISTS (
      SELECT 1 FROM note_sequences ns
      WHERE ns.note_id = n.id
    )
    RETURNING id
  )
  SELECT COUNT(*) INTO missing_count FROM inserted;
  
  IF missing_count > 0 THEN
    changes_made := changes_made || format('Added %s missing sequences\n', missing_count);
  END IF;

  -- Normalize all sequences in the project
  WITH RECURSIVE note_tree AS (
    -- Get all unique parent_ids in the project
    SELECT DISTINCT parent_id
    FROM note_sequences
    WHERE project_id = target_project_id
  )
  SELECT normalize_parent_sequences(target_project_id, parent_id)
  FROM note_tree;

  -- Also normalize root level
  PERFORM normalize_parent_sequences(target_project_id, NULL);

  -- Return status
  IF changes_made = '' THEN
    RETURN 'No issues found, sequences are clean';
  ELSE
    RETURN changes_made || 'All sequences normalized';
  END IF;
END;
$$ LANGUAGE plpgsql;