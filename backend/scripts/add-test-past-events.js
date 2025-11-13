"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const mongoose_1 = __importDefault(require("mongoose"));
// This script adds test past events to production MongoDB
// Run with: docker exec nexa-api node dist/scripts/add-test-past-events.js
async function main() {
    const MONGO_URI = process.env.MONGO_URI;
    if (!MONGO_URI) {
        console.error('❌ MONGO_URI environment variable not found');
        process.exit(1);
    }
    console.log('🔌 Connecting to MongoDB...');
    await mongoose_1.default.connect(MONGO_URI);
    console.log('✅ Connected!\n');
    const db = mongoose_1.default.connection.db;
    const eventsCollection = db.collection('events');
    const usersCollection = db.collection('users');
    // Get first user to use as test staff member
    const firstUser = await usersCollection.findOne({});
    if (!firstUser) {
        console.error('❌ No users found in database. Please create a user first.');
        await mongoose_1.default.disconnect();
        process.exit(1);
    }
    const userKey = firstUser.provider && firstUser.subject
        ? `${firstUser.provider}:${firstUser.subject}`
        : null;
    if (!userKey) {
        console.error('❌ User does not have provider/subject fields');
        await mongoose_1.default.disconnect();
        process.exit(1);
    }
    console.log(`📝 Using test user: ${userKey} (${firstUser.first_name} ${firstUser.last_name})\n`);
    // Create 10 test past events
    const testEvents = [];
    const today = new Date();
    for (let i = 1; i <= 10; i++) {
        // Create dates going back 1-10 days
        const eventDate = new Date(today);
        eventDate.setDate(eventDate.getDate() - i);
        const dateStr = eventDate.toISOString().split('T')[0]; // YYYY-MM-DD format
        testEvents.push({
            event_name: `Test Past Event ${i}`,
            client_name: `Test Client ${i}`,
            venue_name: `Test Venue ${i}`,
            venue_address: `123 Test St, City ${i}`,
            date: dateStr,
            status: 'published',
            visibilityType: 'public',
            accepted_staff: [
                {
                    userKey: userKey,
                    role: `Test Role ${i}`,
                    response: 'accepted',
                    respondedAt: new Date(eventDate.getTime() - 24 * 60 * 60 * 1000).toISOString(), // 1 day before event
                }
            ],
            audience_user_keys: [],
            audience_team_ids: [],
            createdAt: new Date(),
            updatedAt: new Date(),
        });
    }
    console.log(`📥 Inserting ${testEvents.length} test past events...`);
    const result = await eventsCollection.insertMany(testEvents);
    console.log(`✅ Inserted ${result.insertedCount} events\n`);
    // Verify
    const totalEvents = await eventsCollection.countDocuments();
    const pastEvents = await eventsCollection.countDocuments({
        date: { $lt: new Date().toISOString().split('T')[0] }
    });
    const userEvents = await eventsCollection.countDocuments({
        'accepted_staff.userKey': userKey
    });
    console.log('📊 Database Summary:');
    console.log(`  Total events: ${totalEvents}`);
    console.log(`  Past events: ${pastEvents}`);
    console.log(`  Events for ${userKey}: ${userEvents}`);
    await mongoose_1.default.disconnect();
    console.log('\n✅ Done! You should now see past events in the staff app.');
}
main().catch(err => {
    console.error('❌ Error:', err);
    process.exit(1);
});
//# sourceMappingURL=add-test-past-events.js.map