import React, { useState } from 'react';
import { X, Clock } from 'lucide-react';
import { Note } from '../types';
import { useNoteStore } from '../store';

interface TimePickerModalProps {
  note: Note;
  onClose: () => void;
}

export function TimePickerModal({ note, onClose }: TimePickerModalProps) {
  const { toggleTime } = useNoteStore();
  const [time, setTime] = useState(note.time_set?.slice(0, 5) || '');
  const [isUpdating, setIsUpdating] = useState(false);
  const [inputValue, setInputValue] = useState('');

  const handleTimeChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setInputValue(value);
    
    // Convert to 24-hour format
    const [hours, minutes] = value.split(':');
    if (hours && minutes) {
      setTime(`${hours.padStart(2, '0')}:${minutes}`);
    }
  };

  const handleSubmit = async () => {
    try {
      setIsUpdating(true);
      await toggleTime(note.id, time || null);
      onClose();
    } catch (error) {
      console.error('Failed to set time:', error);
    } finally {
      setIsUpdating(false);
    }
  };

  const handleClear = async () => {
    try {
      setIsUpdating(true);
      await toggleTime(note.id, null);
      onClose();
    } catch (error) {
      console.error('Failed to clear time:', error);
    } finally {
      setIsUpdating(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-md">
        <div className="flex items-center justify-between px-4 py-3 border-b">
          <div className="flex items-center gap-2">
            <Clock className="w-5 h-5 text-blue-600" />
            <h2 className="text-lg font-semibold text-gray-900">Set Time</h2>
          </div>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>
        <div className="p-4">
          <div className="mb-4">
            <label htmlFor="time" className="block text-sm font-medium text-gray-700 mb-1">
              Time (24-hour format)
            </label>
            <input
              type="time"
              id="time"
              value={inputValue}
              onChange={handleTimeChange}
              data-time-format="24"
              className="w-full px-3 py-2 border border-gray-300 rounded-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            />
            <p className="mt-1 text-sm text-gray-500">
              Enter time in 24-hour format (00:00 - 23:59)
            </p>
          </div>
        </div>
        <div className="px-4 py-3 bg-gray-50 flex justify-end gap-2 rounded-b-lg">
          <button
            onClick={handleClear}
            disabled={isUpdating || !note.time_set}
            className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-800 disabled:opacity-50"
          >
            Clear
          </button>
          <button
            onClick={onClose}
            disabled={isUpdating}
            className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-800"
          >
            Cancel
          </button>
          <button
            onClick={handleSubmit}
            disabled={isUpdating || !time}
            className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          >
            {isUpdating ? (
              <>
                <span className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                Updating...
              </>
            ) : (
              'Set Time'
            )}
          </button>
        </div>
      </div>
    </div>
  );
}