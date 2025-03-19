import React, { useState } from 'react';
import { X, Upload } from 'lucide-react';
import { useNoteStore } from '../store';

interface ImportNotesModalProps {
  onClose: () => void;
}

export function ImportNotesModal({ onClose }: ImportNotesModalProps) {
  const importNotes = useNoteStore().importNotes;
  const [error, setError] = useState<string>('');

  const handleImport = async (e: React.ChangeEvent<HTMLInputElement>) => {
    try {
      const file = e.target.files?.[0];
      if (!file) return;

      const text = await file.text();
      const notes = text.split('\n').map((line, index) => ({
        notes: [line.trim()],
        level: 0,
        parentContent: undefined
      })).filter(note => note.notes[0].length > 0);

      if (!notes || notes.length === 0) {
        throw new Error('No valid notes found in file');
      }

      await importNotes(notes);
      onClose();
    } catch (error) {
      console.error('Error during import:', error);
      setError(error instanceof Error ? error.message : 'Import failed');
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-md">
        <div className="flex items-center justify-between p-4 border-b">
          <h2 className="text-lg font-semibold text-gray-900">Import Notes</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded-full transition-colors">
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>
        <div className="p-4">
          <label className="flex flex-col items-center justify-center w-full h-32 border-2 border-gray-300 border-dashed rounded-lg cursor-pointer bg-gray-50 hover:bg-gray-100">
            <div className="flex flex-col items-center justify-center pt-5 pb-6">
              <Upload className="w-10 h-10 text-gray-400 mb-3" />
              <p className="mb-2 text-sm text-gray-500">
                <span className="font-semibold">Click to upload</span> or drag and drop
              </p>
              <p className="text-xs text-gray-500">Text files only</p>
            </div>
            <input type="file" className="hidden" accept=".txt" onChange={handleImport} />
          </label>
          {error && (
            <p className="mt-2 text-sm text-red-600">{error}</p>
          )}
        </div>
      </div>
    </div>
  );
}