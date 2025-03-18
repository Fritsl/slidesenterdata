
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
    
    // Get the namespace from the document
    const xmlns = xmlDoc.documentElement.getAttribute('xmlns') || null;
    
    // Helper function to get elements with proper namespace handling
    const getElements = (parent: Element, selector: string): Element[] => {
      if (xmlns) {
        // Use getElementsByTagNameNS for precise namespace handling
        const allElements = parent.getElementsByTagNameNS(xmlns, selector);
        return Array.from(allElements);
      } else {
        // If no namespace, use getElementsByTagName
        const allElements = parent.getElementsByTagName(selector);
        return Array.from(allElements);
      }
    };
    
    // Helper function to get a single element with namespace awareness
    const getElement = (parent: Element, selector: string): Element | null => {
      const elements = getElements(parent, selector);
      return elements.length > 0 ? elements[0] : null;
    };

    const processNote = (noteElement: Element, level: number, parentContent?: string) => {
    const content = getElement(noteElement, 'content')?.textContent?.trim() || '';
    const attributes: string[] = [];
    
    // Process attributes
    if (noteElement.getAttribute('time')) {
      attributes.push(`[time=${noteElement.getAttribute('time')}]`);
    }
    if (noteElement.getAttribute('discussion') === 'true') {
      attributes.push('[discussion=true]');
    }
    if (noteElement.getAttribute('youtube')) {
      attributes.push(`[youtube=${noteElement.getAttribute('youtube')}]`);
    }
    if (noteElement.getAttribute('url')) {
      attributes.push(`[url=${noteElement.getAttribute('url')}]`);
    }
    if (noteElement.getAttribute('url-text')) {
      attributes.push(`[url_display_text=${noteElement.getAttribute('url-text')}]`);
    }

    // Add note with content and attributes
    result.push({
      notes: [content, ...attributes],
      level,
      parentContent
    });

    // Process children
    const childrenElement = getElement(noteElement, 'children');
    if (childrenElement) {
      const childNotes = getElements(childrenElement, 'note');
      childNotes.forEach(childNote => {
        processNote(childNote, level + 1, content);
      });
    }
      // Get content element with namespace awareness
      const contentElement = getElement(noteElement, 'content');
      const content = contentElement?.textContent?.trim();
      
      if (!content) return;

      const note = [content];

      // Handle attributes
      const attrs = {
        'time': noteElement.getAttribute('time'),
        'youtube': noteElement.getAttribute('youtube'),
        'url': noteElement.getAttribute('url'),
        'url-text': noteElement.getAttribute('url-text'),
        'discussion': noteElement.getAttribute('discussion')
      };

      if (attrs.discussion === 'true') {
        note.push('[discussion=true]');
      }
      if (attrs.time) {
        note.push(`[time=${attrs.time}]`);
      }
      if (attrs.youtube) {
        note.push(`[youtube=${attrs.youtube}]`);
      }
      if (attrs.url) {
        note.push(`[url=${attrs.url}]`);
      }
      if (attrs['url-text']) {
        note.push(`[url_display_text=${attrs['url-text']}]`);
      }

      result.push({ notes: note, level, parentContent });

      // Process children with namespace awareness
      const children = getElement(noteElement, 'children');
      if (children) {
        const childNotes = getElements(children, 'note');
        childNotes.forEach(child => {
          processNote(child, level + 1, content);
        });
      }
    };

    // Get notes element with namespace awareness
    const projectElement = xmlDoc.documentElement;
    const notesElement = getElement(projectElement, 'notes');
    
    if (!notesElement) {
      throw new Error('Invalid XML structure: missing notes element');
    }

    // Get root notes with namespace awareness
    const rootNotes = getElements(notesElement, 'note');
    rootNotes.forEach(note => {
      processNote(note, 0);
    });

    if (result.length === 0) {
      throw new Error('No valid notes found in XML');
    }

    return result;
  };

  const handleImport = async (e: React.ChangeEvent<HTMLInputElement>) => {
    try {
      const file = e.target.files?.[0];
      if (!file) return;

      const text = await file.text();
      console.log('XML Content:', text);
      const notes = parseXML(text);
      console.log('Parsed Notes:', notes);
      
      if (!notes || notes.length === 0) {
        throw new Error('No valid notes found in XML');
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
