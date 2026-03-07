import { AuthenticatedRequest } from '../middleware/requireAuth';
import { ManagerDocument, ManagerModel } from '../models/manager';

/**
 * Resolve the Manager document for the authenticated request.
 * SECURITY: Requires managerId in JWT token - does NOT auto-create managers.
 * Managers must be created explicitly via /auth/manager/* endpoints.
 *
 * If the managerId from the JWT is stale (e.g. after demo re-seed),
 * falls back to lookup by {provider, subject} to stay resilient.
 */
export async function resolveManagerForRequest(req: AuthenticatedRequest): Promise<ManagerDocument> {
  if (!req.authUser?.provider || !req.authUser?.sub) {
    throw new Error('Missing authentication claims for manager resolution');
  }

  // SECURITY: Require managerId in JWT token (only manager auth endpoints provide this)
  if (!req.authUser?.managerId) {
    throw new Error('Manager authentication required. Please sign in using the manager app.');
  }

  // Primary: look up by the managerId claim in JWT (fast, indexed)
  let manager = await ManagerModel.findById(req.authUser.managerId);

  // Fallback: if ID is stale (e.g. demo re-seed), look up by provider+subject
  if (!manager) {
    manager = await ManagerModel.findOne({
      provider: req.authUser.provider,
      subject: req.authUser.sub,
    });
  }

  if (!manager) {
    throw new Error('Manager profile not found. Please sign in again using the manager app.');
  }

  // Verify the JWT claims match the manager document (prevent token tampering)
  if (manager.provider !== req.authUser.provider || manager.subject !== req.authUser.sub) {
    throw new Error('Manager authentication mismatch. Please sign in again.');
  }

  return manager;
}
