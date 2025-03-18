/*
  # Fix note ordering for existing data

  1. Changes
    - Add position column if it doesn't exist
    - Initialize positions for existing notes based on creation date
    - Handle null parent_ids by moving notes to root level
    - Normalize positions to ensure no gaps

  2. Details
    - Preserves existing hierarchical relationships
    - Uses created_at timestamp for initial ordering
    - Handles edge cases safely
*/

-- First ensure position column exists
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'notes' 
    AND column_name = 'position'
  ) THEN
    ALTER TABLE notes ADD COLUMN position integer DEFAULT 0;
  END IF;
END $$;

-- Initialize positions for existing notes
WITH RECURSIVE 
-- First get all notes without positions
unordered_notes AS (
  SELECT 
    id,
    parent_id,
    project_id,
    created_at,
    COALESCE(position, 0) as current_position
  FROM notes
  WHERE position IS NULL OR parent_id IS NULL
),
-- Calculate new positions within each parent group
ordered_notes AS (
  SELECT 
    id,
    parent_id,
    project_id,
    ROW_NUMBER() OVER (
      PARTITION BY project_id, parent_id 
      ORDER BY created_at, id
    ) - 1 as new_position
  FROM unordered_notes
)
UPDATE notes n
SET 
  position = o.new_position,
  -- Move orphaned notes (null parent_id) to root level
  parent_id = CASE 
    WHEN n.parent_id IS NULL AND EXISTS (
      SELECT 1 FROM notes p 
      WHERE p.id = n.parent_id
    ) THEN n.parent_id
    ELSE NULL
  END
FROM ordered_notes o
WHERE n.id = o.id;

-- Create function to normalize positions if needed
CREATE OR REPLACE FUNCTION normalize_positions(
  p_project_id uuid,
  p_parent_id uuid DEFAULT NULL
) RETURNS void AS $$
DECLARE
  v_position integer := 0;
  v_note_id uuid;
BEGIN
  FOR v_note_id IN (
    SELECT id
    FROM notes
    WHERE project_id = p_project_id
    AND parent_id IS NOT DISTINCT FROM p_parent_id
    ORDER BY position, created_at, id
  ) LOOP
    UPDATE notes
    SET position = v_position
    WHERE id = v_note_id;
    
    v_position := v_position + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Normalize positions for all existing notes
DO $$
DECLARE
  v_project_id uuid;
  v_parent_id uuid;
BEGIN
  -- First normalize root level notes for each project
  FOR v_project_id IN (SELECT DISTINCT project_id FROM notes) LOOP
    PERFORM normalize_positions(v_project_id, NULL);
    
    -- Then normalize each parent's children
    FOR v_parent_id IN (
      SELECT DISTINCT id 
      FROM notes 
      WHERE project_id = v_project_id 
      AND EXISTS (
        SELECT 1 FROM notes 
        WHERE parent_id = notes.id
      )
    ) LOOP
      PERFORM normalize_positions(v_project_id, v_parent_id);
    END LOOP;
  END LOOP;
END $$;