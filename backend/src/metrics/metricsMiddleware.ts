import { Request, Response, NextFunction } from 'express';
import { httpRequestDuration, httpRequestsTotal, httpRequestsInFlight } from './metrics';

/**
 * Normalizes Express route paths to prevent high-cardinality labels.
 * Replaces MongoDB ObjectIDs and other dynamic segments with `:id`.
 */
function normalizePath(req: Request): string {
  // Use the matched route pattern if Express resolved one
  if (req.route?.path) {
    // Reconstruct the full path including the base URL of the router
    const basePath = req.baseUrl || '';
    return basePath + req.route.path;
  }

  // Fallback: manually normalize the URL path
  return (req.baseUrl || '') + (req.path || '/')
    // Replace MongoDB ObjectIDs (24 hex chars)
    .replace(/[a-f0-9]{24}/gi, ':id')
    // Replace UUIDs
    .replace(/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}/gi, ':id')
    // Replace numeric IDs
    .replace(/\/\d+(?=\/|$)/g, '/:id');
}

export function metricsMiddleware(req: Request, res: Response, next: NextFunction): void {
  // Skip the /metrics endpoint itself to avoid self-referential noise
  if (req.path === '/metrics') {
    next();
    return;
  }

  httpRequestsInFlight.inc();
  const end = httpRequestDuration.startTimer();

  res.on('finish', () => {
    const route = normalizePath(req);
    const labels = {
      method: req.method,
      route,
      status_code: String(res.statusCode),
    };

    end(labels);
    httpRequestsTotal.inc(labels);
    httpRequestsInFlight.dec();
  });

  next();
}
