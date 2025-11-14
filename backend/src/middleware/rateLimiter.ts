import { Request, Response, NextFunction } from 'express';
import { config } from '../config';
import { logger } from '../services/logger';

interface RateLimitEntry {
  count: number;
  resetTime: number;
}

const rateLimitStore = new Map<string, RateLimitEntry>();

// Clean up expired entries every minute
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of rateLimitStore.entries()) {
    if (entry.resetTime < now) {
      rateLimitStore.delete(key);
    }
  }
}, 60000);

export function rateLimiter(req: Request, res: Response, next: NextFunction): void {
  const identifier = req.ip || 'unknown';
  const now = Date.now();

  let entry = rateLimitStore.get(identifier);

  // Create new entry or reset if window expired
  if (!entry || entry.resetTime < now) {
    entry = {
      count: 0,
      resetTime: now + config.rateLimitWindowMs,
    };
    rateLimitStore.set(identifier, entry);
  }

  entry.count++;

  // Set rate limit headers
  const remaining = Math.max(0, config.rateLimitMaxRequests - entry.count);
  const resetTime = Math.ceil(entry.resetTime / 1000);

  res.setHeader('X-RateLimit-Limit', config.rateLimitMaxRequests);
  res.setHeader('X-RateLimit-Remaining', remaining);
  res.setHeader('X-RateLimit-Reset', resetTime);

  if (entry.count > config.rateLimitMaxRequests) {
    logger.warn({ ip: identifier, count: entry.count }, 'Rate limit exceeded');

    res.status(429).json({
      error: 'Too many requests',
      retryAfter: resetTime,
    });
    return;
  }

  next();
}
