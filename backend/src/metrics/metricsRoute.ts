import { Router } from 'express';
import { registry } from './metrics';

const router = Router();

router.get('/metrics', async (req, res) => {
  // Optional bearer-token protection via METRICS_TOKEN env var
  const metricsToken = process.env.METRICS_TOKEN;
  if (metricsToken) {
    const auth = req.headers.authorization;
    if (!auth || auth !== `Bearer ${metricsToken}`) {
      res.status(401).json({ message: 'Unauthorized' });
      return;
    }
  }

  res.set('Content-Type', registry.contentType);
  res.end(await registry.metrics());
});

export default router;
