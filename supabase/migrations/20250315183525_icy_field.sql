/*
  # Add YouTube URL support to notes

  1. Changes
    - Add youtube_url column to notes table
    - Add URL validation check constraint
    - Maintain existing data integrity
*/

-- Add youtube_url column to notes table
ALTER TABLE notes
ADD COLUMN youtube_url text DEFAULT NULL;

-- Add constraint to validate YouTube URLs
ALTER TABLE notes
ADD CONSTRAINT youtube_url_format CHECK (
  youtube_url IS NULL OR
  youtube_url ~ '^https?:\/\/(www\.)?(youtube\.com|youtu\.be)\/.+$'
);