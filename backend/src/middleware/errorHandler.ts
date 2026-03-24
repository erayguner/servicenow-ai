import { Request, Response, NextFunction } from 'express';
import { logger } from '../services/logger';

export interface ApiError extends Error {
  statusCode?: number;
  details?: any;
}

export function errorHandler(
  err: ApiError,
  req: Request,
  res: Response,
  _next: NextFunction
): void {
  const statusCode = err.statusCode || 500;
  const message = err.message || 'Internal server error';

  logger.error(
    {
      error: err.message,
      stack: err.stack,
      path: req.path,
      method: req.method,
      statusCode,
      details: err.details,
    },
    'Request error'
  );

  const isDev = process.env.NODE_ENV === 'development' && !process.env.K_SERVICE;
  res.status(statusCode).json({
    error: message,
    ...(isDev && {
      stack: err.stack,
      details: typeof err.details === 'string' ? err.details : undefined,
    }),
  });
}

export function createError(message: string, statusCode: number, details?: any): ApiError {
  const error = new Error(message) as ApiError;
  error.statusCode = statusCode;
  error.details = details;
  return error;
}
