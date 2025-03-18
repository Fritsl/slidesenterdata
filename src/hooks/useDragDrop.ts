import { useState } from 'react';
import { Note } from '../types';
import { useNoteStore } from '../store';

export const useDragDrop = (note: Note, onError: (error: Error) => void) => {
  const [isDragging, setIsDragging] = useState(false);
  const [isDragOver, setIsDragOver] = useState(false);
  const [isParentTarget, setIsParentTarget] = useState(false);
  const { moveNote, currentLevel } = useNoteStore();

  const handleDragStart = (e: React.DragEvent) => {
    e.dataTransfer.setData('text/plain', note.id);
    e.dataTransfer.effectAllowed = 'move';
    setIsDragging(true);
  };

  const handleDragEnd = () => {
    setIsDragging(false);
    setIsParentTarget(false);
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    
    // Check if we're in the parent drop zone (right third of the note)
    const rect = e.currentTarget.getBoundingClientRect();
    const isParentZone = e.clientX > rect.right - rect.width * 0.3;
    
    setIsParentTarget(isParentZone);
    setIsDragOver(true);
  };

  const handleDragLeave = () => {
    setIsDragOver(false);
    setIsParentTarget(false);
  };

  const handleDrop = async (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragOver(false);
    setIsParentTarget(false);

    // Calculate parent zone first
    const rect = e.currentTarget.getBoundingClientRect();
    const isParentZone = e.clientX > rect.right - rect.width * 0.3;

    const draggedId = e.dataTransfer.getData('text/plain');
    if (draggedId === note.id) return;

    try {
      console.log('Drop event:', {
        draggedId,
        targetId: note.id,
        currentLevel,
        isParentZone,
        targetParentId: note.parent_id,
        targetPosition: note.position
      });

      if (isParentZone) {
        console.log('Parent zone drop:', {
          newParentId: note.id,
          newPosition: 0,
          level: currentLevel
        });
        // Make the dropped note a child of this note at position 0, preserving level
        await moveNote(draggedId, note.id, 0, currentLevel);
      } else {
        console.log('Sibling zone drop:', {
          newParentId: note.parent_id,
          newPosition: note.position,
          level: currentLevel
        });
        // Move as sibling at this note's position, preserving level
        await moveNote(draggedId, note.parent_id, note.position, currentLevel);
      }
    } catch (error) {
      console.error('Drop error:', error);
      onError(error as Error);
    }
  };

  return {
    isDragging,
    isDragOver,
    isParentTarget,
    handleDragStart,
    handleDragEnd,
    handleDragOver,
    handleDragLeave,
    handleDrop
  };
};