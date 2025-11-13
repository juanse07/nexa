"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
const mongoose_1 = __importDefault(require("mongoose"));
// Script to add tariff data to roles in existing events
// Earnings calculation requires tariff.rate in each role
// Run with: MONGO_URI=... node dist/scripts/add-tariffs-to-events.js
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
    const shiftsCollection = db.collection('shifts');
    const userKey = 'google:112603799149919213350';
    console.log(`📝 Adding tariff data to roles for user's events\n`);
    // Find all events for this user
    const events = await shiftsCollection.find({
        'accepted_staff.userKey': userKey,
    }).toArray();
    console.log(`Found ${events.length} events`);
    let updatedCount = 0;
    for (const event of events) {
        // Extract hourly rate from pay_rate_info (e.g., "$21/hour")
        const payRateInfo = event.pay_rate_info || '';
        const rateMatch = payRateInfo.match(/\$(\d+)/);
        const hourlyRate = rateMatch ? parseFloat(rateMatch[1]) : 25.0; // Default to $25 if not found
        // Check if roles already have tariff data
        const rolesHaveTariff = event.roles?.some((r) => r.tariff);
        if (rolesHaveTariff) {
            continue; // Skip if already has tariffs
        }
        // Add tariff data to each role
        const updatedRoles = event.roles?.map((role) => ({
            ...role,
            tariff: {
                rate: hourlyRate,
                currency: 'USD',
                rateDisplay: `USD ${hourlyRate.toFixed(2)}/hr`,
            },
        })) || [];
        // Update the event
        await shiftsCollection.updateOne({ _id: event._id }, { $set: { roles: updatedRoles } });
        updatedCount++;
    }
    console.log(`\n✅ Updated ${updatedCount} events with tariff data`);
    console.log(`⏭️  Skipped ${events.length - updatedCount} events (already had tariffs)`);
    // Verify
    const sample = await shiftsCollection.findOne({
        'accepted_staff.userKey': userKey,
    });
    console.log(`\n📊 Sample event after update:`);
    console.log(`  Event: ${sample.event_name || sample.shift_name}`);
    console.log(`  Roles:`);
    sample.roles?.forEach((role) => {
        console.log(`    - ${role.role} (count: ${role.count})`);
        if (role.tariff) {
            console.log(`      Tariff: ${role.tariff.rateDisplay}`);
        }
    });
    await mongoose_1.default.disconnect();
    console.log('\n✅ Done! Events should now show earnings correctly.');
}
main().catch((err) => {
    console.error('❌ Error:', err);
    process.exit(1);
});
//# sourceMappingURL=add-tariffs-to-events.js.map