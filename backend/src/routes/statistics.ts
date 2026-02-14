import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { EventModel } from '../models/event';
import { TariffModel } from '../models/tariff';
import { RoleModel } from '../models/role';
import { ClientModel } from '../models/client';
import { UserModel } from '../models/user';
import { FlaggedAttendanceModel } from '../models/flaggedAttendance';
import { resolveManagerForRequest } from '../utils/manager';
import { generateReport, ReportFormat, BrandConfig, TemplateDesign } from '../services/docService';
import { ManagerModel } from '../models/manager';
import { getPresignedUrl, extractKeyFromUrl } from '../services/storageService';

const router = Router();

/**
 * Build a BrandConfig payload from a manager's brandProfile (if present).
 * Generates presigned URLs for logo assets so WeasyPrint can fetch them.
 */
async function buildBrandConfig(managerId: string): Promise<BrandConfig | undefined> {
  const mgr = await ManagerModel.findById(managerId).select('brandProfile').lean();
  const bp = mgr?.brandProfile;
  if (!bp?.primaryColor) return undefined;

  const config: BrandConfig = {
    primary_color: bp.primaryColor,
    secondary_color: bp.secondaryColor,
    accent_color: bp.accentColor,
    neutral_color: bp.neutralColor,
  };

  // Generate presigned URLs for logo images (WeasyPrint needs HTTP-accessible URLs)
  if (bp.logoHeaderUrl) {
    const key = extractKeyFromUrl(bp.logoHeaderUrl);
    if (key) {
      try {
        config.logo_header_url = await getPresignedUrl(key, 600);
      } catch { /* skip if presign fails */ }
    }
  }
  if (bp.logoWatermarkUrl) {
    const key = extractKeyFromUrl(bp.logoWatermarkUrl);
    if (key) {
      try {
        config.logo_watermark_url = await getPresignedUrl(key, 600);
      } catch { /* skip if presign fails */ }
    }
  }

  return config;
}

// ============================================================================
// VALIDATION SCHEMAS
// ============================================================================

const PeriodSchema = z.enum(['week', 'month', 'year', 'all', 'custom']).default('month');

const DateRangeSchema = z.object({
  period: PeriodSchema,
  startDate: z.string().optional(),
  endDate: z.string().optional(),
});

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Calculate date range based on period
 */
function getDateRange(period: string, startDate?: string, endDate?: string): { start: Date; end: Date } {
  const now = new Date();
  let start: Date;
  let end: Date;

  switch (period) {
    case 'week':
      start = new Date(now);
      start.setDate(start.getDate() - 7);
      start.setHours(0, 0, 0, 0);
      end = new Date(now);
      end.setHours(23, 59, 59, 999);
      break;
    case 'month':
      start = new Date(now.getFullYear(), now.getMonth(), 1);
      start.setHours(0, 0, 0, 0);
      end = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
      break;
    case 'year':
      start = new Date(now.getFullYear(), 0, 1);
      start.setHours(0, 0, 0, 0);
      end = new Date(now.getFullYear(), 11, 31, 23, 59, 59, 999);
      break;
    case 'custom':
      if (!startDate || !endDate) {
        throw new Error('startDate and endDate required for custom period');
      }
      start = new Date(startDate);
      start.setHours(0, 0, 0, 0);
      end = new Date(endDate);
      end.setHours(23, 59, 59, 999);
      break;
    default: // 'all'
      start = new Date(2020, 0, 1); // System start
      end = new Date(now);
      end.setHours(23, 59, 59, 999);
  }

  return { start, end };
}

/**
 * Calculate hours from start_time and end_time strings
 */
function calculateHours(startTime?: string, endTime?: string): number {
  if (!startTime || !endTime) return 0;

  const startParts = startTime.split(':').map(Number);
  const endParts = endTime.split(':').map(Number);

  const startH = startParts[0] ?? 0;
  const startM = startParts[1] ?? 0;
  const endH = endParts[0] ?? 0;
  const endM = endParts[1] ?? 0;

  if (isNaN(startH) || isNaN(endH)) return 0;

  let hours = (endH + endM / 60) - (startH + startM / 60);
  if (hours < 0) hours += 24; // Handle overnight shifts

  return hours;
}

/**
 * Format period label for display
 */
function getPeriodLabel(period: string, start: Date, end: Date): string {
  switch (period) {
    case 'week':
      return 'Last 7 days';
    case 'month':
      return start.toLocaleString('default', { month: 'long', year: 'numeric' });
    case 'year':
      return `${start.getFullYear()}`;
    case 'custom':
      return `${start.toLocaleDateString()} - ${end.toLocaleDateString()}`;
    default:
      return 'All time';
  }
}

// ============================================================================
// STAFF STATISTICS ENDPOINTS
// ============================================================================

/**
 * GET /statistics/staff/summary
 * Returns aggregated personal statistics for staff member
 */
router.get('/statistics/staff/summary', requireAuth, async (req: Request, res: Response) => {
  try {
    const authUser = (req as any).authUser;
    if (!authUser?.userKey) {
      return res.status(401).json({ message: 'Authentication required' });
    }

    const userKey = authUser.userKey;
    const { period = 'month', startDate, endDate } = req.query;

    const { start, end } = getDateRange(
      period as string,
      startDate as string,
      endDate as string
    );

    console.log(`[statistics/staff/summary] Getting stats for userKey ${userKey}, period ${period}`);

    // Query events where user is in accepted_staff
    const events = await EventModel.find({
      'accepted_staff.userKey': userKey,
      status: { $ne: 'cancelled' },
      date: { $gte: start, $lte: end }
    }).lean();

    console.log(`[statistics/staff/summary] Found ${events.length} events`);

    // Calculate statistics
    const roleStats: Record<string, { shifts: number; hours: number; earnings: number }> = {};
    const venueStats: Record<string, { shifts: number; hours: number }> = {};
    let totalShifts = 0;
    let totalHoursWorked = 0;
    let totalHoursApproved = 0;
    let totalEarnings = 0;

    for (const event of events) {
      const acceptedStaff = (event as any).accepted_staff || [];
      const userInShift = acceptedStaff.find((staff: any) => staff.userKey === userKey);

      if (userInShift && (userInShift.response === 'accepted' || userInShift.response === 'accept')) {
        const role = userInShift.role || 'Staff';
        const venue = (event as any).venue_name || 'Unknown Venue';

        // Get attendance record for approved hours
        const attendance = (userInShift.attendance || []) as any[];
        let approvedHours = 0;
        let workedHours = 0;

        if (attendance.length > 0) {
          // Use most recent attendance record
          const record = attendance[attendance.length - 1];
          approvedHours = record.approvedHours || 0;

          if (record.clockInAt && record.clockOutAt) {
            const clockIn = new Date(record.clockInAt);
            const clockOut = new Date(record.clockOutAt);
            workedHours = (clockOut.getTime() - clockIn.getTime()) / (1000 * 60 * 60);
          }
        }

        // Fall back to scheduled hours if no attendance
        if (workedHours === 0) {
          workedHours = calculateHours((event as any).start_time, (event as any).end_time);
        }

        // Get pay rate from roles array or tariff
        const roles = (event as any).roles || [];
        const roleInfo = roles.find((r: any) => r.role_name === role);
        const hourlyRate = roleInfo?.pay_rate_info?.amount || 0;
        const earnings = hourlyRate * (approvedHours || workedHours);

        // Update role stats
        if (!roleStats[role]) {
          roleStats[role] = { shifts: 0, hours: 0, earnings: 0 };
        }
        roleStats[role].shifts++;
        roleStats[role].hours += approvedHours || workedHours;
        roleStats[role].earnings += earnings;

        // Update venue stats
        if (!venueStats[venue]) {
          venueStats[venue] = { shifts: 0, hours: 0 };
        }
        venueStats[venue].shifts++;
        venueStats[venue].hours += workedHours;

        totalShifts++;
        totalHoursWorked += workedHours;
        totalHoursApproved += approvedHours || workedHours;
        totalEarnings += earnings;
      }
    }

    // Format response
    const byRole = Object.entries(roleStats).map(([role, stats]) => ({
      role,
      shifts: stats.shifts,
      hours: Math.round(stats.hours * 10) / 10,
      earnings: Math.round(stats.earnings * 100) / 100,
    })).sort((a, b) => b.shifts - a.shifts);

    const byVenue = Object.entries(venueStats).map(([venue, stats]) => ({
      venue,
      shifts: stats.shifts,
      hours: Math.round(stats.hours * 10) / 10,
    })).sort((a, b) => b.shifts - a.shifts).slice(0, 10); // Top 10 venues

    return res.json({
      period: {
        type: period,
        start: start.toISOString(),
        end: end.toISOString(),
        label: getPeriodLabel(period as string, start, end),
      },
      summary: {
        totalShifts,
        totalHoursWorked: Math.round(totalHoursWorked * 10) / 10,
        totalHoursApproved: Math.round(totalHoursApproved * 10) / 10,
        totalEarnings: Math.round(totalEarnings * 100) / 100,
        averageHourlyRate: totalHoursApproved > 0
          ? Math.round((totalEarnings / totalHoursApproved) * 100) / 100
          : 0,
      },
      byRole,
      byVenue,
    });
  } catch (err: any) {
    console.error('[statistics/staff/summary] Error:', err);
    return res.status(500).json({ message: 'Failed to fetch statistics', error: err.message });
  }
});

/**
 * GET /statistics/staff/shifts
 * Returns paginated shift history for staff member
 */
router.get('/statistics/staff/shifts', requireAuth, async (req: Request, res: Response) => {
  try {
    const authUser = (req as any).authUser;
    if (!authUser?.userKey) {
      return res.status(401).json({ message: 'Authentication required' });
    }

    const userKey = authUser.userKey;
    const {
      period = 'all',
      startDate,
      endDate,
      page = '1',
      limit = '20',
    } = req.query;

    const pageNum = parseInt(page as string, 10) || 1;
    const limitNum = Math.min(parseInt(limit as string, 10) || 20, 100);
    const skip = (pageNum - 1) * limitNum;

    const { start, end } = getDateRange(
      period as string,
      startDate as string,
      endDate as string
    );

    // Count total for pagination
    const totalCount = await EventModel.countDocuments({
      'accepted_staff.userKey': userKey,
      status: { $ne: 'cancelled' },
      date: { $gte: start, $lte: end }
    });

    // Query events with pagination
    const events = await EventModel.find({
      'accepted_staff.userKey': userKey,
      status: { $ne: 'cancelled' },
      date: { $gte: start, $lte: end }
    })
      .sort({ date: -1 })
      .skip(skip)
      .limit(limitNum)
      .lean();

    // Format shift records
    const shifts = events.map((event: any) => {
      const userInShift = (event.accepted_staff || []).find(
        (staff: any) => staff.userKey === userKey
      );

      const attendance = (userInShift?.attendance || [])[0] || {};
      const scheduledHours = calculateHours(event.start_time, event.end_time);

      // Get pay rate
      const roles = event.roles || [];
      const roleInfo = roles.find((r: any) => r.role_name === userInShift?.role);
      const hourlyRate = roleInfo?.pay_rate_info?.amount || 0;
      const hours = attendance.approvedHours || scheduledHours;

      return {
        eventId: event._id.toString(),
        date: event.date,
        eventName: event.event_name || event.shift_name || 'Shift',
        clientName: event.client_name || '',
        venueName: event.venue_name || '',
        venueAddress: event.venue_address || '',
        role: userInShift?.role || 'Staff',
        scheduledStart: event.start_time || '',
        scheduledEnd: event.end_time || '',
        clockIn: attendance.clockInAt || null,
        clockOut: attendance.clockOutAt || null,
        scheduledHours: Math.round(scheduledHours * 10) / 10,
        hoursWorked: attendance.clockOutAt && attendance.clockInAt
          ? Math.round(((new Date(attendance.clockOutAt).getTime() - new Date(attendance.clockInAt).getTime()) / (1000 * 60 * 60)) * 10) / 10
          : 0,
        hoursApproved: Math.round((attendance.approvedHours || 0) * 10) / 10,
        hourlyRate,
        earnings: Math.round(hourlyRate * hours * 100) / 100,
        status: attendance.status || event.status,
      };
    });

    return res.json({
      shifts,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total: totalCount,
        totalPages: Math.ceil(totalCount / limitNum),
        hasMore: skip + shifts.length < totalCount,
      },
      period: {
        start: start.toISOString(),
        end: end.toISOString(),
      },
    });
  } catch (err: any) {
    console.error('[statistics/staff/shifts] Error:', err);
    return res.status(500).json({ message: 'Failed to fetch shifts', error: err.message });
  }
});

/**
 * GET /statistics/staff/performance
 * Returns performance metrics: punctuality, streaks, acceptance rate
 */
router.get('/statistics/staff/performance', requireAuth, async (req: Request, res: Response) => {
  try {
    const authUser = (req as any).authUser;
    if (!authUser?.userKey) {
      return res.status(401).json({ message: 'Authentication required' });
    }

    const userKey = authUser.userKey;

    // Get user's gamification data
    const user = await UserModel.findOne({
      $or: [
        { google_id: userKey },
        { apple_id: userKey },
        { email: userKey }
      ]
    }).select('gamification').lean();

    const gamification = (user as any)?.gamification || {};

    // Get recent events to calculate punctuality
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const recentEvents = await EventModel.find({
      'accepted_staff.userKey': userKey,
      status: { $in: ['completed', 'in_progress'] },
      date: { $gte: thirtyDaysAgo }
    }).lean();

    let onTimeCount = 0;
    let totalWithClockIn = 0;

    for (const event of recentEvents) {
      const userInShift = ((event as any).accepted_staff || []).find(
        (staff: any) => staff.userKey === userKey
      );

      if (!userInShift) continue;

      const attendance = (userInShift.attendance || [])[0];
      if (!attendance?.clockInAt || !(event as any).start_time) continue;

      totalWithClockIn++;

      // Check if clocked in on time (within 15 minutes of start)
      const clockInTime = new Date(attendance.clockInAt);
      const timeParts = ((event as any).start_time as string).split(':').map(Number);
      const startH = timeParts[0] ?? 0;
      const startM = timeParts[1] ?? 0;

      if (!isNaN(startH) && !isNaN(startM)) {
        const eventDate = new Date((event as any).date);
        const scheduledStart = new Date(eventDate);
        scheduledStart.setHours(startH, startM, 0, 0);

        const diffMinutes = (clockInTime.getTime() - scheduledStart.getTime()) / (1000 * 60);

        // On time if within 15 minutes before or after start
        if (diffMinutes >= -30 && diffMinutes <= 15) {
          onTimeCount++;
        }
      }
    }

    const punctualityScore = totalWithClockIn > 0
      ? Math.round((onTimeCount / totalWithClockIn) * 100)
      : 100;

    return res.json({
      punctuality: {
        score: punctualityScore,
        onTimeShifts: onTimeCount,
        totalShifts: totalWithClockIn,
        period: 'last_30_days',
      },
      streaks: {
        current: gamification.currentStreak || 0,
        longest: gamification.longestStreak || 0,
        lastUpdated: gamification.lastStreakUpdate || null,
      },
      points: {
        total: gamification.totalPoints || 0,
        thisMonth: gamification.monthlyPoints || 0,
        history: (gamification.pointsHistory || []).slice(-5),
      },
    });
  } catch (err: any) {
    console.error('[statistics/staff/performance] Error:', err);
    return res.status(500).json({ message: 'Failed to fetch performance data', error: err.message });
  }
});

// ============================================================================
// MANAGER STATISTICS ENDPOINTS
// ============================================================================

/**
 * GET /statistics/manager/summary
 * Returns team-wide statistics for manager
 */
router.get('/statistics/manager/summary', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    const { period = 'month', startDate, endDate } = req.query;
    const { start, end } = getDateRange(
      period as string,
      startDate as string,
      endDate as string
    );

    console.log(`[statistics/manager/summary] Getting stats for manager ${manager._id}, period ${period}`);

    // Get all events in period
    const events = await EventModel.find({
      managerId: manager._id,
      date: { $gte: start, $lte: end }
    }).lean();

    // Pre-load tariff rate lookup: "clientName|roleName" → rate
    const [allTariffs, allRoles, allClients] = await Promise.all([
      TariffModel.find({ managerId: manager._id }).lean(),
      RoleModel.find({ managerId: manager._id }).lean(),
      ClientModel.find({ managerId: manager._id }).lean(),
    ]);

    const roleIdToName: Record<string, string> = {};
    for (const r of allRoles) {
      roleIdToName[String(r._id)] = r.name.trim().toLowerCase();
    }
    const clientIdToName: Record<string, string> = {};
    for (const c of allClients) {
      clientIdToName[String(c._id)] = c.name.trim().toLowerCase();
    }

    // Build tariff map: "clientNorm|roleNorm" → rate
    const tariffMap: Record<string, number> = {};
    for (const t of allTariffs) {
      const cName = clientIdToName[String(t.clientId)] || '';
      const rName = roleIdToName[String(t.roleId)] || '';
      if (cName && rName) {
        tariffMap[`${cName}|${rName}`] = t.rate;
      }
    }

    let totalEvents = events.length;
    let completedEvents = 0;
    let cancelledEvents = 0;
    let totalStaffHours = 0;
    let totalPayroll = 0;
    let totalStaffAssignments = 0;

    for (const event of events) {
      if ((event as any).status === 'completed') completedEvents++;
      if ((event as any).status === 'cancelled') cancelledEvents++;

      const acceptedStaff = ((event as any).accepted_staff || []).filter(
        (s: any) => s.response === 'accepted' || s.response === 'accept'
      );

      totalStaffAssignments += acceptedStaff.length;

      const eventClientName = ((event as any).client_name || '').trim().toLowerCase();

      for (const staff of acceptedStaff) {
        const attendance = (staff.attendance || [])[0];
        const hours = attendance?.approvedHours ||
          calculateHours((event as any).start_time, (event as any).end_time);

        // Look up pay rate from tariffs
        const staffRoleNorm = (staff.role || '').trim().toLowerCase();
        const hourlyRate = tariffMap[`${eventClientName}|${staffRoleNorm}`] || 0;

        totalStaffHours += hours;
        totalPayroll += hourlyRate * hours;
      }
    }

    // Get pending flags
    const pendingFlags = await FlaggedAttendanceModel.countDocuments({
      managerId: manager._id,
      status: 'pending',
    });

    // Get flag breakdown by type
    const flagsByType = await FlaggedAttendanceModel.aggregate([
      { $match: { managerId: manager._id, createdAt: { $gte: start, $lte: end } } },
      { $group: { _id: '$flagType', count: { $sum: 1 } } }
    ]);

    const flagsBreakdown: Record<string, number> = {};
    for (const flag of flagsByType) {
      flagsBreakdown[flag._id] = flag.count;
    }

    // Calculate utilization (events with full staff / total events)
    let fullyStaffedEvents = 0;
    for (const event of events) {
      const headcount = (event as any).headcount_total || 0;
      const accepted = ((event as any).accepted_staff || []).filter(
        (s: any) => s.response === 'accepted' || s.response === 'accept'
      ).length;
      if (headcount > 0 && accepted >= headcount) fullyStaffedEvents++;
    }

    return res.json({
      period: {
        type: period,
        start: start.toISOString(),
        end: end.toISOString(),
        label: getPeriodLabel(period as string, start, end),
      },
      summary: {
        totalEvents: totalEvents - cancelledEvents,
        completedEvents,
        cancelledEvents,
        totalStaffHours: Math.round(totalStaffHours * 10) / 10,
        totalPayroll: Math.round(totalPayroll * 100) / 100,
        averageEventSize: totalEvents > 0
          ? Math.round((totalStaffAssignments / (totalEvents - cancelledEvents)) * 10) / 10
          : 0,
        fulfillmentRate: totalEvents - cancelledEvents > 0
          ? Math.round((fullyStaffedEvents / (totalEvents - cancelledEvents)) * 100)
          : 0,
      },
      compliance: {
        pendingFlags,
        resolvedThisPeriod: 0, // Can be calculated if needed
        flagsByType: flagsBreakdown,
      },
    });
  } catch (err: any) {
    console.error('[statistics/manager/summary] Error:', err);
    return res.status(500).json({ message: 'Failed to fetch statistics', error: err.message });
  }
});

/**
 * GET /statistics/manager/payroll
 * Returns payroll breakdown by staff member
 */
router.get('/statistics/manager/payroll', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    const { period = 'month', startDate, endDate } = req.query;
    const { start, end } = getDateRange(
      period as string,
      startDate as string,
      endDate as string
    );

    // Get all completed events in period
    const events = await EventModel.find({
      managerId: manager._id,
      status: { $in: ['completed', 'in_progress', 'fulfilled', 'published'] },
      date: { $gte: start, $lte: end }
    }).lean();

    // Pre-load tariff rate lookup
    const [allTariffs, allRoles, allClients] = await Promise.all([
      TariffModel.find({ managerId: manager._id }).lean(),
      RoleModel.find({ managerId: manager._id }).lean(),
      ClientModel.find({ managerId: manager._id }).lean(),
    ]);

    const roleIdToName: Record<string, string> = {};
    for (const r of allRoles) {
      roleIdToName[String(r._id)] = r.name.trim().toLowerCase();
    }
    const clientIdToName: Record<string, string> = {};
    for (const c of allClients) {
      clientIdToName[String(c._id)] = c.name.trim().toLowerCase();
    }

    const tariffMap: Record<string, number> = {};
    for (const t of allTariffs) {
      const cName = clientIdToName[String(t.clientId)] || '';
      const rName = roleIdToName[String(t.roleId)] || '';
      if (cName && rName) {
        tariffMap[`${cName}|${rName}`] = t.rate;
      }
    }

    // Aggregate by staff member
    const staffPayroll: Record<string, {
      userKey: string;
      name: string;
      email: string;
      picture: string;
      shifts: number;
      hours: number;
      earnings: number;
      roles: Set<string>;
    }> = {};

    for (const event of events) {
      const acceptedStaff = ((event as any).accepted_staff || []).filter(
        (s: any) => s.response === 'accepted' || s.response === 'accept'
      );

      const eventClientName = ((event as any).client_name || '').trim().toLowerCase();

      for (const staff of acceptedStaff) {
        const userKey = staff.userKey;
        const attendance = (staff.attendance || [])[0];
        const hours = attendance?.approvedHours ||
          calculateHours((event as any).start_time, (event as any).end_time);

        // Look up pay rate from tariffs
        const staffRoleNorm = (staff.role || '').trim().toLowerCase();
        const hourlyRate = tariffMap[`${eventClientName}|${staffRoleNorm}`] || 0;

        if (!staffPayroll[userKey]) {
          staffPayroll[userKey] = {
            userKey,
            name: staff.name || 'Unknown',
            email: staff.email || '',
            picture: staff.picture || '',
            shifts: 0,
            hours: 0,
            earnings: 0,
            roles: new Set(),
          };
        }

        staffPayroll[userKey].shifts++;
        staffPayroll[userKey].hours += hours;
        staffPayroll[userKey].earnings += hourlyRate * hours;
        if (staff.role) staffPayroll[userKey].roles.add(staff.role);
      }
    }

    // Format and sort by earnings
    const payrollEntries = Object.values(staffPayroll)
      .map(entry => ({
        userKey: entry.userKey,
        name: entry.name,
        email: entry.email,
        picture: entry.picture,
        shifts: entry.shifts,
        hours: Math.round(entry.hours * 10) / 10,
        earnings: Math.round(entry.earnings * 100) / 100,
        averageRate: entry.hours > 0
          ? Math.round((entry.earnings / entry.hours) * 100) / 100
          : 0,
        roles: Array.from(entry.roles),
      }))
      .sort((a, b) => b.earnings - a.earnings);

    const totalPayroll = payrollEntries.reduce((sum, e) => sum + e.earnings, 0);
    const totalHours = payrollEntries.reduce((sum, e) => sum + e.hours, 0);

    return res.json({
      period: {
        start: start.toISOString(),
        end: end.toISOString(),
        label: getPeriodLabel(period as string, start, end),
      },
      summary: {
        staffCount: payrollEntries.length,
        totalHours: Math.round(totalHours * 10) / 10,
        totalPayroll: Math.round(totalPayroll * 100) / 100,
        averagePerStaff: payrollEntries.length > 0
          ? Math.round((totalPayroll / payrollEntries.length) * 100) / 100
          : 0,
      },
      entries: payrollEntries,
    });
  } catch (err: any) {
    console.error('[statistics/manager/payroll] Error:', err);
    return res.status(500).json({ message: 'Failed to fetch payroll data', error: err.message });
  }
});

/**
 * GET /statistics/manager/top-performers
 * Returns top performing staff members
 */
router.get('/statistics/manager/top-performers', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    const { period = 'month', limit = '10' } = req.query;
    const limitNum = Math.min(parseInt(limit as string, 10) || 10, 50);

    const { start, end } = getDateRange(period as string);

    // Get completed events
    const events = await EventModel.find({
      managerId: manager._id,
      status: { $in: ['completed', 'in_progress', 'fulfilled'] },
      date: { $gte: start, $lte: end }
    }).lean();

    // Aggregate staff performance
    const staffPerformance: Record<string, {
      userKey: string;
      name: string;
      picture: string;
      shifts: number;
      hours: number;
      earnings: number;
      onTimeShifts: number;
    }> = {};

    for (const event of events) {
      const acceptedStaff = ((event as any).accepted_staff || []).filter(
        (s: any) => s.response === 'accepted' || s.response === 'accept'
      );

      for (const staff of acceptedStaff) {
        const userKey = staff.userKey;
        const attendance = (staff.attendance || [])[0];
        const hours = attendance?.approvedHours ||
          calculateHours((event as any).start_time, (event as any).end_time);

        // Get pay rate
        const roles = (event as any).roles || [];
        const roleInfo = roles.find((r: any) => r.role_name === staff.role);
        const hourlyRate = roleInfo?.pay_rate_info?.amount || 0;

        if (!staffPerformance[userKey]) {
          staffPerformance[userKey] = {
            userKey,
            name: staff.name || 'Unknown',
            picture: staff.picture || '',
            shifts: 0,
            hours: 0,
            earnings: 0,
            onTimeShifts: 0,
          };
        }

        staffPerformance[userKey].shifts++;
        staffPerformance[userKey].hours += hours;
        staffPerformance[userKey].earnings += hourlyRate * hours;

        // Check punctuality
        if (attendance?.clockInAt && (event as any).start_time) {
          const clockIn = new Date(attendance.clockInAt);
          const punctParts = ((event as any).start_time as string).split(':').map(Number);
          const startH = punctParts[0] ?? 0;
          const startM = punctParts[1] ?? 0;

          if (!isNaN(startH)) {
            const eventDate = new Date((event as any).date);
            const scheduledStart = new Date(eventDate);
            scheduledStart.setHours(startH, startM, 0, 0);

            const diffMinutes = (clockIn.getTime() - scheduledStart.getTime()) / (1000 * 60);
            if (diffMinutes >= -30 && diffMinutes <= 15) {
              staffPerformance[userKey].onTimeShifts++;
            }
          }
        }
      }
    }

    // Sort by shifts completed, then hours
    const topPerformers = Object.values(staffPerformance)
      .map(entry => ({
        userKey: entry.userKey,
        name: entry.name,
        picture: entry.picture,
        shiftsCompleted: entry.shifts,
        hoursWorked: Math.round(entry.hours * 10) / 10,
        earnings: Math.round(entry.earnings * 100) / 100,
        punctualityScore: entry.shifts > 0
          ? Math.round((entry.onTimeShifts / entry.shifts) * 100)
          : 100,
      }))
      .sort((a, b) => {
        // Sort by shifts, then hours, then punctuality
        if (b.shiftsCompleted !== a.shiftsCompleted) return b.shiftsCompleted - a.shiftsCompleted;
        if (b.hoursWorked !== a.hoursWorked) return b.hoursWorked - a.hoursWorked;
        return b.punctualityScore - a.punctualityScore;
      })
      .slice(0, limitNum);

    return res.json({
      period: {
        start: start.toISOString(),
        end: end.toISOString(),
        label: getPeriodLabel(period as string, start, end),
      },
      topPerformers,
    });
  } catch (err: any) {
    console.error('[statistics/manager/top-performers] Error:', err);
    return res.status(500).json({ message: 'Failed to fetch top performers', error: err.message });
  }
});

/**
 * GET /statistics/manager/compliance
 * Returns compliance/flagged attendance summary
 */
router.get('/statistics/manager/compliance', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    const { period = 'month', startDate, endDate } = req.query;
    const { start, end } = getDateRange(
      period as string,
      startDate as string,
      endDate as string
    );

    // Get flags in period
    const flags = await FlaggedAttendanceModel.find({
      managerId: manager._id,
      createdAt: { $gte: start, $lte: end }
    }).populate('eventId', 'event_name date').lean();

    // Aggregate by type and status
    const byType: Record<string, number> = {};
    const byStatus: Record<string, number> = {};
    const bySeverity: Record<string, number> = {};

    for (const flag of flags) {
      byType[flag.flagType] = (byType[flag.flagType] || 0) + 1;
      byStatus[flag.status] = (byStatus[flag.status] || 0) + 1;
      bySeverity[flag.severity] = (bySeverity[flag.severity] || 0) + 1;
    }

    // Get recent flags for review
    const recentFlags = flags
      .filter(f => f.status === 'pending')
      .sort((a: any, b: any) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
      .slice(0, 10)
      .map((flag: any) => ({
        id: flag._id.toString(),
        type: flag.flagType,
        severity: flag.severity,
        staffName: flag.staffName || 'Unknown',
        eventName: (flag.eventId as any)?.event_name || 'Unknown Event',
        eventDate: (flag.eventId as any)?.date,
        reason: flag.reason,
        createdAt: flag.createdAt,
      }));

    return res.json({
      period: {
        start: start.toISOString(),
        end: end.toISOString(),
        label: getPeriodLabel(period as string, start, end),
      },
      summary: {
        total: flags.length,
        pending: byStatus['pending'] || 0,
        approved: byStatus['approved'] || 0,
        dismissed: byStatus['dismissed'] || 0,
      },
      byType,
      bySeverity,
      recentFlags,
    });
  } catch (err: any) {
    console.error('[statistics/manager/compliance] Error:', err);
    return res.status(500).json({ message: 'Failed to fetch compliance data', error: err.message });
  }
});

// ============================================================================
// EXPORT ENDPOINTS
// ============================================================================

/**
 * GET /exports/staff-shifts
 * Export staff shifts as CSV or PDF
 */
router.get('/exports/staff-shifts', requireAuth, async (req: Request, res: Response) => {
  try {
    const authUser = (req as any).authUser;
    if (!authUser?.userKey) {
      return res.status(401).json({ message: 'Authentication required' });
    }

    const userKey = authUser.userKey;
    const {
      format = 'csv',
      period = 'month',
      startDate,
      endDate
    } = req.query;

    const { start, end } = getDateRange(
      period as string,
      startDate as string,
      endDate as string
    );

    // Query all events in period
    const events = await EventModel.find({
      'accepted_staff.userKey': userKey,
      status: { $ne: 'cancelled' },
      date: { $gte: start, $lte: end }
    }).sort({ date: -1 }).lean();

    // Build shift records
    const records = events.map((event: any) => {
      const userInShift = (event.accepted_staff || []).find(
        (staff: any) => staff.userKey === userKey
      );

      const attendance = (userInShift?.attendance || [])[0] || {};
      const scheduledHours = calculateHours(event.start_time, event.end_time);

      // Get pay rate
      const roles = event.roles || [];
      const roleInfo = roles.find((r: any) => r.role_name === userInShift?.role);
      const hourlyRate = roleInfo?.pay_rate_info?.amount || 0;
      const hours = attendance.approvedHours || scheduledHours;

      return {
        date: new Date(event.date).toLocaleDateString(),
        eventName: event.event_name || event.shift_name || 'Shift',
        clientName: event.client_name || '',
        venueName: event.venue_name || '',
        role: userInShift?.role || 'Staff',
        clockIn: attendance.clockInAt
          ? new Date(attendance.clockInAt).toLocaleTimeString()
          : event.start_time || '',
        clockOut: attendance.clockOutAt
          ? new Date(attendance.clockOutAt).toLocaleTimeString()
          : event.end_time || '',
        hoursWorked: Math.round((attendance.approvedHours || scheduledHours) * 10) / 10,
        hourlyRate,
        earnings: Math.round(hourlyRate * hours * 100) / 100,
      };
    });

    const periodLabel = getPeriodLabel(period as string, start, end);
    const summary = {
      totalShifts: records.length,
      totalHours: Math.round(records.reduce((sum, r) => sum + r.hoursWorked, 0) * 10) / 10,
      totalEarnings: Math.round(records.reduce((sum, r) => sum + r.earnings, 0) * 100) / 100,
    };

    if (format === 'csv') {
      // Generate CSV
      const headers = [
        'Date',
        'Event',
        'Client',
        'Venue',
        'Role',
        'Clock In',
        'Clock Out',
        'Hours',
        'Pay Rate',
        'Earnings'
      ];

      const csvRows = [headers.join(',')];

      for (const record of records) {
        const row = [
          `"${record.date}"`,
          `"${record.eventName.replace(/"/g, '""')}"`,
          `"${record.clientName.replace(/"/g, '""')}"`,
          `"${record.venueName.replace(/"/g, '""')}"`,
          `"${record.role}"`,
          `"${record.clockIn}"`,
          `"${record.clockOut}"`,
          record.hoursWorked,
          record.hourlyRate,
          record.earnings,
        ];
        csvRows.push(row.join(','));
      }

      csvRows.push('');
      csvRows.push(`"TOTAL","","","","","","",${summary.totalHours},"",${summary.totalEarnings}`);

      const csvContent = csvRows.join('\n');

      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', `attachment; filename="shifts_${start.toISOString().split('T')[0]}_to_${end.toISOString().split('T')[0]}.csv"`);
      return res.send(csvContent);
    } else if (format === 'pdf' || format === 'docx' || format === 'xlsx') {
      // Generate document via Python doc-service, upload to R2
      const reportPayload = {
        report_type: 'staff-shifts' as const,
        report_format: format as ReportFormat,
        title: 'Shift History Report',
        period: { start: start.toISOString(), end: end.toISOString(), label: periodLabel },
        records,
        summary,
      };

      const report = await generateReport(reportPayload, userKey);
      return res.json({
        url: report.url,
        key: report.key,
        filename: report.filename,
        contentType: report.contentType,
      });
    } else {
      // JSON fallback
      return res.json({
        format: 'pdf_data',
        title: 'Shift History Report',
        period: { start: start.toISOString(), end: end.toISOString(), label: periodLabel },
        records,
        summary,
      });
    }
  } catch (err: any) {
    console.error('[exports/staff-shifts] Error:', err);
    return res.status(500).json({ message: 'Failed to generate export', error: err.message });
  }
});

/**
 * GET /exports/team-report
 * Export team payroll/attendance report as CSV or PDF
 */
router.get('/exports/team-report', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    const {
      format = 'csv',
      reportType = 'payroll',
      period = 'month',
      startDate,
      endDate
    } = req.query;

    const { start, end } = getDateRange(
      period as string,
      startDate as string,
      endDate as string
    );

    // Get completed events
    const events = await EventModel.find({
      managerId: manager._id,
      status: { $in: ['completed', 'in_progress', 'fulfilled'] },
      date: { $gte: start, $lte: end }
    }).lean();

    if (reportType === 'payroll') {
      // Aggregate by staff
      const staffData: Record<string, any> = {};

      for (const event of events) {
        const acceptedStaff = ((event as any).accepted_staff || []).filter(
          (s: any) => s.response === 'accepted' || s.response === 'accept'
        );

        for (const staff of acceptedStaff) {
          const userKey = staff.userKey;
          const attendance = (staff.attendance || [])[0];
          const hours = attendance?.approvedHours ||
            calculateHours((event as any).start_time, (event as any).end_time);

          const roles = (event as any).roles || [];
          const roleInfo = roles.find((r: any) => r.role_name === staff.role);
          const hourlyRate = roleInfo?.pay_rate_info?.amount || 0;

          if (!staffData[userKey]) {
            staffData[userKey] = {
              name: staff.name || 'Unknown',
              email: staff.email || '',
              shifts: 0,
              hours: 0,
              earnings: 0,
            };
          }

          staffData[userKey].shifts++;
          staffData[userKey].hours += hours;
          staffData[userKey].earnings += hourlyRate * hours;
        }
      }

      const records = Object.values(staffData).map((s: any) => ({
        name: s.name,
        email: s.email,
        shifts: s.shifts,
        hours: Math.round(s.hours * 10) / 10,
        averageRate: s.hours > 0 ? Math.round((s.earnings / s.hours) * 100) / 100 : 0,
        totalPay: Math.round(s.earnings * 100) / 100,
      })).sort((a, b) => b.totalPay - a.totalPay);

      const payrollPeriodLabel = getPeriodLabel(period as string, start, end);
      const payrollSummary = {
        staffCount: records.length,
        totalHours: Math.round(records.reduce((sum, r) => sum + r.hours, 0) * 10) / 10,
        totalPayroll: Math.round(records.reduce((sum, r) => sum + r.totalPay, 0) * 100) / 100,
      };

      if (format === 'csv') {
        const headers = ['Staff Name', 'Email', 'Shifts', 'Total Hours', 'Avg Rate', 'Total Pay'];
        const csvRows = [headers.join(',')];

        for (const record of records) {
          csvRows.push([
            `"${record.name.replace(/"/g, '""')}"`,
            `"${record.email}"`,
            record.shifts,
            record.hours,
            record.averageRate,
            record.totalPay,
          ].join(','));
        }

        csvRows.push('');
        csvRows.push(`"TOTAL","",${records.reduce((s, r) => s + r.shifts, 0)},${payrollSummary.totalHours},"",${payrollSummary.totalPayroll}`);

        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', `attachment; filename="payroll_${start.toISOString().split('T')[0]}_to_${end.toISOString().split('T')[0]}.csv"`);
        return res.send(csvRows.join('\n'));
      } else if (format === 'pdf' || format === 'docx' || format === 'xlsx') {
        const brandConfig = await buildBrandConfig(String(manager._id));
        const templateDesign = (req.query.template_design as TemplateDesign) || undefined;
        const reportPayload = {
          report_type: 'payroll' as const,
          report_format: format as ReportFormat,
          title: 'Payroll Report',
          period: { start: start.toISOString(), end: end.toISOString(), label: payrollPeriodLabel },
          records,
          summary: payrollSummary,
          ...(brandConfig && { brand_config: brandConfig }),
          ...(templateDesign && { template_design: templateDesign }),
        };

        const report = await generateReport(reportPayload, String(manager._id));
        return res.json({
          url: report.url,
          key: report.key,
          filename: report.filename,
          contentType: report.contentType,
        });
      } else {
        return res.json({
          format: 'pdf_data',
          title: 'Payroll Report',
          period: { start: start.toISOString(), end: end.toISOString(), label: payrollPeriodLabel },
          records,
          summary: payrollSummary,
        });
      }
    } else {
      // Attendance report - list all attendance records
      const records: any[] = [];

      for (const event of events) {
        const acceptedStaff = ((event as any).accepted_staff || []).filter(
          (s: any) => s.response === 'accepted' || s.response === 'accept'
        );

        for (const staff of acceptedStaff) {
          const attendance = (staff.attendance || [])[0];

          records.push({
            date: new Date((event as any).date).toLocaleDateString(),
            eventName: (event as any).event_name || 'Event',
            staffName: staff.name || 'Unknown',
            role: staff.role || 'Staff',
            scheduledStart: (event as any).start_time || '',
            scheduledEnd: (event as any).end_time || '',
            clockIn: attendance?.clockInAt
              ? new Date(attendance.clockInAt).toLocaleTimeString()
              : '',
            clockOut: attendance?.clockOutAt
              ? new Date(attendance.clockOutAt).toLocaleTimeString()
              : '',
            hoursWorked: attendance?.approvedHours
              || (attendance?.clockOutAt && attendance?.clockInAt
                ? (new Date(attendance.clockOutAt).getTime() - new Date(attendance.clockInAt).getTime()) / (1000 * 60 * 60)
                : 0),
            status: attendance?.status || 'unknown',
          });
        }
      }

      const attendPeriodLabel = getPeriodLabel(period as string, start, end);
      const attendSummary = {
        totalRecords: records.length,
        totalHours: Math.round(records.reduce((sum, r) => sum + r.hoursWorked, 0) * 10) / 10,
      };

      if (format === 'csv') {
        const headers = ['Date', 'Event', 'Staff', 'Role', 'Scheduled Start', 'Scheduled End', 'Clock In', 'Clock Out', 'Hours', 'Status'];
        const csvRows = [headers.join(',')];

        for (const record of records) {
          csvRows.push([
            `"${record.date}"`,
            `"${record.eventName.replace(/"/g, '""')}"`,
            `"${record.staffName.replace(/"/g, '""')}"`,
            `"${record.role}"`,
            `"${record.scheduledStart}"`,
            `"${record.scheduledEnd}"`,
            `"${record.clockIn}"`,
            `"${record.clockOut}"`,
            Math.round(record.hoursWorked * 10) / 10,
            `"${record.status}"`,
          ].join(','));
        }

        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', `attachment; filename="attendance_${start.toISOString().split('T')[0]}_to_${end.toISOString().split('T')[0]}.csv"`);
        return res.send(csvRows.join('\n'));
      } else if (format === 'pdf' || format === 'docx' || format === 'xlsx') {
        const attendBrandConfig = await buildBrandConfig(String(manager._id));
        const attendTemplateDesign = (req.query.template_design as TemplateDesign) || undefined;
        const reportPayload = {
          report_type: 'attendance' as const,
          report_format: format as ReportFormat,
          title: 'Attendance Report',
          period: { start: start.toISOString(), end: end.toISOString(), label: attendPeriodLabel },
          records,
          summary: attendSummary,
          ...(attendBrandConfig && { brand_config: attendBrandConfig }),
          ...(attendTemplateDesign && { template_design: attendTemplateDesign }),
        };

        const report = await generateReport(reportPayload, String(manager._id));
        return res.json({
          url: report.url,
          key: report.key,
          filename: report.filename,
          contentType: report.contentType,
        });
      } else {
        return res.json({
          format: 'pdf_data',
          title: 'Attendance Report',
          period: { start: start.toISOString(), end: end.toISOString(), label: attendPeriodLabel },
          records,
          summary: attendSummary,
        });
      }
    }
  } catch (err: any) {
    console.error('[exports/team-report] Error:', err);
    return res.status(500).json({ message: 'Failed to generate export', error: err.message });
  }
});

// ============================================================================
// AI ANALYSIS DOCUMENT GENERATION
// ============================================================================

const aiAnalysisDocSchema = z.object({
  analysis: z.string().min(1),
  format: z.enum(['pdf', 'docx']).default('pdf'),
  period: z.object({
    start: z.string(),
    end: z.string(),
    label: z.string(),
  }),
  summary: z.object({
    totalEvents: z.number().optional(),
    totalStaffHours: z.number().optional(),
    totalPayroll: z.number().optional(),
    fulfillmentRate: z.number().optional(),
  }).optional(),
  template_design: z.enum(['plain', 'classic', 'executive', 'modern']).optional(),
});

/**
 * POST /statistics/manager/ai-analysis-doc
 * Generate a PDF or DOCX from the AI analysis text
 */
router.post('/statistics/manager/ai-analysis-doc', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    const parsed = aiAnalysisDocSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid request', errors: parsed.error.issues });
    }

    const { analysis, format, period, summary, template_design } = parsed.data;

    console.log(`[statistics/ai-analysis-doc] Generating ${format} for manager ${manager._id}`);

    const aiBrandConfig = await buildBrandConfig(String(manager._id));
    const reportPayload = {
      report_type: 'ai-analysis' as const,
      report_format: format as ReportFormat,
      title: 'AI Team Analysis',
      period,
      records: [{ content: analysis }],
      summary: summary || {},
      ...(aiBrandConfig && { brand_config: aiBrandConfig }),
      ...(template_design && { template_design }),
    };

    const report = await generateReport(reportPayload, String(manager._id));

    return res.json({
      url: report.url,
      key: report.key,
      filename: report.filename,
      contentType: report.contentType,
    });
  } catch (err: any) {
    console.error('[statistics/ai-analysis-doc] Error:', err);
    return res.status(500).json({ message: 'Failed to generate document', error: err.message });
  }
});

// ============================================================================
// WORKING HOURS SHEET
// ============================================================================

const workingHoursSchema = z.object({
  format: z.enum(['pdf', 'docx']).default('pdf'),
  template_design: z.enum(['plain', 'classic', 'executive', 'modern']).optional(),
});

/**
 * POST /events/:eventId/working-hours-sheet
 * Generate a Working Hours Sheet PDF/DOCX for a specific event.
 * Enriches accepted staff with User model data (phone, app_id).
 */
router.post('/events/:eventId/working-hours-sheet', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) {
      return res.status(403).json({ message: 'Manager access required' });
    }

    const { eventId } = req.params;
    const parsed = workingHoursSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Invalid request', errors: parsed.error.issues });
    }

    const { format, template_design: whTemplateDesign } = parsed.data;

    // Fetch the event
    const event = await EventModel.findOne({
      _id: eventId,
      managerId: manager._id,
    }).lean();

    if (!event) {
      return res.status(404).json({ message: 'Event not found' });
    }

    const acceptedStaff = ((event as any).accepted_staff || []).filter(
      (s: any) => s.response === 'accepted' || s.response === 'accept'
    );

    if (acceptedStaff.length === 0) {
      return res.status(400).json({ message: 'No accepted staff for this event' });
    }

    // Collect userKeys to batch-lookup User data
    const userKeys = acceptedStaff
      .map((s: any) => s.userKey)
      .filter(Boolean);

    // Lookup users for phone_number and app_id
    const users = await UserModel.find({
      $or: [
        { google_id: { $in: userKeys } },
        { apple_id: { $in: userKeys } },
        { email: { $in: userKeys } },
      ]
    }).select('google_id apple_id email phone_number app_id auth_phone_number').lean();

    // Build userKey → user data map
    const userMap: Record<string, { phone: string; appId: string }> = {};
    for (const u of users) {
      const keys = [
        (u as any).google_id,
        (u as any).apple_id,
        (u as any).email,
      ].filter(Boolean);
      const phone = (u as any).phone_number || (u as any).auth_phone_number || '';
      const appId = (u as any).app_id || '';
      for (const k of keys) {
        userMap[k] = { phone, appId };
      }
    }

    const eventDate = (event as any).date
      ? new Date((event as any).date).toLocaleDateString('en-US', {
          weekday: 'short', year: 'numeric', month: 'short', day: 'numeric'
        })
      : '';

    const scheduledHours = calculateHours((event as any).start_time, (event as any).end_time);

    // Build records
    const records = acceptedStaff.map((staff: any) => {
      const attendance = (staff.attendance || [])[0];
      const userData = userMap[staff.userKey] || { phone: '', appId: '' };

      let clockInStr = '';
      let clockOutStr = '';
      let totalHours = 0;

      if (attendance?.clockInAt) {
        const ci = new Date(attendance.clockInAt);
        clockInStr = ci.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
      }
      if (attendance?.clockOutAt) {
        const co = new Date(attendance.clockOutAt);
        clockOutStr = co.toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' });
      }

      if (attendance?.approvedHours) {
        totalHours = Math.round(attendance.approvedHours * 10) / 10;
      } else if (attendance?.clockInAt && attendance?.clockOutAt) {
        totalHours = Math.round(
          ((new Date(attendance.clockOutAt).getTime() - new Date(attendance.clockInAt).getTime()) / (1000 * 60 * 60)) * 10
        ) / 10;
      } else {
        totalHours = Math.round(scheduledHours * 10) / 10;
      }

      return {
        name: staff.name || staff.first_name || 'Unknown',
        role: staff.role || 'Staff',
        phone: userData.phone,
        companyId: userData.appId,
        scheduledIn: (event as any).start_time || '',
        scheduledOut: (event as any).end_time || '',
        clockIn: clockInStr,
        clockOut: clockOutStr,
        breakDuration: '',  // Blank for manual entry
        totalHours,
      };
    });

    console.log(`[events/working-hours-sheet] Generating ${format} for event ${eventId}, ${records.length} staff`);

    const whBrandConfig = await buildBrandConfig(String(manager._id));
    const reportPayload = {
      report_type: 'working-hours' as const,
      report_format: format as ReportFormat,
      title: `Working Hours Sheet — ${(event as any).shift_name || (event as any).event_name || 'Event'}`,
      period: {
        start: (event as any).date ? new Date((event as any).date).toISOString() : new Date().toISOString(),
        end: (event as any).date ? new Date((event as any).date).toISOString() : new Date().toISOString(),
        label: eventDate,
      },
      records,
      summary: {
        client: (event as any).client_name || '',
        eventName: (event as any).shift_name || (event as any).event_name || 'Event',
        date: eventDate,
        startTime: (event as any).start_time || '',
        endTime: (event as any).end_time || '',
        venue: (event as any).venue_name || '',
        notes: (event as any).notes || '',
      },
      ...(whBrandConfig && { brand_config: whBrandConfig }),
      ...(whTemplateDesign && { template_design: whTemplateDesign }),
    };

    const report = await generateReport(reportPayload, String(manager._id));

    return res.json({
      url: report.url,
      key: report.key,
      filename: report.filename,
      contentType: report.contentType,
    });
  } catch (err: any) {
    console.error('[events/working-hours-sheet] Error:', err);
    return res.status(500).json({ message: 'Failed to generate working hours sheet', error: err.message });
  }
});

export default router;
