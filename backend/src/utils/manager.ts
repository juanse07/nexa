import { AuthenticatedRequest } from '../middleware/requireAuth';
import { ManagerDocument, ManagerModel } from '../models/manager';

/**
 * Resolve the Manager document for the authenticated request.
 * Automatically provisions a manager profile when first encountered.
 */
export async function resolveManagerForRequest(req: AuthenticatedRequest): Promise<ManagerDocument> {
  if (!req.authUser?.provider || !req.authUser?.sub) {
    throw new Error('Missing authentication claims for manager resolution');
  }

  const existing = await ManagerModel.findOne({
    provider: req.authUser.provider,
    subject: req.authUser.sub,
  });

  if (existing) {
    return existing;
  }

  const created = await ManagerModel.create({
    provider: req.authUser.provider,
    subject: req.authUser.sub,
    email: req.authUser.email,
    name: req.authUser.name,
    picture: req.authUser.picture,
  });

  return created;
}
