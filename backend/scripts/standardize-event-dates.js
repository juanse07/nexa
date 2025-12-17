"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const mongoose_1 = __importDefault(require("mongoose"));
const dotenv_1 = __importDefault(require("dotenv"));
const event_1 = require("../src/models/event");
// Load environment variables
dotenv_1.default.config();
/**
 * Standardize all event dates to Date objects
 * Converts any string dates (e.g., '2025-10-15') to proper Date objects
 * This ensures consistency with what the app produces
 */
async function standardizeEventDates() {
    try {
        // Connect to MongoDB
        const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/test';
        console.log('Connecting to MongoDB...');
        await mongoose_1.default.connect(mongoUri);
        console.log('✅ Connected to MongoDB');
        // Find all events with string dates
        const allEvents = await event_1.EventModel.find({}).lean();
        console.log(`\n📊 Found ${allEvents.length} total events`);
        let stringDateCount = 0;
        let dateObjectCount = 0;
        let nullDateCount = 0;
        let convertedCount = 0;
        // Analyze current state
        for (const event of allEvents) {
            if (event.date == null) {
                nullDateCount++;
            }
            else if (typeof event.date === 'string') {
                stringDateCount++;
            }
            else if (event.date instanceof Date) {
                dateObjectCount++;
            }
        }
        console.log('\n📋 Current State:');
        console.log(`   String dates: ${stringDateCount}`);
        console.log(`   Date objects: ${dateObjectCount}`);
        console.log(`   Null/undefined: ${nullDateCount}`);
        if (stringDateCount === 0) {
            console.log('\n✅ All dates are already standardized as Date objects!');
            await mongoose_1.default.disconnect();
            process.exit(0);
        }
        console.log('\n🔧 Converting string dates to Date objects...');
        // Convert all string dates to Date objects
        for (const event of allEvents) {
            if (event.date != null && typeof event.date === 'string') {
                try {
                    // Convert string to Date object
                    const dateObj = new Date(event.date);
                    // Validate the date is valid
                    if (isNaN(dateObj.getTime())) {
                        console.log(`   ⚠️ Skipping invalid date for event ${event._id}: ${event.date}`);
                        continue;
                    }
                    // Update the event
                    await event_1.EventModel.updateOne({ _id: event._id }, { $set: { date: dateObj } });
                    convertedCount++;
                    if (convertedCount % 10 === 0) {
                        console.log(`   ✅ Converted ${convertedCount}/${stringDateCount} dates...`);
                    }
                }
                catch (err) {
                    console.error(`   ❌ Error converting date for event ${event._id}:`, err);
                }
            }
        }
        console.log(`\n✅ Conversion complete!`);
        console.log(`   Successfully converted: ${convertedCount} dates`);
        console.log(`   Failed: ${stringDateCount - convertedCount} dates`);
        // Verify the fix
        console.log('\n🔍 Verifying results...');
        const updatedEvents = await event_1.EventModel.find({}).lean();
        let finalStringCount = 0;
        let finalDateObjectCount = 0;
        let finalNullCount = 0;
        for (const event of updatedEvents) {
            if (event.date == null) {
                finalNullCount++;
            }
            else if (typeof event.date === 'string') {
                finalStringCount++;
            }
            else if (event.date instanceof Date) {
                finalDateObjectCount++;
            }
        }
        console.log('\n📋 Final State:');
        console.log(`   String dates: ${finalStringCount}`);
        console.log(`   Date objects: ${finalDateObjectCount}`);
        console.log(`   Null/undefined: ${finalNullCount}`);
        // Show some sample dates
        const sampleEvents = await event_1.EventModel.find({ date: { $ne: null } }).limit(5).lean();
        console.log('\n📅 Sample dates (first 5):');
        for (const event of sampleEvents) {
            console.log(`   - ${event.shift_name || 'Unnamed'}: ${event.date} (type: ${typeof event.date})`);
        }
        console.log('\n✅ Migration complete!');
    }
    catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    }
    finally {
        await mongoose_1.default.disconnect();
        console.log('\n✅ Disconnected from MongoDB');
        process.exit(0);
    }
}
// Run the script
standardizeEventDates();
//# sourceMappingURL=standardize-event-dates.js.map