import React, { useState } from 'react';
import { X, ArrowUpCircle, ChevronRight, ArrowRight, MoveVertical } from 'lucide-react';
import { useNoteStore } from '../store';
import { findNoteById } from '../lib/utils';
import type { Note } from '../types';

interface MoveToMenuProps {
  noteId: string;
  onClose: () => void;
}

export const MoveToMenu: React.FC<MoveToMenuProps> = ({ noteId, onClose }) => {
  const { notes, moveNote, currentLevel } = useNoteStore();
  const noteToMove = findNoteById(notes, noteId);
  const [selectedParent, setSelectedParent] = useState<string | null>(null);
  const [expandedNodes, setExpandedNodes] = useState<Set<string>>(new Set());

  const toggleExpanded = (id: string) => {
    setExpandedNodes(prev => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const renderNoteOption = (note: Note, level = 0): React.ReactNode => {
    // Skip if this is the note being moved
    if (note.id === noteId) {
      return null;
    }

    const displayText = note.content || 'Empty note...';
    const truncatedText = displayText.length > 40 
      ? `${displayText.substring(0, 40)}...` 
      : displayText;

    return (
      <React.Fragment key={note.id}>
        <div className="group">
          <div className="flex items-center hover:bg-gray-50 relative">
            {note.children.length > 0 && (
              <button
                onClick={() => toggleExpanded(note.id)}
                className="p-1.5 hover:bg-gray-100 rounded"
                style={{ marginLeft: `${level * 1}rem` }}
              >
                <ChevronRight
                  className={`w-4 h-4 text-gray-400 transition-transform ${
                    expandedNodes.has(note.id) ? 'rotate-90' : ''
                  }`}
                />
              </button>
            )}
            <button
              onClick={() => setSelectedParent(note.id)}
              className={`flex-1 text-left px-4 py-2 flex items-center text-sm text-gray-700 hover:bg-gray-50 ${
                selectedParent === note.id ? 'bg-blue-50' : ''
              }`}
              style={{ marginLeft: note.children.length === 0 ? `${level * 1.5}rem` : 0 }}
            >
              <span className="truncate flex-1">{truncatedText}</span>
              <ArrowRight className={`w-4 h-4 ml-2 transition-opacity ${
                selectedParent === note.id ? 'opacity-100 text-blue-600' : 'opacity-0'
              }`} />
            </button>
          </div>
        </div>
        {selectedParent === note.id && (
          <div className="border-l-2 border-blue-100 ml-6 my-1">
            <div className="pl-4 py-2 text-xs text-gray-500 font-medium">Select position:</div>
            <button
              onClick={() => handleMoveNote(note.id, 0)}
              className="w-full text-left px-4 py-2 hover:bg-blue-50 text-sm text-blue-700 flex items-center gap-2"
            >
              <span>At the beginning</span>
            </button>
            {note.children.map((child, index) => (
              <button
                key={index + 1}
                onClick={() => handleMoveNote(note.id, index + 1)}
                className="w-full text-left px-4 py-2 hover:bg-blue-50 text-sm text-blue-700 flex items-center gap-2"
              >
                <span>After {child.content || 'Empty note...'}</span>
              </button>
            ))}
          </div>
        )}
        {expandedNodes.has(note.id) && note.children.map(child => renderNoteOption(child, level + 1))}
      </React.Fragment>
    );
  };

  const handleMoveNote = async (targetParentId: string | null, position: number) => {
    try {
      await moveNote(noteId, targetParentId, position, currentLevel);
      onClose();
    } catch (error) {
      console.error('Move failed:', error);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-2xl">
        <div className="flex items-center justify-between px-4 py-3 border-b">
          <div className="pr-8">
            <h2 className="text-lg font-semibold text-gray-900">Move note</h2>
            <p className="text-sm text-gray-600 mt-1 line-clamp-2">
              {noteToMove?.content || 'Empty note...'}
            </p>
          </div>
            <button
              onClick={onClose}
              className="p-1 hover:bg-gray-100 rounded-full transition-colors"
            >
              <X className="w-5 h-5 text-gray-500" />
            </button>
        </div>
        <div className="px-4 py-2 bg-gray-50 border-b">
          <p className="text-sm text-gray-600">
            Select where to move this note
          </p>
        </div>
        <div className="max-h-[60vh] overflow-y-auto">
          <button
            onClick={() => {
              if (selectedParent === null) {
                setSelectedParent(undefined);
              } else {
                setSelectedParent(null);
              }
            }}
            className={`w-full text-left px-4 py-2 hover:bg-gray-100 flex items-center gap-2 text-sm text-gray-700 font-medium ${
              selectedParent === null ? 'bg-blue-50' : ''
            }`}
          >
            <ArrowUpCircle className="w-4 h-4" />
            <span className="flex-1">Root level</span>
            <ArrowRight className={`w-4 h-4 transition-opacity ${
              selectedParent === null ? 'opacity-100 text-blue-600' : 'opacity-0'
            }`} />
          </button>
          {selectedParent === null && (
            <div className="border-l-2 border-blue-100 ml-6 my-1">
            <div className="pl-4 py-2 text-xs text-gray-500 font-medium">Select position:</div>
            <button
              onClick={() => handleMoveNote(null, 0)}
              className="w-full text-left px-4 py-2 hover:bg-blue-50 text-sm text-blue-700 flex items-center gap-2"
            >
              <span>At the beginning</span>
            </button>
            {notes.map((note, index) => (
              <button
                key={index + 1}
                onClick={() => handleMoveNote(null, index + 1)}
                className="w-full text-left px-4 py-2 hover:bg-blue-50 text-sm text-blue-700 flex items-center gap-2"
              >
                <span>After {note.content || 'Empty note...'}</span>
              </button>
            ))}
          </div>
          )}
          <div className="py-1">
            {notes.map(note => renderNoteOption(note))}
          </div>
        </div>
        <div className="p-4 border-t bg-gray-50 flex justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 text-gray-600 hover:text-gray-800"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
};