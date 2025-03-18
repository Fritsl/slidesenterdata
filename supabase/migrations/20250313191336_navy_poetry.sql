/*
  # Fix image storage and handling

  1. Changes
    - Create storage bucket with proper configuration
    - Set up RLS policies for image access
    - Add triggers for image cleanup
    - Add position handling for images
    - Fix storage path handling

  2. Details
    - Ensures proper image storage
    - Maintains data integrity
    - Handles cleanup automatically
*/

-- Create the storage bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('note-images', 'note-images', true)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies
DROP POLICY IF EXISTS "Allow public read access" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes" ON storage.objects;

-- Create policies for the note-images bucket
CREATE POLICY "Allow public read access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'note-images');

CREATE POLICY "Allow authenticated uploads"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'note-images'
  AND (LOWER(storage.extension(name)) = 'jpg' OR LOWER(storage.extension(name)) = 'jpeg' OR LOWER(storage.extension(name)) = 'png')
);

CREATE POLICY "Allow authenticated deletes"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'note-images');

-- Add position column to note_images if it doesn't exist
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

-- Function to delete storage object when image is deleted
CREATE OR REPLACE FUNCTION delete_storage_object()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete from storage if storage_path exists
  IF OLD.storage_path IS NOT NULL THEN
    PERFORM storage.delete('note-images', OLD.storage_path);
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to delete storage objects
DROP TRIGGER IF EXISTS delete_storage_object_trigger ON note_images;
CREATE TRIGGER delete_storage_object_trigger
BEFORE DELETE ON note_images
FOR EACH ROW
EXECUTE FUNCTION delete_storage_object();

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