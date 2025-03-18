/*
  # Update YouTube URL validation

  1. Changes
    - Update YouTube URL validation to support shorts with query parameters
    - Keep support for regular watch URLs and youtu.be links
    - Maintain proper URL format validation

  2. Details
    - Allows shorts URLs with query parameters
    - Maintains 11-character video ID requirement
    - Preserves existing URL patterns
*/

-- Drop existing constraint
ALTER TABLE notes
DROP CONSTRAINT IF EXISTS youtube_url_format;

-- Add new constraint with shorts and query parameter support
ALTER TABLE notes
ADD CONSTRAINT youtube_url_format CHECK (
  youtube_url IS NULL OR
  youtube_url ~ '^https?:\/\/(www\.)?(youtube\.com\/(watch\?v=|shorts\/)[a-zA-Z0-9_-]{11}|youtu\.be\/[a-zA-Z0-9_-]{11})([?&][^&\s]*)*$'
);