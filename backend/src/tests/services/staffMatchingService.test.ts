// DB setup is handled by global setup.ts (MongoMemoryServer)
import mongoose from 'mongoose';
import { rankStaffForRole } from '../../services/staffMatchingService';
import { StaffProfileModel } from '../../models/staffProfile';
import { UserModel } from '../../models/user';
import { EventModel } from '../../models/event';
import { ManagerModel } from '../../models/manager';

describe('staffMatchingService', () => {
  let managerId: mongoose.Types.ObjectId;

  beforeEach(async () => {
    // Create a manager
    const manager = await ManagerModel.create({
      provider: 'google',
      subject: 'mgr-test',
      name: 'Test Manager',
    });
    managerId = manager._id as mongoose.Types.ObjectId;
  });

  async function createStaffMember(opts: {
    name: string;
    userKey: string;
    skills?: string[];
    certifications?: { name: string; expiryDate?: Date; certNumber?: string }[];
    profileSkills?: string[];
    profileCerts?: { name: string; expiryDate?: Date; verifiedAt?: Date }[];
    rating?: number;
    isFavorite?: boolean;
    workPreferences?: any;
    homeCoordinates?: { lat: number; lng: number };
  }) {
    const [provider, subject] = opts.userKey.split(':');
    await UserModel.create({
      provider,
      subject,
      name: opts.name,
      email: `${subject}@test.com`,
      skills: opts.skills || [],
      certifications: opts.certifications || [],
      workPreferences: opts.workPreferences,
      homeCoordinates: opts.homeCoordinates,
    });
    await StaffProfileModel.create({
      managerId,
      userKey: opts.userKey,
      rating: opts.rating || 0,
      isFavorite: opts.isFavorite || false,
      skills: opts.profileSkills || [],
      certifications: opts.profileCerts || [],
    });
  }

  async function createPastEvent(opts: {
    date: Date;
    staffEntries: { userKey: string; name: string; role: string; clockInAt?: Date }[];
  }) {
    await EventModel.create({
      managerId,
      status: 'completed',
      date: opts.date,
      start_time: '09:00',
      roles: [{ role: 'Server', count: 5 }],
      client_name: 'Test Client',
      accepted_staff: opts.staffEntries.map((s) => ({
        userKey: s.userKey,
        name: s.name,
        role: s.role,
        response: 'accept',
        attendance: s.clockInAt ? [{ clockInAt: s.clockInAt }] : [],
      })),
    });
  }

  describe('rankStaffForRole', () => {
    it('returns empty array when no staff exist', async () => {
      const result = await rankStaffForRole(managerId, {
        roleName: 'Bartender',
      });
      expect(result).toEqual([]);
    });

    it('ranks staff with matching skills higher', async () => {
      await createStaffMember({
        name: 'Alice',
        userKey: 'google:alice',
        skills: ['Bartending', 'Mixology'],
        profileSkills: ['Wine Service'],
      });
      await createStaffMember({
        name: 'Bob',
        userKey: 'google:bob',
        skills: ['Cleaning'],
        profileSkills: [],
      });

      const result = await rankStaffForRole(managerId, {
        roleName: 'Bartender',
        requiredSkills: ['Bartending', 'Mixology', 'Wine Service'],
      });

      expect(result.length).toBe(2);
      expect(result[0].name).toBe('Alice');
      expect(result[0].scores.skills).toBe(100); // 3/3 matched
      expect(result[0].matchedSkills).toEqual(
        expect.arrayContaining(['Bartending', 'Mixology', 'Wine Service'])
      );
      expect(result[0].missingSkills).toEqual([]);

      expect(result[1].name).toBe('Bob');
      expect(result[1].scores.skills).toBe(0); // 0/3 matched
      expect(result[1].missingSkills).toEqual(
        expect.arrayContaining(['Bartending', 'Mixology', 'Wine Service'])
      );
    });

    it('uses union of user skills and profile skills', async () => {
      // Alice has "Bartending" self-reported, "Mixology" manager-confirmed
      await createStaffMember({
        name: 'Alice',
        userKey: 'google:alice',
        skills: ['Bartending'],          // self-reported
        profileSkills: ['Mixology'],      // manager-confirmed
      });

      const result = await rankStaffForRole(managerId, {
        roleName: 'Bartender',
        requiredSkills: ['Bartending', 'Mixology'],
      });

      expect(result[0].scores.skills).toBe(100); // both matched via union
      expect(result[0].matchedSkills).toHaveLength(2);
    });

    it('scores certifications and checks expiry', async () => {
      const futureDate = new Date();
      futureDate.setFullYear(futureDate.getFullYear() + 1);

      const pastDate = new Date();
      pastDate.setFullYear(pastDate.getFullYear() - 1);

      await createStaffMember({
        name: 'Alice',
        userKey: 'google:alice',
        certifications: [
          { name: 'TIPS', expiryDate: futureDate },          // valid
          { name: 'ServSafe Food Handler', expiryDate: pastDate }, // expired
        ],
      });

      const result = await rankStaffForRole(managerId, {
        roleName: 'Server',
        requiredCertifications: ['TIPS', 'ServSafe Food Handler'],
      });

      expect(result[0].matchedCerts).toContain('TIPS');
      expect(result[0].missingCerts).toContain('ServSafe Food Handler'); // expired = missing
      expect(result[0].scores.certifications).toBe(50); // 1/2
    });

    it('gives manager-verified certs a bonus', async () => {
      const futureDate = new Date();
      futureDate.setFullYear(futureDate.getFullYear() + 1);

      // Need multiple required certs so the 10% bonus is visible
      // (with 1 cert, both 1.0 and 1.1 get capped to 1.0 by Math.min)
      await createStaffMember({
        name: 'Alice',
        userKey: 'google:alice',
        profileCerts: [
          { name: 'TIPS', expiryDate: futureDate, verifiedAt: new Date() },
          { name: 'ServSafe Food Handler', expiryDate: futureDate, verifiedAt: new Date() },
        ],
      });
      await createStaffMember({
        name: 'Bob',
        userKey: 'google:bob',
        certifications: [
          { name: 'TIPS', expiryDate: futureDate },
          { name: 'ServSafe Food Handler', expiryDate: futureDate },
        ],
      });

      const result = await rankStaffForRole(managerId, {
        roleName: 'Server',
        requiredCertifications: ['TIPS', 'ServSafe Food Handler', 'CPR / First Aid'],
      });

      // Both have 2/3 certs, but Alice's are verified → higher cert score
      const alice = result.find((c) => c.name === 'Alice')!;
      const bob = result.find((c) => c.name === 'Bob')!;
      expect(alice.scores.certifications).toBeGreaterThan(bob.scores.certifications);
    });

    it('defaults skills/certs to 0.5 (neutral) when no requirements', async () => {
      await createStaffMember({
        name: 'Alice',
        userKey: 'google:alice',
        skills: ['Bartending'],
        rating: 4,
      });

      const result = await rankStaffForRole(managerId, {
        roleName: 'Bartender',
        // No requiredSkills or requiredCertifications
      });

      expect(result[0].scores.skills).toBe(50);          // 0.5 * 100
      expect(result[0].scores.certifications).toBe(50);   // 0.5 * 100
    });

    it('factors in performance from recent events', async () => {
      await createStaffMember({
        name: 'Alice',
        userKey: 'google:alice',
        rating: 5,
      });
      await createStaffMember({
        name: 'Bob',
        userKey: 'google:bob',
        rating: 2,
      });

      // Create 4 past events (need ≥3 for performance scoring)
      for (let i = 0; i < 4; i++) {
        const eventDate = new Date();
        eventDate.setDate(eventDate.getDate() - (10 + i));
        const eventStart = new Date(eventDate);
        eventStart.setHours(9, 0, 0, 0);

        await createPastEvent({
          date: eventDate,
          staffEntries: [
            { userKey: 'google:alice', name: 'Alice', role: 'Server', clockInAt: eventStart }, // on time
            { userKey: 'google:bob', name: 'Bob', role: 'Server' }, // no clock-in = no-show
          ],
        });
      }

      const result = await rankStaffForRole(managerId, { roleName: 'Server' });

      const alice = result.find((c) => c.name === 'Alice')!;
      const bob = result.find((c) => c.name === 'Bob')!;
      expect(alice.scores.performance).toBeGreaterThan(bob.scores.performance);
    });

    it('marks busy candidates on same-day events', async () => {
      const eventDate = new Date();
      eventDate.setDate(eventDate.getDate() + 7); // next week

      await createStaffMember({
        name: 'Alice',
        userKey: 'google:alice',
      });

      // Alice is already accepted on another event same day
      await EventModel.create({
        managerId,
        status: 'published',
        date: eventDate,
        start_time: '14:00',
        shift_name: 'Wedding Reception',
        roles: [{ role: 'Server', count: 2 }],
        accepted_staff: [{
          userKey: 'google:alice',
          name: 'Alice',
          response: 'accept',
          role: 'Server',
        }],
      });

      const result = await rankStaffForRole(managerId, {
        roleName: 'Bartender',
        eventDate,
      });

      expect(result[0].isBusy).toBe(true);
      expect(result[0].busyReason).toContain('Wedding Reception');
    });

    it('favorites rank higher as tiebreaker', async () => {
      await createStaffMember({
        name: 'Alice',
        userKey: 'google:alice',
        isFavorite: false,
      });
      await createStaffMember({
        name: 'Bob',
        userKey: 'google:bob',
        isFavorite: true,
      });

      const result = await rankStaffForRole(managerId, { roleName: 'Server' });

      // Same scores, but Bob is favorite → ranks first
      expect(result[0].name).toBe('Bob');
      expect(result[0].isFavorite).toBe(true);
    });

    it('respects limit parameter', async () => {
      for (let i = 0; i < 5; i++) {
        await createStaffMember({
          name: `Staff${i}`,
          userKey: `google:staff${i}`,
        });
      }

      const result = await rankStaffForRole(managerId, {
        roleName: 'Server',
      }, { limit: 3 });

      expect(result.length).toBe(3);
    });

    it('returns correct response shape', async () => {
      await createStaffMember({
        name: 'Alice',
        userKey: 'google:alice',
        skills: ['Bartending'],
        rating: 4,
        isFavorite: true,
      });

      const result = await rankStaffForRole(managerId, {
        roleName: 'Bartender',
        requiredSkills: ['Bartending', 'Mixology'],
      });

      const candidate = result[0];
      // Verify shape
      expect(candidate).toHaveProperty('userKey');
      expect(candidate).toHaveProperty('name');
      expect(candidate).toHaveProperty('scores');
      expect(candidate.scores).toHaveProperty('skills');
      expect(candidate.scores).toHaveProperty('certifications');
      expect(candidate.scores).toHaveProperty('performance');
      expect(candidate.scores).toHaveProperty('availability');
      expect(candidate.scores).toHaveProperty('total');
      expect(candidate).toHaveProperty('matchedSkills');
      expect(candidate).toHaveProperty('missingSkills');
      expect(candidate).toHaveProperty('matchedCerts');
      expect(candidate).toHaveProperty('missingCerts');
      expect(candidate).toHaveProperty('isFavorite');
      expect(candidate).toHaveProperty('rating');
      expect(candidate).toHaveProperty('isBusy');

      // Verify values
      expect(candidate.scores.total).toBeGreaterThanOrEqual(0);
      expect(candidate.scores.total).toBeLessThanOrEqual(100);
    });
  });
});
