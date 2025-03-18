import React from 'react';
import { RotateCcw, Trash2 } from 'lucide-react';

interface DeletedProject {
  id: string;
  title: string;
  deleted_at: string;
  note_count: number;
}

interface DeletedProjectListProps {
  projects: DeletedProject[];
  isLoading: boolean;
  onRestore: (projectId: string) => Promise<void>;
  onDelete: (projectId: string) => Promise<void>;
}

export const DeletedProjectList: React.FC<DeletedProjectListProps> = ({
  projects,
  isLoading,
  onRestore,
  onDelete
}) => {
  if (isLoading) {
    return (
      <div className="absolute inset-0 flex items-center justify-center">
        <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-blue-600"></div>
      </div>
    );
  }

  if (projects.length === 0) {
    return (
      <div className="text-center py-8 text-gray-500">
        No deleted projects found
      </div>
    );
  }

  return (
    <div className="max-h-[400px] overflow-y-auto min-h-[100px]">
      {projects.map((project) => (
        <div
          key={project.id}
          className="flex items-center justify-between px-4 py-2 hover:bg-gray-50"
        >
          <div className="flex-1">
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-700 font-medium">
                {project.title}
              </span>
              <div className="flex items-center gap-1">
                <button
                  onClick={() => onRestore(project.id)}
                  className="p-1 hover:bg-gray-200 rounded group"
                  title="Restore project"
                >
                  <RotateCcw className="w-4 h-4 text-gray-400 group-hover:text-blue-600" />
                </button>
                <button
                  onClick={() => {
                    if (confirm('This will permanently delete the project. This action cannot be undone.')) {
                      onDelete(project.id);
                    }
                  }}
                  className="p-1 hover:bg-gray-200 rounded group"
                  title="Delete permanently"
                >
                  <Trash2 className="w-4 h-4 text-gray-400 group-hover:text-red-600" />
                </button>
              </div>
            </div>
            <div className="mt-2 grid grid-cols-2 gap-2 text-xs">
              <div className="px-2 py-1 bg-gray-50 rounded">
                <span className="text-gray-500">Deleted:</span>
                <span className="ml-1 text-gray-900 font-medium">
                  {new Date(project.deleted_at).toLocaleDateString()}
                </span>
              </div>
              <div className="px-2 py-1 bg-gray-50 rounded">
                <span className="text-gray-500">Notes:</span>
                <span className="ml-1 text-gray-900 font-medium">{project.note_count}</span>
              </div>
            </div>
          </div>
        </div>
      ))}
    </div>
  );
};