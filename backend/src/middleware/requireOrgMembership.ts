import { Request, Response, NextFunction } from 'express';
import { OrganizationModel, OrgMemberRole } from '../models/organization';

/**
 * Middleware factory that validates the requesting manager is a member of the org
 * specified by the :id route param, and optionally checks their role.
 *
 * Must be used AFTER requireAuth.
 */
export function requireOrgMembership(requiredRole?: 'owner' | 'admin') {
  return async (req: Request, res: Response, next: NextFunction) => {
    try {
      const managerId = (req as any).user?.managerId;
      if (!managerId) {
        return res.status(403).json({ message: 'Manager access required' });
      }

      const orgId = req.params.id;
      if (!orgId) {
        return res.status(400).json({ message: 'Organization ID is required' });
      }

      const org = await OrganizationModel.findById(orgId).lean();
      if (!org) {
        return res.status(404).json({ message: 'Organization not found' });
      }

      const member = org.members.find(
        (m) => String(m.managerId) === managerId,
      );

      if (!member) {
        return res.status(403).json({ message: 'You are not a member of this organization' });
      }

      // Role hierarchy: owner > admin > member
      if (requiredRole) {
        const roleRank: Record<OrgMemberRole, number> = { owner: 3, admin: 2, member: 1 };
        const requiredRank = roleRank[requiredRole];
        const actualRank = roleRank[member.role] || 0;

        if (actualRank < requiredRank) {
          return res.status(403).json({ message: `Requires ${requiredRole} role or higher` });
        }
      }

      // Attach org and member info for downstream handlers
      (req as any).org = org;
      (req as any).orgMember = member;

      next();
    } catch (err) {
      console.error('[requireOrgMembership] Error:', err);
      return res.status(500).json({ message: 'Failed to verify organization membership' });
    }
  };
}
