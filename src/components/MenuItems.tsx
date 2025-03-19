import React from 'react';
import { Folder, Trash, FolderPlus, Clock, ExternalLink, FileText, Printer } from 'lucide-react';

interface MenuItemsProps {
  onShowProjects: () => void;
  onShowTrash: () => void;
  userEmail: string | undefined;
  onNewProject: () => void;
  onShowTimedNotes: () => void;
  onCopyNotes: () => void;
  onSignOut: () => void;
  onClose: () => void;
  onEditDescription: () => void;
  notes: any[];
}

export const MenuItems: React.FC<MenuItemsProps> = ({
  onShowProjects,
  onShowTrash,
  onNewProject,
  onShowTimedNotes,
  onCopyNotes,
  onSignOut,
  userEmail,
  onClose,
  onEditDescription,
}) => (
  <div className="fixed right-4 mt-2 w-48 bg-gray-800 rounded-lg shadow-lg py-1">
    <button
      onClick={() => {
        onNewProject();
        onClose();
      }}
      className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 transition-colors"
    >
      <FolderPlus className="w-4 h-4" />
      <span>New Project</span>
    </button>
    <button
      onClick={() => {
        onShowProjects();
        onClose();
      }}
      className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 transition-colors"
    >
      <Folder className="w-4 h-4" />
      <span>Projects</span>
    </button>
    <button
      onClick={() => {
        onShowTimedNotes();
        onClose();
      }}
      className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 transition-colors"
    >
      <Clock className="w-4 h-4" />
      <span>View Timed Notes</span>
    </button>
    <div className="border-t border-gray-700 my-1"></div>
    <button
      onClick={() => {
        onCopyNotes();
        onClose();
      }}
      className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 transition-colors"
    >
      <FileText className="w-4 h-4" />
      <span>Copy as Text</span>
    </button>
    <button
      onClick={() => {
        const jsonData = {
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
        navigator.clipboard.writeText(JSON.stringify(jsonData, null, 2));
        onClose();
        alert('Project exported as JSON and copied to clipboard!');
      }}
      className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 transition-colors"
    >
      <FileText className="w-4 h-4" />
      <span>Export as JSON</span>
    </button>
    <div className="border-t border-gray-700 my-1"></div>

    <button
      onClick={() => {
        onEditDescription();
        onClose();
      }}
      className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 transition-colors"
    >
      <FileText className="w-4 h-4" />
      <span>Edit Description</span>
    </button>

    <button
      onClick={() => {
        onShowTrash();
        onClose();
      }}
      className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-300 hover:bg-gray-700 transition-colors"
    >
      <Trash className="w-4 h-4" />
      <span>Trash</span>
    </button>
    {userEmail && (
      <div className="px-4 py-2 text-sm text-gray-400 border-t border-gray-700">
        <div className="truncate">{userEmail}</div>
        <button
          onClick={() => {
            onSignOut();
            onClose();
          }}
          className="text-red-400 hover:text-red-300 transition-colors mt-1"
        >
          Sign out
        </button>
      </div>
    )}
  </div>
);