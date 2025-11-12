import mongoose from 'mongoose';
import { UserModel } from '../models/user';
import * as dotenv from 'dotenv';

dotenv.config();

/**
 * Script to reset AI message limits for all users
 * This sets ai_messages_used_this_month to 0 for all users
 */
async function resetMessageLimits() {
  try {
    const mongoUri = process.env.MONGO_URI;
    if (!mongoUri) {
      throw new Error('MONGO_URI not found in environment');
    }

    console.log('Connecting to MongoDB...');
    await mongoose.connect(mongoUri);
    console.log('Connected to MongoDB');

    // Find all users with message usage > 0
    const usersWithMessages = await UserModel.find({
      ai_messages_used_this_month: { $gt: 0 }
    });

    console.log(`Found ${usersWithMessages.length} users with message usage to reset`);

    if (usersWithMessages.length === 0) {
      console.log('No users to reset. All users already have 0 messages used.');
      await mongoose.connection.close();
      return;
    }

    // Show current state before reset
    console.log('\nCurrent usage:');
    for (const user of usersWithMessages) {
      console.log(`  User ${user._id} (${user.email || user.name}): ${user.ai_messages_used_this_month} messages`);
    }

    // Update all users to reset their message count
    const result = await UserModel.updateMany(
      {}, // All users
      {
        $set: {
          ai_messages_used_this_month: 0
        }
      }
    );

    console.log(`\n✅ Reset complete!`);
    console.log(`   Modified ${result.modifiedCount} user(s)`);
    console.log(`   All users now have 0 AI messages used this month`);

    // Verify the reset
    const verifyUsers = await UserModel.find({
      _id: { $in: usersWithMessages.map(u => u._id) }
    });

    console.log('\nVerification:');
    for (const user of verifyUsers) {
      console.log(`  User ${user._id}: ${user.ai_messages_used_this_month} messages (reset date: ${user.ai_messages_reset_date?.toISOString()})`);
    }

    await mongoose.connection.close();
    console.log('\nDatabase connection closed');

  } catch (error) {
    console.error('Error resetting message limits:', error);
    process.exit(1);
  }
}

// Run the script
resetMessageLimits();
