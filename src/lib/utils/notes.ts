import { Note } from '../../types';

export const findNoteById = (notes: Note[], id: string): Note | null => {
  for (const note of notes) {
    if (note.id === id) return note;
    const found = findNoteById(note.children, id);
    if (found) return found;
  }
  return null;
};

export const removeNoteById = (notes: Note[], id: string): Note[] => {
  return notes.filter(note => {
    if (note.id === id) return false;
    note.children = removeNoteById(note.children, id);
    return true;
  });
};

export const countChildren = (note: Note): number => {
  let count = 0;
  for (const child of note.children) {
    count += 1 + countChildren(child);
  }
  return count;
};