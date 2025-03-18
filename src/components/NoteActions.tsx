import React from 'react';
import { Plus, Edit2, MoveVertical, Trash2, Clock } from 'lucide-react';

interface NoteActionsProps {
  onEdit: () => void;
  onMove: () => void;
  onAdd: () => void;
  onDelete: () => void;
  onToggleTime: () => void;
  hasTimeSet: boolean;
}

export const NoteActions: React.FC<NoteActionsProps> = ({
  onEdit,
  onMove,
  onAdd,
  onDelete,
  onToggleTime,
  hasTimeSet
}) => (
  <div className="flex items-center justify-between gap-4">
    {/* Main action buttons group */}
    <div className="flex items-center gap-1">
      <button
        onClick={onEdit}
        className="p-1.5 rounded hover:bg-gray-700 touch-manipulation transition-colors group" 
        title="Edit note"
      >
        <Edit2 className="w-4 h-4 text-gray-300 group-hover:text-white" />
      </button>
      <button
        onClick={onMove}
        className="p-1.5 rounded hover:bg-gray-700 touch-manipulation transition-colors group" 
        title="Move note to another location"
      >
        <MoveVertical className="w-4 h-4 text-gray-300 group-hover:text-white" />
      </button>
      <button
        onClick={onAdd}
        className="p-1.5 rounded hover:bg-gray-700 touch-manipulation transition-colors group" 
        title="Add child note"
      >
        <Plus className="w-4 h-4 text-gray-300 group-hover:text-white" />
      </button>
      <button
        onClick={onToggleTime}
        className={`p-1.5 rounded hover:bg-gray-700 touch-manipulation transition-colors ${
          hasTimeSet ? 'text-blue-600' : ''
        } group`} 
        title={hasTimeSet ? "Change time" : "Set time"}
      >
        <Clock className={`w-4 h-4 ${!hasTimeSet ? 'text-gray-300 group-hover:text-white' : ''}`} />
      </button>
    </div>
    
    {/* Delete button */}
    <button
      onClick={onDelete}
      className="p-1.5 rounded hover:bg-red-900/50 touch-manipulation transition-colors group" 
      title="Delete note"
    >
      <Trash2 className="w-4 h-4 text-gray-300 group-hover:text-red-400" />
    </button>
  </div>
);