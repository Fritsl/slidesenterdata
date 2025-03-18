/*
  # Fix YouTube URL validation

  1. Changes
    - Drop existing YouTube URL constraint
    - Add new constraint with proper validation
    - Handle both youtube.com and youtu.be URLs
    - Support video IDs with hyphens and underscores

  2. Details
    - Validates standard YouTube URLs
    - Validates shortened youtu.be URLs
    - Allows query parameters
    - Ensures proper video ID format
*/

-- Drop existing constraint
ALTER TABLE notes
DROP CONSTRAINT IF EXISTS youtube_url_format;

-- Add new constraint with proper validation
ALTER TABLE notes
ADD CONSTRAINT youtube_url_format CHECK (
  youtube_url IS NULL OR
  youtube_url ~ '^https?:\/\/(www\.)?(youtube\.com\/watch\?v=[\w-]{11}|youtu\.be\/[\w-]{11})(&.*)?$'
);