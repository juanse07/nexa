/**
 * Script to rebuild notification collection indexes
 * Run this after deleting the notifications collection to restore indexes
 */

import { connectToDatabase } from '../db/mongoose';
import { NotificationModel } from '../models/notification';

async function rebuildNotificationIndexes() {
  try {
    console.log('🔧 Connecting to database...');
    await connectToDatabase();
    console.log('✅ Connected to database');

    console.log('🔧 Dropping existing indexes (if any)...');
    try {
      await NotificationModel.collection.dropIndexes();
      console.log('✅ Existing indexes dropped');
    } catch (error: any) {
      if (error.code === 26) {
        // NamespaceNotFound error - collection doesn't exist yet, that's fine
        console.log('ℹ️  Collection doesn\'t exist yet (will be created on first insert)');
      } else {
        console.log('⚠️  Note: Could not drop indexes:', error.message);
      }
    }

    console.log('🔧 Rebuilding indexes from schema...');
    await NotificationModel.syncIndexes();
    console.log('✅ Indexes rebuilt successfully!');

    console.log('\n📋 Current indexes:');
    const indexes = await NotificationModel.collection.indexes();
    indexes.forEach((index, i) => {
      console.log(`  ${i + 1}. ${JSON.stringify(index.key)} - ${index.name || 'unnamed'}`);
      if (index.expireAfterSeconds) {
        console.log(`     → TTL: ${index.expireAfterSeconds} seconds (${index.expireAfterSeconds / 86400} days)`);
      }
    });

    console.log('\n✅ Notification indexes are now ready!');
    process.exit(0);
  } catch (error) {
    console.error('❌ Failed to rebuild indexes:', error);
    process.exit(1);
  }
}

rebuildNotificationIndexes();
