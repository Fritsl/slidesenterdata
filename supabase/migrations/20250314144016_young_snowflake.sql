/*
  # Add time support for notes
  
  1. Changes
    - Add time column to notes table
    - Add function to toggle time
    - Add validation for time format
    
  2. Details
    - Uses PostgreSQL's time type
    - Stores time in 24-hour format
    - Maintains data integrity
*/

-- Add time column to notes table
ALTER TABLE notes
ADD COLUMN time_set time DEFAULT NULL;

-- Function to set/unset time
CREATE OR REPLACE FUNCTION toggle_note_time(
  p_note_id uuid,
  p_time time DEFAULT NULL
) RETURNS void AS $$
BEGIN
  UPDATE notes
  SET 
    time_set = p_time,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_note_id;

  -- Update project's last modified timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = (
    SELECT project_id 
    FROM notes 
    WHERE id = p_note_id
  );
END;
$$ LANGUAGE plpgsql;