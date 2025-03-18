-- Create the storage bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('note-images', 'note-images', true)
ON CONFLICT (id) DO UPDATE
SET public = true;

-- Enable RLS on storage objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop any existing policies to avoid conflicts
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

-- Ensure note_images table has proper RLS policies
ALTER TABLE note_images ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own note images" ON note_images;
DROP POLICY IF EXISTS "Users can insert their own note images" ON note_images;
DROP POLICY IF EXISTS "Users can update their own note images" ON note_images;
DROP POLICY IF EXISTS "Users can delete their own note images" ON note_images;

-- Create specific policies for each operation
CREATE POLICY "Users can view their own note images"
ON note_images FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM notes
    WHERE notes.id = note_images.note_id
    AND notes.user_id = auth.uid()
  )
);

CREATE POLICY "Users can insert their own note images"
ON note_images FOR INSERT
TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM notes
    WHERE notes.id = note_images.note_id
    AND notes.user_id = auth.uid()
  )
);

CREATE POLICY "Users can update their own note images"
ON note_images FOR UPDATE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM notes
    WHERE notes.id = note_images.note_id
    AND notes.user_id = auth.uid()
  )
) WITH CHECK (
  EXISTS (
    SELECT 1 FROM notes
    WHERE notes.id = note_images.note_id
    AND notes.user_id = auth.uid()
  )
);

CREATE POLICY "Users can delete their own note images"
ON note_images FOR DELETE
TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM notes
    WHERE notes.id = note_images.note_id
    AND notes.user_id = auth.uid()
  )
);

-- Function to delete storage object when image is deleted
CREATE OR REPLACE FUNCTION delete_storage_object()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete from storage if storage_path exists
  IF OLD.storage_path IS NOT NULL THEN
    BEGIN
      PERFORM storage.delete('note-images', OLD.storage_path);
    EXCEPTION WHEN OTHERS THEN
      -- Log error but continue with deletion
      RAISE NOTICE 'Failed to delete storage object: %', SQLERRM;
    END;
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