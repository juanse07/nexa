import { Types } from 'mongoose';
import { ManagerModel } from '../models/manager';
import { OrganizationModel } from '../models/organization';

/**
 * Check if a manager is allowed to add a specific staff member to a team,
 * based on the manager's organization staff policy.
 *
 * - No org → always allowed (solo freelancers)
 * - staffPolicy 'open' → always allowed
 * - staffPolicy 'restricted' → only if provider+subject is in approvedStaff[]
 */
export async function canAddStaffToTeam(
  managerId: Types.ObjectId,
  provider: string,
  subject: string,
): Promise<{ allowed: boolean; reason?: string }> {
  const manager = await ManagerModel.findById(managerId)
    .select('organizationId')
    .lean();

  if (!manager?.organizationId) {
    return { allowed: true };
  }

  const org = await OrganizationModel.findById(manager.organizationId)
    .select('staffPolicy approvedStaff')
    .lean();

  if (!org) {
    return { allowed: true };
  }

  if (org.staffPolicy !== 'restricted') {
    return { allowed: true };
  }

  const isApproved = org.approvedStaff.some(
    (s) => s.provider === provider && s.subject === subject,
  );

  if (isApproved) {
    return { allowed: true };
  }

  return {
    allowed: false,
    reason: 'Staff not in organization approved pool',
  };
}
