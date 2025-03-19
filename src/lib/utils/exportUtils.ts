
import { Note } from '../../types';

export const exportNotesAsJson = (notes: Note[]) => {
  const exportData = {
    notes: notes.map(note => ({
      id: note.id,
      content: note.content,
      position: note.position,
      is_discussion: note.is_discussion,
      time_set: note.time_set,
      youtube_url: note.youtube_url,
      url: note.url,
      url_display_text: note.url_display_text,
      children: note.children.map(child => ({
        id: child.id,
        content: child.content,
        position: child.position,
        is_discussion: child.is_discussion
      }))
    }))
  };
  return JSON.stringify(exportData, null, 2);
};
