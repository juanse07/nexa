import { EventDocument, RoleRequirement, AcceptedStaffMember } from '../models/event';

/**
 * Check if all role positions in an event are filled
 * @param event - The event document to check
 * @returns true if all roles are at capacity, false otherwise
 */
export function checkIfEventFulfilled(event: EventDocument): boolean {
  const roles = event.roles || [];
  const acceptedStaff = event.accepted_staff || [];

  // If no roles defined, event cannot be fulfilled
  if (roles.length === 0) {
    return false;
  }

  // Count accepted staff per role
  const roleAcceptCounts: Record<string, number> = {};
  for (const staff of acceptedStaff) {
    if (staff.role && staff.response === 'accept') {
      const roleKey = staff.role.toLowerCase();
      roleAcceptCounts[roleKey] = (roleAcceptCounts[roleKey] || 0) + 1;
    }
  }

  // Check if every role has reached its capacity
  for (const role of roles) {
    const roleKey = (role.role || '').toLowerCase();
    const required = role.count || 0;
    const accepted = roleAcceptCounts[roleKey] || 0;

    // If any role is not filled, event is not fulfilled
    if (accepted < required) {
      return false;
    }
  }

  // All roles are at capacity
  return true;
}

/**
 * Get detailed capacity status for each role in an event
 * @param event - The event document to analyze
 * @returns Array of role capacity information
 */
export function getRoleCapacityStatus(event: EventDocument): Array<{
  role: string;
  required: number;
  accepted: number;
  remaining: number;
  isFull: boolean;
}> {
  const roles = event.roles || [];
  const acceptedStaff = event.accepted_staff || [];

  // Count accepted staff per role
  const roleAcceptCounts: Record<string, number> = {};
  for (const staff of acceptedStaff) {
    if (staff.role && staff.response === 'accept') {
      const roleKey = staff.role.toLowerCase();
      roleAcceptCounts[roleKey] = (roleAcceptCounts[roleKey] || 0) + 1;
    }
  }

  // Build capacity status for each role
  return roles.map((role) => {
    const roleKey = (role.role || '').toLowerCase();
    const required = role.count || 0;
    const accepted = roleAcceptCounts[roleKey] || 0;
    const remaining = Math.max(required - accepted, 0);
    const isFull = accepted >= required && required > 0;

    return {
      role: role.role,
      required,
      accepted,
      remaining,
      isFull,
    };
  });
}

/**
 * Check if a specific role in an event has capacity for more staff
 * @param event - The event document
 * @param roleId - The role identifier (can be role name or _id)
 * @returns true if role has remaining capacity, false otherwise
 */
/**
 * Compute per-role capacity stats from roles array and accepted staff array.
 * Used by both REST endpoints (events.ts) and AI tool execution (ai.ts).
 */
export function computeRoleStats(roles: any[], accepted: any[]) {
  const acceptedCounts = (accepted || []).reduce((acc: Record<string, number>, m: any) => {
    const key = (m?.role || '').toLowerCase();
    if (!key) return acc;
    acc[key] = (acc[key] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);
  return (roles || []).map((r: any) => {
    const key = (r?.role || '').toLowerCase();
    const capacity = r?.count || 0;
    const taken = acceptedCounts[key] || 0;
    const remaining = Math.max(capacity - taken, 0);
    return { role: r.role, capacity, taken, remaining, is_full: remaining === 0 && capacity > 0 };
  });
}

export function checkRoleHasCapacity(
  event: EventDocument,
  roleId: string
): boolean {
  const roles = event.roles || [];
  const acceptedStaff = event.accepted_staff || [];

  // Find the role by ID or name
  const role = roles.find(
    (r: any) =>
      r._id?.toString() === roleId ||
      r.role_id?.toString() === roleId ||
      r.role?.toLowerCase() === roleId.toLowerCase()
  );

  if (!role) {
    return false; // Role not found
  }

  const roleKey = (role.role || '').toLowerCase();
  const required = role.count || 0;

  // Count accepted staff for this role
  const accepted = acceptedStaff.filter(
    (s) => s.role?.toLowerCase() === roleKey && s.response === 'accept'
  ).length;

  return accepted < required;
}
