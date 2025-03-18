
import { useState, useEffect, useRef } from 'react';
import { ArrowLeft, ArrowRight } from 'lucide-react';
import { NoteImage as NoteImageType } from '../types';
import { supabase } from '../lib/supabase';

interface NoteImageProps {
  image: NoteImageType;
  onDelete?: (imageId: string) => void;
  onMoveLeft?: () => void;
  onMoveRight?: () => void;
  isFirst?: boolean;
  isLast?: boolean;
}

export const NoteImage = ({ 
  image, 
  onDelete,
  onMoveLeft,
  onMoveRight,
  isFirst,
  isLast
}: NoteImageProps) => {
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadImage = async () => {
      try {
        setLoading(true);
        
        // If we already have a URL, use it
        if (image.url) {
          setImageUrl(image.url);
          return;
        }
        
        // If we have a storage path, get the public URL
        if (image.storage_path) {
          const { data } = supabase.storage
            .from('note-images')
            .getPublicUrl(image.storage_path);
          
          setImageUrl(data.publicUrl);
        } else {
          setError('No image URL or storage path available');
        }
      } catch (err: any) {
        console.error('Error loading image:', err);
        setError(err.message || 'Failed to load image');
      } finally {
        setLoading(false);
      }
    };

    loadImage();
  }, [image]);

  if (loading) return <div className="w-full h-32 bg-gray-200 animate-pulse rounded"></div>;
  if (error) return <div className="text-red-500">Failed to load image: {error}</div>;
  if (!imageUrl) return null;

  return (
    <div className="relative group">
      <img 
        src={imageUrl} 
        alt="Note attachment" 
        className="w-32 h-32 object-cover rounded-lg shadow-sm" 
      />
      <div className="absolute top-2 right-2 flex gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
        {!isFirst && onMoveLeft && (
          <button
            onClick={onMoveLeft}
            className="bg-gray-800 text-white rounded-full p-1 hover:bg-gray-700 transition-colors"
            aria-label="Move image left"
          >
            <ArrowLeft className="w-4 h-4" />
          </button>
        )}
        {!isLast && onMoveRight && (
          <button
            onClick={onMoveRight}
            className="bg-gray-800 text-white rounded-full p-1 hover:bg-gray-700 transition-colors"
            aria-label="Move image right"
          >
            <ArrowRight className="w-4 h-4" />
          </button>
        )}
        {onDelete && (
          <button
            onClick={() => onDelete(image.id)}
            className="bg-red-500 text-white rounded-full p-1 hover:bg-red-600 transition-colors"
            aria-label="Delete image"
          >
            <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        )}
      </div>
    </div>
  );
};
