/*
  # Clean up old images and add cleanup trigger

  1. Changes
    - Remove all existing image records
    - Add trigger to clean up orphaned images
    - Add function to handle image cleanup

  2. Details
    - Safely removes all existing images
    - Ensures future image cleanup
    - Maintains referential integrity
*/

-- First remove all existing image records
DELETE FROM note_images;

-- Create function to clean up orphaned images
CREATE OR REPLACE FUNCTION cleanup_orphaned_images()
RETURNS TRIGGER AS $$
BEGIN
  -- Delete any images that no longer have an associated note
  DELETE FROM note_images
  WHERE note_id IN (
    SELECT note_images.note_id 
    FROM note_images
    LEFT JOIN notes ON notes.id = note_images.note_id
    WHERE notes.id IS NULL
  );
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically clean up orphaned images
DROP TRIGGER IF EXISTS cleanup_images_trigger ON notes;
CREATE TRIGGER cleanup_images_trigger
AFTER DELETE ON notes
FOR EACH STATEMENT
EXECUTE FUNCTION cleanup_orphaned_images();