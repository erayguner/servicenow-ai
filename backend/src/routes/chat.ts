import { Router, Response } from 'express';
import { z } from 'zod';
import { AuthenticatedRequest } from '../middleware/auth';
import { createError } from '../middleware/errorHandler';
import { agentdb } from '../services/agentdb';
import { chat, chatStream, ChatMessage } from '../services/claude';
import { logger } from '../services/logger';

const router = Router();

const chatRequestSchema = z.object({
  conversationId: z.string().uuid().optional(),
  message: z.string().min(1).max(10000),
  model: z.string().optional(),
  stream: z.boolean().optional().default(false),
  systemPrompt: z.string().optional(),
});

/**
 * POST /api/chat
 * Send a message and get AI response
 */
router.post('/', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const body = chatRequestSchema.parse(req.body);
    const userId = req.user!.id;

    // Get or create conversation
    let conversationId = body.conversationId;
    if (!conversationId) {
      const conversation = await agentdb.createConversation(userId, body.message.substring(0, 50));
      conversationId = conversation.id;
    } else {
      // Verify conversation belongs to user
      const conversation = await agentdb.getConversation(conversationId);
      if (!conversation || conversation.userId !== userId) {
        throw createError('Conversation not found', 404);
      }
    }

    // Store user message
    await agentdb.addMessage({
      conversationId,
      role: 'user',
      content: body.message,
    });

    // Get conversation history
    const history = await agentdb.getRecentMessages(conversationId, 20);
    const messages: ChatMessage[] = history.map((msg) => ({
      role: msg.role as 'user' | 'assistant',
      content: msg.content,
    }));

    // Handle streaming response
    if (body.stream) {
      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');

      let fullResponse = '';

      try {
        for await (const chunk of chatStream(messages, body.model, body.systemPrompt)) {
          fullResponse += chunk;
          res.write(`data: ${JSON.stringify({ chunk })}\n\n`);
        }

        // Store assistant response
        await agentdb.addMessage({
          conversationId,
          role: 'assistant',
          content: fullResponse,
        });

        res.write(`data: ${JSON.stringify({ done: true, conversationId })}\n\n`);
        res.end();
      } catch (error) {
        logger.error({ error, conversationId }, 'Streaming failed');
        res.write(`data: ${JSON.stringify({ error: 'Streaming failed' })}\n\n`);
        res.end();
      }
    } else {
      // Non-streaming response
      const response = await chat(messages, body.model, body.systemPrompt);

      // Store assistant response
      await agentdb.addMessage({
        conversationId,
        role: 'assistant',
        content: response.content,
      });

      res.json({
        conversationId,
        message: response.content,
        model: response.model,
        usage: response.usage,
      });
    }
  } catch (error) {
    if (error instanceof z.ZodError) {
      throw createError('Invalid request', 400, error.errors);
    }
    throw error;
  }
});

/**
 * POST /api/chat/research
 * Start a research-swarm multi-agent flow
 */
router.post('/research', async (req: AuthenticatedRequest, res: Response) => {
  try {
    const body = z
      .object({
        conversationId: z.string().uuid().optional(),
        query: z.string().min(1).max(10000),
        depth: z.enum(['quick', 'standard', 'deep']).optional().default('standard'),
      })
      .parse(req.body);

    const userId = req.user!.id;

    // Get or create conversation
    let conversationId = body.conversationId;
    if (!conversationId) {
      const conversation = await agentdb.createConversation(
        userId,
        `Research: ${body.query.substring(0, 40)}`
      );
      conversationId = conversation.id;
    }

    // Store user query
    await agentdb.addMessage({
      conversationId,
      role: 'user',
      content: body.query,
      metadata: { type: 'research', depth: body.depth },
    });

    // TODO: Integrate with research-swarm
    // For now, return a placeholder response
    const response = await chat(
      [{ role: 'user', content: body.query }],
      undefined,
      'You are a research assistant. Provide a comprehensive, well-researched answer with citations.'
    );

    // Store assistant response
    await agentdb.addMessage({
      conversationId,
      role: 'assistant',
      content: response.content,
      metadata: { type: 'research-result', depth: body.depth },
    });

    res.json({
      conversationId,
      result: response.content,
      sources: [],
      model: response.model,
      usage: response.usage,
    });
  } catch (error) {
    if (error instanceof z.ZodError) {
      throw createError('Invalid request', 400, error.errors);
    }
    throw error;
  }
});

export default router;
