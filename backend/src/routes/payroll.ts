/**
 * Payroll routes — config, bulk mapping, and CSV export endpoints.
 *
 * Payroll mappings are now stored on StaffProfile (externalEmployeeId, workerType, etc.)
 * instead of the separate EmployeePayrollMapping collection.
 * Provider is org-wide on Manager.payrollConfig.
 */

import { Router, Request, Response } from 'express';
import { z } from 'zod';
import { requireAuth } from '../middleware/requireAuth';
import { resolveManagerForRequest } from '../utils/manager';
import { ManagerModel } from '../models/manager';
import { StaffProfileModel } from '../models/staffProfile';
import { calculatePayroll } from '../services/payroll/payrollCalculator';
import {
  formatAdpCsv,
  formatPaychexCsv,
  formatGenericCsv,
} from '../services/payroll/exportFormatters';
import { applyOvertime } from '../services/payroll/overtimeCalculator';
import { uploadDocument, getPresignedUrl } from '../services/storageService';

const router = Router();

// ─── Validation ──────────────────────────────────────────────────────

const PayrollConfigSchema = z.object({
  provider: z.enum(['adp', 'paychex', 'gusto', 'none']),
  companyCode: z.string().optional(),
  defaultDepartment: z.string().optional(),
  defaultEarningsCode: z.string().optional(),
  overtimeThreshold: z.number().min(0).max(168).optional(),
  overtimeMultiplier: z.number().min(1).max(3).optional(),
});

const BulkMappingItemSchema = z.object({
  userKey: z.string().min(1),
  externalEmployeeId: z.string(),
  workerType: z.enum(['w2', '1099']).optional(),
  department: z.string().optional(),
  earningsCode: z.string().optional(),
});

const BulkMappingSchema = z.object({
  mappings: z.array(BulkMappingItemSchema).min(1).max(500),
});

const ExportQuerySchema = z.object({
  startDate: z.string().min(1, 'startDate is required'),
  endDate: z.string().min(1, 'endDate is required'),
  companyCode: z.string().optional(),
  checkDate: z.string().optional(),
});

// ─── OT config helper ────────────────────────────────────────────────

function getOvertimeConfig(manager: any): { threshold: number; multiplier: number } {
  const config = manager.payrollConfig || {};
  return {
    threshold: config.overtimeThreshold ?? 40,
    multiplier: config.overtimeMultiplier ?? 1.5,
  };
}

// ─── Date helper ─────────────────────────────────────────────────────

function parseExportDateRange(startDate: string, endDate: string): { start: Date; end: Date } {
  const start = new Date(startDate);
  start.setHours(0, 0, 0, 0);
  const end = new Date(endDate);
  end.setHours(23, 59, 59, 999);

  if (isNaN(start.getTime()) || isNaN(end.getTime())) {
    throw new Error('Invalid date format');
  }
  if (start > end) {
    throw new Error('startDate must be before endDate');
  }

  return { start, end };
}

// ============================================================================
// PAYROLL CONFIG ENDPOINTS
// ============================================================================

/**
 * GET /payroll/config
 * Returns the manager's org-wide payroll configuration.
 */
router.get('/payroll/config', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) return res.status(403).json({ message: 'Manager access required' });

    const config = (manager as any).payrollConfig || {
      provider: 'none',
      companyCode: '',
      defaultDepartment: '',
      defaultEarningsCode: 'REG',
      overtimeThreshold: 40,
      overtimeMultiplier: 1.5,
    };
    // Ensure OT defaults for existing configs that predate these fields
    if (config.overtimeThreshold === undefined) config.overtimeThreshold = 40;
    if (config.overtimeMultiplier === undefined) config.overtimeMultiplier = 1.5;

    return res.json({ config });
  } catch (err: any) {
    console.error('[payroll/config GET] Error:', err);
    return res.status(500).json({ message: 'Failed to fetch config', error: err.message });
  }
});

/**
 * PATCH /payroll/config
 * Update the manager's org-wide payroll configuration.
 */
router.patch('/payroll/config', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) return res.status(403).json({ message: 'Manager access required' });

    const parsed = PayrollConfigSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', errors: parsed.error.issues });
    }

    const updated = await ManagerModel.findByIdAndUpdate(
      manager._id,
      { $set: { payrollConfig: parsed.data } },
      { new: true },
    );

    return res.json({ config: updated?.payrollConfig });
  } catch (err: any) {
    console.error('[payroll/config PATCH] Error:', err);
    return res.status(500).json({ message: 'Failed to update config', error: err.message });
  }
});

// ============================================================================
// BULK MAPPING ENDPOINT
// ============================================================================

/**
 * POST /payroll/bulk-mapping
 * Bulk-update payroll fields on StaffProfiles.
 * Accepts [{ userKey, externalEmployeeId, workerType?, department?, earningsCode? }]
 */
router.post('/payroll/bulk-mapping', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) return res.status(403).json({ message: 'Manager access required' });

    const parsed = BulkMappingSchema.safeParse(req.body);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', errors: parsed.error.issues });
    }

    const ops = parsed.data.mappings.map(m => ({
      updateOne: {
        filter: { managerId: manager._id, userKey: m.userKey },
        update: {
          $set: {
            externalEmployeeId: m.externalEmployeeId,
            ...(m.workerType && { workerType: m.workerType }),
            ...(m.department !== undefined && { department: m.department }),
            ...(m.earningsCode !== undefined && { earningsCode: m.earningsCode }),
          },
        },
        upsert: true,
      },
    }));

    const result = await StaffProfileModel.bulkWrite(ops);

    return res.json({
      upserted: result.upsertedCount,
      modified: result.modifiedCount,
      total: parsed.data.mappings.length,
    });
  } catch (err: any) {
    console.error('[payroll/bulk-mapping POST] Error:', err);
    return res.status(500).json({ message: 'Failed to save mappings', error: err.message });
  }
});

// ============================================================================
// LEGACY MAPPING ENDPOINTS (kept for backward compatibility)
// ============================================================================

/**
 * GET /payroll/employee-mappings
 * Returns mapped staff from StaffProfile (replaces EmployeePayrollMapping collection).
 */
router.get('/payroll/employee-mappings', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) return res.status(403).json({ message: 'Manager access required' });

    const profiles = await StaffProfileModel.find({
      managerId: manager._id,
      externalEmployeeId: { $exists: true, $ne: '' },
    }).sort({ userKey: 1 }).lean();

    // Map to legacy format for backward compat
    const provider = (manager as any).payrollConfig?.provider || 'none';
    const mappings = profiles.map(p => ({
      _id: String(p._id),
      userKey: p.userKey,
      staffName: '',
      provider,
      externalEmployeeId: p.externalEmployeeId || '',
      workerType: p.workerType || 'w2',
      department: p.department || '',
      earningsCode: p.earningsCode || '',
    }));

    return res.json({ mappings });
  } catch (err: any) {
    console.error('[payroll/employee-mappings GET] Error:', err);
    return res.status(500).json({ message: 'Failed to fetch mappings', error: err.message });
  }
});

// ============================================================================
// EXPORT ENDPOINTS — now read from StaffProfile
// ============================================================================

/** Helper: load mapped StaffProfiles as the export formatters' expected shape. */
async function loadMappedProfiles(managerId: any) {
  return StaffProfileModel.find({
    managerId,
    externalEmployeeId: { $exists: true, $ne: '' },
  }).lean();
}

/**
 * GET /exports/payroll-adp
 * Export payroll data as ADP Workforce Now import CSV.
 */
router.get('/exports/payroll-adp', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) return res.status(403).json({ message: 'Manager access required' });

    const parsed = ExportQuerySchema.safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', errors: parsed.error.issues });
    }

    const { startDate, endDate } = parsed.data;
    const companyCode = parsed.data.companyCode || (manager as any).payrollConfig?.companyCode || '000';
    const { start, end } = parseExportDateRange(startDate, endDate);

    const [payroll, profiles] = await Promise.all([
      calculatePayroll(manager._id, start, end),
      loadMappedProfiles(manager._id),
    ]);

    const { threshold, multiplier } = getOvertimeConfig(manager);
    const { items: lineItems } = applyOvertime(payroll.lineItems, threshold, multiplier);

    const { csv, unmapped } = formatAdpCsv(lineItems, profiles as any[], companyCode);

    const filename = `PR${companyCode}EPI_${startDate}_${endDate}.csv`;
    const buffer = Buffer.from(csv, 'utf-8');
    const { key } = await uploadDocument(buffer, String(manager._id), filename, 'text/csv');
    const url = await getPresignedUrl(key, 3600);

    return res.json({
      url,
      filename,
      summary: payroll.summary,
      unmappedStaff: unmapped,
      mappedCount: lineItems.length - unmapped.length,
    });
  } catch (err: any) {
    console.error('[exports/payroll-adp] Error:', err);
    return res.status(500).json({ message: 'Failed to generate ADP export', error: err.message });
  }
});

/**
 * GET /exports/payroll-paychex
 * Export payroll data as Paychex Flex import CSV.
 */
router.get('/exports/payroll-paychex', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) return res.status(403).json({ message: 'Manager access required' });

    const parsed = ExportQuerySchema.safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', errors: parsed.error.issues });
    }

    const { startDate, endDate, checkDate } = parsed.data;
    const { start, end } = parseExportDateRange(startDate, endDate);

    const [payroll, profiles] = await Promise.all([
      calculatePayroll(manager._id, start, end),
      loadMappedProfiles(manager._id),
    ]);

    const { threshold, multiplier } = getOvertimeConfig(manager);
    const { items: lineItems } = applyOvertime(payroll.lineItems, threshold, multiplier);

    const { csv, unmapped } = formatPaychexCsv(lineItems, profiles as any[], checkDate);

    const filename = `paychex_import_${startDate}_${endDate}.csv`;
    const buffer = Buffer.from(csv, 'utf-8');
    const { key } = await uploadDocument(buffer, String(manager._id), filename, 'text/csv');
    const url = await getPresignedUrl(key, 3600);

    return res.json({
      url,
      filename,
      summary: payroll.summary,
      unmappedStaff: unmapped,
      mappedCount: lineItems.length - unmapped.length,
    });
  } catch (err: any) {
    console.error('[exports/payroll-paychex] Error:', err);
    return res.status(500).json({ message: 'Failed to generate Paychex export', error: err.message });
  }
});

/**
 * GET /exports/payroll-csv
 * Generic CSV export — human-readable, works with any payroll system.
 */
router.get('/exports/payroll-csv', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) return res.status(403).json({ message: 'Manager access required' });

    const parsed = ExportQuerySchema.safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', errors: parsed.error.issues });
    }

    const { startDate, endDate } = parsed.data;
    const { start, end } = parseExportDateRange(startDate, endDate);

    const [payroll, profiles] = await Promise.all([
      calculatePayroll(manager._id, start, end),
      loadMappedProfiles(manager._id),
    ]);

    const { threshold, multiplier } = getOvertimeConfig(manager);
    const { items: lineItems } = applyOvertime(payroll.lineItems, threshold, multiplier);

    const { csv, unmapped } = formatGenericCsv(lineItems, profiles as any[]);

    const filename = `flowshift_payroll_${startDate}_${endDate}.csv`;
    const buffer = Buffer.from(csv, 'utf-8');
    const { key } = await uploadDocument(buffer, String(manager._id), filename, 'text/csv');
    const url = await getPresignedUrl(key, 3600);

    return res.json({
      url,
      filename,
      summary: payroll.summary,
      unmappedStaff: unmapped,
      mappedCount: lineItems.length - unmapped.length,
    });
  } catch (err: any) {
    console.error('[exports/payroll-csv] Error:', err);
    return res.status(500).json({ message: 'Failed to generate CSV export', error: err.message });
  }
});

/**
 * GET /exports/payroll-preview
 * Preview payroll data without formatting — returns JSON with line items.
 */
router.get('/exports/payroll-preview', requireAuth, async (req: Request, res: Response) => {
  try {
    const manager = await resolveManagerForRequest(req as any);
    if (!manager) return res.status(403).json({ message: 'Manager access required' });

    const parsed = ExportQuerySchema.safeParse(req.query);
    if (!parsed.success) {
      return res.status(400).json({ message: 'Validation failed', errors: parsed.error.issues });
    }

    const { startDate, endDate } = parsed.data;
    const { start, end } = parseExportDateRange(startDate, endDate);

    const payroll = await calculatePayroll(manager._id, start, end);
    const profiles = await StaffProfileModel.find({
      managerId: manager._id,
      externalEmployeeId: { $exists: true, $ne: '' },
    }).lean();

    // Apply overtime to line items for stats
    const { threshold, multiplier } = getOvertimeConfig(manager);
    const { items: otLineItems, stats: overtimeStats } = applyOvertime(
      payroll.lineItems, threshold, multiplier,
    );

    // Build per-staff OT hours lookup for annotating entries
    const staffOTHours = new Map<string, number>();
    for (const item of otLineItems) {
      if (item.earningsType === 'OT') {
        staffOTHours.set(item.userKey, (staffOTHours.get(item.userKey) || 0) + item.hours);
      }
    }

    const mappedUserKeys = new Set(profiles.map(p => p.userKey));
    const annotatedEntries = payroll.entries.map(e => ({
      ...e,
      isMapped: mappedUserKeys.has(e.userKey),
      otHours: staffOTHours.get(e.userKey) || 0,
    }));

    return res.json({
      period: {
        start: start.toISOString(),
        end: end.toISOString(),
      },
      summary: payroll.summary,
      entries: annotatedEntries,
      overtimeStats,
      mappingStats: {
        totalStaff: payroll.entries.length,
        mapped: annotatedEntries.filter(e => e.isMapped).length,
        unmapped: annotatedEntries.filter(e => !e.isMapped).length,
      },
    });
  } catch (err: any) {
    console.error('[exports/payroll-preview] Error:', err);
    return res.status(500).json({ message: 'Failed to generate preview', error: err.message });
  }
});

export default router;
