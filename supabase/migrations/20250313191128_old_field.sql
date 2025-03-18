/*
  # Fix storage permissions for image uploads

  1. Changes
    - Create storage bucket if it doesn't exist
    - Set up proper RLS policies for the bucket
    - Enable uploads for authenticated users
    - Add security policies for image access

  2. Details
    - Ensures authenticated users can upload images
    - Maintains data security
    - Prevents unauthorized access
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
  AND (LOWER(storage.extension(name)) = 'jpg' OR LOWER(storage.extension(name)) = 'jpeg')
);

CREATE POLICY "Allow authenticated deletes"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'note-images');

-- Function to delete storage object when image is deleted
CREATE OR REPLACE FUNCTION delete_storage_object()
RETURNS TRIGGER AS $$
BEGIN
  -- Extract filename from URL or storage_path
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