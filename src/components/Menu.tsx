import React, { useState, useRef, useEffect } from 'react';
import { Menu as MenuIcon } from 'lucide-react';
import { useNoteStore } from '../store';
import { useAuth } from '../hooks/useAuth';

import { DeleteProjectModal } from './DeleteProjectModal';
import { NewProjectModal } from './NewProjectModal';
import { PrintAllNotes } from './PrintAllNotes';

import { TimedNotesView } from './TimedNotesView';
import { MenuItems } from './MenuItems';
import { ProjectList } from './ProjectList';
import { DeletedProjectList } from './DeletedProjectList';
// Placeholder component - replace with actual implementation
import { ImportNotesModal } from './ImportNotesModal';

interface MenuProps {
  onSignOut: () => void;
}

export function Menu({ onSignOut }: MenuProps) {
  const { loadProjects, projects, title, copyProject, deleteProject, switchProject, printNotes, notes, loadDeletedProjects, restoreProject, permanentlyDeleteProject } = useNoteStore();
  const { user } = useAuth();
  const [isOpen, setIsOpen] = useState(false);
  const [isPrintModalOpen, setIsPrintModalOpen] = useState(false);
  const [showProjectsMenu, setShowProjectsMenu] = useState(false);
  const [showTrashMenu, setShowTrashMenu] = useState(false);
  const [deletedProjects, setDeletedProjects] = useState<any[]>([]);
  const [projectToDelete, setProjectToDelete] = useState<{ id: string; title: string } | null>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const [showExportModal, setShowExportModal] = useState(false);
  const [showNewProjectModal, setShowNewProjectModal] = useState(false);
  const [showTimedNotesModal, setShowTimedNotesModal] = useState(false);
  const [showImportModal, setShowImportModal] = useState(false); // Added import modal state
  const projectsMenuRef = useRef<HTMLDivElement>(null);
  const trashMenuRef = useRef<HTMLDivElement>(null);
  const [isLoadingProjects, setIsLoadingProjects] = useState(false);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        if (!projectsMenuRef.current?.contains(event.target as Node) && !trashMenuRef.current?.contains(event.target as Node)) {
          setIsOpen(false);
          setShowProjectsMenu(false);
          setShowTrashMenu(false);
          setShowImportModal(false); // Added to close import modal on click outside
        }
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [projectsMenuRef]);

  const handleShowTrash = async () => {
    setIsLoadingProjects(true);
    setShowTrashMenu(true);
    const deleted = await loadDeletedProjects();
    setDeletedProjects(deleted || []);
    setIsLoadingProjects(false);
  };

  const handleShowProjects = async () => {
    setIsLoadingProjects(true);
    setShowProjectsMenu(true);
    await loadProjects();
    setIsLoadingProjects(false);
  };

  const handleDeleteConfirm = async () => {
    if (!projectToDelete) return;
    try {
      await deleteProject(projectToDelete.id);
      setProjectToDelete(null);
      setShowProjectsMenu(false);
    } catch (error) {
      console.error('Failed to delete project:', error);
      alert('Failed to delete project. Please try again.');
    }
  };

  const handleCopyProject = async (projectId: string) => {
    await copyProject(projectId);
    setShowProjectsMenu(false);
  };

  return (
    <div className="relative z-50" ref={menuRef}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="p-2 hover:bg-gray-800 rounded-lg transition-colors text-white"
        aria-label="Menu"
      >
        <MenuIcon className="w-5 h-5" />
      </button>

      {isOpen && (
        <MenuItems
          onShowProjects={handleShowProjects}
          onShowTrash={handleShowTrash}
          onNewProject={() => setShowNewProjectModal(true)}
          onShowTimedNotes={() => setShowTimedNotesModal(true)}
          onCopyNotes={() => {
            const text = printNotes();
            try {
              navigator.clipboard.writeText(text);
              alert('Notes copied to clipboard!');
            } catch (error) {
              console.error('Failed to copy notes:', error);
              alert('Failed to copy notes to clipboard. Please try again.');
            }
          }}
          onPrint={() => setIsPrintModalOpen(true)}
          onExport={() => setShowExportModal(true)}
          onImport={() => setShowImportModal(true)} // Added import handler
          onSignOut={onSignOut}
          onClose={() => setIsOpen(false)}
          userEmail={user?.email}
        />
      )}

      {showProjectsMenu && (
        <div 
          ref={projectsMenuRef}
          className="fixed right-4 mt-2 w-[480px] bg-white rounded-lg shadow-lg py-1"
        >
          <div className="px-4 py-2 border-b border-gray-100">
            <h3 className="font-medium text-gray-900">Your Projects</h3>
          </div>
          <ProjectList
            projects={projects}
            currentTitle={title}
            isLoading={isLoadingProjects}
            onProjectSelect={async (projectId) => {
              await switchProject(projectId);
              setShowProjectsMenu(false);
              setIsOpen(false);
            }}
            onProjectCopy={handleCopyProject}
            onProjectDelete={setProjectToDelete}
          />
        </div>
      )}

      {showTrashMenu && (
        <div 
          ref={trashMenuRef}
          className="fixed right-4 mt-2 w-[480px] bg-white rounded-lg shadow-lg py-1"
        >
          <div className="px-4 py-2 border-b border-gray-100">
            <h3 className="font-medium text-gray-900">Deleted Projects</h3>
          </div>
          <DeletedProjectList
            projects={deletedProjects}
            isLoading={isLoadingProjects}
            onRestore={async (projectId) => {
              await restoreProject(projectId);
              const deleted = await loadDeletedProjects();
              setDeletedProjects(deleted || []);
            }}
            onDelete={async (projectId) => {
              await permanentlyDeleteProject(projectId);
              const deleted = await loadDeletedProjects();
              setDeletedProjects(deleted || []);
            }}
          />
        </div>
      )}

      {isPrintModalOpen && (
        <PrintAllNotes
          notes={notes}
          onClose={() => setIsPrintModalOpen(false)}
        />
      )}

      

      {showImportModal && (
        <ImportNotesModal
          onClose={() => setShowImportModal(false)}
        />
      )}

      {projectToDelete && (
        <DeleteProjectModal
          projectTitle={projectToDelete.title}
          onConfirm={handleDeleteConfirm}
          onCancel={() => setProjectToDelete(null)}
        />
      )}

      {showNewProjectModal && (
        <NewProjectModal
          onClose={() => setShowNewProjectModal(false)}
          onSuccess={async (projectId) => {
            const newUrl = new URL(window.location.href);
            newUrl.searchParams.set('project', projectId);
            window.history.replaceState({}, '', newUrl.toString());
            await switchProject(projectId);
            setShowNewProjectModal(false);
          }}
        />
      )}

      {showTimedNotesModal && (
        <TimedNotesView onClose={() => setShowTimedNotesModal(false)} />
      )}
    </div>
  );
}