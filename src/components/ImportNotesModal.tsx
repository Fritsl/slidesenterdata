import React, { useState } from 'react';
import { X, Upload } from 'lucide-react';
import { useNoteStore } from '../store';

interface ImportNotesModalProps {
  onClose: () => void;
}

interface XMLNote {
  $: {
    id?: string;
    discussion?: string;
    time?: string;
    youtube?: string;
    url?: string;
    url_display_text?: string;
  };
  content: string[];
  children?: { note: XMLNote[] };
}

interface XMLProject {
  project: {
    title: string[];
    notes: { note: XMLNote[] };
  };
}

export function ImportNotesModal({ onClose }: ImportNotesModalProps) {
  const [text, setText] = useState('');
  const [isImporting, setIsImporting] = useState(false);
  const store = useNoteStore();
  const importNotes = store.importNotes;

  const parseXML = (xmlText: string): { notes: string[], level: number, parentContent?: string }[] => {

    try {
      const parser = new DOMParser();
      const xmlDoc = parser.parseFromString(xmlText, "text/xml");
      const result: { notes: string[], level: number, parentContent?: string }[] = [];

      const processNote = (noteElement: Element, level: number, parentContent?: string) => {
        const content = noteElement.getElementsByTagName("content")[0]?.textContent || '';
        const time = noteElement.getAttribute("time") || '';
        const youtube = noteElement.getAttribute("youtube") || '';
        const url = noteElement.getAttribute("url") || '';
        const urlDisplayText = noteElement.getAttribute("url_display_text") || '';
        const discussion = noteElement.getAttribute("discussion") === "true";

        if (content) {
          const note = [content];
          if (time) note.push(`[time=${time}]`);
          if (youtube) note.push(`[youtube=${youtube}]`);
          if (url) note.push(`[url=${url}]`);
          if (urlDisplayText) note.push(`[url_display_text=${urlDisplayText}]`);
          if (discussion) note.push(`[discussion=true]`);

          result.push({ notes: note, level, parentContent });

          const children = noteElement.getElementsByTagName("children")[0];
          if (children) {
            Array.from(children.getElementsByTagName("note")).forEach(child => {
              processNote(child, level + 1, content);
            });
          }
        }
      };

      const notes = xmlDoc.getElementsByTagName("notes")[0];
      if (notes) {
        Array.from(notes.getElementsByTagName("note")).forEach(note => {
          processNote(note, 0);
        });
      }

      return result;
    } catch (error) {
      throw error;
    }
  };

  const handleImport = async () => {
    try {
      setIsImporting(true);
      if (text.trim().startsWith('<?xml')) {
        const parsedNotes = parseXML(text);
        if (parsedNotes && parsedNotes.length > 0) {
          const uniqueNotes = Array.from(new Set(parsedNotes.map(note => JSON.stringify(note))))
            .map(str => JSON.parse(str));
          await importNotes(uniqueNotes);
        } else {
          throw new Error("No valid notes found in XML");
        }
      } else {
        const lines = text.split('\n').filter(line => line.trim());
        if (lines.length > 0) {
          await importNotes([{ notes: lines, level: 0 }]);
        } else {
          throw new Error("No valid notes found in text");
        }
      }
      onClose();
    } catch (error) {
      console.error('Error importing notes:', error);
      alert('Failed to import notes. Please check the format and try again.');
    } finally {
      setIsImporting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col overflow-hidden">
        <div className="flex items-center justify-between p-4 border-b">
          <h2 className="text-lg font-semibold text-gray-900">Import Notes</h2>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>
        <div className="p-4">
          <div className="mb-4">
            <h3 className="font-medium text-gray-700 mb-2">Import Format</h3>
            <div className="space-y-2 text-sm text-gray-600">
              <div className="p-3 bg-gray-50 rounded-lg">
                <strong>Bullet Format:</strong>
                <br/>• Each line starts with (•)
                <br/>• Use spaces for indentation
              </div>
              <div className="p-3 bg-blue-50 rounded-lg border border-blue-100">
                <strong>XML Format:</strong>
                <br/>• Paste XML exported from this app
                <br/>• Starts with &lt;?xml version="1.0"&gt;
              </div>
            </div>
          </div>
          <div className="flex-1 p-4 flex flex-col min-h-0">
            <textarea
              value={text}
              onChange={(e) => setText(e.target.value)}
              className="w-full h-48 font-mono text-sm p-4 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
              placeholder="• Main note
  • Sub-note
    • Sub-sub-note
• Another main note"
            />
          </div>
        </div>
        <div className="p-4 border-t bg-gray-50 flex justify-end gap-2">
          <button
            onClick={onClose}
            className="px-4 py-2 text-gray-600 hover:text-gray-800"
          >
            Cancel
          </button>
          <button
            onClick={handleImport}
            disabled={!text.trim() || isImporting}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          >
            <Upload className="w-4 h-4" />
            {isImporting ? 'Importing...' : 'Import Notes'}
          </button>
        </div>
      </div>
    </div>
  );
}