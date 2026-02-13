/**
 * Client for the Python document generation microservice.
 * Generates documents and uploads them to R2 for secure access.
 */

import { uploadDocument, getPresignedUrl } from './storageService';

const DOC_SERVICE_URL = process.env.DOC_SERVICE_URL || 'http://doc-service:5000';
const DOC_SERVICE_SECRET = process.env.DOC_SERVICE_SECRET || '';

export type ReportFormat = 'pdf' | 'docx' | 'xlsx';
export type ReportType = 'staff-shifts' | 'payroll' | 'attendance' | 'ai-analysis' | 'working-hours';

export interface ReportPayload {
  report_type: ReportType;
  report_format: ReportFormat;
  title: string;
  period: { start: string; end: string; label: string };
  records: Record<string, any>[];
  summary: Record<string, any>;
  company_name?: string;
}

export interface GeneratedReport {
  url: string;
  key: string;
  filename: string;
  contentType: string;
}

const CONTENT_TYPES: Record<ReportFormat, string> = {
  pdf: 'application/pdf',
  docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
};

const FILE_EXTENSIONS: Record<ReportFormat, string> = {
  pdf: '.pdf',
  docx: '.docx',
  xlsx: '.xlsx',
};

/**
 * Calls the Python doc-service to generate a file, uploads to R2,
 * and returns a presigned download URL (1h expiry).
 */
export async function generateReport(
  payload: ReportPayload,
  ownerId: string,
): Promise<GeneratedReport> {
  const headers: Record<string, string> = {
    'Content-Type': 'application/json',
  };
  if (DOC_SERVICE_SECRET) {
    headers['X-Service-Secret'] = DOC_SERVICE_SECRET;
  }

  const response = await fetch(`${DOC_SERVICE_URL}/generate-report`, {
    method: 'POST',
    headers,
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Doc service error (${response.status}): ${text}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);

  const ext = FILE_EXTENSIONS[payload.report_format];
  const contentType = CONTENT_TYPES[payload.report_format];
  const filename = `${payload.report_type}${ext}`;

  // Upload to R2 under documents/{ownerId}/{timestamp}-{filename}
  const { key, url } = await uploadDocument(buffer, ownerId, filename, contentType);

  // Return a presigned URL so the file stays private
  const presignedUrl = await getPresignedUrl(key, 3600);

  return {
    url: presignedUrl,
    key,
    filename,
    contentType,
  };
}
