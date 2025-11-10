/**
 * Migration Script: Convert preferredCity to cities array
 *
 * This script migrates existing manager data from the old single-city structure
 * to the new multi-city structure:
 *
 * Before:
 * - preferredCity: "Denver, CO, USA"
 * - venueList: [{ name, address, city }]
 *
 * After:
 * - cities: [{ name: "Denver, CO, USA", isTourist: false }]
 * - venueList: [{ name, address, city, cityName: "Denver, CO, USA" }]
 *
 * Usage:
 *   npx ts-node src/scripts/migrate-cities.ts
 *   npx ts-node src/scripts/migrate-cities.ts --dry-run  # Test without saving
 */

import mongoose from 'mongoose';
import { ManagerModel } from '../models/manager';

const DRY_RUN = process.argv.includes('--dry-run');

async function migratePreferredCity() {
  try {
    // Connect to MongoDB
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/nexa';
    console.log(`[Migration] Connecting to MongoDB: ${mongoUri}`);
    await mongoose.connect(mongoUri);
    console.log('[Migration] Connected to MongoDB');

    // Find all managers with preferredCity but no cities array
    const managersToMigrate = await ManagerModel.find({
      preferredCity: { $exists: true, $ne: null },
      $or: [
        { cities: { $exists: false } },
        { cities: { $size: 0 } },
      ],
    });

    console.log(`\n[Migration] Found ${managersToMigrate.length} managers to migrate`);

    if (managersToMigrate.length === 0) {
      console.log('[Migration] No managers need migration. All done!');
      process.exit(0);
    }

    let successCount = 0;
    let errorCount = 0;

    for (const manager of managersToMigrate) {
      try {
        console.log(`\n[Migration] Processing manager: ${manager.email || manager._id}`);
        console.log(`  - Current preferredCity: ${manager.preferredCity}`);

        // Create cities array from preferredCity
        const cities = [
          {
            name: manager.preferredCity!,
            isTourist: false, // Default to metro area search
          },
        ];

        // Update venues to include cityName
        const updatedVenueList = (manager.venueList || []).map((venue) => ({
          name: venue.name,
          address: venue.address,
          city: venue.city,
          cityName: venue.cityName || manager.preferredCity!, // Add cityName if missing
          source: venue.source,
        }));

        console.log(`  - New cities array: ${JSON.stringify(cities)}`);
        console.log(`  - Updated ${updatedVenueList.length} venues with cityName`);

        if (DRY_RUN) {
          console.log('  - [DRY RUN] Would save changes (use without --dry-run to actually save)');
        } else {
          // Save changes
          manager.cities = cities;
          manager.venueList = updatedVenueList;
          await manager.save();
          console.log('  - ✅ Migration successful');
        }

        successCount++;
      } catch (error) {
        console.error(`  - ❌ Error migrating manager ${manager._id}:`, error);
        errorCount++;
      }
    }

    console.log('\n========================================');
    console.log('[Migration] Summary');
    console.log('========================================');
    console.log(`Total managers processed: ${managersToMigrate.length}`);
    console.log(`Successfully migrated: ${successCount}`);
    console.log(`Errors: ${errorCount}`);
    console.log(`Mode: ${DRY_RUN ? 'DRY RUN (no changes saved)' : 'LIVE (changes saved)'}`);
    console.log('========================================\n');

    if (DRY_RUN) {
      console.log('✨ Dry run complete! Run without --dry-run to apply changes.');
    } else {
      console.log('✨ Migration complete!');
    }

  } catch (error) {
    console.error('[Migration] Fatal error:', error);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
    console.log('[Migration] Disconnected from MongoDB');
  }
}

// Run migration
migratePreferredCity().catch((error) => {
  console.error('[Migration] Unhandled error:', error);
  process.exit(1);
});
