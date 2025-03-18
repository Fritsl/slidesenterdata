/*
  # Update allowed image formats

  1. Changes
    - Allow more web-friendly image formats (webp, gif, avif)
    - Keep existing formats (jpg, jpeg, png)
    - Update storage policies to enforce format restrictions

  2. Details
    - Maintains existing RLS policies
    - Updates upload policy to allow additional formats
    - Preserves all other functionality
*/

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow public read access" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes" ON storage.objects;

-- Create updated policies with more formats
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
      'webp',
      'gif',
      'avif'
    )
  )
);

CREATE POLICY "Allow public read access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'note-images');

CREATE POLICY "Allow authenticated deletes"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'note-images');