import { useState } from 'react';
import { Note } from '../types';
import { useNoteStore } from '../store';

export const useNoteMovement = (note: Note, onError: (error: Error) => void) => {
  const { notes, expandedNotes, moveNote } = useNoteStore();
  
  // Get siblings at the same level
  const siblings = notes;

  // Calculate current position and max position
  const currentPosition = note.position ?? 0;
  const maxPosition = siblings.length - 1;

  const handleMoveUp = () => {
    if (currentPosition > 0) {
      moveNote(note.id, null, currentPosition - 1)
        .catch(error => {
          onError(error);
        });
    }
  };

  const handleMoveDown = () => {
    if (currentPosition < maxPosition) {
      moveNote(note.id, null, currentPosition + 1)
        .catch(error => {
          onError(error);
        });
    }
  };

  return {
    handleMoveUp,
    handleMoveDown,
    currentPosition,
    maxPosition
  };
};