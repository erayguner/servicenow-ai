import { Router, Request, Response } from 'express';

const router = Router();

router.get('/', (_req: Request, res: Response) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'ai-research-assistant-backend',
  });
});

router.get('/ready', (_req: Request, res: Response) => {
  // Add checks for dependencies (Firestore, Secret Manager, etc.)
  res.status(200).json({
    status: 'ready',
    timestamp: new Date().toISOString(),
  });
});

export default router;
