import React, { useState } from 'react';
import { Clock, Pencil } from 'lucide-react';
import { useNoteStore } from '../store';
import { Note } from '../types';
import { TimePickerModal } from './TimePickerModal';

function findAllTimedNotes(notes: Note[]): Note[] {
  const timedNotes: Note[] = [];
  
  const traverse = (note: Note) => {
    if (note.time_set) {
      timedNotes.push(note);
    }
    note.children.forEach(traverse);
  };
  
  notes.forEach(traverse);
  return timedNotes.sort((a, b) => {
    if (!a.time_set || !b.time_set) return 0;
    return a.time_set.localeCompare(b.time_set);
  });
}

export function TimedNotesView({ onClose }: { onClose: () => void }) {
  const { notes } = useNoteStore();
  const [editingNote, setEditingNote] = useState<Note | null>(null);
  const timedNotes = findAllTimedNotes(notes);

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-2xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between p-4 border-b">
          <div className="flex items-center gap-2">
            <Clock className="w-5 h-5 text-blue-600" />
            <h2 className="text-lg font-semibold text-gray-900">Notes with Time Set</h2>
          </div>
          <button
            onClick={onClose}
            className="px-4 py-2 text-gray-600 hover:text-gray-800"
          >
            Close
          </button>
        </div>
        
        <div className="flex-1 overflow-auto p-4">
          {timedNotes.length > 0 ? (
            <div className="space-y-4">
              {timedNotes.map(note => (
                <div
                  key={note.id}
                  className="p-4 bg-white rounded-lg border hover:border-blue-200 transition-colors"
                >
                  <div className="flex items-center justify-between gap-4">
                    <div className="flex-1">
                      <p className="text-gray-900">{note.content || 'Empty note...'}</p>
                    </div>
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => setEditingNote(note)}
                        className="flex items-center gap-2 px-3 py-1.5 rounded-lg hover:bg-gray-50 text-blue-600 group"
                      >
                        <Clock className="w-4 h-4" />
                        <span className="text-sm font-medium">{note.time_set?.slice(0, 5)}</span>
                        <Pencil className="w-3 h-3 opacity-0 group-hover:opacity-100 transition-opacity" />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          ) : (
            <div className="text-center py-12">
              <Clock className="w-12 h-12 text-gray-400 mx-auto mb-4" />
              <h3 className="text-lg font-medium text-gray-900 mb-2">No Timed Notes</h3>
              <p className="text-gray-600">
                None of your notes have a time set. Use the clock icon in the note actions to set a time.
              </p>
            </div>
          )}
        </div>
        
        {editingNote && (
          <TimePickerModal
            note={editingNote}
            onClose={() => setEditingNote(null)}
          />
        )}
      </div>
    </div>
  );
}