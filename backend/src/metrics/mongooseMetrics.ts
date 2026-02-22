import mongoose from 'mongoose';
import { mongoQueryDuration } from './metrics';

/**
 * Wraps `mongoose.Query.prototype.exec` to record query timing in a histogram.
 * Call once after mongoose is imported but before any queries run.
 */
export function enableMongooseMetrics(): void {
  const originalExec = mongoose.Query.prototype.exec;

  (mongoose.Query.prototype as any).exec = async function (this: any) {
    const model = this.model?.modelName || 'unknown';
    const operation = this.op || 'unknown';
    const end = mongoQueryDuration.startTimer({ model, operation });

    try {
      const result = await originalExec.call(this);
      end();
      return result;
    } catch (err) {
      end();
      throw err;
    }
  };
}
