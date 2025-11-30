// IMPORTANT: OpenTelemetry instrumentation must be imported FIRST
// This ensures auto-instrumentation captures all HTTP, Express, and database calls
import './instrumentation';

import express, { Express, Request, Response, NextFunction } from 'express';
import helmet from 'helmet';
import cors from 'cors';
import compression from 'compression';
import 'express-async-errors';
import { config } from './config';
import { logger } from './services/logger';
import { errorHandler } from './middleware/errorHandler';
import { authMiddleware } from './middleware/auth';
import { rateLimiter } from './middleware/rateLimiter';
import chatRouter from './routes/chat';
import sessionRouter from './routes/session';
import adminRouter from './routes/admin';
import healthRouter from './routes/health';

const app: Express = express();

// Security middleware
app.use(helmet());
app.use(
  cors({
    origin: config.corsOrigins,
    credentials: true,
  })
);
app.use(compression());

// Body parsing middleware
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Request logging
app.use((req: Request, _res: Response, next: NextFunction) => {
  logger.info(
    {
      method: req.method,
      path: req.path,
      ip: req.ip,
    },
    'Incoming request'
  );
  next();
});

// Health check (no auth required)
app.use('/health', healthRouter);

// Apply rate limiting to API routes
app.use('/api', rateLimiter);

// Apply authentication to protected routes
app.use('/api', authMiddleware);

// API routes
app.use('/api/chat', chatRouter);
app.use('/api/session', sessionRouter);
app.use('/api/admin', adminRouter);

// 404 handler
app.use((_req: Request, res: Response) => {
  res.status(404).json({ error: 'Not found' });
});

// Error handler (must be last)
app.use(errorHandler);

// Start server
const port = config.port;
app.listen(port, () => {
  logger.info({ port }, 'Server started successfully');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});

export default app;
