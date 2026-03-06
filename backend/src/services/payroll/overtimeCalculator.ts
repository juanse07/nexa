/**
 * Overtime post-processor for payroll line items.
 *
 * Calculates per-client overtime: when a staff member works more than
 * `threshold` hours for the same client in a pay period, excess hours
 * are marked as OT at `multiplier` × base rate.
 *
 * Key rule: Overtime is per client, NOT total across all clients.
 * 30h Client A + 20h Client B = no overtime.
 * 45h Client A alone = 5h OT for Client A.
 */

import { PayrollLineItem } from './payrollCalculator';

// ─── Types ───────────────────────────────────────────────────────────

export interface OvertimeStats {
  staffWithOT: number;
  totalOTHours: number;
  totalOTEarnings: number;
}

// ─── Main Function ───────────────────────────────────────────────────

/**
 * Apply per-client overtime rules to payroll line items.
 *
 * Algorithm:
 * 1. Group items by (userKey, clientName)
 * 2. Sort each group chronologically
 * 3. Walk shifts accumulating hours:
 *    - While cumulative ≤ threshold → REG
 *    - When a shift crosses threshold → split into REG + OT rows
 *    - All subsequent shifts → fully OT
 * 4. Return new array (may be longer due to splits)
 */
export function applyOvertime(
  lineItems: PayrollLineItem[],
  threshold: number = 40,
  multiplier: number = 1.5,
): { items: PayrollLineItem[]; stats: OvertimeStats } {
  // If threshold is 0 or negative, everything is OT (edge case)
  // If threshold >= 168 (hours in a week), effectively no OT
  if (lineItems.length === 0) {
    return { items: [], stats: { staffWithOT: 0, totalOTHours: 0, totalOTEarnings: 0 } };
  }

  // Group by (userKey, clientName normalized)
  const groups = new Map<string, PayrollLineItem[]>();
  for (const item of lineItems) {
    const key = `${item.userKey}||${(item.clientName || '').trim().toLowerCase()}`;
    const group = groups.get(key);
    if (group) {
      group.push(item);
    } else {
      groups.set(key, [item]);
    }
  }

  const result: PayrollLineItem[] = [];
  const otStaffSet = new Set<string>();
  let totalOTHours = 0;
  let totalOTEarnings = 0;

  for (const [, group] of groups) {
    // Sort chronologically within the group
    group.sort((a, b) => a.eventDate.getTime() - b.eventDate.getTime());

    let cumHours = 0;

    for (const item of group) {
      const baseRate = item.rate;

      if (cumHours >= threshold) {
        // Already past threshold — entire shift is OT
        const otRate = Math.round(baseRate * multiplier * 100) / 100;
        const otEarnings = Math.round(item.hours * otRate * 100) / 100;
        result.push({
          ...item,
          rate: otRate,
          earnings: otEarnings,
          earningsType: 'OT',
          originalRate: baseRate,
        });
        otStaffSet.add(item.userKey);
        totalOTHours += item.hours;
        totalOTEarnings += otEarnings;
      } else if (cumHours + item.hours > threshold) {
        // This shift crosses the threshold — split into REG + OT
        const regHours = Math.round((threshold - cumHours) * 10) / 10;
        const otHours = Math.round((item.hours - regHours) * 10) / 10;

        // REG portion
        const regEarnings = Math.round(regHours * baseRate * 100) / 100;
        result.push({
          ...item,
          hours: regHours,
          earnings: regEarnings,
          earningsType: 'REG',
        });

        // OT portion
        const otRate = Math.round(baseRate * multiplier * 100) / 100;
        const otEarnings = Math.round(otHours * otRate * 100) / 100;
        result.push({
          ...item,
          hours: otHours,
          rate: otRate,
          earnings: otEarnings,
          earningsType: 'OT',
          originalRate: baseRate,
        });

        otStaffSet.add(item.userKey);
        totalOTHours += otHours;
        totalOTEarnings += otEarnings;
      } else {
        // Entirely within threshold — REG
        result.push({
          ...item,
          earningsType: 'REG',
        });
      }

      cumHours += item.hours;
    }
  }

  // Sort final result chronologically (groups may have interleaved dates)
  result.sort((a, b) => a.eventDate.getTime() - b.eventDate.getTime());

  return {
    items: result,
    stats: {
      staffWithOT: otStaffSet.size,
      totalOTHours: Math.round(totalOTHours * 10) / 10,
      totalOTEarnings: Math.round(totalOTEarnings * 100) / 100,
    },
  };
}
