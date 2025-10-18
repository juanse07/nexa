/**
 * Script to check and fix conversations that might be missing managerId
 *
 * LOCAL USAGE:
 *   npx ts-node src/scripts/fix-conversations.ts
 *
 * PRODUCTION USAGE (on server):
 *   1. SSH into your server
 *   2. Navigate to your backend directory
 *   3. Run: npx ts-node src/scripts/fix-conversations.ts
 *
 * This script will:
 * - Find all conversations with missing or null managerId
 * - Try to recover the managerId from the first message in the conversation
 * - Update the conversation with the recovered managerId
 * - Report how many were fixed and how many couldn't be fixed
 */

import mongoose from 'mongoose';
import { config } from 'dotenv';
import { ConversationModel } from '../models/conversation';
import { ChatMessageModel } from '../models/chatMessage';

config();

async function fixConversations() {
  try {
    // Connect to MongoDB
    const mongoUri = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/nexa';
    await mongoose.connect(mongoUri);
    console.log('Connected to MongoDB');

    // Find all conversations
    const conversations = await ConversationModel.find({}).lean();
    console.log(`Found ${conversations.length} conversations`);

    let fixedCount = 0;
    let invalidCount = 0;

    for (const conv of conversations) {
      console.log(`\nConversation ${conv._id}:`);
      console.log(`  managerId: ${conv.managerId} (type: ${typeof conv.managerId})`);
      console.log(`  userKey: ${conv.userKey}`);

      if (!conv.managerId) {
        console.log(`  ❌ Missing managerId!`);
        invalidCount++;

        // Try to find managerId from messages
        const message = await ChatMessageModel.findOne({
          conversationId: conv._id
        }).lean();

        if (message && message.managerId) {
          console.log(`  ✓ Found managerId from message: ${message.managerId}`);
          await ConversationModel.updateOne(
            { _id: conv._id },
            { $set: { managerId: message.managerId } }
          );
          fixedCount++;
          console.log(`  ✓ Fixed!`);
        } else {
          console.log(`  ✗ Cannot fix - no messages found`);
        }
      } else {
        console.log(`  ✓ OK`);
      }
    }

    console.log(`\n=== Summary ===`);
    console.log(`Total conversations: ${conversations.length}`);
    console.log(`Invalid (missing managerId): ${invalidCount}`);
    console.log(`Fixed: ${fixedCount}`);
    console.log(`Unable to fix: ${invalidCount - fixedCount}`);

    await mongoose.disconnect();
    console.log('\nDisconnected from MongoDB');
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

fixConversations();
