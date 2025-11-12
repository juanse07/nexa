import mongoose from 'mongoose';
import { ENV } from '../src/config/env';
import { UserModel } from '../src/models/user';
import { EventModel } from '../src/models/event';
import { TariffModel } from '../src/models/tariff';
import { ManagerModel } from '../src/models/manager';
import { ClientModel } from '../src/models/client';
import { RoleModel } from '../src/models/role';

/**
 * High-Volume Historical Jobs Script
 * Creates 16-24 events per month for juan.2007@gmail.com from January 2024 to today
 * This generates realistic full-time hospitality work history
 */


interface GeneratedEvent {
  managerId: mongoose.Types.ObjectId;
  clientId: mongoose.Types.ObjectId;
  status: string;
  date: Date;
  start_time: string;
  end_time: string;
  client_name: string;
  venue_name: string;
  venue_address: string;
  city: string;
  state: string;
  country: string;
  shift_name: string;
  contact_name: string;
  contact_phone: string;
  contact_email: string;
  notes: string;
  uniform: string;
  headcount_total: number;
  roles: Array<{ role: string; count: number; call_time?: string }>;
  accepted_staff: Array<{
    userKey: string;
    provider: string;
    subject: string;
    email: string;
    name: string;
    role: string;
    respondedAt: Date;
  }>;
  attendance: Array<{
    userKey: string;
    clockInAt: Date;
    clockOutAt: Date;
    estimatedHours: number;
  }>;
  hoursStatus: string;
  approvedHours: number;
  fulfilledAt: Date;
  createdAt: Date;
}

// Configuration
const USER_EMAIL = 'juan.2007@gmail.com';
const USER_SUBJECT = 'google:112603799149919213350';
const START_DATE = new Date('2024-01-01');
const END_DATE = new Date();

// Role rates per hour
const ROLE_RATES = {
  'Server': 22,
  'Bartender': 26,
  'Host': 20,
  'Chef': 28,
  'Event Staff': 24,
  'Security': 25,
  'Server Assistant': 18
};

// Event types and their typical characteristics
const EVENT_TYPES = [
  { type: 'Restaurant Shift', duration: 6, venues: ['Restaurant', 'Bistro', 'Cafe'] },
  { type: 'Private Party', duration: 5, venues: ['Private Residence', 'Clubhouse', 'Event Hall'] },
  { type: 'Wedding', duration: 7, venues: ['Wedding Venue', 'Country Club', 'Hotel'] },
  { type: 'Corporate Event', duration: 6, venues: ['Conference Center', 'Hotel', 'Office Building'] },
  { type: 'Hotel Banquet', duration: 7, venues: ['Hotel', 'Resort', 'Conference Center'] },
  { type: 'Festival', duration: 8, venues: ['Park', 'Outdoor Venue', 'Festival Grounds'] },
  { type: 'Concert', duration: 6, venues: ['Concert Hall', 'Stadium', 'Outdoor Amphitheater'] }
];

// Venue data
const VENUES = [
  { name: 'The Grand Ballroom', address: '123 Main St', city: 'Los Angeles', state: 'CA', country: 'USA' },
  { name: 'Sunset Restaurant', address: '456 Ocean Ave', city: 'Santa Monica', state: 'CA', country: 'USA' },
  { name: 'Hilton Downtown', address: '789 Commerce St', city: 'Los Angeles', state: 'CA', country: 'USA' },
  { name: 'Beverly Hills Hotel', address: '987 Sunset Blvd', city: 'Beverly Hills', state: 'CA', country: 'USA' },
  { name: 'Convention Center', address: '1201 Figueroa St', city: 'Los Angeles', state: 'CA', country: 'USA' },
  { name: 'Marina Del Rey Hotel', address: '13540 Fiji Way', city: 'Marina Del Rey', state: 'CA', country: 'USA' },
  { name: 'Pasadena Convention Center', address: '300 E Green St', city: 'Pasadena', state: 'CA', country: 'USA' },
  { name: 'The Grove', address: '189 The Grove Drive', city: 'Los Angeles', state: 'CA', country: 'USA' },
  { name: 'Universal CityWalk', address: '100 Universal City Plaza', city: 'Universal City', state: 'CA', country: 'USA' },
  { name: 'Staples Center', address: '1111 S Figueroa St', city: 'Los Angeles', state: 'CA', country: 'USA' }
];

// Client names
const CLIENT_NAMES = [
  'Elite Catering Services', 'Premier Events LLC', 'Sunset Hospitality Group', 'Beverly Hills Catering',
  'Luxury Event Planning', 'Corporate Entertainment Co', 'Hotel Management Group', 'Restaurant Chain Inc',
  'Wedding Professionals', 'Festival Organizers', 'Concert Promotions', 'Private Party Planners',
  'Upscale Restaurant Group', 'Banquet Services Inc', 'Conference Planners', 'Special Events Co',
  'Gourmet Catering', 'Venue Management', 'Entertainment Group', 'Hospitality Partners'
];

class HistoricalJobsGenerator {
  private managers: any[] = [];
  private clients: any[] = [];
  private roles: any[] = [];
  private tariffs: any[] = [];
  private user: any = null;
  private eventsGenerated: GeneratedEvent[] = [];

  async initialize(): Promise<void> {
    console.log('🚀 Connecting to database...');

    if (!ENV.mongoUri) {
      throw new Error('MONGO_URI environment variable is required');
    }

    // Determine database name based on NODE_ENV
    const dbName = ENV.nodeEnv === 'production' ? 'nexa_prod' : 'nexa_test';

    let uri = ENV.mongoUri.trim();
    if (uri.endsWith('/')) {
      uri = uri.slice(0, -1);
    }

    await mongoose.connect(`${uri}/${dbName}`);
    console.log(`✅ Database connected to ${dbName}`);
  }

  async verifyUser(): Promise<void> {
    console.log('👤 Verifying user...');
    this.user = await UserModel.findOne({ email: USER_EMAIL });

    if (!this.user) {
      throw new Error(`User ${USER_EMAIL} not found`);
    }

    console.log(`✅ User found: ${this.user.name} (${this.user.email})`);
  }

  async createManagers(): Promise<void> {
    console.log('👥 Creating managers...');

    const managerData = [
      { name: 'Michael Johnson', email: 'michael.johnson@eliteevents.com', subject: 'google:manager001' },
      { name: 'Sarah Williams', email: 'sarah.williams@sunsethospitality.com', subject: 'google:manager002' },
      { name: 'David Chen', email: 'david.chen@premierevents.com', subject: 'google:manager003' },
      { name: 'Emily Rodriguez', email: 'emily.rodriguez@luxurycatering.com', subject: 'google:manager004' },
      { name: 'James Wilson', email: 'james.wilson@hospitalitygroup.com', subject: 'google:manager005' }
    ];

    for (const data of managerData) {
      let manager = await ManagerModel.findOne({ email: data.email });

      if (!manager) {
        const ManagerConstructor = mongoose.model('Manager') as any;
        manager = new ManagerConstructor({
          provider: 'google',
          subject: data.subject,
          email: data.email,
          name: data.name,
          venues: [],
          discovery: {
            enabled: true,
            preferences: {
              cities: ['Los Angeles', 'Santa Monica', 'Beverly Hills', 'Pasadena'],
              radius: 50,
              eventTypes: ['wedding', 'corporate', 'private']
            }
          }
        });
        await manager.save();
        console.log(`  ✅ Created manager: ${data.name}`);
      } else {
        console.log(`  ✅ Found existing manager: ${data.name}`);
      }

      this.managers.push(manager);
    }
  }

  async createClients(): Promise<void> {
    console.log('🏢 Creating clients...');

    for (let i = 0; i < CLIENT_NAMES.length; i++) {
      const manager = this.managers[i % this.managers.length];
      let clientName = CLIENT_NAMES[i];
      let normalizedName = clientName.toLowerCase().replace(/\s+/g, '');
      let attempt = 0;
      let client = null;

      // Try to find or create a unique client for this manager
      while (attempt < 3 && !client) {
        try {
          client = await ClientModel.findOne({
            managerId: manager._id,
            normalizedName: normalizedName
          });

          if (!client) {
            const ClientConstructor = mongoose.model('Client') as any;
            client = new ClientConstructor({
              managerId: manager._id,
              name: clientName,
              normalizedName: normalizedName
            });
            await client.save();
            console.log(`  ✅ Created client: ${clientName} for ${manager.name}`);
          } else {
            console.log(`  ✅ Found existing client: ${clientName} for ${manager.name}`);
          }
        } catch (error: any) {
          if (error.code === 11000) {
            // Try with a modified name
            attempt++;
            if (attempt === 1) {
              clientName = `${CLIENT_NAMES[i]} (${manager.name.split(' ')[0]})`;
            } else if (attempt === 2) {
              clientName = `${CLIENT_NAMES[i]} ${Math.floor(Math.random() * 1000)}`;
            }
            normalizedName = clientName.toLowerCase().replace(/\s+/g, '');
            console.log(`  🔄 Retrying with modified name: ${clientName}`);
          } else {
            throw error;
          }
        }
      }

      if (client) {
        this.clients.push(client);
      } else {
        console.warn(`  ⚠️  Failed to create client: ${CLIENT_NAMES[i]}`);
      }
    }
  }

  async createRoles(): Promise<void> {
    console.log('👔 Creating roles...');

    for (const manager of this.managers) {
      for (const role of Object.keys(ROLE_RATES)) {
        let roleDoc = await RoleModel.findOne({
          managerId: manager._id,
          normalizedName: role.toLowerCase()
        });

        if (!roleDoc) {
          const RoleConstructor = mongoose.model('Role') as any;
          try {
            roleDoc = new RoleConstructor({
              managerId: manager._id,
              name: role,
              normalizedName: role.toLowerCase()
            });
            await roleDoc.save();
            console.log(`  ✅ Created role: ${role} for ${manager.name}`);
          } catch (error: any) {
            if (error.code === 11000) {
              console.log(`  ⚠️  Role ${role} already exists for ${manager.name}`);
              roleDoc = await RoleModel.findOne({
                managerId: manager._id,
                normalizedName: role.toLowerCase()
              });
              if (!roleDoc) {
                throw new Error(`Failed to find existing role after duplicate error: ${role}`);
              }
            } else {
              throw error;
            }
          }
        }

        this.roles.push({
          managerId: manager._id,
          name: role,
          normalizedName: role.toLowerCase(),
          roleId: roleDoc._id
        });
      }
    }
    console.log(`  ✅ Created ${this.roles.length} role records`);
  }

  async createTariffs(): Promise<void> {
    console.log('💰 Creating tariffs...');

    for (const client of this.clients) {
      const manager = this.managers.find(m => m._id.equals(client.managerId))!;

      for (const role of Object.keys(ROLE_RATES)) {
        // Find the role ObjectId for this manager and role name
        const roleData = this.roles.find(r =>
          r.managerId.equals(manager._id) && r.name === role
        );

        if (!roleData) {
          console.warn(`  ⚠️  Role ${role} not found for manager ${manager.name}`);
          continue;
        }

        // Add some rate variation (±$3)
        const baseRate = ROLE_RATES[role as keyof typeof ROLE_RATES];
        const variation = Math.floor(Math.random() * 7) - 3;
        const finalRate = Math.max(15, baseRate + variation);

        let tariff = await TariffModel.findOne({
          managerId: manager._id,
          clientId: client._id,
          roleId: roleData.roleId
        });

        if (!tariff) {
          const TariffConstructor = mongoose.model('Tariff') as any;
          try {
            tariff = new TariffConstructor({
              managerId: manager._id,
              clientId: client._id,
              roleId: roleData.roleId,
              rate: finalRate,
              currency: 'USD'
            });
            await tariff.save();
          } catch (error: any) {
            if (error.code === 11000) {
              console.log(`  ⚠️  Tariff for ${role} already exists`);
              tariff = await TariffModel.findOne({
                managerId: manager._id,
                clientId: client._id,
                roleId: roleData.roleId
              });
              if (!tariff) {
                throw new Error(`Failed to find existing tariff after duplicate error: ${role}`);
              }
            } else {
              throw error;
            }
          }
        }

        this.tariffs.push({
          managerId: manager._id,
          clientId: client._id,
          roleId: roleData.roleId,
          roleName: role,
          rate: finalRate,
          currency: 'USD'
        });
      }
    }
    console.log(`  ✅ Created ${this.tariffs.length} tariff records`);
  }

  getEventsForMonth(year: number, month: number): number {
    const baseDate = new Date(year, month, 1);
    const monthsSinceStart = (baseDate.getTime() - START_DATE.getTime()) / (1000 * 60 * 60 * 24 * 30);

    if (monthsSinceStart < 3) {
      return 16 + Math.floor(Math.random() * 3); // Jan-Mar: 16-18 events
    } else if (monthsSinceStart < 8) {
      return 20 + Math.floor(Math.random() * 3); // Apr-Aug: 20-22 events
    } else {
      return 22 + Math.floor(Math.random() * 3); // Sep-Nov: 22-24 events
    }
  }

  generateMonthlyEvents(year: number, month: number): GeneratedEvent[] {
    const eventCount = this.getEventsForMonth(year, month);
    const monthlyEvents: GeneratedEvent[] = [];
    const daysInMonth = new Date(year, month + 1, 0).getDate();

    console.log(`  📅 Generating ${eventCount} events for ${year}-${month + 1}`);

    // Generate 4-6 shifts per week pattern
    for (let week = 0; week < 4; week++) {
      const weekStartDay = week * 7 + 1;

      // Friday evening
      if (Math.random() > 0.2) {
        monthlyEvents.push(this.generateSingleEvent(year, month, Math.min(weekStartDay + 4, daysInMonth), 'evening'));
      }

      // Saturday (possibly double shifts)
      if (Math.random() > 0.1) {
        monthlyEvents.push(this.generateSingleEvent(year, month, Math.min(weekStartDay + 5, daysInMonth), 'day'));

        // Evening shift on Saturday
        if (Math.random() > 0.3) {
          monthlyEvents.push(this.generateSingleEvent(year, month, Math.min(weekStartDay + 5, daysInMonth), 'evening'));
        }
      }

      // Sunday
      if (Math.random() > 0.15) {
        const sundayEvent = this.generateSingleEvent(year, month, Math.min(weekStartDay + 6, daysInMonth), 'day');
        if (sundayEvent) monthlyEvents.push(sundayEvent);
      }

      // 1-2 weekday shifts per week
      if (Math.random() > 0.3) {
        const weekdayEvent1 = this.generateSingleEvent(year, month, Math.min(weekStartDay + 2, daysInMonth), 'evening');
        if (weekdayEvent1) monthlyEvents.push(weekdayEvent1);
      }

      if (Math.random() > 0.7) {
        const weekdayEvent2 = this.generateSingleEvent(year, month, Math.min(weekStartDay + 3, daysInMonth), 'evening');
        if (weekdayEvent2) monthlyEvents.push(weekdayEvent2);
      }
    }

    return monthlyEvents.slice(0, eventCount);
  }

  generateSingleEvent(year: number, month: number, day: number, timeOfDay: 'day' | 'evening'): GeneratedEvent | null {
    const eventType = EVENT_TYPES[Math.floor(Math.random() * EVENT_TYPES.length)];
    const venue = VENUES[Math.floor(Math.random() * VENUES.length)];
    const client = this.clients[Math.floor(Math.random() * this.clients.length)];
    const manager = this.managers.find(m => m._id.equals(client.managerId))!;

    // Role distribution
    const roles = ['Server', 'Server', 'Bartender', 'Host', 'Server', 'Event Staff'];
    const selectedRoleName = roles[Math.floor(Math.random() * roles.length)];

    // Find the tariff with the proper ObjectId
    const tariff = this.tariffs.find(t =>
      t.managerId.equals(manager._id) &&
      t.clientId.equals(client._id) &&
      t.roleName === selectedRoleName
    )!;

    if (!tariff) {
      console.warn(`No tariff found for role ${selectedRoleName}, skipping event generation`);
      return null;
    }

    // Time generation
    let startHour = timeOfDay === 'day' ? 10 + Math.floor(Math.random() * 3) : 17 + Math.floor(Math.random() * 3);
    const startTime = `${startHour.toString().padStart(2, '0')}:00`;
    const endHour = startHour + eventType.duration;
    const endTime = `${(endHour % 24).toString().padStart(2, '0')}:00`;

    // Event date
    const eventDate = new Date(year, month, day);
    const createdDate = new Date(eventDate.getTime() - (Math.random() * 7 * 24 * 60 * 60 * 1000)); // Created 0-7 days before
    const fulfilledDate = new Date(eventDate.getTime() + (eventType.duration * 60 * 60 * 1000));

    // Clock in/out times (realistic variations)
    const clockInHour = startHour + Math.floor(Math.random() * 2) - 1; // Clock in 1 hour early to 1 hour late
    const clockOutHour = endHour + Math.floor(Math.random() * 2); // Clock out on time to 2 hours late
    const actualHours = eventType.duration + (Math.random() * 2 - 0.5); // Duration variation

    const clockInTime = new Date(eventDate);
    clockInTime.setHours(clockInHour, Math.floor(Math.random() * 60), 0, 0);

    const clockOutTime = new Date(eventDate);
    clockOutTime.setHours(clockOutHour % 24, Math.floor(Math.random() * 60), 0, 0);
    if (clockOutHour >= 24) {
      clockOutTime.setDate(clockOutTime.getDate() + 1);
    }

    return {
      managerId: manager._id,
      clientId: client._id,
      status: 'completed',
      date: eventDate,
      start_time: startTime,
      end_time: endTime,
      client_name: client.name,
      venue_name: venue.name,
      venue_address: venue.address,
      city: venue.city,
      state: venue.state,
      country: venue.country,
      shift_name: `${selectedRoleName} - ${eventType.type}`,
      contact_name: `Contact Person`,
      contact_phone: `+1-555-${Math.floor(Math.random() * 900000 + 100000).toString()}`,
      contact_email: `contact@${client.name.toLowerCase().replace(/\s+/g, '')}.com`,
      notes: `High-volume ${eventType.type} with professional service requirements.`,
      uniform: 'Black pants, white shirt, apron',
      headcount_total: 5 + Math.floor(Math.random() * 20),
      roles: [{ role: selectedRoleName, count: 1 }],
      accepted_staff: [{
        userKey: this.user.subject,
        provider: this.user.provider,
        subject: this.user.subject,
        email: this.user.email,
        name: this.user.name,
        role: selectedRoleName,
        respondedAt: new Date(createdDate.getTime() + Math.random() * 24 * 60 * 60 * 1000)
      }],
      attendance: [{
        userKey: this.user.subject,
        clockInAt: clockInTime,
        clockOutAt: clockOutTime,
        estimatedHours: actualHours
      }],
      hoursStatus: 'approved',
      approvedHours: actualHours,
      fulfilledAt: fulfilledDate,
      createdAt: createdDate
    };
  }

  async generateAllEvents(): Promise<void> {
    console.log('🎉 Generating all historical events...');

    let currentDate = new Date(START_DATE);

    while (currentDate < END_DATE) {
      const year = currentDate.getFullYear();
      const month = currentDate.getMonth();

      const monthlyEvents = this.generateMonthlyEvents(year, month);
      this.eventsGenerated.push(...monthlyEvents);

      currentDate.setMonth(currentDate.getMonth() + 1);
    }

    console.log(`✅ Generated ${this.eventsGenerated.length} total events`);
  }

  async saveEvents(): Promise<void> {
    console.log('💾 Saving events to database...');

    // Delete any existing events for this user to avoid duplicates
    await EventModel.deleteMany({
      'accepted_staff.userKey': this.user.subject
    });
    console.log('  🗑️ Cleared existing events for user');

    // Save in batches to avoid memory issues
    const batchSize = 100;
    let savedCount = 0;

    for (let i = 0; i < this.eventsGenerated.length; i += batchSize) {
      const batch = this.eventsGenerated.slice(i, i + batchSize);
      await EventModel.insertMany(batch);
      savedCount += batch.length;
      console.log(`  ✅ Saved ${savedCount}/${this.eventsGenerated.length} events`);
    }

    console.log(`✅ Successfully saved ${this.eventsGenerated.length} events`);
  }

  calculateTotalEarnings(): number {
    return this.eventsGenerated.reduce((total, event) => {
      const tariff = this.tariffs.find(t =>
        t.managerId.equals(event.managerId) &&
        t.clientId.equals(event.clientId) &&
        t.roleName === event.accepted_staff[0].role
      );
      return total + (event.approvedHours * (tariff?.rate || ROLE_RATES[event.accepted_staff[0].role as keyof typeof ROLE_RATES]));
    }, 0);
  }

  calculateTotalHours(): number {
    return this.eventsGenerated.reduce((total, event) => total + event.approvedHours, 0);
  }

  async generateReport(): Promise<void> {
    const totalEarnings = this.calculateTotalEarnings();
    const totalHours = this.calculateTotalHours();
    const averageHourlyRate = totalEarnings / totalHours;

    console.log('\n📊 HISTORICAL JOBS GENERATION REPORT');
    console.log('=====================================');
    console.log(`👤 User: ${this.user.name} (${this.user.email})`);
    console.log(`📅 Period: ${START_DATE.toLocaleDateString()} to ${END_DATE.toLocaleDateString()}`);
    console.log(`🎉 Total Events: ${this.eventsGenerated.length}`);
    console.log(`⏰ Total Hours: ${totalHours.toFixed(1)}`);
    console.log(`💰 Total Earnings: $${totalEarnings.toFixed(2)}`);
    console.log(`💵 Average Hourly Rate: $${averageHourlyRate.toFixed(2)}`);
    console.log(`📈 Average Events Per Month: ${(this.eventsGenerated.length / 11).toFixed(1)}`);

    console.log('\n📈 Monthly Breakdown:');
    const monthlyBreakdown = new Map<string, { events: number; hours: number; earnings: number }>();

    for (const event of this.eventsGenerated) {
      const monthKey = `${event.date.getFullYear()}-${(event.date.getMonth() + 1).toString().padStart(2, '0')}`;
      if (!monthlyBreakdown.has(monthKey)) {
        monthlyBreakdown.set(monthKey, { events: 0, hours: 0, earnings: 0 });
      }

      const month = monthlyBreakdown.get(monthKey)!;
      month.events++;
      month.hours += event.approvedHours;

      const tariff = this.tariffs.find(t =>
        t.managerId.equals(event.managerId) &&
        t.clientId.equals(event.clientId) &&
        t.roleName === event.accepted_staff[0].role
      );
      month.earnings += event.approvedHours * (tariff?.rate || ROLE_RATES[event.accepted_staff[0].role as keyof typeof ROLE_RATES]);
    }

    const sortedMonths = Array.from(monthlyBreakdown.keys()).sort();
    for (const month of sortedMonths) {
      const data = monthlyBreakdown.get(month)!;
      console.log(`  ${month}: ${data.events} events, ${data.hours.toFixed(1)}h, $${data.earnings.toFixed(2)}`);
    }

    console.log('\n✅ High-volume historical jobs generation completed successfully!');
  }

  async cleanup(): Promise<void> {
    await mongoose.disconnect();
    console.log('🔌 Database disconnected');
  }
}

async function main(): Promise<void> {
  const generator = new HistoricalJobsGenerator();

  try {
    await generator.initialize();
    await generator.verifyUser();
    await generator.createManagers();
    await generator.createClients();
    await generator.createRoles();
    await generator.createTariffs();
    await generator.generateAllEvents();
    await generator.saveEvents();
    await generator.generateReport();
    await generator.cleanup();
  } catch (error) {
    console.error('❌ Error generating historical jobs:', error);
    await generator.cleanup();
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}