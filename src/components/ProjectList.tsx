import React from 'react';
import { Copy, Trash2 } from 'lucide-react';
import { Project } from '../types';

interface ProjectListProps {
  projects: Project[];
  currentTitle: string;
  isLoading: boolean;
  onProjectSelect: (projectId: string) => void;
  onProjectCopy: (projectId: string) => void;
  onProjectDelete: (project: { id: string; title: string }) => void;
}

export const ProjectList: React.FC<ProjectListProps> = ({
  projects,
  currentTitle,
  isLoading,
  onProjectSelect,
  onProjectCopy,
  onProjectDelete
}) => {
  if (isLoading) {
    return (
      <div className="absolute inset-0 flex items-center justify-center">
        <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  return (
    <div className="max-h-[400px] overflow-y-auto min-h-[100px]">
      {projects.map((project) => (
        <div
          key={project.id}
          className={`flex items-center justify-between px-4 py-2 hover:bg-gray-50 ${
            project.title === currentTitle ? 'bg-blue-50' : ''
          }`}
        >
          <div className="flex-1">
            <div className="flex items-center justify-between">
              <button
                onClick={() => onProjectSelect(project.id)}
                className="text-left text-sm text-gray-700 font-medium hover:text-gray-900"
              >
                {project.title}
              </button>
              <div className="flex items-center gap-1">
                <button
                  onClick={() => onProjectCopy(project.id)}
                  className="p-1 hover:bg-gray-200 rounded group"
                  title="Duplicate project"
                >
                  <Copy className="w-4 h-4 text-gray-400 group-hover:text-blue-600" />
                </button>
                <button
                  onClick={() => onProjectDelete({ id: project.id, title: project.title })}
                  className="p-1 hover:bg-gray-200 rounded group"
                  title="Delete project"
                >
                  <Trash2 className="w-4 h-4 text-gray-400 group-hover:text-red-600" />
                </button>
              </div>
            </div>
            <div className="mt-2 grid grid-cols-3 gap-2 text-xs">
              <div className="px-2 py-1 bg-gray-50 rounded">
                <span className="text-gray-500">Notes:</span>
                <span className="ml-1 text-gray-900 font-medium">{project.note_count}</span>
              </div>
              <div className="px-2 py-1 bg-gray-50 rounded">
                <span className="text-gray-500">Modified:</span>
                <span className="ml-1 text-gray-900 font-medium">
                  {project.last_modified_at
                    ? new Date(project.last_modified_at).toLocaleDateString()
                    : 'Never'}
                </span>
              </div>
              <div className="px-2 py-1 bg-gray-50 rounded">
                <span className="text-gray-500">Created:</span>
                <span className="ml-1 text-gray-900 font-medium">
                  {project.created_at
                    ? new Date(project.created_at).toLocaleDateString()
                    : 'Unknown'}
                </span>
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
};