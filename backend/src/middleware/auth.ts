import { Request, Response, NextFunction } from 'express';
import { logger } from '../services/logger';

export interface AuthenticatedRequest extends Request {
  user?: {
    email: string;
    id: string;
    groups?: string[];
  };
}

/**
 * Authentication middleware for IAP-protected services
 * Validates the JWT token from Google Identity-Aware Proxy
 */
export async function authMiddleware(
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
): Promise<void> {
  try {
    // In production, IAP adds headers with authenticated user info
    const iapEmail = req.get('X-Goog-Authenticated-User-Email');
    const iapId = req.get('X-Goog-Authenticated-User-Id');

    // For local development, allow bypassing IAP
    if (process.env.NODE_ENV === 'development' && !iapEmail) {
      req.user = {
        email: 'dev@example.com',
        id: 'dev-user-id',
        groups: ['ai-assist-users'],
      };
      return next();
    }

    if (!iapEmail || !iapId) {
      logger.warn({ headers: req.headers }, 'Missing IAP headers');
      res.status(401).json({ error: 'Unauthorized: Missing authentication headers' });
      return;
    }

    // Extract email from IAP header format (accounts.google.com:user@example.com)
    const email = iapEmail.split(':')[1] || iapEmail;
    const userId = iapId.split(':')[1] || iapId;

    req.user = {
      email,
      id: userId,
      // In production, fetch groups from Cloud Identity
      groups: ['ai-assist-users'],
    };

    logger.info({ email, userId }, 'User authenticated');
    next();
  } catch (error) {
    logger.error({ error }, 'Authentication failed');
    res.status(401).json({ error: 'Unauthorized' });
  }
}

/**
 * Admin middleware - requires user to be in admin group
 */
export function requireAdmin(req: AuthenticatedRequest, res: Response, next: NextFunction): void {
  const user = req.user;

  if (!user || !user.groups?.includes('ai-assist-admins')) {
    logger.warn({ user: user?.email }, 'Admin access denied');
    res.status(403).json({ error: 'Forbidden: Admin access required' });
    return;
  }

  next();
}
