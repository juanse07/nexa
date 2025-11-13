"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const mongoose_1 = __importDefault(require("mongoose"));
const dotenv_1 = __importDefault(require("dotenv"));
const path_1 = __importDefault(require("path"));
// Load environment variables
dotenv_1.default.config({ path: path_1.default.resolve(__dirname, '../../.env') });
async function main() {
    const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/nexa';
    console.log('Connecting to MongoDB...');
    await mongoose_1.default.connect(MONGODB_URI);
    console.log('✅ Connected to MongoDB\n');
    const db = mongoose_1.default.connection.db;
    const eventsCollection = db.collection('events');
    const usersCollection = db.collection('users');
    // Get today's date
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const todayISO = today.toISOString().split('T')[0];
    // Count total events
    const totalEvents = await eventsCollection.countDocuments();
    console.log(`📊 Total events in database: ${totalEvents}`);
    // Count past events (date < today)
    const pastEventsCount = await eventsCollection.countDocuments({
        date: { $exists: true, $lt: todayISO }
    });
    console.log(`📅 Past events (date < ${todayISO}): ${pastEventsCount}`);
    // Count events with accepted_staff
    const eventsWithAcceptedStaff = await eventsCollection.countDocuments({
        accepted_staff: { $exists: true, $ne: [], $not: { $size: 0 } }
    });
    console.log(`👥 Events with accepted_staff: ${eventsWithAcceptedStaff}`);
    // Get sample event
    const sampleEvent = await eventsCollection.findOne({});
    if (sampleEvent) {
        console.log('\n📋 Sample event structure:');
        console.log(JSON.stringify({
            _id: sampleEvent._id,
            event_name: sampleEvent.event_name,
            date: sampleEvent.date,
            status: sampleEvent.status,
            accepted_staff: sampleEvent.accepted_staff,
            audience_user_keys: sampleEvent.audience_user_keys,
        }, null, 2));
    }
    // Get all unique userKeys from database
    console.log('\n🔑 Checking for users in the system...');
    const users = await usersCollection.find({}).limit(10).toArray();
    console.log(`Found ${users.length} users (showing first 10):`);
    users.forEach((user) => {
        const userKey = user.provider && user.subject ? `${user.provider}:${user.subject}` : 'unknown';
        console.log(`  - ${userKey} (${user.first_name} ${user.last_name})`);
    });
    // Check past events without accepted_staff
    const pastEventsNoStaff = await eventsCollection.find({
        date: { $exists: true, $lt: todayISO },
        $or: [
            { accepted_staff: { $exists: false } },
            { accepted_staff: { $eq: [] } },
            { accepted_staff: { $size: 0 } }
        ]
    }).limit(5).toArray();
    console.log(`\n⚠️  Past events WITHOUT accepted_staff: ${pastEventsNoStaff.length} (showing first 5)`);
    pastEventsNoStaff.forEach((evt) => {
        console.log(`  - ${evt.event_name} (${evt.date})`);
    });
    await mongoose_1.default.disconnect();
    console.log('\n✅ Done!');
}
main().catch(err => {
    console.error('Error:', err);
    process.exit(1);
});
//# sourceMappingURL=check-past-events.js.map