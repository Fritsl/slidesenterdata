// UI Constants
export const LEVEL_COLORS = [
  'bg-gray-800 hover:bg-gray-700',              // Level 0 - Dark Gray
  'bg-indigo-900/60 hover:bg-indigo-800/80',    // Level 1 - Dark Indigo
  'bg-sky-900/60 hover:bg-sky-800/80',          // Level 2 - Dark Sky Blue
  'bg-emerald-900/60 hover:bg-emerald-800/80',  // Level 3 - Dark Emerald
  'bg-amber-900/60 hover:bg-amber-800/80',      // Level 4 - Dark Amber
  'bg-rose-900/60 hover:bg-rose-800/80',        // Level 5+ - Dark Rose
] as const;

export const LEVEL_TEXT_STYLES = {
  0: 'text-2xl font-bold tracking-tight text-gray-100',        // Root level
  1: 'text-xl font-semibold text-gray-200',                    // First level
  2: 'text-lg font-medium text-gray-300',                      // Second level
  3: 'text-base font-normal text-gray-300',                    // Third level
  4: 'text-sm font-normal text-gray-400',                      // Fourth level
  default: 'text-xs font-normal text-gray-500'                 // Deeper levels
} as const;