import { AuthenticatedRequest } from '../middleware/requireAuth';
import { ManagerDocument, ManagerModel } from '../models/manager';

/**
 * Resolve the Manager document for the authenticated request.
 * SECURITY: Requires managerId in JWT token - does NOT auto-create managers.
 * Managers must be created explicitly via /auth/manager/* endpoints.
 */
export async function resolveManagerForRequest(req: AuthenticatedRequest): Promise<ManagerDocument> {
  if (!req.authUser?.provider || !req.authUser?.sub) {
    throw new Error('Missing authentication claims for manager resolution');
  }

  // SECURITY: Require managerId in JWT token (only manager auth endpoints provide this)
  if (!req.authUser?.managerId) {
    throw new Error('Manager authentication required. Please sign in using the manager app.');
  }

  // Look up manager by the managerId claim in JWT (more efficient and secure)
  const manager = await ManagerModel.findById(req.authUser.managerId);

  if (!manager) {
    throw new Error('Manager profile not found. Please sign in again using the manager app.');
  }

  // Verify the JWT claims match the manager document (prevent token tampering)
  if (manager.provider !== req.authUser.provider || manager.subject !== req.authUser.sub) {
    throw new Error('Manager authentication mismatch. Please sign in again.');
  }

  return manager;
}
