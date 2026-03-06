/**
 * Payroll export formatters — converts FlowShift payroll data
 * into provider-specific CSV formats for ADP, Paychex, and generic CSV.
 *
 * ADP format: PRcccEPI.csv — Employee File Number, Earnings Code, Hours, Rate, Dept
 * Paychex format: Employee ID, Check Date, Hours, Rate, Earnings Type
 *
 * Mapping data is now read from StaffProfile documents instead of EmployeePayrollMapping.
 */

import { PayrollLineItem } from './payrollCalculator';

// ─── Types ──────────────────────────────────────────────────────────

/** Shape of a StaffProfile document with payroll fields (lean query result). */
export interface PayrollMappingSource {
  userKey: string;
  externalEmployeeId?: string;
  workerType?: 'w2' | '1099';
  department?: string;
  earningsCode?: string;
}

// ─── Helpers ─────────────────────────────────────────────────────────

/** Escape a CSV field (wrap in quotes if it contains commas, quotes, or newlines) */
function csvField(value: string | number): string {
  const str = String(value);
  if (str.includes(',') || str.includes('"') || str.includes('\n')) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

function csvRow(fields: (string | number)[]): string {
  return fields.map(csvField).join(',');
}

function formatDate(d: Date): string {
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  const yyyy = d.getFullYear();
  return `${mm}/${dd}/${yyyy}`;
}

type MappingLookup = Map<string, PayrollMappingSource>;

function buildMappingLookup(sources: PayrollMappingSource[]): MappingLookup {
  const map = new Map<string, PayrollMappingSource>();
  for (const s of sources) {
    if (s.externalEmployeeId) {
      map.set(s.userKey, s);
    }
  }
  return map;
}

// ─── ADP Format ──────────────────────────────────────────────────────

/**
 * ADP Workforce Now import format (PRcccEPI.csv).
 * Simplified to the columns ADP actually requires for hourly import:
 *   File Number, Earnings Code, Hours, Rate, Department
 */
export function formatAdpCsv(
  lineItems: PayrollLineItem[],
  sources: PayrollMappingSource[],
  companyCode: string = '000',
): { csv: string; unmapped: string[] } {
  const lookup = buildMappingLookup(sources);
  const unmapped: string[] = [];

  const header = csvRow([
    'Co Code',
    'Batch ID',
    'File #',
    'Earnings 3 Code',
    'Earnings 3 Amount',
    'Hours 3 Amount',
    'Rate 3',
    'Temp Dept',
  ]);

  const rows: string[] = [header];

  for (const item of lineItems) {
    const mapping = lookup.get(item.userKey);
    if (!mapping && !unmapped.includes(item.userKey)) {
      unmapped.push(item.userKey);
    }

    // Use OT earnings type from overtime processor, fall back to mapping or default
    const earningsCode = item.earningsType || mapping?.earningsCode || 'REG';
    const dept = mapping?.department || '';
    // Unmapped staff: use app_id, phone, or name as placeholder for manual reconciliation
    const fileNumber = mapping?.externalEmployeeId || item.appId || item.phone || item.name;

    rows.push(csvRow([
      companyCode,
      'FLOWSHIFT',
      fileNumber,
      earningsCode,
      item.earnings.toFixed(2),
      item.hours.toFixed(2),
      item.rate.toFixed(2),
      dept,
    ]));
  }

  return { csv: rows.join('\r\n') + '\r\n', unmapped };
}

// ─── Paychex Format ──────────────────────────────────────────────────

/**
 * Paychex Flex import CSV format.
 * Columns: Employee ID, Check Date, Hours, Rate, Earnings Type, Department
 */
export function formatPaychexCsv(
  lineItems: PayrollLineItem[],
  sources: PayrollMappingSource[],
  checkDate?: string,
): { csv: string; unmapped: string[] } {
  const lookup = buildMappingLookup(sources);
  const unmapped: string[] = [];

  const header = csvRow([
    'Employee ID',
    'Check Date',
    'Earnings Type',
    'Hours',
    'Rate',
    'Amount',
    'Department',
  ]);

  const rows: string[] = [header];
  const defaultCheckDate = checkDate || formatDate(new Date());

  for (const item of lineItems) {
    const mapping = lookup.get(item.userKey);
    if (!mapping && !unmapped.includes(item.userKey)) {
      unmapped.push(item.userKey);
    }

    // 1099 workers keep their type; W-2 workers get REG/OT from overtime processor
    const earningsType = mapping?.workerType === '1099' ? '1099' : (item.earningsType || 'REG');
    // Unmapped staff: use app_id, phone, or name as placeholder for manual reconciliation
    const employeeId = mapping?.externalEmployeeId || item.appId || item.phone || item.name;

    rows.push(csvRow([
      employeeId,
      defaultCheckDate,
      earningsType,
      item.hours.toFixed(2),
      item.rate.toFixed(2),
      item.earnings.toFixed(2),
      mapping?.department || '',
    ]));
  }

  return { csv: rows.join('\r\n') + '\r\n', unmapped };
}

// ─── Generic CSV ─────────────────────────────────────────────────────

/**
 * Generic CSV export — human-readable format that works with any payroll system.
 * Includes all available fields for maximum flexibility.
 */
export function formatGenericCsv(
  lineItems: PayrollLineItem[],
  sources: PayrollMappingSource[],
): { csv: string; unmapped: string[] } {
  const lookup = buildMappingLookup(sources);
  const unmapped: string[] = [];

  const header = csvRow([
    'Staff Name',
    'Email',
    'Phone',
    'App ID',
    'External ID',
    'Worker Type',
    'Date',
    'Event',
    'Client',
    'Role',
    'Hours',
    'Rate',
    'Earnings',
    'Earnings Type',
    'Department',
  ]);

  const rows: string[] = [header];

  for (const item of lineItems) {
    const mapping = lookup.get(item.userKey);
    if (!mapping && !unmapped.includes(item.userKey)) {
      unmapped.push(item.userKey);
    }

    rows.push(csvRow([
      item.name,
      item.email,
      item.phone || '',
      item.appId || '',
      mapping?.externalEmployeeId || '',
      mapping?.workerType || '',
      formatDate(item.eventDate),
      item.eventName,
      item.clientName,
      item.role,
      item.hours.toFixed(2),
      item.rate.toFixed(2),
      item.earnings.toFixed(2),
      item.earningsType || 'REG',
      mapping?.department || '',
    ]));
  }

  return { csv: rows.join('\r\n') + '\r\n', unmapped };
}
