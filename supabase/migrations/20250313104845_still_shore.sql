/*
  # Add last_level to settings table

  1. Changes
    - Add last_level column to settings table
    - Add default value of 0
    - Add constraint to ensure valid level range
*/

-- Add last_level column to settings table
ALTER TABLE settings
ADD COLUMN last_level integer DEFAULT 0;

-- Add constraint to ensure valid level range (0-10)
ALTER TABLE settings
ADD CONSTRAINT last_level_range CHECK (last_level >= 0 AND last_level <= 10);