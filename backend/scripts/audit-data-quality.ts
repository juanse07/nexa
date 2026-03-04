import mongoose from 'mongoose';
import { ENV } from '../src/config/env';
import { UserModel } from '../src/models/user';
import { TeamMemberModel } from '../src/models/teamMember';
import { StaffProfileModel } from '../src/models/staffProfile';
import { ManagerModel } from '../src/models/manager';
import { StaffGroupModel } from '../src/models/staffGroup';
import { TeamModel } from '../src/models/team';

/**
 * FlowShift Data Quality Audit
 *
 * Read-only diagnostic script that checks for:
 *   A. Orphaned records across users / teammembers / staffprofiles
 *   B. Duplicates & stale cached fields
 *   C. Status inconsistencies & missing data
 *   D. Summary statistics
 *
 * Exit code 0 = clean, 1 = issues found
 */

const MAX_SAMPLES = 5;
const STALE_PENDING_DAYS = 30;

interface Issue {
  label: string;
  count: number;
  samples: Record<string, unknown>[];
}

// ── Helpers ──────────────────────────────────────────────

function fmt(n: number): string {
  return n.toLocaleString('en-US');
}

function line(char: string, len = 50): string {
  return char.repeat(len);
}

function printIssue(issue: Issue): void {
  if (issue.count === 0) {
    console.log(`  ✅ ${issue.label}: All OK`);
  } else {
    console.log(`  ⚠️  ${issue.label}: ${fmt(issue.count)} found`);
    for (const s of issue.samples) {
      const parts = Object.entries(s)
        .map(([k, v]) => `${k}=${JSON.stringify(v)}`)
        .join(' ');
      console.log(`     • ${parts}`);
    }
    if (issue.count > MAX_SAMPLES) {
      console.log(`     ... and ${fmt(issue.count - MAX_SAMPLES)} more`);
    }
  }
}

// ── Section A: Orphaned Records ──────────────────────────

async function checkOrphanedTeamMembersToUsers(): Promise<Issue> {
  // TeamMembers (active/pending) whose (provider, subject) has no matching User
  const results = await TeamMemberModel.aggregate([
    { $match: { status: { $in: ['active', 'pending'] } } },
    {
      $lookup: {
        from: 'users',
        let: { p: '$provider', s: '$subject' },
        pipeline: [
          { $match: { $expr: { $and: [{ $eq: ['$provider', '$$p'] }, { $eq: ['$subject', '$$s'] }] } } },
          { $project: { _id: 1 } },
        ],
        as: 'user',
      },
    },
    { $match: { user: { $size: 0 } } },
    { $project: { provider: 1, subject: 1, status: 1, email: 1, teamId: 1 } },
  ]);

  return {
    label: 'TeamMembers → Users (orphaned)',
    count: results.length,
    samples: results.slice(0, MAX_SAMPLES).map((r) => ({
      _id: r._id,
      key: `${r.provider}:${r.subject}`,
      status: r.status,
      email: r.email || '(none)',
    })),
  };
}

async function checkOrphanedStaffProfilesToUsers(): Promise<Issue> {
  // StaffProfiles whose userKey has no matching User (provider:subject)
  const results = await StaffProfileModel.aggregate([
    {
      $addFields: {
        _parts: { $split: ['$userKey', ':'] },
      },
    },
    {
      $addFields: {
        _provider: { $arrayElemAt: ['$_parts', 0] },
        _subject: {
          $reduce: {
            input: { $slice: ['$_parts', 1, { $subtract: [{ $size: '$_parts' }, 1] }] },
            initialValue: '',
            in: {
              $cond: [
                { $eq: ['$$value', ''] },
                '$$this',
                { $concat: ['$$value', ':', '$$this'] },
              ],
            },
          },
        },
      },
    },
    {
      $lookup: {
        from: 'users',
        let: { p: '$_provider', s: '$_subject' },
        pipeline: [
          { $match: { $expr: { $and: [{ $eq: ['$provider', '$$p'] }, { $eq: ['$subject', '$$s'] }] } } },
          { $project: { _id: 1 } },
        ],
        as: 'user',
      },
    },
    { $match: { user: { $size: 0 } } },
    { $project: { userKey: 1, managerId: 1 } },
  ]);

  return {
    label: 'StaffProfiles → Users (orphaned)',
    count: results.length,
    samples: results.slice(0, MAX_SAMPLES).map((r) => ({
      _id: r._id,
      userKey: r.userKey,
      managerId: r.managerId,
    })),
  };
}

async function checkOrphanedStaffProfilesToManagers(): Promise<Issue> {
  // StaffProfiles whose managerId references a non-existent Manager
  const results = await StaffProfileModel.aggregate([
    {
      $lookup: {
        from: 'managers',
        localField: 'managerId',
        foreignField: '_id',
        as: 'manager',
      },
    },
    { $match: { manager: { $size: 0 } } },
    { $project: { userKey: 1, managerId: 1 } },
  ]);

  return {
    label: 'StaffProfiles → Managers (orphaned)',
    count: results.length,
    samples: results.slice(0, MAX_SAMPLES).map((r) => ({
      _id: r._id,
      userKey: r.userKey,
      managerId: r.managerId,
    })),
  };
}

async function checkOrphanedStaffProfilesToTeamMembers(): Promise<Issue> {
  // StaffProfiles for users who are not active TeamMembers under that manager
  const results = await StaffProfileModel.aggregate([
    {
      $addFields: {
        _parts: { $split: ['$userKey', ':'] },
      },
    },
    {
      $addFields: {
        _provider: { $arrayElemAt: ['$_parts', 0] },
        _subject: {
          $reduce: {
            input: { $slice: ['$_parts', 1, { $subtract: [{ $size: '$_parts' }, 1] }] },
            initialValue: '',
            in: {
              $cond: [
                { $eq: ['$$value', ''] },
                '$$this',
                { $concat: ['$$value', ':', '$$this'] },
              ],
            },
          },
        },
      },
    },
    {
      $lookup: {
        from: 'teammembers',
        let: { p: '$_provider', s: '$_subject', mid: '$managerId' },
        pipeline: [
          {
            $match: {
              $expr: {
                $and: [
                  { $eq: ['$provider', '$$p'] },
                  { $eq: ['$subject', '$$s'] },
                  { $eq: ['$managerId', '$$mid'] },
                  { $eq: ['$status', 'active'] },
                ],
              },
            },
          },
          { $project: { _id: 1 } },
        ],
        as: 'activeMember',
      },
    },
    { $match: { activeMember: { $size: 0 } } },
    { $project: { userKey: 1, managerId: 1 } },
  ]);

  return {
    label: 'StaffProfiles → TeamMembers (no active member)',
    count: results.length,
    samples: results.slice(0, MAX_SAMPLES).map((r) => ({
      _id: r._id,
      userKey: r.userKey,
      managerId: r.managerId,
    })),
  };
}

async function checkStaffProfilesInvalidGroupIds(): Promise<Issue> {
  // StaffProfiles referencing StaffGroup IDs that don't exist
  const allGroupIds = await StaffGroupModel.distinct('_id');
  const groupIdSet = new Set(allGroupIds.map((id) => id.toString()));

  const profilesWithGroups = await StaffProfileModel.find(
    { groupIds: { $exists: true, $not: { $size: 0 } } },
    { userKey: 1, managerId: 1, groupIds: 1 }
  ).lean();

  const invalid: { _id: unknown; userKey: string; managerId: unknown; badGroupIds: string[] }[] = [];

  for (const p of profilesWithGroups) {
    const badIds = p.groupIds
      .map((id) => id.toString())
      .filter((id) => !groupIdSet.has(id));
    if (badIds.length > 0) {
      invalid.push({
        _id: p._id,
        userKey: p.userKey,
        managerId: p.managerId,
        badGroupIds: badIds,
      });
    }
  }

  return {
    label: 'StaffProfiles with invalid groupIds',
    count: invalid.length,
    samples: invalid.slice(0, MAX_SAMPLES).map((r) => ({
      _id: r._id,
      userKey: r.userKey,
      badGroupIds: r.badGroupIds.join(', '),
    })),
  };
}

// ── Section B: Duplicates & Conflicts ────────────────────

async function checkDuplicateTeamMembers(): Promise<Issue> {
  // Same (provider, subject) with multiple "active" entries under the same team
  const results = await TeamMemberModel.aggregate([
    { $match: { status: 'active' } },
    {
      $group: {
        _id: { teamId: '$teamId', provider: '$provider', subject: '$subject' },
        count: { $sum: 1 },
        ids: { $push: '$_id' },
      },
    },
    { $match: { count: { $gt: 1 } } },
  ]);

  return {
    label: 'Duplicate active TeamMembers (same team)',
    count: results.length,
    samples: results.slice(0, MAX_SAMPLES).map((r) => ({
      key: `${r._id.provider}:${r._id.subject}`,
      teamId: r._id.teamId,
      duplicateCount: r.count,
    })),
  };
}

async function checkStaleCachedFields(): Promise<Issue> {
  // TeamMember email/name that don't match the corresponding User
  const results = await TeamMemberModel.aggregate([
    { $match: { status: { $in: ['active', 'pending'] } } },
    {
      $lookup: {
        from: 'users',
        let: { p: '$provider', s: '$subject' },
        pipeline: [
          { $match: { $expr: { $and: [{ $eq: ['$provider', '$$p'] }, { $eq: ['$subject', '$$s'] }] } } },
          { $project: { email: 1, name: 1 } },
        ],
        as: 'user',
      },
    },
    { $unwind: '$user' },
    {
      $match: {
        $or: [
          { $expr: { $and: [{ $ne: ['$email', null] }, { $ne: ['$user.email', null] }, { $ne: ['$email', '$user.email'] }] } },
          { $expr: { $and: [{ $ne: ['$name', null] }, { $ne: ['$user.name', null] }, { $ne: ['$name', '$user.name'] }] } },
        ],
      },
    },
    {
      $project: {
        provider: 1,
        subject: 1,
        tmEmail: '$email',
        userEmail: '$user.email',
        tmName: '$name',
        userName: '$user.name',
      },
    },
  ]);

  return {
    label: 'Stale cached fields (TeamMember vs User)',
    count: results.length,
    samples: results.slice(0, MAX_SAMPLES).map((r) => ({
      key: `${r.provider}:${r.subject}`,
      tmEmail: r.tmEmail,
      userEmail: r.userEmail,
      tmName: r.tmName,
      userName: r.userName,
    })),
  };
}

async function checkUserKeyFormat(): Promise<Issue> {
  // StaffProfile userKey values that don't match provider:subject pattern
  const validProviders = ['google', 'apple', 'phone', 'email'];
  const all = await StaffProfileModel.find({}, { userKey: 1 }).lean();

  const invalid: { _id: unknown; userKey: string; reason: string }[] = [];

  for (const p of all) {
    const colonIdx = p.userKey.indexOf(':');
    if (colonIdx === -1) {
      invalid.push({ _id: p._id, userKey: p.userKey, reason: 'no colon separator' });
    } else {
      const provider = p.userKey.substring(0, colonIdx);
      const subject = p.userKey.substring(colonIdx + 1);
      if (!validProviders.includes(provider)) {
        invalid.push({ _id: p._id, userKey: p.userKey, reason: `unknown provider: ${provider}` });
      } else if (!subject || subject.trim() === '') {
        invalid.push({ _id: p._id, userKey: p.userKey, reason: 'empty subject' });
      }
    }
  }

  return {
    label: 'UserKey format inconsistencies',
    count: invalid.length,
    samples: invalid.slice(0, MAX_SAMPLES).map((r) => ({
      _id: r._id,
      userKey: r.userKey,
      reason: r.reason,
    })),
  };
}

// ── Section C: Status Inconsistencies ────────────────────

async function checkLongPendingTeamMembers(): Promise<Issue> {
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - STALE_PENDING_DAYS);

  const results = await TeamMemberModel.find(
    { status: 'pending', createdAt: { $lt: cutoff } },
    { provider: 1, subject: 1, email: 1, createdAt: 1, teamId: 1 }
  )
    .sort({ createdAt: 1 })
    .lean();

  return {
    label: `Long-pending TeamMembers (>${STALE_PENDING_DAYS} days)`,
    count: results.length,
    samples: results.slice(0, MAX_SAMPLES).map((r) => ({
      key: `${r.provider}:${r.subject}`,
      email: r.email || '(none)',
      pendingSince: r.createdAt.toISOString().split('T')[0],
      teamId: r.teamId,
    })),
  };
}

async function checkMissingJoinedAt(): Promise<Issue> {
  const count = await TeamMemberModel.countDocuments({
    status: 'active',
    $or: [{ joinedAt: { $exists: false } }, { joinedAt: null }],
  });

  const samples = await TeamMemberModel.find(
    { status: 'active', $or: [{ joinedAt: { $exists: false } }, { joinedAt: null }] },
    { provider: 1, subject: 1, email: 1, status: 1 }
  )
    .limit(MAX_SAMPLES)
    .lean();

  return {
    label: 'Active TeamMembers with no joinedAt',
    count,
    samples: samples.map((r) => ({
      key: `${r.provider}:${r.subject}`,
      email: r.email || '(none)',
    })),
  };
}

async function checkUsersWithNoTeamMember(): Promise<Issue> {
  const results = await UserModel.aggregate([
    {
      $lookup: {
        from: 'teammembers',
        let: { p: '$provider', s: '$subject' },
        pipeline: [
          {
            $match: {
              $expr: {
                $and: [{ $eq: ['$provider', '$$p'] }, { $eq: ['$subject', '$$s'] }],
              },
            },
          },
          { $project: { _id: 1 } },
          { $limit: 1 },
        ],
        as: 'membership',
      },
    },
    { $match: { membership: { $size: 0 } } },
    { $project: { provider: 1, subject: 1, email: 1, name: 1, createdAt: 1 } },
  ]);

  return {
    label: 'Users with no TeamMember at all',
    count: results.length,
    samples: results.slice(0, MAX_SAMPLES).map((r) => ({
      key: `${r.provider}:${r.subject}`,
      email: r.email || '(none)',
      name: r.name || '(none)',
      created: r.createdAt?.toISOString().split('T')[0] || '?',
    })),
  };
}

async function checkTeamMembersWithMissingTeams(): Promise<Issue> {
  // Active TeamMembers referencing a teamId that doesn't exist
  const results = await TeamMemberModel.aggregate([
    { $match: { status: { $in: ['active', 'pending'] } } },
    {
      $lookup: {
        from: 'teams',
        localField: 'teamId',
        foreignField: '_id',
        as: 'team',
      },
    },
    { $match: { team: { $size: 0 } } },
    { $project: { provider: 1, subject: 1, email: 1, teamId: 1, status: 1 } },
  ]);

  return {
    label: 'Active/pending TeamMembers under missing Teams',
    count: results.length,
    samples: results.slice(0, MAX_SAMPLES).map((r) => ({
      key: `${r.provider}:${r.subject}`,
      teamId: r.teamId,
      status: r.status,
    })),
  };
}

// ── Section D: Summary Statistics ────────────────────────

async function collectSummary(): Promise<void> {
  const [userCount, tmCount, spCount, managerCount, teamCount, groupCount] = await Promise.all([
    UserModel.countDocuments(),
    TeamMemberModel.countDocuments(),
    StaffProfileModel.countDocuments(),
    ManagerModel.countDocuments(),
    TeamModel.countDocuments(),
    StaffGroupModel.countDocuments(),
  ]);

  const tmByStatus = await TeamMemberModel.aggregate([
    { $group: { _id: '$status', count: { $sum: 1 } } },
    { $sort: { count: -1 } },
  ]);

  const spRated = await StaffProfileModel.countDocuments({ rating: { $gt: 0 } });
  const spUnrated = spCount - spRated;

  const usersByProvider = await UserModel.aggregate([
    { $group: { _id: '$provider', count: { $sum: 1 } } },
    { $sort: { count: -1 } },
  ]);

  console.log('\n📊 Collection Counts');
  console.log(`  users:          ${fmt(userCount)}`);

  const statusParts = tmByStatus.map((s) => `${s._id}: ${fmt(s.count)}`).join(' | ');
  console.log(`  teammembers:    ${fmt(tmCount)} (${statusParts})`);
  console.log(`  staffprofiles:  ${fmt(spCount)} (rated: ${fmt(spRated)} | unrated: ${fmt(spUnrated)})`);
  console.log(`  managers:       ${fmt(managerCount)}`);
  console.log(`  teams:          ${fmt(teamCount)}`);
  console.log(`  staffgroups:    ${fmt(groupCount)}`);

  console.log('\n  Users by provider:');
  for (const u of usersByProvider) {
    console.log(`    ${u._id}: ${fmt(u.count)}`);
  }
}

// ── Main ─────────────────────────────────────────────────

async function main(): Promise<void> {
  const startTime = Date.now();

  console.log(`\n${line('═')}`);
  console.log('  FlowShift Data Quality Audit');
  console.log(`  ENV: ${ENV.nodeEnv} | Date: ${new Date().toISOString().split('T')[0]}`);
  console.log(line('═'));

  // Connect
  if (!ENV.mongoUri) {
    throw new Error('MONGO_URI environment variable is required');
  }

  const dbName = ENV.nodeEnv === 'production' ? 'nexa_prod' : 'nexa_test';
  let uri = ENV.mongoUri.trim();

  // Check if URI already contains a database name (path after host before query)
  const uriObj = new URL(uri);
  if (uriObj.pathname && uriObj.pathname !== '/') {
    // URI already specifies a DB — use as-is
    await mongoose.connect(uri);
  } else {
    if (uri.endsWith('/')) uri = uri.slice(0, -1);
    await mongoose.connect(`${uri}/${dbName}`);
  }
  console.log(`  Connected to: ${dbName}`);

  // D. Summary first
  await collectSummary();

  const allIssues: Issue[] = [];

  // A. Orphaned Records
  console.log(`\n${line('─', 3)} A. Orphaned Records ${line('─', 28)}\n`);

  const orphanChecks = await Promise.all([
    checkOrphanedTeamMembersToUsers(),
    checkOrphanedStaffProfilesToUsers(),
    checkOrphanedStaffProfilesToManagers(),
    checkOrphanedStaffProfilesToTeamMembers(),
    checkStaffProfilesInvalidGroupIds(),
  ]);
  for (const issue of orphanChecks) {
    printIssue(issue);
    allIssues.push(issue);
  }

  // B. Duplicates & Conflicts
  console.log(`\n${line('─', 3)} B. Duplicates & Conflicts ${line('─', 22)}\n`);

  const dupChecks = await Promise.all([
    checkDuplicateTeamMembers(),
    checkStaleCachedFields(),
    checkUserKeyFormat(),
  ]);
  for (const issue of dupChecks) {
    printIssue(issue);
    allIssues.push(issue);
  }

  // C. Status Inconsistencies
  console.log(`\n${line('─', 3)} C. Status Inconsistencies ${line('─', 22)}\n`);

  const statusChecks = await Promise.all([
    checkLongPendingTeamMembers(),
    checkMissingJoinedAt(),
    checkUsersWithNoTeamMember(),
    checkTeamMembersWithMissingTeams(),
  ]);
  for (const issue of statusChecks) {
    printIssue(issue);
    allIssues.push(issue);
  }

  // Final summary
  const issuesFound = allIssues.filter((i) => i.count > 0);
  const totalRecords = issuesFound.reduce((sum, i) => sum + i.count, 0);
  const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);

  console.log(`\n${line('═')}`);
  if (issuesFound.length === 0) {
    console.log('  Result: All checks passed — no issues found');
  } else {
    console.log(`  Summary: ${issuesFound.length} issue(s) found (${fmt(totalRecords)} records affected)`);
    for (const issue of issuesFound) {
      console.log(`    • ${issue.label}: ${fmt(issue.count)}`);
    }
  }
  console.log(`  Completed in ${elapsed}s`);
  console.log(line('═'));

  await mongoose.disconnect();

  if (issuesFound.length > 0) {
    process.exit(1);
  }
}

if (require.main === module) {
  main().catch((err) => {
    console.error('❌ Fatal error:', err);
    process.exit(2);
  });
}
