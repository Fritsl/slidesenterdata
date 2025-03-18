import { StateCreator } from 'zustand';
import { Store } from '../types';
import { database } from '../../database';
import { handleDatabaseError } from '../../errors';
import { supabase } from '../../supabase';

export const createProjectSlice: StateCreator<Store> = (set, get) => ({
  title: 'New Project',
  projects: [],

  loadDeletedProjects: async () => {
    const user = await database.auth.getCurrentUser();

    const { data: projects, error } = await supabase
      .from('settings')
      .select('*')
      .not('deleted_at', 'is', null)
      .eq('user_id', user.id)
      .order('deleted_at', { ascending: false });

    if (error) {
      throw handleDatabaseError(error, 'Failed to load deleted projects');
    }

    return projects;
  },

  restoreProject: async (projectId: string) => {
    try {
      const { error } = await supabase.rpc('restore_project', {
        project_id: projectId
      });

      if (error) throw error;

      await get().loadProjects();
    } catch (error) {
      console.error('Error restoring project:', error);
      throw error;
    }
  },

  permanentlyDeleteProject: async (projectId: string) => {
    try {
      const { error } = await supabase.rpc('permanently_delete_project', {
        project_id: projectId
      });

      if (error) {
        console.error('Database error deleting project:', error);
        throw new Error('Failed to delete project: ' + error.message);
      }
    } catch (error) {
      console.error('Error permanently deleting project:', error);
      throw new Error('Failed to delete project. Please try again.');
    }
  },

  updateTitle: async (title: string) => {
    try {
      const user = await database.auth.getCurrentUser();
      const projectId = await database.projects.getCurrentProjectId();
      if (!projectId) return;

      await database.projects.update(projectId, user.id, title);

      set({ title });
      set(state => ({
        projects: state.projects.map(p =>
          p.id === projectId ? {
            ...p,
            title,
            updated_at: new Date().toISOString()
          } : p
        )
      }));
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to update title');
    }
  },

  loadProjects: async () => {
    try {
      const user = await database.auth.getCurrentUser();
      const projects = await database.projects.loadProjects(user.id);
      set({ projects });
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to load projects');
    }
  },

  switchProject: async (projectId: string) => {
    try {
      const user = await database.auth.getCurrentUser();
      set({ notes: [] });

      const project = await database.projects.getProject(projectId);
      if (!project) {
        throw new Error('Project not found');
      }

      await database.projects.updateProjectUrl(projectId);
      set({ title: project.title });

      // Set the last level from project settings if available
      if (project.last_level !== undefined) {
        get().setCurrentLevel(project.last_level);
      }

      try {
        const notes = await database.notes.loadNotes(user.id, projectId);
        set({ notes });
      } catch (error) {
        console.error('Failed to load notes:', error);
        set({ notes: [] });
      }
      
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to switch project');
    }
  },

  deleteProject: async (id: string) => {
    try {
      await database.projects.delete(id);

      const currentProjectId = await database.projects.getCurrentProjectId();
      if (currentProjectId === id) {
        const user = await database.auth.getCurrentUser();
        const remainingProjects = await database.projects.loadProjects(user.id);

        if (remainingProjects.length > 0) {
          await get().switchProject(remainingProjects[0].id);
        } else {
          const newProject = await database.projects.create(user.id, 'New Project');
          await get().switchProject(newProject.id);
        }
      }

      const user = await database.auth.getCurrentUser();
      const updatedProjects = await database.projects.loadProjects(user.id);
      set({ projects: updatedProjects });
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to delete project');
    }
  },

  copyProject: async (id: string) => {
    try {
      const user = await database.auth.getCurrentUser();
      const newProject = await database.projects.copy(id, user.id);
      await get().switchProject(newProject.id);
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to copy project');
    }
  },

  loadNotes: async () => {
    try {
      const user = await database.auth.getCurrentUser();
      const projects = await database.projects.loadProjects(user.id);

      if (projects.length > 0) {
        const projectId = await database.projects.getCurrentProjectId() || projects[0].id;
        const currentProject = projects.find(p => p.id === projectId) || projects[0];

        await database.projects.updateProjectUrl(currentProject.id);

        set({ 
          title: currentProject.title,
          projects
        });

        // Set the last level from project settings if available
        if (currentProject.last_level !== undefined) {
          get().setCurrentLevel(currentProject.last_level);
        }

        try {
          const notes = await database.notes.loadNotes(user.id, currentProject.id);
          set({ notes });
        } catch (error) {
          console.error('Failed to load notes:', error);
          set({ notes: [] });
        }
      } else {
        const newProject = await database.projects.create(user.id, 'New Project');
        set({ 
          title: newProject.title,
          projects: [newProject],
          notes: []
        });
        await database.projects.updateProjectUrl(newProject.id);
      }
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to load notes');
    }
  }
});