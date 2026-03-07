/**
 * Staff Matching Service
 *
 * Ranks staff candidates for a given event role using a composite score (0-100):
 *   - Skills Match (35%): Union of manager-confirmed + self-reported skills
 *   - Certifications (25%): Valid (non-expired) certs, bonus for manager-verified
 *   - Performance (25%): Rating, punctuality, reliability from last 90 days
 *   - Availability (15%): Day/shift preferences, travel distance, max hours
 *
 * Tiebreakers: isFavorite → higher rating → alphabetical name.
 */

import mongoose from 'mongoose';
import { StaffProfileModel, StaffProfileDocument } from '../models/staffProfile';
import { UserModel, UserDocument } from '../models/user';
import { EventModel } from '../models/event';
import { TeamMemberModel } from '../models/teamMember';
import { computePunctuality } from '../utils/performanceMetrics';

export interface StaffMatchCandidate {
  userKey: string;
  name: string;
  email?: string;
  picture?: string;
  scores: {
    skills: number;
    certifications: number;
    performance: number;
    availability: number;
    total: number;
  };
  matchedSkills: string[];
  missingSkills: string[];
  matchedCerts: string[];
  missingCerts: string[];
  isFavorite: boolean;
  rating: number;
  isBusy: boolean;
  busyReason?: string;
}

export interface RoleRequest {
  roleName: string;
  requiredSkills?: string[];
  requiredCertifications?: string[];
  eventDate?: Date;
  eventStartTime?: string;
  eventEndTime?: string;
  venueLat?: number;
  venueLng?: number;
}

interface MatchOptions {
  limit?: number;
}

// Weights for composite score
const WEIGHT_SKILLS = 0.35;
const WEIGHT_CERTS = 0.25;
const WEIGHT_PERFORMANCE = 0.25;
const WEIGHT_AVAILABILITY = 0.15;

/**
 * Haversine distance in miles between two lat/lng points.
 */
function haversineDistanceMiles(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 3958.8; // Earth radius in miles
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLng / 2) * Math.sin(dLng / 2);
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Compute skills match score (0-1).
 * Union of manager-confirmed (StaffProfile.skills) and self-reported (User.skills).
 */
function scoreSkills(
  requiredSkills: string[],
  profileSkills: string[],
  userSkills: string[]
): { score: number; matched: string[]; missing: string[] } {
  if (requiredSkills.length === 0) {
    return { score: 0.5, matched: [], missing: [] }; // Neutral when no requirements
  }

  const candidateSkills = new Set([
    ...profileSkills.map(s => s.toLowerCase()),
    ...userSkills.map(s => s.toLowerCase()),
  ]);

  const matched: string[] = [];
  const missing: string[] = [];

  for (const req of requiredSkills) {
    if (candidateSkills.has(req.toLowerCase())) {
      matched.push(req);
    } else {
      missing.push(req);
    }
  }

  return {
    score: matched.length / requiredSkills.length,
    matched,
    missing,
  };
}

/**
 * Compute certifications match score (0-1).
 * Must be non-expired on event date. 10% bonus for manager-verified.
 */
function scoreCertifications(
  requiredCerts: string[],
  profileCerts: StaffProfileDocument['certifications'],
  userCerts: UserDocument['certifications'],
  eventDate?: Date
): { score: number; matched: string[]; missing: string[] } {
  if (requiredCerts.length === 0) {
    return { score: 0.5, matched: [], missing: [] }; // Neutral when no requirements
  }

  const checkDate = eventDate || new Date();

  // Build a map of all certs (name → { valid, verified })
  const certMap = new Map<string, { valid: boolean; verified: boolean }>();

  // User self-reported certs
  if (userCerts) {
    for (const cert of userCerts) {
      const name = cert.name.toLowerCase();
      const valid = !cert.expiryDate || new Date(cert.expiryDate) >= checkDate;
      certMap.set(name, { valid, verified: false });
    }
  }

  // Manager-confirmed certs (override user certs)
  if (profileCerts) {
    for (const cert of profileCerts) {
      const name = cert.name.toLowerCase();
      const valid = !cert.expiryDate || new Date(cert.expiryDate) >= checkDate;
      const existing = certMap.get(name);
      certMap.set(name, {
        valid: valid || (existing?.valid ?? false),
        verified: !!cert.verifiedAt,
      });
    }
  }

  const matched: string[] = [];
  const missing: string[] = [];
  let rawScore = 0;

  for (const req of requiredCerts) {
    const entry = certMap.get(req.toLowerCase());
    if (entry && entry.valid) {
      matched.push(req);
      rawScore += 1 + (entry.verified ? 0.1 : 0); // 10% bonus for verified
    } else {
      missing.push(req);
    }
  }

  return {
    score: Math.min(1, rawScore / requiredCerts.length),
    matched,
    missing,
  };
}

/**
 * Compute performance score (0-1).
 * Weighted: rating (40%) + punctuality (35%) + reliability (25%).
 * Requires min 3 events in lookback period, else defaults to 0.5.
 */
function scorePerformance(
  rating: number,
  punctualityRecords: { onTimeCount: number; totalEvents: number; noShowCount: number }[]
): number {
  const ratingScore = rating > 0 ? rating / 5 : 0.5;

  const record = punctualityRecords[0];
  if (!record || record.totalEvents < 3) {
    // Not enough data — return neutral
    return ratingScore * 0.4 + 0.5 * 0.35 + 0.5 * 0.25;
  }

  const punctualityPct = record.totalEvents > 0
    ? record.onTimeCount / record.totalEvents
    : 0.5;

  // Reliability = 1 - (noShows / totalEvents)
  const reliability = record.totalEvents > 0
    ? 1 - (record.noShowCount / record.totalEvents)
    : 0.5;

  return ratingScore * 0.4 + punctualityPct * 0.35 + reliability * 0.25;
}

/**
 * Compute availability score (0-1).
 * Factors: day preference (30%), shift preference (30%), travel distance (20%), max hours (20%).
 */
function scoreAvailability(
  user: UserDocument,
  roleRequest: RoleRequest
): number {
  const prefs = user.workPreferences;
  let dayScore = 0.5;
  let shiftScore = 0.5;
  let travelScore = 0.5;
  let hoursScore = 0.5;

  if (prefs && roleRequest.eventDate) {
    // Day preference
    if (prefs.preferredDays && prefs.preferredDays.length > 0) {
      const dayNames: readonly ('mon'|'tue'|'wed'|'thu'|'fri'|'sat'|'sun')[] = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
      const eventDay = dayNames[roleRequest.eventDate.getDay()]!;
      dayScore = prefs.preferredDays.includes(eventDay) ? 1.0 : 0.2;
    }

    // Shift preference
    if (prefs.preferredShifts && prefs.preferredShifts.length > 0 && roleRequest.eventStartTime) {
      const hour = parseInt(roleRequest.eventStartTime.split(':')[0] || '12', 10);
      let shiftName: 'morning' | 'afternoon' | 'evening' | 'overnight';
      if (hour < 12) shiftName = 'morning';
      else if (hour < 17) shiftName = 'afternoon';
      else if (hour < 21) shiftName = 'evening';
      else shiftName = 'overnight';

      shiftScore = prefs.preferredShifts.includes(shiftName) ? 1.0 : 0.2;
    }

    // Max hours per week — simple check: if set and very low, penalize
    if (prefs.maxHoursPerWeek && prefs.maxHoursPerWeek > 0) {
      hoursScore = prefs.maxHoursPerWeek >= 20 ? 1.0 : prefs.maxHoursPerWeek >= 10 ? 0.7 : 0.4;
    }
  }

  // Travel distance
  if (
    user.homeCoordinates?.lat && user.homeCoordinates?.lng &&
    roleRequest.venueLat && roleRequest.venueLng
  ) {
    const distance = haversineDistanceMiles(
      user.homeCoordinates.lat, user.homeCoordinates.lng,
      roleRequest.venueLat, roleRequest.venueLng
    );
    const maxRadius = user.workPreferences?.travelRadiusMiles || 50;

    if (distance <= maxRadius * 0.5) {
      travelScore = 1.0; // Well within range
    } else if (distance <= maxRadius) {
      travelScore = 0.7; // Within range
    } else if (distance <= maxRadius * 1.5) {
      travelScore = 0.3; // Slightly outside range
    } else {
      travelScore = 0.1; // Far outside range
    }
  }

  return dayScore * 0.3 + shiftScore * 0.3 + travelScore * 0.2 + hoursScore * 0.2;
}

/**
 * Main matching function: ranks all team staff for a given event role.
 *
 * Performance: Batch-fetches all team StaffProfiles + Users in 2 queries.
 * Single aggregation for event stats. No N+1.
 */
export async function rankStaffForRole(
  managerId: mongoose.Types.ObjectId,
  roleRequest: RoleRequest,
  options: MatchOptions = {}
): Promise<StaffMatchCandidate[]> {
  const limit = options.limit || 10;
  const requiredSkills = roleRequest.requiredSkills || [];
  const requiredCerts = roleRequest.requiredCertifications || [];

  // 1. Batch-fetch all team members' StaffProfiles
  const profiles = await StaffProfileModel.find({ managerId }).lean();
  if (profiles.length === 0) return [];

  const userKeys = profiles.map(p => p.userKey);

  // 2. Batch-fetch corresponding Users
  const userKeyParts = userKeys.map(key => {
    const [provider, ...subjectParts] = key.split(':');
    return { provider, subject: subjectParts.join(':') };
  });

  const users = await UserModel.find({
    $or: userKeyParts.map(({ provider, subject }) => ({ provider, subject })),
  }).lean();

  const userMap = new Map<string, UserDocument>();
  for (const user of users) {
    const key = `${user.provider}:${user.subject}`;
    userMap.set(key, user as UserDocument);
  }

  // 3. Fetch events from last 90 days for performance metrics
  const ninetyDaysAgo = new Date();
  ninetyDaysAgo.setDate(ninetyDaysAgo.getDate() - 90);

  const recentEvents = await EventModel.find({
    managerId,
    date: { $gte: ninetyDaysAgo },
    status: { $in: ['completed', 'fulfilled', 'in_progress'] },
  }).select('date start_time roles accepted_staff client_name status').lean();

  // 4. Check for busy conflicts on event date
  let busyMap = new Map<string, string>();
  if (roleRequest.eventDate) {
    const dateStart = new Date(roleRequest.eventDate);
    dateStart.setHours(0, 0, 0, 0);
    const dateEnd = new Date(roleRequest.eventDate);
    dateEnd.setHours(23, 59, 59, 999);

    const sameDayEvents = await EventModel.find({
      managerId,
      date: { $gte: dateStart, $lte: dateEnd },
      status: { $in: ['published', 'confirmed', 'fulfilled', 'in_progress'] },
      'accepted_staff.response': { $in: ['accept', 'accepted'] },
    }).select('shift_name client_name accepted_staff').lean();

    for (const evt of sameDayEvents) {
      if (evt.accepted_staff) {
        for (const staff of evt.accepted_staff) {
          if (staff.response === 'accept' || staff.response === 'accepted') {
            const eventLabel = evt.shift_name || evt.client_name || 'another event';
            busyMap.set(staff.userKey || '', `Already on "${eventLabel}"`);
          }
        }
      }
    }
  }

  // 5. Score each candidate
  const candidates: StaffMatchCandidate[] = [];

  for (const profile of profiles) {
    const user = userMap.get(profile.userKey);
    if (!user) continue;

    const userName = user.name || `${user.first_name || ''} ${user.last_name || ''}`.trim() || 'Unknown';

    // Skills
    const skillResult = scoreSkills(
      requiredSkills,
      profile.skills || [],
      user.skills || []
    );

    // Certifications
    const certResult = scoreCertifications(
      requiredCerts,
      profile.certifications || [],
      user.certifications || [],
      roleRequest.eventDate
    );

    // Performance — compute punctuality for this specific staff member
    const punctRecords = computePunctuality(recentEvents as any[], profile.userKey);
    const perfScore = scorePerformance(profile.rating || 0, punctRecords);

    // Availability
    const availScore = scoreAvailability(user as UserDocument, roleRequest);

    // Composite score (0-100)
    const total = Math.round(
      (skillResult.score * WEIGHT_SKILLS +
        certResult.score * WEIGHT_CERTS +
        perfScore * WEIGHT_PERFORMANCE +
        availScore * WEIGHT_AVAILABILITY) * 100
    );

    candidates.push({
      userKey: profile.userKey,
      name: userName,
      email: user.email,
      picture: user.picture,
      scores: {
        skills: Math.round(skillResult.score * 100),
        certifications: Math.round(certResult.score * 100),
        performance: Math.round(perfScore * 100),
        availability: Math.round(availScore * 100),
        total,
      },
      matchedSkills: skillResult.matched,
      missingSkills: skillResult.missing,
      matchedCerts: certResult.matched,
      missingCerts: certResult.missing,
      isFavorite: profile.isFavorite || false,
      rating: profile.rating || 0,
      isBusy: busyMap.has(profile.userKey),
      busyReason: busyMap.get(profile.userKey),
    });
  }

  // 6. Sort: total desc → isFavorite → rating desc → name asc
  candidates.sort((a, b) => {
    if (b.scores.total !== a.scores.total) return b.scores.total - a.scores.total;
    if (a.isFavorite !== b.isFavorite) return a.isFavorite ? -1 : 1;
    if (b.rating !== a.rating) return b.rating - a.rating;
    return a.name.localeCompare(b.name);
  });

  return candidates.slice(0, limit);
}
