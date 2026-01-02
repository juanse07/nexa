/**
 * Gamification Service
 *
 * Handles punctuality tracking with points and streaks:
 * - Award points for on-time clock-ins
 * - Track consecutive punctual day streaks
 * - Celebrate new personal records
 */

import { UserModel, UserDocument } from '../models/user';

// Points configuration
const POINTS = {
  ON_TIME: 10,      // Clocked in within 5 minutes of shift start
  EARLY: 5,         // Clocked in more than 5 minutes early
  LATE: 0,          // Clocked in late
  STREAK_BONUS_5: 25,   // Bonus for 5-day streak
  STREAK_BONUS_10: 50,  // Bonus for 10-day streak
  PERFECT_WEEK: 75,     // Bonus for 7 consecutive punctual days
};

// Time window for "on time" (in minutes)
const ON_TIME_WINDOW_MINUTES = 5;

export interface GamificationResult {
  pointsEarned: number;
  reason: 'on_time_clock_in' | 'early_arrival' | 'streak_bonus' | 'perfect_week';
  newStreak: number;
  previousStreak: number;
  isNewRecord: boolean;
  totalPoints: number;
  bonusPoints?: number;
  bonusReason?: string;
}

/**
 * Parse event start time from date and start_time fields
 */
function parseEventStartTime(event: any): Date | undefined {
  if (!event.date || !event.start_time) return undefined;

  try {
    const eventDate = new Date(event.date);
    const [hours, minutes] = event.start_time.split(':').map(Number);

    if (isNaN(hours) || isNaN(minutes)) return undefined;

    eventDate.setHours(hours, minutes, 0, 0);
    return eventDate;
  } catch {
    return undefined;
  }
}

/**
 * Check if two dates are on consecutive days
 */
function isConsecutiveDay(date1: Date, date2: Date): boolean {
  const d1 = new Date(date1);
  const d2 = new Date(date2);

  // Reset to midnight
  d1.setHours(0, 0, 0, 0);
  d2.setHours(0, 0, 0, 0);

  // Calculate difference in days
  const diffMs = d2.getTime() - d1.getTime();
  const diffDays = diffMs / (1000 * 60 * 60 * 24);

  return diffDays === 1;
}

/**
 * Check if two dates are on the same day
 */
function isSameDay(date1: Date, date2: Date): boolean {
  return (
    date1.getFullYear() === date2.getFullYear() &&
    date1.getMonth() === date2.getMonth() &&
    date1.getDate() === date2.getDate()
  );
}

/**
 * Award points for a clock-in and update streak
 *
 * @param userKey - User's key in "provider:subject" format
 * @param event - The event being clocked into
 * @param clockInTime - The actual clock-in timestamp
 * @returns Gamification result with points and streak info
 */
export async function awardClockInPoints(
  userKey: string,
  event: any,
  clockInTime: Date = new Date()
): Promise<GamificationResult | null> {
  const [provider, subject] = userKey.split(':');
  if (!provider || !subject) return null;

  const user = await UserModel.findOne({ provider, subject });
  if (!user) return null;

  // Parse event start time
  const eventStart = parseEventStartTime(event);
  if (!eventStart) return null;

  // Calculate punctuality
  const diffMinutes = (clockInTime.getTime() - eventStart.getTime()) / (1000 * 60);

  let points = 0;
  let reason: GamificationResult['reason'];

  if (diffMinutes <= ON_TIME_WINDOW_MINUTES && diffMinutes >= -60) {
    // On time: within 5 minutes of start (and not more than 60 min early)
    points = POINTS.ON_TIME;
    reason = 'on_time_clock_in';
  } else if (diffMinutes < -ON_TIME_WINDOW_MINUTES) {
    // Early: more than 5 minutes before shift
    points = POINTS.EARLY;
    reason = 'early_arrival';
  } else {
    // Late: don't award points, don't break streak
    // Return null to indicate no gamification update
    return null;
  }

  // Initialize gamification if needed
  if (!user.gamification) {
    user.gamification = {
      totalPoints: 0,
      currentStreak: 0,
      longestStreak: 0,
      pointsHistory: [],
    };
  }

  const now = new Date();
  const previousStreak = user.gamification.currentStreak || 0;
  let newStreak = 1;
  let bonusPoints = 0;
  let bonusReason: string | undefined;

  // Update streak logic
  if (user.gamification.lastPunctualClockIn) {
    const lastClockIn = new Date(user.gamification.lastPunctualClockIn);

    if (isSameDay(lastClockIn, now)) {
      // Already clocked in punctually today - keep current streak
      newStreak = previousStreak;
    } else if (isConsecutiveDay(lastClockIn, now)) {
      // Consecutive day - increment streak
      newStreak = previousStreak + 1;
    } else {
      // Streak broken - start fresh
      newStreak = 1;
      user.gamification.streakStartDate = now;
    }
  } else {
    // First punctual clock-in ever
    user.gamification.streakStartDate = now;
  }

  // Check for streak bonuses
  if (newStreak === 5 && previousStreak < 5) {
    bonusPoints = POINTS.STREAK_BONUS_5;
    bonusReason = '5-day streak bonus!';
    reason = 'streak_bonus';
  } else if (newStreak === 7 && previousStreak < 7) {
    bonusPoints = POINTS.PERFECT_WEEK;
    bonusReason = 'Perfect week bonus!';
    reason = 'perfect_week';
  } else if (newStreak === 10 && previousStreak < 10) {
    bonusPoints = POINTS.STREAK_BONUS_10;
    bonusReason = '10-day streak bonus!';
    reason = 'streak_bonus';
  }

  const totalPointsEarned = points + bonusPoints;

  // Check for new record
  const isNewRecord = newStreak > (user.gamification.longestStreak || 0);

  // Update user's gamification data
  user.gamification.totalPoints = (user.gamification.totalPoints || 0) + totalPointsEarned;
  user.gamification.currentStreak = newStreak;
  user.gamification.lastPunctualClockIn = now;

  if (isNewRecord) {
    user.gamification.longestStreak = newStreak;
  }

  // Add to points history (keep last 50 entries)
  const historyEntry = {
    points: totalPointsEarned,
    reason,
    eventId: String(event._id),
    earnedAt: now,
  };

  if (!user.gamification.pointsHistory) {
    user.gamification.pointsHistory = [];
  }

  user.gamification.pointsHistory.push(historyEntry);

  // Trim history to last 50 entries
  if (user.gamification.pointsHistory.length > 50) {
    user.gamification.pointsHistory = user.gamification.pointsHistory.slice(-50);
  }

  // Save the updated user
  await user.save();

  return {
    pointsEarned: totalPointsEarned,
    reason,
    newStreak,
    previousStreak,
    isNewRecord,
    totalPoints: user.gamification.totalPoints,
    bonusPoints: bonusPoints > 0 ? bonusPoints : undefined,
    bonusReason,
  };
}

/**
 * Get user's current gamification stats
 */
export async function getGamificationStats(userKey: string): Promise<{
  totalPoints: number;
  currentStreak: number;
  longestStreak: number;
  recentHistory: any[];
} | null> {
  const [provider, subject] = userKey.split(':');
  if (!provider || !subject) return null;

  const user = await UserModel.findOne({ provider, subject }).lean();
  if (!user) return null;

  return {
    totalPoints: user.gamification?.totalPoints || 0,
    currentStreak: user.gamification?.currentStreak || 0,
    longestStreak: user.gamification?.longestStreak || 0,
    recentHistory: (user.gamification?.pointsHistory || []).slice(-20),
  };
}

/**
 * Reset a user's streak (e.g., after too many days without punctual clock-in)
 * This can be called from a daily maintenance job
 */
export async function checkAndResetExpiredStreaks(): Promise<number> {
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - 2); // 2 days without punctual clock-in

  const result = await UserModel.updateMany(
    {
      'gamification.lastPunctualClockIn': { $lt: cutoffDate },
      'gamification.currentStreak': { $gt: 0 },
    },
    {
      $set: { 'gamification.currentStreak': 0 },
    }
  );

  return result.modifiedCount;
}
