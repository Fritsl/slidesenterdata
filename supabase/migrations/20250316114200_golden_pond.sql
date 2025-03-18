/*
  # Add move_image function with proper position handling

  1. Changes
    - Add move_image function for reordering images
    - Add position validation and normalization
    - Add proper error handling
    - Maintain position integrity

  2. Details
    - Handles edge cases properly
    - Maintains sequential positions
    - Prevents position conflicts
*/

-- Function to move images with proper position handling
CREATE OR REPLACE FUNCTION move_image(
  p_image_id uuid,
  p_new_position integer,
  p_note_id uuid
) RETURNS void AS $$
DECLARE
  v_old_position integer;
  v_max_position integer;
  v_image_exists boolean;
BEGIN
  -- Check if image exists and belongs to the note
  SELECT EXISTS (
    SELECT 1 FROM note_images
    WHERE id = p_image_id AND note_id = p_note_id
  ) INTO v_image_exists;

  IF NOT v_image_exists THEN
    RAISE EXCEPTION 'Image not found or does not belong to the specified note';
  END IF;

  -- Get current position
  SELECT position INTO v_old_position
  FROM note_images
  WHERE id = p_image_id;

  -- Get max position
  SELECT COALESCE(MAX(position), -1)
  INTO v_max_position
  FROM note_images
  WHERE note_id = p_note_id;

  -- Validate position
  IF p_new_position < 0 THEN
    p_new_position := 0;
  ELSIF p_new_position > v_max_position THEN
    p_new_position := v_max_position;
  END IF;

  -- Update positions
  IF v_old_position < p_new_position THEN
    -- Moving forward
    UPDATE note_images
    SET position = position - 1
    WHERE note_id = p_note_id
    AND position > v_old_position
    AND position <= p_new_position;
  ELSE
    -- Moving backward
    UPDATE note_images
    SET position = position + 1
    WHERE note_id = p_note_id
    AND position >= p_new_position
    AND position < v_old_position;
  END IF;

  -- Update the image's position
  UPDATE note_images
  SET 
    position = p_new_position,
    updated_at = CURRENT_TIMESTAMP
  WHERE id = p_image_id;
END;
$$ LANGUAGE plpgsql;