/*
  # Remove theme system

  1. Changes
    - Drop all theme-related functions first
    - Remove theme column from notes
    - Drop theme_type enum
*/

-- Drop all theme-related functions first to handle dependencies
DROP FUNCTION IF EXISTS get_next_theme(theme_type) CASCADE;
DROP FUNCTION IF EXISTS cascade_theme_changes() CASCADE;
DROP FUNCTION IF EXISTS set_note_theme() CASCADE;
DROP FUNCTION IF EXISTS update_theme_on_move() CASCADE;
DROP FUNCTION IF EXISTS update_note_themes() CASCADE;

-- Drop theme-related triggers
DROP TRIGGER IF EXISTS cascade_theme_changes_trigger ON notes;
DROP TRIGGER IF EXISTS set_note_theme_trigger ON notes;

-- Remove theme column from notes
ALTER TABLE notes DROP COLUMN IF EXISTS theme;

-- Now we can safely drop the enum
DROP TYPE IF EXISTS theme_type;