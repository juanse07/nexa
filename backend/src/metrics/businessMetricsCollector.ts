import { activeManagersGauge, activeEventsGauge, totalStaffGauge } from './metrics';

let intervalHandle: ReturnType<typeof setInterval> | null = null;

async function collectBusinessMetrics(): Promise<void> {
  try {
    // Lazy-import models to avoid circular dependency issues at startup
    const { ManagerModel } = await import('../models/manager');
    const { EventModel } = await import('../models/event');
    const { UserModel } = await import('../models/user');

    const [managerCount, activeEventCount, staffCount] = await Promise.all([
      ManagerModel.countDocuments(),
      EventModel.countDocuments({ status: { $in: ['published', 'confirmed', 'in_progress'] } }),
      UserModel.countDocuments(),
    ]);

    activeManagersGauge.set(managerCount);
    activeEventsGauge.set(activeEventCount);
    totalStaffGauge.set(staffCount);
  } catch (err) {
    // Silently ignore — metrics collection should never crash the app
    console.warn('[metrics] Business metrics collection failed:', err);
  }
}

export function startBusinessMetricsCollector(): void {
  // Collect immediately, then every 60 seconds
  void collectBusinessMetrics();
  intervalHandle = setInterval(collectBusinessMetrics, 60_000);
}

export function stopBusinessMetricsCollector(): void {
  if (intervalHandle) {
    clearInterval(intervalHandle);
    intervalHandle = null;
  }
}
