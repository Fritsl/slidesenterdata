/*
  # Fix YouTube URL validation

  1. Changes
    - Drop existing YouTube URL constraint
    - Add new, more permissive constraint
    - Handle query parameters and video IDs properly

  2. Details
    - Allows both youtube.com and youtu.be URLs
    - Handles various URL formats
    - Maintains data integrity
*/

-- Drop existing constraint
ALTER TABLE notes
DROP CONSTRAINT IF EXISTS youtube_url_format;

-- Add new, more permissive constraint
ALTER TABLE notes
ADD CONSTRAINT youtube_url_format CHECK (
  youtube_url IS NULL OR
  youtube_url ~ '^https?:\/\/(www\.)?(youtube\.com\/watch\?v=[\w-]+|youtu\.be\/[\w-]+)(&.*)?$'
);