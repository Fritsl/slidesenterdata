/*
  # Add WebP image format support

  1. Changes
    - Allow WebP format for image uploads
    - Keep existing formats (jpg, jpeg, png)
    - Maintain existing RLS policies

  2. Details
    - Updates storage upload policy
    - Preserves all other functionality
*/

-- Drop existing upload policy
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;

-- Create updated upload policy with WebP support
CREATE POLICY "Allow authenticated uploads"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'note-images'
  AND (
    LOWER(storage.extension(name)) IN (
      'jpg',
      'jpeg',
      'png',
      'webp'
    )
  )
);

-- Ensure other policies exist
CREATE POLICY IF NOT EXISTS "Allow public read access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'note-images');

CREATE POLICY IF NOT EXISTS "Allow authenticated deletes"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'note-images');