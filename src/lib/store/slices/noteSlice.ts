import { StateCreator } from 'zustand';
import { Store } from '../types';
import { findNoteById, removeNoteById } from '../../utils';
import { database } from '../../database';
import { supabase } from '../../supabase';
import { handleDatabaseError } from '../../errors';

export const createNoteSlice: StateCreator<Store> = (set, get) => ({
  notes: [],
  isEditMode: false,
  expandedNotes: new Set<string>(),
  currentLevel: 0,
  canExpandMore: false,
  canCollapseMore: false,
  isImporting: false, // Added import flag

  moveNote: async (id: string, parentId: string | null, position: number, level: number) => {
    try {
      const currentLevel = Math.max(0, level);

      // Validate position
      const siblings = get().notes.filter(n => n.parent_id === parentId);
      const maxPosition = siblings.length;
      const safePosition = Math.max(0, Math.min(position, maxPosition));

      await database.notes.move(id, parentId, safePosition);

      // Reload notes to get updated structure
      const user = await database.auth.getCurrentUser();
      const projectId = await database.projects.getCurrentProjectId();
      if (!projectId) return;

      const notes = await database.notes.loadNotes(user.id, projectId);

      // Update expanded states using the same level
      console.log('Setting expanded states with level:', level);

      set(state => {
        const newExpandedNotes = new Set(state.expandedNotes);
        const updateExpanded = (notes: Store['notes'], depth = 0) => {
          console.log('Updating expanded states at depth:', depth, 'target level:', level);
          notes.forEach(note => {
            if (note.children.length > 0) {
              if (depth < currentLevel) {
                console.log('Adding note to expanded:', note.id);
                newExpandedNotes.add(note.id);
              } else {
                console.log('Removing note from expanded:', note.id);
                newExpandedNotes.delete(note.id);
              }
              updateExpanded(note.children, depth + 1);
            }
          });
        };

        updateExpanded(notes);
        console.log('Final expanded state:', {
          expandedNotes: Array.from(newExpandedNotes),
          currentLevel: level
        });

        return {
          notes,
          expandedNotes: newExpandedNotes,
          currentLevel,
          canExpandMore: currentLevel < Math.max(...notes.map(note => {
            let depth = 0;
            const traverse = (note: Store['notes'][0], currentDepth = 0) => {
              depth = Math.max(depth, currentDepth);
              note.children.forEach(child => traverse(child, currentDepth + 1));
            };
            traverse(note);
            return depth;
          })),
          canCollapseMore: currentLevel > 0
        };
      });
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to move note');
    }
  },

  deleteNote: async (id: string) => {
    try {
      console.log('Starting deleteNote in store:', { noteId: id });

      // First get the note to check project_id
      const { data: note, error: noteError } = await supabase
        .from('notes')
        .select('project_id')
        .eq('id', id)
        .single();

      console.log('Retrieved note data:', { note, noteError });

      if (noteError) throw noteError;
      if (!note) throw new Error('Note not found');

      // Call RPC function
      console.log('Calling delete_note_safely RPC function');
      const { error: deleteError } = await supabase
        .rpc('delete_note_safely', { note_id: id });

      console.log('RPC function response:', { deleteError });
      if (deleteError) throw deleteError;

      console.log('Updating local state');
      set(state => ({
        notes: removeNoteById(state.notes, id)
      }));

      // Update project's note count in state
      console.log('Updating project note count');
      set(state => ({
        projects: state.projects.map(p =>
          p.id === note.project_id
            ? { ...p, note_count: Math.max(0, (p.note_count || 0) - 1) }
            : p
        )
      }));

      console.log('Note deletion completed successfully in store');
    } catch (error) {
      console.error('Error in deleteNote:', {
        error,
        noteId: id,
        errorMessage: error instanceof Error ? error.message : 'Unknown error',
        errorStack: error instanceof Error ? error.stack : undefined
      });
      throw handleDatabaseError(error, 'Failed to delete note');
    }
  },

  addNote: async (parentId: string | null = null, content: string = '') => {
    try {
      const user = await database.auth.getCurrentUser();
      const projectId = await database.projects.getCurrentProjectId();
      if (!projectId) return;

      const noteId = await database.notes.create(user.id, projectId, parentId, content);

      const newNote = {
        id: noteId,
        content: content,
        children: [],
        isEditing: false, // Default to not editing
        unsavedContent: '',
        user_id: user.id,
        project_id: projectId,
        is_discussion: false,
        parent_id: parentId,
        images: []
      };

      // Set isEditing to true only for manual note creation
      if (!get().isImporting) {
        newNote.isEditing = true;
      }

      set(state => {
        if (!parentId) {
          return { notes: [...state.notes, newNote] };
        }

        const updateChildren = (notes: Store['notes']): Store['notes'] => {
          return notes.map(note => {
            if (note.id === parentId) {
              return { ...note, children: [...note.children, newNote] };
            }
            return { ...note, children: updateChildren(note.children) };
          });
        };

        return { notes: updateChildren(state.notes) };
      });
      return newNote;
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to add note');
    }
  },

  updateNote: (id: string, content: string) => {
    set(state => {
      const updateNoteContent = (notes: Store['notes']): Store['notes'] => {
        return notes.map(note => {
          if (note.id === id) {
            return { ...note, unsavedContent: content };
          }
          if (note.children.length > 0) {
            return { ...note, children: updateNoteContent(note.children) };
          }
          return note;
        });
      };
      return { notes: updateNoteContent(state.notes) };
    });
  },

  saveNote: async (id: string) => {
    const note = findNoteById(get().notes, id);
    if (!note?.unsavedContent && note?.content === '') {
      await database.notes.delete(id);
      set(state => ({ notes: removeNoteById(state.notes, id) }));
      return;
    }

    if (note && note.unsavedContent !== undefined) {
      try {
        await database.notes.update(id, note.unsavedContent);
        set(state => {
          const updateNoteContent = (notes: Store['notes']): Store['notes'] => {
            return notes.map(n => {
              if (n.id === id) {
                return { ...n, content: note.unsavedContent, unsavedContent: undefined };
              }
              if (n.children.length > 0) {
                return { ...n, children: updateNoteContent(n.children) };
              }
              return n;
            });
          };
          return { notes: updateNoteContent(state.notes) };
        });
      } catch (error) {
        throw handleDatabaseError(error, 'Failed to save note');
      }
    }
  },

  toggleEdit: (id: string) => {
    set(state => {
      const updateNoteEdit = (notes: Store['notes']): Store['notes'] => {
        return notes.map(note => {
          if (note.id === id) {
            const newIsEditing = !note.isEditing;
            set(state => ({ ...state, isEditMode: newIsEditing }));
            return { ...note, isEditing: newIsEditing };
          }
          if (note.children.length > 0) {
            return { ...note, children: updateNoteEdit(note.children) };
          }
          return note;
        });
      };
      return {
        notes: updateNoteEdit(state.notes)
      };
    });
  },

  setCurrentLevel: (level: number) => {
    const state = get();
    const treeDepth = Math.max(...state.notes.map(note => {
      let depth = 0;
      const traverse = (note: Store['notes'][0], currentDepth = 0) => {
        depth = Math.max(depth, currentDepth);
        note.children.forEach(child => traverse(child, currentDepth + 1));
      };
      traverse(note);
      return depth;
    }));

    const newLevel = Math.max(0, Math.min(level, treeDepth));
    const newExpandedNotes = new Set(state.expandedNotes);

    const updateExpanded = (notes: Store['notes'], currentDepth = 0) => {
      notes.forEach(note => {
        if (note.children.length > 0) {
          if (currentDepth < newLevel) {
            newExpandedNotes.add(note.id);
          } else {
            newExpandedNotes.delete(note.id);
          }
          updateExpanded(note.children, currentDepth + 1);
        }
      });
    };

    updateExpanded(state.notes);

    // Save the level to the database
    const saveLevel = async () => {
      try {
        const projectId = await database.projects.getCurrentProjectId();
        if (projectId) {
          await database.projects.updateLastLevel(projectId, newLevel);
        }
      } catch (error) {
        console.error('Failed to save level:', error);
      }
    };
    saveLevel();

    set({
      expandedNotes: newExpandedNotes,
      currentLevel: newLevel,
      canExpandMore: newLevel < treeDepth,
      canCollapseMore: newLevel > 0
    });
  },

  expandOneLevel: () => {
    const state = get();
    return state.setCurrentLevel(state.currentLevel + 1);
  },

  collapseOneLevel: () => {
    const state = get();
    return state.setCurrentLevel(state.currentLevel - 1);
  },

  setEditMode: (isEditing: boolean) => set({ isEditMode: isEditing }),

  addImage: async (noteId: string, url: string) => {
    try {
      const image = await database.images.add(noteId, url);
      console.log('Image added successfully:', image);

      set(state => {
        const updateNoteImages = (notes: Store['notes']): Store['notes'] => {
          return notes.map(note => {
            if (note.id === noteId) {
              return {
                ...note,
                images: [...(note.images || []), image]
              };
            }
            if (note.children.length > 0) {
              return { ...note, children: updateNoteImages(note.children) };
            }
            return note;
          });
        };

        return {
          notes: updateNoteImages(state.notes)
        };
      });
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to add image');
    }
  },

  removeImage: async (noteId: string, imageId: string) => {
    try {
      console.log('Starting image removal:', { noteId, imageId });
      await database.images.remove(imageId);
      console.log('Image removed from database');

      set(state => {
        const updateNoteImages = (notes: Store['notes']): Store['notes'] => {
          return notes.map(note => {
            if (note.id === noteId) {
              return {
                ...note,
                images: (note.images || []).filter(img => img.id !== imageId)
              };
            }
            if (note.children.length > 0) {
              return { ...note, children: updateNoteImages(note.children) };
            }
            return note;
          });
        };

        return {
          notes: updateNoteImages(state.notes)
        };
      });

      console.log('Local state updated after image removal');
    } catch (error) {
      console.error('Error removing image:', error);
      throw handleDatabaseError(error, 'Failed to remove image');
    }
  },

  moveImage: async (noteId: string, imageId: string, newPosition: number) => {
    try {
      await database.images.move(noteId, imageId, newPosition);

      // Get updated note data to ensure correct order
      const { data: updatedImages, error } = await supabase
        .from('note_images')
        .select('*')
        .eq('note_id', noteId)
        .order('position');

      if (error) throw error;

      set(state => {
        const updateNoteImages = (notes: Store['notes']): Store['notes'] => {
          return notes.map(note => {
            if (note.id === noteId) {
              return { ...note, images: updatedImages };
            }
            if (note.children.length > 0) {
              return { ...note, children: updateNoteImages(note.children) };
            }
            return note;
          });
        };

        return {
          notes: updateNoteImages(state.notes)
        };
      });
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to move image');
    }
  },

  toggleDiscussion: async (id: string, value: boolean) => {
    try {
      await database.notes.toggleDiscussion(id, value);
      set(state => {
        const updateNoteDiscussion = (notes: Store['notes']): Store['notes'] => {
          return notes.map(note => {
            if (note.id === id) {
              return { ...note, is_discussion: value };
            }
            if (note.children.length > 0) {
              return { ...note, children: updateNoteDiscussion(note.children) };
            }
            return note;
          });
        };

        return {
          notes: updateNoteDiscussion(state.notes)
        };
      });
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to toggle discussion');
    }
  },

  toggleTime: async (id: string, time: string | null) => {
    try {
      await database.notes.toggleTime(id, time);
      set(state => {
        const updateNoteTime = (notes: Store['notes']): Store['notes'] => {
          return notes.map(note => {
            if (note.id === id) {
              return { ...note, time_set: time };
            }
            if (note.children.length > 0) {
              return { ...note, children: updateNoteTime(note.children) };
            }
            return note;
          });
        };

        return {
          notes: updateNoteTime(state.notes)
        };
      });
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to set time');
    }
  },

  setYoutubeUrl: async (id: string, url: string | null) => {
    try {
      const { error } = await supabase
        .from('notes')
        .update({ youtube_url: url })
        .eq('id', id);

      if (error) throw error;

      set(state => {
        const updateNoteYoutube = (notes: Store['notes']): Store['notes'] => {
          return notes.map(note => {
            if (note.id === id) {
              return { ...note, youtube_url: url };
            }
            if (note.children.length > 0) {
              return { ...note, children: updateNoteYoutube(note.children) };
            }
            return note;
          });
        };

        return {
          notes: updateNoteYoutube(state.notes)
        };
      });
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to set YouTube URL');
    }
  },

  setUrl: async (id: string, url: string | null, displayText: string | null) => {
    try {
      const { error } = await supabase
        .from('notes')
        .update({ 
          url: url,
          url_display_text: displayText 
        })
        .eq('id', id);

      if (error) throw error;

      set(state => {
        const updateNoteUrl = (notes: Store['notes']): Store['notes'] => {
          return notes.map(note => {
            if (note.id === id) {
              return { 
                ...note, 
                url: url,
                url_display_text: displayText 
              };
            }
            if (note.children.length > 0) {
              return { ...note, children: updateNoteUrl(note.children) };
            }
            return note;
          });
        };

        return {
          notes: updateNoteUrl(state.notes)
        };
      });
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to set URL');
    }
  },

  printNotes: () => {
    const { notes, expandedNotes } = get();
    let result = '';

    const formatNote = (note: Store['notes'][0], level = 0) => {
      const indent = '  '.repeat(level);
      result += `${indent}• ${note.content || 'Empty note...'}\n`;
      if (note.children.length > 0 && expandedNotes.has(note.id)) {
        note.children.forEach(child => formatNote(child, level + 1));
      }
    };

    notes.forEach(note => formatNote(note));
    return result;
  },

  importNotes: async (parsedNotes: { notes: string[], level: number, parentContent?: string }[]) => {
    const log = (msg: string, data?: any) => {
      const logEl = document.getElementById('debug-log');
      if (logEl) {
        const message = data ? `${msg}: ${JSON.stringify(data, null, 2)}` : msg;
        logEl.textContent = message + '\n' + (logEl.textContent || '');
      }
    };

    try {
      if (!parsedNotes || parsedNotes.length === 0) {
        throw new Error('No valid notes to import');
      }

      set({ isImporting: true });
      log('Starting importNotes');

      const contentToIdMap = new Map<string, string>();
      const processedContent = new Set<string>();
      
      // First pass: Create all notes and track their IDs
      for (const { notes, level, parentContent } of parsedNotes) {
        for (const content of notes) {
          if (!content || typeof content !== 'string') continue;
          const trimmedContent = content.trim();
          
          // Filter out debug messages and invalid content
          if (!trimmedContent 
              || processedContent.has(trimmedContent)
              || trimmedContent.startsWith('{')
              || trimmedContent.startsWith('[')
              || trimmedContent.startsWith('"')
              || trimmedContent.includes('console.log')
              || trimmedContent.includes('Created root note')
              || trimmedContent.includes('Import completed')
              || trimmedContent.includes('Starting')
              || /^[\[\]{}",]+$/.test(trimmedContent)) continue;
          
          const parentId = parentContent ? contentToIdMap.get(parentContent) : null;
          const addNoteResponse = await get().addNote(parentId, trimmedContent);
          if (!addNoteResponse?.id) throw new Error('Failed to create note');
          
          contentToIdMap.set(trimmedContent, addNoteResponse.id);
          processedContent.add(trimmedContent);
        }
      }

      // Second pass: Create child notes level by level
      let currentLevel = 1;
      let hasMoreLevels = true;

      while (hasMoreLevels) {
        hasMoreLevels = false;
        for (const { notes, level, parentContent } of parsedNotes) {
          if (level === currentLevel && parentContent) {
            const parentId = contentToIdMap.get(parentContent);
            if (!parentId) continue;

            for (const content of notes) {
              if (!content || typeof content !== 'string') continue;
              const trimmedContent = content.trim();
              if (!trimmedContent || processedContent.has(trimmedContent)) continue;

              console.log(`Creating level ${currentLevel} note:`, trimmedContent, 'parent:', parentContent);
              const addNoteResponse = await get().addNote(parentId, trimmedContent);
              if (!addNoteResponse?.id) throw new Error('Failed to create note');

              contentToIdMap.set(trimmedContent, addNoteResponse.id);
              processedContent.add(trimmedContent);
              log('Created child note', addNoteResponse);
            }
          }
          if (level > currentLevel) hasMoreLevels = true;
        }
        currentLevel++;
      }

      log('Import completed');
    } catch (error) {
      log('Error importing notes:', error);
      throw error;
    } finally {
      set({ isImporting: false }); // Reset import flag after import
    }
  }
});

export interface Store {
  notes: Note[];
  title: string;
  isEditMode: boolean;
  isImporting: boolean; // Added import flag
}