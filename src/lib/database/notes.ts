import { supabase } from '../supabase';
import { Note } from '../../types';
import { handleDatabaseError, handleValidationError } from '../errors';

export const noteOperations = {
  async create(userId: string, projectId: string, parentId: string | null = null, content: string = '') {
    const noteId = crypto.randomUUID();

    const { error: noteError } = await supabase
      .from('notes')
      .insert({
        id: noteId,
        content,
        parent_id: parentId,
        position: 0,
        user_id: userId,
        project_id: projectId,
        is_discussion: false
      });

    if (noteError) {
      throw handleDatabaseError(noteError, 'Failed to create note');
    }

    return noteId;
  },

  async update(noteId: string, content: string) {
    const { error } = await supabase
      .from('notes')
      .update({ content })
      .eq('id', noteId);

    if (error) {
      throw handleDatabaseError(error, 'Failed to update note');
    }
  },

  async delete(noteId: string) {
    const { error } = await supabase.rpc('delete_note_safely', {
      note_id: noteId
    });

    if (error) {
      throw handleDatabaseError(error, 'Failed to delete note');
    }
  },

  async toggleDiscussion(noteId: string, value: boolean) {
    const { error } = await supabase
      .from('notes')
      .update({ is_discussion: value })
      .eq('id', noteId);

    if (error) {
      throw handleDatabaseError(error, 'Failed to toggle discussion');
    }
  },

  async toggleTime(noteId: string, time: string | null) {
    const { error } = await supabase
      .rpc('toggle_note_time', {
        p_note_id: noteId,
        p_time: time
      });

    if (error) {
      throw handleDatabaseError(error, 'Failed to set time');
    }
  },

  async move(noteId: string, parentId: string | null, position: number) {
    // First try the move
    const { error } = await supabase.rpc('move_note', {
      p_note_id: noteId,
      p_new_parent_id: parentId,
      p_new_position: position
    });

    if (error && error.message.includes('position')) {
      // If position error, try normalizing positions first
      await supabase.rpc('normalize_positions', {
        p_project_id: (await supabase
          .from('notes')
          .select('project_id')
          .eq('id', noteId)
          .single()
        ).data?.project_id,
        p_parent_id: parentId
      });
      
      // Try move again
      const { error: retryError } = await supabase.rpc('move_note', {
        p_note_id: noteId,
        p_new_parent_id: parentId,
        p_new_position: position
      });
      
      if (retryError) {
        throw handleDatabaseError(retryError, 'Failed to move note');
      }
    } else if (error) {
      throw handleDatabaseError(error, 'Failed to move note');
    }
  },

  async loadNotes(userId: string, projectId: string): Promise<Note[]> {
    const { data: notes, error } = await supabase
      .from('notes')
      .select(`
        *,
        images:note_images(*)
      `)
      .eq('user_id', userId)
      .eq('project_id', projectId)
      .order('position');

    if (error) {
      throw handleDatabaseError(error, 'Failed to load notes');
    }

    // Build tree structure
    const noteMap = new Map(notes?.map(note => ({
      ...note,
      children: [],
      images: note.images || [],
      isEditing: false,
      unsavedContent: undefined
    })).map(note => [note.id, note]) ?? []);
    
    const rootNotes: Note[] = [];

    if (notes) {
      for (const note of notes) {
        const noteWithChildren = noteMap.get(note.id);
        if (noteWithChildren) {
          if (note.parent_id && noteMap.has(note.parent_id)) {
            const parent = noteMap.get(note.parent_id);
            if (parent) {
              parent.children.push(noteWithChildren);
            } else {
              rootNotes.push(noteWithChildren);
            }
          } else {
            rootNotes.push(noteWithChildren);
          }
        }
      }
    }

    return rootNotes;
  }
};