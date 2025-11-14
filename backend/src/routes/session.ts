import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../middleware/auth';
import { createError } from '../middleware/errorHandler';
import { agentdb } from '../services/agentdb';

const router = Router();

/**
 * GET /api/session/conversations
 * Get all conversations for the authenticated user
 */
router.get('/conversations', async (req: AuthenticatedRequest, res: Response) => {
  const userId = req.user!.id;
  const limit = parseInt(req.query.limit as string) || 50;

  const conversations = await agentdb.getUserConversations(userId, limit);

  res.json({ conversations });
});

/**
 * GET /api/session/conversations/:id
 * Get a specific conversation with messages
 */
router.get('/conversations/:id', async (req: AuthenticatedRequest, res: Response) => {
  const conversationId = req.params.id;
  const userId = req.user!.id;

  const conversation = await agentdb.getConversation(conversationId);

  if (!conversation) {
    throw createError('Conversation not found', 404);
  }

  if (conversation.userId !== userId) {
    throw createError('Forbidden', 403);
  }

  const messages = await agentdb.getConversationMessages(conversationId);

  res.json({
    conversation,
    messages,
  });
});

/**
 * POST /api/session/conversations
 * Create a new conversation
 */
router.post('/conversations', async (req: AuthenticatedRequest, res: Response) => {
  const body = z
    .object({
      title: z.string().min(1).max(200),
    })
    .parse(req.body);

  const userId = req.user!.id;
  const conversation = await agentdb.createConversation(userId, body.title);

  res.status(201).json({ conversation });
});

/**
 * PATCH /api/session/conversations/:id
 * Update a conversation
 */
router.patch('/conversations/:id', async (req: AuthenticatedRequest, res: Response) => {
  const conversationId = req.params.id;
  const userId = req.user!.id;

  const body = z
    .object({
      title: z.string().min(1).max(200).optional(),
      metadata: z.record(z.any()).optional(),
    })
    .parse(req.body);

  const conversation = await agentdb.getConversation(conversationId);

  if (!conversation) {
    throw createError('Conversation not found', 404);
  }

  if (conversation.userId !== userId) {
    throw createError('Forbidden', 403);
  }

  await agentdb.updateConversation(conversationId, body);

  res.json({ success: true });
});

/**
 * GET /api/session/user
 * Get current user information
 */
router.get('/user', async (req: AuthenticatedRequest, res: Response) => {
  const user = req.user!;

  res.json({
    user: {
      id: user.id,
      email: user.email,
      groups: user.groups,
    },
  });
});

export default router;
