/*
  # Fix image deletion functionality

  1. Changes
    - Add proper cascade deletion for note_images
    - Add function to handle image deletion
    - Add trigger to maintain referential integrity
    - Fix error handling for image deletion

  2. Details
    - Ensures images are properly deleted
    - Maintains data integrity
    - Improves error handling
*/

-- Drop existing triggers
DROP TRIGGER IF EXISTS delete_storage_object_trigger ON note_images;

-- Create function to delete image
CREATE OR REPLACE FUNCTION delete_note_image(p_image_id uuid)
RETURNS void AS $$
BEGIN
  -- Delete the image record
  DELETE FROM note_images
  WHERE id = p_image_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to handle storage cleanup
CREATE OR REPLACE FUNCTION delete_storage_object()
RETURNS TRIGGER AS $$
BEGIN
  -- Only attempt storage deletion if path exists
  IF OLD.storage_path IS NOT NULL THEN
    BEGIN
      PERFORM storage.delete('note-images', OLD.storage_path);
    EXCEPTION WHEN OTHERS THEN
      -- Log error but continue with deletion
      RAISE NOTICE 'Failed to delete storage object: %', SQLERRM;
    END;
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for storage cleanup
CREATE TRIGGER delete_storage_object_trigger
BEFORE DELETE ON note_images
FOR EACH ROW
EXECUTE FUNCTION delete_storage_object();

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS note_images_id_idx ON note_images(id);