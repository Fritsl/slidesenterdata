import { useState } from 'react';
import { Note } from '../types';
import { useNoteStore } from '../store';

export const useDragDrop = (note: Note, onError: (error: Error) => void) => {
  const [isDragging, setIsDragging] = useState(false);
  const [isDragOver, setIsDragOver] = useState(false);
  const [isParentTarget, setIsParentTarget] = useState(false);
  const [dropZone, setDropZone] = useState<'above' | 'below' | 'child' | null>(null); // Added dropZone state and 'child' option
  const { moveNote, currentLevel } = useNoteStore();

  const handleDragStart = (e: React.DragEvent) => {
    e.dataTransfer.setData('text/plain', note.id);
    e.dataTransfer.effectAllowed = 'move';
    setIsDragging(true);
  };

  const handleDragEnd = () => {
    setIsDragging(false);
    setIsParentTarget(false);
    setDropZone(null); // Reset dropZone on drag end
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    const rect = e.currentTarget.getBoundingClientRect();
    const isParentZone = e.clientX > rect.right - rect.width * 0.3;
    const mouseY = e.clientY;
    const relativeY = mouseY - rect.top;

    setIsParentTarget(isParentZone);
    setIsDragOver(true);

    if (isParentZone) {
      setDropZone('child');
    } else {
      setDropZone(relativeY < rect.height / 2 ? 'above' : 'below');
    }
  };

  const handleDragLeave = () => {
    setIsDragOver(false);
    setIsParentTarget(false);
    setDropZone(null); // Reset dropZone on drag leave
  };

  const handleDrop = async (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragOver(false);
    setIsParentTarget(false);
    setDropZone(null); // Reset dropZone after drop

    const rect = e.currentTarget.getBoundingClientRect();
    const isParentZone = e.clientX > rect.right - rect.width * 0.3;

    const draggedId = e.dataTransfer.getData('text/plain');
    if (draggedId === note.id) return;

    try {
      if (isParentZone) {
        await moveNote(draggedId, note.id, 0, currentLevel);
      } else {
        const newPosition = dropZone === 'above' ? note.position : note.position + 1;
        await moveNote(draggedId, note.parent_id, newPosition, currentLevel);
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
    dropZone, // Expose dropZone
    handleDragStart,
    handleDragEnd,
    handleDragOver,
    handleDragLeave,
    handleDrop
  };
};