/**
 * Payroll calculation engine.
 * Extracted from statistics.ts to be reused by both the statistics API
 * and the payroll export endpoints (ADP, Paychex CSV).
 */

import mongoose from 'mongoose';
import { EventModel } from '../../models/event';
import { TariffModel } from '../../models/tariff';
import { RoleModel } from '../../models/role';
import { ClientModel } from '../../models/client';
import { UserModel } from '../../models/user';
import { enrichEventsWithAttendance } from '../../utils/attendanceHelper';
import { enrichEventsWithStaff } from '../../utils/eventStaffHelper';

// ─── Types ───────────────────────────────────────────────────────────

export interface PayrollEntry {
  userKey: string;
  name: string;
  email: string;
  picture: string;
  phone: string;
  appId: string;
  shifts: number;
  hours: number;
  earnings: number;
  averageRate: number;
  roles: string[];
}

/** Per-shift detail line (needed for CSV exports — one row per shift, not per person) */
export interface PayrollLineItem {
  userKey: string;
  name: string;
  email: string;
  phone: string;
  appId: string;
  eventDate: Date;
  eventName: string;
  clientName: string;
  role: string;
  hours: number;
  rate: number;
  earnings: number;
  earningsType?: 'REG' | 'OT';   // Set by overtime post-processor
  originalRate?: number;           // Pre-multiplier rate (when OT applied)
  approvalStatus: 'approved' | 'pending';
}

export interface UnapprovedStaffShift {
  userKey: string;
  name: string;
  eventName: string;
  eventDate: Date;
}

export interface PayrollResult {
  entries: PayrollEntry[];
  lineItems: PayrollLineItem[];
  summary: {
    staffCount: number;
    totalHours: number;
    totalPayroll: number;
    averagePerStaff: number;
  };
  warnings: {
    unapprovedStaffShifts: UnapprovedStaffShift[];
  };
}

// ─── Helpers ─────────────────────────────────────────────────────────

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

// ─── Main Calculator ─────────────────────────────────────────────────

/**
 * Calculate payroll for a manager's events in a date range.
 * Returns both aggregated per-staff entries (for the summary view)
 * and individual line items (for CSV export — one row per staff per shift).
 */
export async function calculatePayroll(
  managerId: any,
  start: Date,
  end: Date,
): Promise<PayrollResult> {
  // Fetch events and reference data in parallel
  const [rawEvents, allTariffs, allRoles, allClients] = await Promise.all([
    EventModel.find({
      managerId,
      status: { $in: ['completed', 'in_progress', 'fulfilled', 'published'] },
      date: { $gte: start, $lte: end },
    }).lean(),
    TariffModel.find({ managerId }).lean(),
    RoleModel.find({ managerId }).lean(),
    ClientModel.find({ managerId }).lean(),
  ]);

  // Enrich with staff + attendance data (falls back to nested data on failure)
  let events = rawEvents;
  try {
    events = await enrichEventsWithStaff(rawEvents);
    events = await enrichEventsWithAttendance(rawEvents);
  } catch (err) {
    console.warn('[payrollCalculator] AttendanceLog enrichment failed, using nested data:', err);
  }

  // Build lookup maps
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

  // Aggregate by staff member + collect line items
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

  const lineItems: PayrollLineItem[] = [];
  const unapprovedStaffShifts: UnapprovedStaffShift[] = [];

  for (const event of events) {
    const acceptedStaff = ((event as any).accepted_staff || []).filter(
      (s: any) => s.response === 'accepted' || s.response === 'accept',
    );

    const eventClientName = ((event as any).client_name || '').trim().toLowerCase();
    const eventName = (event as any).shift_name || (event as any).event_name || '';
    const eventDate = event.date ? new Date(event.date as any) : new Date();

    for (const staff of acceptedStaff) {
      const userKey = staff.userKey;
      const attendance = (staff.attendance || [])[0];

      // Strict: only count hours that are explicitly approved
      const isApproved = attendance?.status === 'approved' && attendance?.approvedHours != null;
      const hours = isApproved
        ? attendance.approvedHours
        : calculateHours((event as any).start_time, (event as any).end_time);
      const approvalStatus = isApproved ? 'approved' as const : 'pending' as const;

      // Track unapproved staff for warnings (only for staff who had attendance)
      if (!isApproved && attendance) {
        unapprovedStaffShifts.push({
          userKey,
          name: staff.name || 'Unknown',
          eventName,
          eventDate,
        });
      }

      if (hours === 0) continue;

      const staffRoleNorm = (staff.role || '').trim().toLowerCase();
      const hourlyRate = tariffMap[`${eventClientName}|${staffRoleNorm}`] || 0;
      const earnings = hourlyRate * hours;

      // Line item (one per staff per shift) — phone/appId filled after User lookup
      const lineEarnings = approvalStatus === 'approved' ? Math.round(earnings * 100) / 100 : 0;
      lineItems.push({
        userKey,
        name: staff.name || 'Unknown',
        email: staff.email || '',
        phone: '',
        appId: '',
        eventDate,
        eventName,
        clientName: (event as any).client_name || '',
        role: staff.role || '',
        hours: Math.round(hours * 10) / 10,
        rate: hourlyRate,
        earnings: lineEarnings,
        approvalStatus,
      });

      // Aggregate
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
      if (approvalStatus === 'approved') {
        staffPayroll[userKey].hours += hours;
        staffPayroll[userKey].earnings += earnings;
      }
      if (staff.role) staffPayroll[userKey].roles.add(staff.role);
    }
  }

  // Hydrate phone/appId from User collection (userKey = "provider:subject")
  const allUserKeys = Object.keys(staffPayroll);
  const userLookup = new Map<string, { phone: string; appId: string }>();
  if (allUserKeys.length > 0) {
    // Build $or query: each userKey is "provider:subject"
    const orClauses = allUserKeys.map(uk => {
      const sepIdx = uk.indexOf(':');
      return { provider: uk.substring(0, sepIdx), subject: uk.substring(sepIdx + 1) };
    });
    const users = await UserModel.find(
      { $or: orClauses },
      { provider: 1, subject: 1, phone_number: 1, auth_phone_number: 1, app_id: 1 },
    ).lean();
    for (const u of users) {
      const key = `${u.provider}:${u.subject}`;
      userLookup.set(key, {
        phone: u.phone_number || u.auth_phone_number || '',
        appId: u.app_id || '',
      });
    }
  }

  // Backfill phone/appId on line items
  for (const item of lineItems) {
    const u = userLookup.get(item.userKey);
    if (u) {
      item.phone = u.phone;
      item.appId = u.appId;
    }
  }

  // Format and sort entries by earnings descending
  const entries: PayrollEntry[] = Object.values(staffPayroll)
    .map(entry => {
      const u = userLookup.get(entry.userKey);
      return {
        userKey: entry.userKey,
        name: entry.name,
        email: entry.email,
        picture: entry.picture,
        phone: u?.phone || '',
        appId: u?.appId || '',
        shifts: entry.shifts,
        hours: Math.round(entry.hours * 10) / 10,
        earnings: Math.round(entry.earnings * 100) / 100,
        averageRate: entry.hours > 0
          ? Math.round((entry.earnings / entry.hours) * 100) / 100
          : 0,
        roles: Array.from(entry.roles),
      };
    })
    .sort((a, b) => b.earnings - a.earnings);

  const totalPayroll = entries.reduce((sum, e) => sum + e.earnings, 0);
  const totalHours = entries.reduce((sum, e) => sum + e.hours, 0);

  return {
    entries,
    lineItems: lineItems.sort((a, b) => a.eventDate.getTime() - b.eventDate.getTime()),
    summary: {
      staffCount: entries.length,
      totalHours: Math.round(totalHours * 10) / 10,
      totalPayroll: Math.round(totalPayroll * 100) / 100,
      averagePerStaff: entries.length > 0
        ? Math.round((totalPayroll / entries.length) * 100) / 100
        : 0,
    },
    warnings: {
      unapprovedStaffShifts,
    },
  };
}
