/*
  # Add image reordering support

  1. Changes
    - Add function to move images
    - Handle position updates properly
    - Maintain order integrity

  2. Details
    - Updates image positions safely
    - Maintains data consistency
    - Handles edge cases properly
*/

-- Function to move images
CREATE OR REPLACE FUNCTION move_image(
  p_note_id uuid,
  p_image_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_old_position integer;
  v_max_position integer;
BEGIN
  -- Get current position
  SELECT position INTO v_old_position
  FROM note_images
  WHERE id = p_image_id;

  -- Get max position
  SELECT COALESCE(MAX(position), 0)
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
  SET position = p_new_position
  WHERE id = p_image_id;
END;
$$ LANGUAGE plpgsql;