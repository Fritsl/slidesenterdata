import React, { useState } from 'react';
import { Note as NoteType } from '../types';
import { useNoteStore } from '../store';
import { useClickOutside } from '../lib/hooks/useClickOutside';
import { LEVEL_COLORS } from '../lib/constants';
import { FullscreenEditor } from './FullscreenEditor';
import { TimePickerModal } from './TimePickerModal';
import { MoveToMenu } from './MoveToMenu';
import { DeleteNoteModal } from './DeleteNoteModal';
import { NoteContent } from './NoteContent';
import { NoteActions } from './NoteActions';
import { useDragDrop } from '../hooks/useDragDrop';
import { ChevronRight, ChevronDown, MoreVertical, Timer, Youtube, Link, Clock, ChevronUp, ChevronDown as MoveDown } from 'lucide-react';

interface NoteProps {
  note: NoteType;
  level: number;
  onError: (error: Error) => void;
}

export const Note: React.FC<NoteProps> = ({ note, level, onError }) => {
  const { updateNote, toggleEdit, addNote, saveNote, setEditMode, deleteNote, expandedNotes, moveNote, notes } = useNoteStore();
  const [isSelected, setIsSelected] = useState(false);
  const [isMoveMenuOpen, setIsMoveMenuOpen] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [showTimeModal, setShowTimeModal] = useState(false);
  const noteRef = React.useRef<HTMLDivElement>(null);
  const children = note.children || [];
  const {
    isDragging,
    isDragOver,
    isParentTarget,
    dropZone,
    handleDragStart,
    handleDragEnd,
    handleDragOver,
    handleDragLeave,
    handleDrop
  } = useDragDrop(note, onError); // Assumed useDragDrop now returns dropZone

  useClickOutside(noteRef, () => {
    if (isSelected) {
      setIsSelected(false);
    }
  }, [isSelected]);

  const isDiscussionThread = note.is_discussion;
  const isLastChild = !notes.some(n => n.parent_id === note.parent_id && n.position > note.position);

  return (
    <div className="group relative" id={note.id} ref={noteRef}>
      <div
        draggable
        onDragStart={handleDragStart}
        onDragEnd={handleDragEnd}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onClick={(e) => {
          e.preventDefault();
          e.stopPropagation();
          setIsSelected(true);
        }}
        className={`flex items-start gap-2 p-3 rounded-lg shadow-md hover:shadow-lg transition-all cursor-move bg-opacity-90 hover:bg-opacity-100 relative
          ${LEVEL_COLORS[Math.min(level, LEVEL_COLORS.length - 1)]} 
          ${isDragging ? 'opacity-50' : ''}
          ${isDragOver ? (dropZone === 'above' ? 'border-t-2 border-t-blue-500' : dropZone === 'below' ? 'border-b-2 border-b-blue-500' : '') : ''}
          ${isSelected ? 'ring-2 ring-blue-500' : ''}
          ${isDragOver && (isParentTarget || dropZone === 'child') ? 'border-r-4 border-r-purple-500' : ''}
        `}
      >
        <div className="w-full">
          <div className="flex flex-col gap-2">
            {note.isEditing ? (
              <FullscreenEditor
                content={note.unsavedContent ?? note.content}
                isNew={!note.content}
                note={note}
                onChange={(content) => updateNote(note.id, content)}
                onClose={() => {
                  setEditMode(false);
                  saveNote(note.id);
                  toggleEdit(note.id);
                }}
              />
            ) : (
              <div className="flex-1">
                <div className="flex flex-col gap-2">
                  <NoteContent note={note} level={level} />
                  <div className={`flex items-center gap-1 ${isSelected || note.isEditing ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'} transition-opacity`}>
                    <NoteActions 
                      onEdit={() => {
                        setEditMode(true);
                        toggleEdit(note.id);
                        setIsSelected(false);
                      }}
                      onMove={() => {
                        setIsMoveMenuOpen(true);
                        setIsSelected(false);
                      }}
                      onAdd={() => {
                        addNote(note.id);
                        setIsSelected(false);
                      }}
                      onToggleTime={() => {
                        setShowTimeModal(true);
                        setIsSelected(false);
                      }}
                      hasTimeSet={!!note.time_set}
                      onDelete={() => {
                        setShowDeleteModal(true);
                        setIsSelected(false);
                      }}
                    />
                    <div className="opacity-0 group-hover:opacity-100 transition-opacity flex gap-1">
                      {note.position > 0 && (
                        <button 
                          onClick={(e) => {
                            e.stopPropagation();
                            moveNote(note.id, note.parent_id, note.position - 1);
                          }}
                          className="p-1 hover:bg-gray-700 rounded"
                        >
                          <ChevronUp className="w-4 h-4" />
                        </button>
                      )}
                      {!isLastChild && (
                        <button 
                          onClick={(e) => {
                            e.stopPropagation();
                            e.preventDefault();
                            moveNote(note.id, note.parent_id, note.position + 1);
                          }}
                          className="p-1 hover:bg-gray-700 rounded cursor-pointer"
                        >
                          <MoveDown className="w-4 h-4" />
                        </button>
                      )}
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>
      </div>

      {isMoveMenuOpen && (
        <MoveToMenu
          noteId={note.id}
          onClose={() => setIsMoveMenuOpen(false)}
        />
      )}

      {showDeleteModal && (
        <DeleteNoteModal
          noteContent={note.content}
          note={note}
          onConfirm={async () => {
            await deleteNote(note.id);
            setShowDeleteModal(false);
          }}
          onCancel={() => setShowDeleteModal(false)}
        />
      )}

      {showTimeModal && (
        <TimePickerModal
          note={note}
          onClose={() => setShowTimeModal(false)}
        />
      )}

      {children.length > 0 && expandedNotes.has(note.id) && (
        <div className="pl-4 mt-3 space-y-3 border-l-2 border-gray-200">
          {children.map((child) => (
            <Note 
              key={child.id} 
              note={child}
              level={level + 1}
              onError={onError}
            />
          ))}
        </div>
      )}
    </div>
  );
};