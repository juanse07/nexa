import { Request } from 'express';
import { ManagerDocument, ManagerModel } from '../models/manager';

/**
 * Resolve the Manager document for the authenticated request.
 * Automatically provisions a manager profile when first encountered.
 */
export async function resolveManagerForRequest(req: Request): Promise<ManagerDocument> {
  if (!req.user?.provider || !req.user?.sub) {
    throw new Error('Missing authentication claims for manager resolution');
  }

  const existing = await ManagerModel.findOne({
    provider: req.user.provider,
    subject: req.user.sub,
  });

  if (existing) {
    return existing;
  }

  const created = await ManagerModel.create({
    provider: req.user.provider,
    subject: req.user.sub,
    email: req.user.email,
    name: req.user.name,
    picture: req.user.picture,
  });

  return created;
}
