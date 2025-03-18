import React from 'react';
import { Image as ImageIcon, Users, Clock, Youtube } from 'lucide-react';
import { Note } from '../types';
import { LEVEL_TEXT_STYLES } from '../lib/constants';
import { linkify } from '../lib/utils/text';

interface NoteContentProps {
  note: Note;
  level: number;
}

const NoteContent: React.FC<NoteContentProps> = ({ note, level }) => (
  <div className="flex flex-col gap-1">
    <div className={`flex items-center gap-2 ${LEVEL_TEXT_STYLES[Math.min(level, 4) as keyof typeof LEVEL_TEXT_STYLES] || LEVEL_TEXT_STYLES.default}`}>
      <div className="flex-1 break-words">
        <span className="whitespace-pre-wrap">
          {linkify(note.content || 'Empty note...').map(part => (
            part.type === 'link' ? (
              <a
                key={part.key}
                href={part.url}
                target="_blank"
                rel="noopener noreferrer"
                className="text-blue-600 hover:text-blue-800 underline"
                onClick={(e) => e.stopPropagation()}
              >
                {part.url}
              </a>
            ) : (
              <React.Fragment key={part.key}>{part.content}</React.Fragment>
            )
          ))}
        </span>
      </div>
      <div className="flex items-center gap-1 text-xs text-gray-400">
        <span>pos: {note.position}</span>
      </div>
      {note.images && note.images.length > 0 && (
        <span className="text-gray-400">
          <ImageIcon className="w-4 h-4" />
        </span>
      )}
      {note.is_discussion && (
        <Users className="w-4 h-4 text-blue-500" />
      )}
      {note.youtube_url && (
        <Youtube className="w-4 h-4 text-red-500" />
      )}
      {note.time_set && (
        <div className="flex items-center gap-1 text-blue-500">
          <Clock className="w-4 h-4" />
          <span className="text-xs font-medium">{note.time_set.slice(0, 5)}</span>
        </div>
      )}
    </div>
  </div>
);

export { NoteContent }