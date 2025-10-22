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
 * @param timezone - IANA timezone identifier (e.g., "America/New_York", "America/Denver")
 * Example: "Wednesday, January 15, 2025 at 2:30 PM EST (UTC-5)"
 */
export function getDateTimeContext(timezone?: string): string {
  const now = new Date();
  const tz = timezone || 'UTC';

  // Get day of week (e.g., "Wednesday")
  const dayOfWeek = now.toLocaleDateString('en-US', {
    weekday: 'long',
    timeZone: tz
  });

  // Get full date (e.g., "January 15, 2025")
  const fullDate = now.toLocaleDateString('en-US', {
    month: 'long',
    day: 'numeric',
    year: 'numeric',
    timeZone: tz
  });

  // Get time in 12-hour format (e.g., "2:30 PM")
  const time = now.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
    timeZone: tz
  });

  // Get timezone abbreviation (e.g., "EST", "PST", "MST")
  const timezoneName = now.toLocaleTimeString('en-US', {
    timeZoneName: 'short',
    timeZone: tz
  })
    .split(' ')
    .pop() || 'UTC';

  // Calculate UTC offset for the given timezone
  const formatter = new Intl.DateTimeFormat('en-US', {
    timeZone: tz,
    timeZoneName: 'longOffset'
  });
  const parts = formatter.formatToParts(now);
  const offsetPart = parts.find(part => part.type === 'timeZoneName');
  let utcOffset = 'UTC';

  if (offsetPart?.value) {
    // Extract offset from format like "GMT-7" or "GMT+5:30"
    const match = offsetPart.value.match(/GMT([+-]\d+(?::\d+)?)/);
    if (match) {
      utcOffset = `UTC${match[1]}`;
    }
  }

  return `${dayOfWeek}, ${fullDate} at ${time} ${timezoneName} (${utcOffset})`;
}

/**
 * Get a shorter date context suitable for welcome messages
 * @param timezone - IANA timezone identifier (e.g., "America/New_York", "America/Denver")
 * Example: "Wednesday, January 15th at 2:30 PM"
 */
export function getWelcomeDateContext(timezone?: string): string {
  const now = new Date();
  const tz = timezone || 'UTC';

  // Get day of week
  const dayOfWeek = now.toLocaleDateString('en-US', {
    weekday: 'long',
    timeZone: tz
  });

  // Get month and day with ordinal suffix
  const month = now.toLocaleDateString('en-US', {
    month: 'long',
    timeZone: tz
  });

  const dayNum = parseInt(now.toLocaleDateString('en-US', {
    day: 'numeric',
    timeZone: tz
  }), 10);
  const ordinalSuffix = getOrdinalSuffix(dayNum);

  // Get time in 12-hour format
  const time = now.toLocaleTimeString('en-US', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
    timeZone: tz
  });

  return `${dayOfWeek}, ${month} ${dayNum}${ordinalSuffix} at ${time}`;
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
 * @param timezone - IANA timezone identifier (e.g., "America/New_York", "America/Denver")
 */
export function getISODate(timezone?: string): string {
  const now = new Date();
  const tz = timezone || 'UTC';

  // Format date in the specified timezone as YYYY-MM-DD
  const year = now.toLocaleDateString('en-US', {
    year: 'numeric',
    timeZone: tz
  });
  const month = now.toLocaleDateString('en-US', {
    month: '2-digit',
    timeZone: tz
  });
  const day = now.toLocaleDateString('en-US', {
    day: '2-digit',
    timeZone: tz
  });

  return `${year}-${month}-${day}`;
}

/**
 * Get full system context including date, time, and year
 * This is the most comprehensive format for AI system prompts
 * @param timezone - IANA timezone identifier (e.g., "America/New_York", "America/Denver")
 */
export function getFullSystemContext(timezone?: string): string {
  const now = new Date();
  const tz = timezone || 'UTC';

  const currentYear = now.toLocaleDateString('en-US', {
    year: 'numeric',
    timeZone: tz
  });
  const dateTimeContext = getDateTimeContext(tz);
  const isoDate = getISODate(tz);

  return `Current system date/time: ${dateTimeContext}
Current year: ${currentYear}
Current date (ISO): ${isoDate}`;
}
