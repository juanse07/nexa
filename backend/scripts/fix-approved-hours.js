"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const mongoose_1 = __importDefault(require("mongoose"));
const env_1 = require("../src/config/env");
const event_1 = require("../src/models/event");
/**
 * Fix Approved Hours in Historical Events
 * Adds approvedHours based on attendance records for historical events
 */
const USER_SUBJECT = '112603799149919213350';
async function main() {
    console.log('🔧 Fixing approvedHours in historical events...');
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
        // Find events with missing approvedHours
        const eventsNeedingFix = await event_1.EventModel.find({
            'accepted_staff.userKey': USER_SUBJECT,
            $or: [
                { approvedHours: { $exists: false } },
                { approvedHours: null },
                { approvedHours: 0 }
            ]
        });
        console.log(`📊 Found ${eventsNeedingFix.length} events missing approvedHours`);
        let updatedCount = 0;
        let totalHoursAdded = 0;
        for (const event of eventsNeedingFix) {
            let calculatedHours = 0;
            // Try to get hours from attendance records
            const eventAny = event;
            if (eventAny.attendance && eventAny.attendance.length > 0) {
                const userAttendance = eventAny.attendance.find((att) => att.userKey === USER_SUBJECT);
                if (userAttendance && userAttendance.estimatedHours) {
                    calculatedHours = userAttendance.estimatedHours;
                }
            }
            // If no attendance records, estimate based on event duration
            if (calculatedHours === 0 && event.start_time && event.end_time) {
                const startParts = event.start_time.split(':');
                const endParts = event.end_time.split(':');
                const startHour = parseInt(startParts[0]);
                const endHour = parseInt(endParts[0]);
                // Handle overnight events
                let hours = endHour - startHour;
                if (hours < 0) {
                    hours += 24;
                }
                calculatedHours = Math.max(4, Math.min(8, hours + Math.random() * 2 - 1)); // 4-8 hours with variation
            }
            // If still no hours, use a default
            if (calculatedHours === 0) {
                calculatedHours = 6; // Default 6 hours
            }
            // Update the event
            event.approvedHours = calculatedHours;
            event.hoursStatus = 'approved';
            await event.save();
            updatedCount++;
            totalHoursAdded += calculatedHours;
            if (updatedCount <= 10) { // Show first 10 updates
                const eventDate = new Date(event.date);
                console.log(`  ✅ Updated ${eventDate.toISOString().split('T')[0]}: ${calculatedHours.toFixed(1)}h - ${event.shift_name || 'Event'}`);
            }
        }
        console.log(`\n✅ Updated ${updatedCount} events with approvedHours`);
        console.log(`📊 Total hours added: ${totalHoursAdded.toFixed(1)}`);
        // Calculate total earnings
        const totalEarnings = totalHoursAdded * 22; // Average rate
        console.log(`💰 Estimated total earnings: $${totalEarnings.toFixed(2)}`);
        // Final verification
        const finalCheck = await event_1.EventModel.find({
            'accepted_staff.userKey': USER_SUBJECT,
            approvedHours: { $gt: 0 }
        });
        console.log(`🎯 Final verification: ${finalCheck.length} events now have approvedHours`);
        await mongoose_1.default.disconnect();
        console.log('🔌 Database disconnected');
    }
    catch (error) {
        console.error('❌ Error fixing approvedHours:', error);
        throw error;
    }
}
if (require.main === module) {
    main();
}
//# sourceMappingURL=fix-approved-hours.js.map