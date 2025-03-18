import React, { useState, useEffect, useRef } from 'react';
import { X, Users, Image as ImageIcon, Youtube } from 'lucide-react';
import { Note } from '../types';
import { useNoteStore } from '../store';
import { NoteImage } from './NoteImage';

interface FullscreenEditorProps {
  content: string;
  note: Note;
  onChange: (content: string) => void;
  onClose: () => void;
  isNew?: boolean;
}

export const FullscreenEditor = ({
  content,
  note,
  onChange,
  onClose,
  isNew = false,
}: FullscreenEditorProps) => {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const [fileInput, setFileInput] = useState<HTMLInputElement | null>(null);
  const [isUploading, setIsUploading] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  const [youtubeUrl, setYoutubeUrl] = useState(note.youtube_url || '');
  const [url, setUrl] = useState<string>(note.url || '');
  const [urlDisplayText, setUrlDisplayText] = useState<string>(note.url_display_text || '');

  // Clean up file input on unmount
  useEffect(() => {
    return () => {
      if (fileInput) {
        fileInput.removeEventListener('change', handleFileInputChange);
        document.body.removeChild(fileInput);
      }
    };
  }, [fileInput]);

  const { 
    saveNote, 
    toggleDiscussion, 
    addImage, 
    removeImage,
    moveImage,
    updateNote,
    setYoutubeUrl: setNoteYoutubeUrl,
    setUrl: setNoteUrl
  } = useNoteStore();

  const handleYoutubeUrlChange = async (url: string) => {
    setYoutubeUrl(url);
    try {
      await setNoteYoutubeUrl(note.id, url || null);
    } catch (error) {
      setError('Failed to update YouTube URL');
    }
  };

  const handleImageUpload = async (file: File) => {
    try {
      const reader = new FileReader();

      reader.onerror = (error) => {
        setError('Failed to read image file');
        setIsUploading(false);
      };

      reader.onloadend = async () => {
        if (!reader.result) {
          setError('Failed to read image file');
          setIsUploading(false);
          return;
        }

        const dataUrl = reader.result as string;

        try {
          await addImage(note.id, dataUrl);
        } catch (error) {
          setError('Failed to add image');
        } finally {
          setIsUploading(false);
        }
      };

      reader.readAsDataURL(file);
    } catch (err) {
      setError('Failed to upload image');
      setIsUploading(false);
    }
  };

  const handleFileInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      const file = e.target.files[0];

      if (!file.type.startsWith('image/')) {
        setError('Only image files are allowed');
        return;
      }

      setIsUploading(true);
      setError(null);
      handleImageUpload(file);
    } 
  };

  useEffect(() => {
    textareaRef.current?.focus();
    const handler = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        saveNote(note.id);
        onClose();
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [onClose, note.id, saveNote]);

  const handleClose = () => {
    Promise.all([
      saveNote(note.id),
      setNoteUrl(note.id, url || null, urlDisplayText || null)
    ])
      .then(() => onClose())
      .catch(error => setError('Failed to save changes'));
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between p-4 border-b">
          <h2 className="text-lg font-semibold text-gray-900">
            {isNew ? 'New note' : 'Edit note'}
          </h2>
          <button
            onClick={handleClose}
            className="p-1 hover:bg-gray-100 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>
        <textarea
          ref={textareaRef}
          value={content}
          onChange={(e) => onChange(e.target.value)}
          className="flex-1 p-4 resize-none focus:outline-none text-lg mb-4"
          placeholder="Enter your note..."
        />
        <div className="px-4">
          <div className="flex items-center gap-2 mb-4 flex-wrap">
            <button
              onClick={() => {
                if (!fileInput) {
                  const input = document.createElement('input');
                  input.type = 'file';
                  input.accept = 'image/*';
                  input.style.display = 'none';
                  input.addEventListener('change', handleFileInputChange);
                  document.body.appendChild(input);
                  setFileInput(input);
                  input.click();
                } else {
                  fileInput.value = '';
                  fileInput.click();
                }
              }}
              disabled={isUploading}
              className="px-4 py-2 text-sm font-medium text-blue-600 hover:text-blue-700 flex items-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <ImageIcon className="w-4 h-4" />
              {isUploading ? 'Uploading...' : 'Add Image'}
            </button>
            <button
              onClick={() => toggleDiscussion(note.id, !note.is_discussion)}
              className={`px-4 py-2 text-sm font-medium flex items-center gap-2 rounded-lg transition-colors ${
                note.is_discussion 
                  ? 'bg-blue-100 text-blue-700 hover:bg-blue-200' 
                  : 'text-gray-600 hover:bg-gray-100'
              }`}
            >
              <Users className="w-4 h-4" />
              {note.is_discussion ? 'Discussion' : 'Mark as Discussion'}
            </button>
          </div>
          {error && <p className="mt-2 text-sm text-red-600">{error}</p>}
          {(note.images || []).length > 0 && (
            <div className="flex flex-wrap gap-2 mb-4">
              {(note.images || []).map((image, index) => (
                <NoteImage
                  key={image.id}
                  image={image}
                  onDelete={() => removeImage(note.id, image.id)}
                  onMoveLeft={() => {
                    moveImage(note.id, image.id, index - 1)
                      .catch(err => setError('Failed to move image'));
                  }}
                  onMoveRight={() => {
                    moveImage(note.id, image.id, index + 1)
                      .catch(err => setError('Failed to move image'));
                  }}
                  isFirst={index === 0}
                  isLast={index === (note.images || []).length - 1}
                />
              ))}
            </div>
          )}
          <div className="mt-4">
            <div className="flex items-center gap-2 text-sm text-gray-600">
              <Youtube className="w-4 h-4" />
              <span>YouTube Video URL</span>
            </div>
            <input
              type="url"
              value={youtubeUrl}
              onChange={(e) => handleYoutubeUrlChange(e.target.value)}
              placeholder="https://www.youtube.com/watch?v=..."
              className="mt-1 w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
            />
            <div className="mt-4">
              <div className="flex items-center gap-2 text-sm text-gray-600">
                <span>URL</span>
              </div>
              <input
                type="url"
                value={url}
                onChange={(e) => setUrl(e.target.value)}
                placeholder="https://example.com"
                className="mt-1 w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
              />
            </div>
            <div className="mt-2">
              <div className="flex items-center gap-2 text-sm text-gray-600">
                <span>Link Text (optional)</span>
              </div>
              <input
                type="text"
                value={urlDisplayText}
                onChange={(e) => setUrlDisplayText(e.target.value)}
                placeholder="Display text for URL"
                className="mt-1 w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent text-sm"
              />
            </div>
          </div>
        </div>
        <div className="p-4 border-t bg-gray-50 flex justify-end">
          <button
            onClick={handleClose}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            Done
          </button>
        </div>
      </div>
    </div>
  );
};