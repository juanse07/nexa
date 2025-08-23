import { NextFunction, Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { ENV } from '../config/env';

export interface AuthenticatedUser {
  provider: string;
  sub: string;
  email?: string;
  name?: string;
  picture?: string;
}

export function requireAuth(req: Request, res: Response, next: NextFunction) {
  try {
    const header = req.headers.authorization || '';
    const token = header.startsWith('Bearer ')
      ? header.slice('Bearer '.length)
      : '';
    if (!token) return res.status(401).json({ message: 'Unauthorized' });
    const decoded = jwt.verify(token, ENV.jwtSecret, { algorithms: ['HS256'] }) as Partial<AuthenticatedUser & { sub: string; provider: string }>;
    if (!decoded || !decoded.sub || !decoded.provider) {
      return res.status(401).json({ message: 'Unauthorized' });
    }
    (req as any).user = {
      provider: decoded.provider,
      sub: decoded.sub,
      email: decoded.email,
      name: decoded.name,
      picture: decoded.picture,
    } as AuthenticatedUser;
    next();
  } catch {
    return res.status(401).json({ message: 'Unauthorized' });
  }
}


