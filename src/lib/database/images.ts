import { supabase } from '../supabase';
import { handleDatabaseError } from '../errors';

async function optimizeImage(dataUrl: string): Promise<string> {
  try {
    // Call the Edge Function to optimize the image
    const { data, error } = await supabase.functions.invoke('optimize-image', {
      body: { imageData: dataUrl }
    });

    if (error) throw error;
    if (!data?.url) throw new Error('No optimized image URL returned');

    return data.url;
  } catch (error) {
    console.warn('Image optimization failed, using original:', error);
    return dataUrl;
  }
}

export const imageOperations = {
  async add(noteId: string, url: string) {
    try {
      // Optimize image first
      const optimizedDataUrl = await optimizeImage(url);

      // Extract base64 data
      const base64Data = optimizedDataUrl.split(',')[1];
      const mimeType = url.split(';')[0].split(':')[1];

      // Convert base64 to blob
      const byteCharacters = atob(base64Data);
      const byteArrays = [];

      for (let offset = 0; offset < byteCharacters.length; offset += 512) {
        const slice = byteCharacters.slice(offset, offset + 512);
        const byteNumbers = new Array(slice.length);
        for (let i = 0; i < slice.length; i++) {
          byteNumbers[i] = slice.charCodeAt(i);
        }
        const byteArray = new Uint8Array(byteNumbers);
        byteArrays.push(byteArray);
      }

      const blob = new Blob(byteArrays, { type: mimeType });

      // Create a unique filename
      const filename = `${crypto.randomUUID()}.jpg`;
      const filePath = `images/${filename}`;

      // Upload to storage
      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('note-images')
        .upload(filePath, blob, {
          contentType: mimeType,
          cacheControl: '3600'
        });

      if (uploadError) {
        throw handleDatabaseError(uploadError, 'Failed to upload image');
      }

      // Get public URL
      const { data: { publicUrl } } = supabase.storage
        .from('note-images')
        .getPublicUrl(filePath);

      // Create database record
      const { data, error } = await supabase
        .from('note_images')
        .insert([{
          note_id: noteId,
          url: publicUrl,
          storage_path: `images/${publicUrl.split('/').pop()}`
        }])
        .select();

      if (error) {
        throw handleDatabaseError(error, 'Failed to add image');
      }

      if (!data || data.length === 0) {
        throw handleDatabaseError(new Error('No data returned'), 'Failed to create image record');
      }

      return data[0];
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to add image');
    }
  },

  async remove(imageId: string) {
    try {
      // Get image record first
      const { data: image, error: fetchError } = await supabase
        .from('note_images')
        .select('url, storage_path')
        .eq('id', imageId)
        .single();

      if (fetchError) {
        throw handleDatabaseError(fetchError, 'Failed to fetch image');
      }

      // Try to remove from storage if we have a storage path
      if (image?.storage_path) {
        const { error: storageError } = await supabase.storage
          .from('note-images')
          .remove([image.storage_path]);

        if (storageError) {
          // Continue with database deletion even if storage removal fails
        }
      }

      // Remove database record
      const { error } = await supabase
        .from('note_images')
        .delete()
        .eq('id', imageId);

      if (error) {
        throw handleDatabaseError(error, 'Failed to remove image');
      }
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to remove image');
    }
  },

  async move(noteId: string, imageId: string, newPosition: number) {
    try {
      const { error } = await supabase.rpc('move_image', {
        p_note_id: noteId,
        p_image_id: imageId,
        p_new_position: newPosition
      });

      if (error) {
        throw handleDatabaseError(error, 'Failed to move image');
      }
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to move image');
    }
  }
};