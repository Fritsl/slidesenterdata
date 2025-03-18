import React, { useState } from 'react';
import { X, Upload } from 'lucide-react';
import { useNoteStore } from '../store';

interface ImportNotesModalProps {
  onClose: () => void;
}

export function ImportNotesModal({ onClose }: ImportNotesModalProps) {
  const importNotes = useNoteStore().importNotes;
  const [error, setError] = useState<string>('');

  const parseXML = (xmlText: string): { notes: string[], level: number, parentContent?: string }[] => {
    const parser = new DOMParser();
    const xmlDoc = parser.parseFromString(xmlText, "text/xml");
    const result: { notes: string[], level: number, parentContent?: string }[] = [];

    const processNote = (noteElement: Element, level: number, parentContent?: string) => {
      if (!noteElement) return;

      const contentEl = noteElement.querySelector("content");
      const content = contentEl?.textContent?.trim();

      if (!content) return;

      const note = [content];
      const attrs = ['time', 'youtube', 'url', 'url-text', 'discussion'];

      attrs.forEach(attr => {
        const value = noteElement.getAttribute(attr);
        if (value) {
          if (attr === 'discussion' && value === 'true') {
            note.push('[discussion=true]');
          } else if (attr === 'url-text') {
            note.push(`[url_display_text=${value}]`);
          } else {
            note.push(`[${attr}=${value}]`);
          }
        }
      });

      result.push({ notes: note, level, parentContent });

      const children = noteElement.querySelector('children');
      if (children) {
        const childNotes = children.querySelectorAll(':scope > note');
        childNotes.forEach(child => processNote(child, level + 1, content));
      }
    };

    const notes = xmlDoc.getElementsByTagName("notes")[0];
    if (notes) {
      Array.from(notes.getElementsByTagName("note")).forEach(note => {
        processNote(note, 0);
      });
    }

    return result;
  };

  const handleImport = async (e: React.ChangeEvent<HTMLInputElement>) => {
    try {
      const file = e.target.files?.[0];
      if (!file) return;

      const text = await file.text();
      const notes = parseXML(text);
      await importNotes(notes);
      onClose();
    } catch (error) {
      console.error("Error during import:", error);
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
              <p className="text-xs text-gray-500">XML files only</p>
            </div>
            <input type="file" className="hidden" accept=".xml" onChange={handleImport} />
          </label>
          {error && (
            <p className="mt-2 text-sm text-red-600">{error}</p>
          )}
        </div>
      </div>
    </div>
  );
}