import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { ENV } from '../config/env';

export interface AuthenticatedUser {
  provider: string;
  sub: string;
  userKey: string;
  email?: string;
  name?: string;
  picture?: string;
  managerId?: string;
  organizationId?: string;
  orgRole?: string;
}

export interface AuthenticatedRequest extends Request {
  authUser: AuthenticatedUser;
  user: AuthenticatedUser; // Legacy compatibility
}

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ')
      ? header.slice('Bearer '.length)
      : '';
    if (!token) {
      return res.status(401).json({
        error: 'Authentication required',
        message: 'Please sign in to continue'
      });
    }
    const decoded = jwt.verify(token, ENV.jwtSecret, { algorithms: ['HS256'] }) as Partial<AuthenticatedUser & { sub: string; provider: string }>;
    if (!decoded || !decoded.sub || !decoded.provider) {
      return res.status(401).json({
        error: 'Invalid authentication',
        message: 'Please sign in again'
      });
    }
    (req as any).user = {
      provider: decoded.provider,
      sub: decoded.sub,
      userKey: `${decoded.provider}:${decoded.sub}`,
      email: decoded.email,
      name: decoded.name,
      picture: decoded.picture,
      managerId: decoded.managerId,
      organizationId: (decoded as any).organizationId,
      orgRole: (decoded as any).orgRole,
    } as AuthenticatedUser;
    (req as any).authUser = (req as any).user; // Add authUser alias for compatibility
    next();
  } catch (err) {
    const errorMessage = (err as Error).message || '';
    if (errorMessage.includes('expired')) {
      return res.status(401).json({
        error: 'Session expired',
        message: 'Please sign in again'
      });
    }
    return res.status(401).json({
      error: 'Authentication failed',
      message: 'Please sign in to continue'
    });
  }
}


