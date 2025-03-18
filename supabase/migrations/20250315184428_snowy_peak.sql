/*
  # Add YouTube Shorts Support

  1. Changes
    - Drop existing YouTube URL constraint
    - Add new constraint that supports:
      - Regular YouTube URLs
      - YouTube Shorts URLs
      - Short youtu.be URLs
    - Maintain strict video ID validation

  2. Details
    - Validates all YouTube URL formats
    - Ensures proper video ID format
    - Maintains data integrity
*/

-- Drop existing constraint
ALTER TABLE notes
DROP CONSTRAINT IF EXISTS youtube_url_format;

-- Add new constraint with shorts support
ALTER TABLE notes
ADD CONSTRAINT youtube_url_format CHECK (
  youtube_url IS NULL OR
  youtube_url ~ '^https?:\/\/(www\.)?(youtube\.com\/(watch\?v=|shorts\/)[\w-]{11}|youtu\.be\/[\w-]{11})(&.*)?$'
);