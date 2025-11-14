import { Router, Response } from 'express';
import { AuthenticatedRequest, requireAdmin } from '../middleware/auth';
import { agentdb } from '../services/agentdb';
import { logger } from '../services/logger';

const router = Router();

// Apply admin middleware to all routes
router.use(requireAdmin);

/**
 * GET /api/admin/stats
 * Get system statistics
 */
router.get('/stats', async (_req: AuthenticatedRequest, res: Response) => {
  // TODO: Implement proper statistics gathering
  const stats = {
    totalConversations: 0,
    totalMessages: 0,
    activeUsers: 0,
    timestamp: new Date().toISOString(),
  };

  logger.info({ stats }, 'Admin stats requested');

  res.json({ stats });
});

/**
 * GET /api/admin/users
 * Get all users
 */
router.get('/users', async (_req: AuthenticatedRequest, res: Response) => {
  // TODO: Implement user listing from Cloud Identity
  const users = [];

  res.json({ users });
});

/**
 * POST /api/admin/documents
 * Ingest documents for RAG
 */
router.post('/documents', async (req: AuthenticatedRequest, res: Response) => {
  const { title, content, metadata } = req.body;

  if (!title || !content) {
    res.status(400).json({ error: 'Title and content are required' });
    return;
  }

  const document = await agentdb.storeDocument({
    title,
    content,
    metadata,
  });

  logger.info({ documentId: document.id, title }, 'Document ingested');

  res.status(201).json({ document });
});

/**
 * GET /api/admin/documents
 * List all documents
 */
router.get('/documents', async (req: AuthenticatedRequest, res: Response) => {
  const query = (req.query.q as string) || '';
  const limit = parseInt(req.query.limit as string) || 50;

  const documents = await agentdb.searchDocuments(query, limit);

  res.json({ documents });
});

/**
 * POST /api/admin/logs
 * Query system logs
 */
router.post('/logs', async (_req: AuthenticatedRequest, res: Response) => {
  // TODO: Implement log querying from Cloud Logging
  const logs = [];

  res.json({ logs });
});

export default router;
