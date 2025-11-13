"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const mongoose_1 = __importDefault(require("mongoose"));
const env_1 = require("../src/config/env");
const event_1 = require("../src/models/event");
/**
 * Fix Historical Events Status
 * Ensures all events for juan.2007@gmail.com have proper status field set
 */
const USER_EMAIL = 'juan.2007@gmail.com';
const USER_SUBJECT = 'google:112603799149919213350';
async function main() {
    console.log('🔧 Fixing historical events status...');
    try {
        // Connect to database
        if (!env_1.ENV.mongoUri) {
            throw new Error('MONGO_URI environment variable is required');
        }
        const dbName = env_1.ENV.nodeEnv === 'production' ? 'nexa_prod' : 'nexa_test';
        let uri = env_1.ENV.mongoUri.trim();
        if (uri.endsWith('/')) {
            uri = uri.slice(0, -1);
        }
        await mongoose_1.default.connect(`${uri}/${dbName}`);
        console.log(`✅ Connected to database: ${dbName}`);
        // Find all events for the user
        const userEvents = await event_1.EventModel.find({
            'accepted_staff.userKey': USER_SUBJECT
        });
        console.log(`📊 Found ${userEvents.length} events for ${USER_EMAIL}`);
        if (userEvents.length === 0) {
            // Try different userKey formats
            const altUserEvents = await event_1.EventModel.find({
                'accepted_staff.email': USER_EMAIL
            });
            console.log(`📊 Found ${altUserEvents.length} events with email ${USER_EMAIL}`);
            // Check all events to see what userKey formats exist
            const allUserEvents = await event_1.EventModel.find({
                'accepted_staff': { $exists: true, $ne: [] }
            }).limit(10);
            console.log('🔍 Sample accepted_staff formats:');
            allUserEvents.forEach((event, i) => {
                if (event.accepted_staff && event.accepted_staff.length > 0) {
                    const staff = event.accepted_staff[0];
                    console.log(`  Event ${i + 1}: userKey="${staff.userKey}", email="${staff.email}"`);
                }
            });
            return; // Exit early if no events found
        }
        let updatedCount = 0;
        const now = new Date();
        for (const event of userEvents) {
            let needsUpdate = false;
            // Check if status field exists and is valid
            if (!event.status) {
                // Set status based on date
                const eventDate = new Date(event.date);
                if (eventDate < now) {
                    event.status = 'completed';
                }
                else {
                    event.status = 'confirmed';
                }
                needsUpdate = true;
                console.log(`  📅 Setting status to '${event.status}' for event: ${event.shift_name} (${eventDate.toISOString().split('T')[0]})`);
            }
            // Ensure other required fields are present
            if (!event.createdAt) {
                event.createdAt = new Date(event.date);
                needsUpdate = true;
            }
            if (!event.fulfilledAt && event.status === 'completed') {
                const eventDate = new Date(event.date);
                event.fulfilledAt = new Date(eventDate.getTime() + (6 * 60 * 60 * 1000)); // 6 hours after event start
                needsUpdate = true;
            }
            if (needsUpdate) {
                await event.save();
                updatedCount++;
            }
        }
        console.log(`✅ Updated ${updatedCount} events with proper status`);
        // Summary by status
        const statusSummary = await event_1.EventModel.aggregate([
            { $match: { 'accepted_staff.userKey': USER_SUBJECT } },
            { $group: { _id: '$status', count: { $sum: 1 } } },
            { $sort: { count: -1 } }
        ]);
        console.log('\n📈 Status Summary:');
        for (const status of statusSummary) {
            console.log(`  ${status._id || 'undefined'}: ${status.count} events`);
        }
        // Check some sample events
        console.log('\n🔍 Sample Events:');
        const sampleEvents = await event_1.EventModel.find({
            'accepted_staff.userKey': USER_SUBJECT
        })
            .sort({ date: -1 })
            .limit(5)
            .select('date status shift_name attendance approvedHours hoursStatus');
        for (const event of sampleEvents) {
            const eventDate = new Date(event.date);
            const approvedHours = event.approvedHours || 0;
            console.log(`  ${eventDate.toISOString().split('T')[0]}: ${event.status} - ${event.shift_name} (${approvedHours}h)`);
        }
    }
    catch (error) {
        console.error('❌ Error fixing events:', error);
        throw error;
    }
    finally {
        await mongoose_1.default.disconnect();
        console.log('🔌 Database disconnected');
    }
}
if (require.main === module) {
    main();
}
//# sourceMappingURL=fix-historical-events-status.js.map