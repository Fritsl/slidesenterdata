/*
  # Remove storage path column

  1. Changes
    - Remove storage_path column from note_images table
    - Keep url column for direct image URLs
*/

-- Remove storage_path column from note_images
ALTER TABLE note_images DROP COLUMN IF EXISTS storage_path;