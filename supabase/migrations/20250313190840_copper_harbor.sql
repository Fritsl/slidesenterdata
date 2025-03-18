/*
  # Fix image upload functionality

  1. Changes
    - Add position column to note_images if not exists
    - Add proper indexes for performance
    - Add trigger to maintain image positions
    - Add cleanup function for orphaned images

  2. Details
    - Ensures proper ordering of images
    - Maintains data integrity
    - Improves query performance
*/

-- Add position column if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM information_schema.columns 
    WHERE table_name = 'note_images' 
    AND column_name = 'position'
  ) THEN
    ALTER TABLE note_images ADD COLUMN position integer DEFAULT 0;
  END IF;
END $$;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS note_images_note_id_position_idx ON note_images(note_id, position);

-- Function to maintain image positions
CREATE OR REPLACE FUNCTION maintain_image_positions()
RETURNS TRIGGER AS $$
DECLARE
  v_max_position integer;
BEGIN
  -- Get max position for the note
  SELECT COALESCE(MAX(position), -1)
  INTO v_max_position
  FROM note_images
  WHERE note_id = NEW.note_id;
  
  -- Set position to max + 1
  NEW.position := v_max_position + 1;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for new images
DROP TRIGGER IF EXISTS maintain_image_positions_trigger ON note_images;
CREATE TRIGGER maintain_image_positions_trigger
BEFORE INSERT ON note_images
FOR EACH ROW
EXECUTE FUNCTION maintain_image_positions();

-- Function to clean up orphaned images
CREATE OR REPLACE FUNCTION cleanup_orphaned_images()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete any images that no longer have an associated note
  DELETE FROM note_images
  WHERE note_id IN (
    SELECT note_images.note_id 
    FROM note_images
    LEFT JOIN notes ON notes.id = note_images.note_id
    WHERE notes.id IS NULL
  );
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically clean up orphaned images
DROP TRIGGER IF EXISTS cleanup_images_trigger ON notes;
CREATE TRIGGER cleanup_images_trigger
AFTER DELETE ON notes
FOR EACH STATEMENT
EXECUTE FUNCTION cleanup_orphaned_images();

-- Initialize positions for existing images
WITH ordered_images AS (
  SELECT 
    id,
    note_id,
    ROW_NUMBER() OVER (
      PARTITION BY note_id 
      ORDER BY created_at, id
    ) - 1 as new_position
  FROM note_images
)
UPDATE note_images ni
SET position = oi.new_position
FROM ordered_images oi
WHERE ni.id = oi.id;