/**
 * Utility for generating date/time context for AI chat systems
 * Provides consistent, server-side date/time information with timezone awareness
 */

/**
 * Format the current date/time with timezone information for AI context
 * Returns a human-friendly string that includes:
 * - Day of week
 * - Full date (Month DD, YYYY)
 * - Current time (HH:MM AM/PM)
 * - Timezone name and UTC offset
 *
 * Example: "Wednesday, January 15, 2025 at 2:30 PM EST (UTC-5)"
 */
export function getDateTimeContext(): string {
  const now = new Date();

  // Get day of week (e.g., "Wednesday")
  const dayOfWeek = now.toLocaleDateString('en-US', { weekday: 'long' });

  // Get full date (e.g., "January 15, 2025")
  const fullDate = now.toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
    year: 'numeric'
  });

  // Get time in 12-hour format (e.g., "2:30 PM")
  const time = now.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true
  });

  // Get timezone abbreviation (e.g., "EST", "PST")
  const timezone = now.toLocaleTimeString('en-US', { timeZoneName: 'short' })
    .split(' ')
    .pop() || 'UTC';

  // Calculate UTC offset (e.g., "-5" for EST)
  const offsetMinutes = -now.getTimezoneOffset();
  const offsetHours = Math.floor(Math.abs(offsetMinutes) / 60);
  const offsetSign = offsetMinutes >= 0 ? '+' : '-';
  const utcOffset = `UTC${offsetSign}${offsetHours}`;

  return `${dayOfWeek}, ${fullDate} at ${time} ${timezone} (${utcOffset})`;
}

/**
 * Get a shorter date context suitable for welcome messages
 * Example: "Wednesday, January 15th at 2:30 PM"
 */
export function getWelcomeDateContext(): string {
  const now = new Date();

  // Get day of week
  const dayOfWeek = now.toLocaleDateString('en-US', { weekday: 'long' });

  // Get month and day with ordinal suffix
  const month = now.toLocaleDateString('en-US', { month: 'long' });
  const day = now.getDate();
  const ordinalSuffix = getOrdinalSuffix(day);

  // Get time in 12-hour format
  const time = now.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true
  });

  return `${dayOfWeek}, ${month} ${day}${ordinalSuffix} at ${time}`;
}

/**
 * Get ordinal suffix for day (1st, 2nd, 3rd, 4th, etc.)
 */
function getOrdinalSuffix(day: number): string {
  if (day > 3 && day < 21) return 'th';
  switch (day % 10) {
    case 1: return 'st';
    case 2: return 'nd';
    case 3: return 'rd';
    default: return 'th';
  }
}

/**
 * Get ISO 8601 date format (YYYY-MM-DD) - useful for event dates
 */
export function getISODate(): string {
  const now = new Date();
  const isoDate = now.toISOString().split('T')[0];
  return isoDate || now.toISOString(); // Fallback to full ISO string if split fails
}

/**
 * Get full system context including date, time, and year
 * This is the most comprehensive format for AI system prompts
 */
export function getFullSystemContext(): string {
  const now = new Date();
  const currentYear = now.getFullYear();
  const dateTimeContext = getDateTimeContext();
  const isoDate = getISODate();

  return `Current system date/time: ${dateTimeContext}
Current year: ${currentYear}
Current date (ISO): ${isoDate}`;
}
