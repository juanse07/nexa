import mongoose from 'mongoose';
import dotenv from 'dotenv';
import { UserModel } from '../src/models/user.js';

// Load environment variables
dotenv.config();

/**
 * Migration: Give existing free users a fresh 30-day free month from deploy date.
 *
 * - Finds all UserModel documents where subscription_tier != 'pro' and != 'premium'
 * - Sets free_month_end_override = now + 30 days
 * - Sets subscription_status = 'free_month'
 *
 * This ensures existing users aren't immediately locked into read-only mode
 * when the new subscription model deploys.
 */
async function migrateFreeMonth() {
  try {
    const mongoUri = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/test';
    const dbName = process.env.NODE_ENV === 'production' ? 'nexa_prod' : 'nexa_test';
    console.log(`Connecting to MongoDB (database: ${dbName})...`);
    await mongoose.connect(mongoUri, { dbName });
    console.log('Connected to MongoDB');

    // Count affected users first
    const affectedCount = await UserModel.countDocuments({
      subscription_tier: { $nin: ['pro', 'premium'] },
    });
    console.log(`Found ${affectedCount} non-pro users to migrate`);

    if (affectedCount === 0) {
      console.log('No users to migrate. Exiting.');
      await mongoose.disconnect();
      return;
    }

    // Set free_month_end_override to 30 days from now
    const freeMonthEnd = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    console.log(`Setting free_month_end_override to: ${freeMonthEnd.toISOString()}`);

    const result = await UserModel.updateMany(
      {
        subscription_tier: { $nin: ['pro', 'premium'] },
      },
      {
        $set: {
          free_month_end_override: freeMonthEnd,
          subscription_status: 'free_month',
        },
      }
    );

    console.log(`Migrated ${result.modifiedCount} users to free_month status`);
    console.log(`Free month expires: ${freeMonthEnd.toISOString()}`);

    await mongoose.disconnect();
    console.log('Done. Disconnected from MongoDB.');
  } catch (err) {
    console.error('Migration failed:', err);
    await mongoose.disconnect();
    process.exit(1);
  }
}

migrateFreeMonth();
