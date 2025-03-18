/*
  # Add URL and display text fields to notes

  1. Changes
    - Add url column for storing URLs
    - Add url_display_text column for custom link text
    - Add URL format validation
    - Maintain existing data integrity

  2. Details
    - Ensures proper URL format
    - Makes display text optional
    - Preserves existing note data
*/

-- Add URL and display text columns
ALTER TABLE notes
ADD COLUMN url text DEFAULT NULL,
ADD COLUMN url_display_text text DEFAULT NULL;

-- Add URL format validation
ALTER TABLE notes
ADD CONSTRAINT url_format CHECK (
  url IS NULL OR
  url ~ '^https?:\/\/.+'
);