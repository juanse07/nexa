/**
 * Create Test Users for Load Testing
 *
 * This script creates test user records in your database that can be used
 * for concurrent acceptance testing.
 */

require('dotenv').config();
const mongoose = require('mongoose');

const NUM_TEST_USERS = parseInt(process.env.NUM_TEST_USERS) || 100;

async function createTestUsers() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/nexa');
    console.log('✅ Connected to MongoDB\n');

    // Get or create User model
    const UserSchema = new mongoose.Schema({
      provider: String,
      subject: String,
      email: String,
      name: String,
      first_name: String,
      last_name: String,
      picture: String,
      phone_number: String,
      app_id: String,
    }, { timestamps: true });

    const User = mongoose.models.User || mongoose.model('User', UserSchema);

    console.log(`Creating ${NUM_TEST_USERS} test users...`);

    const testUsers = [];
    for (let i = 1; i <= NUM_TEST_USERS; i++) {
      testUsers.push({
        provider: 'google',
        subject: `test-user-${i}`,
        email: `testuser${i}@loadtest.example.com`,
        name: `Test User ${i}`,
        first_name: `Test`,
        last_name: `User${i}`,
        app_id: 'staff',
      });
    }

    // Insert or update test users
    const operations = testUsers.map(user => ({
      updateOne: {
        filter: { provider: user.provider, subject: user.subject },
        update: { $set: user },
        upsert: true,
      }
    }));

    const result = await User.bulkWrite(operations);

    console.log(`✅ Created/Updated ${result.upsertedCount + result.modifiedCount} test users`);
    console.log(`\nTest user credentials (userKey format):`);
    console.log(`  google:test-user-1`);
    console.log(`  google:test-user-2`);
    console.log(`  ...`);
    console.log(`  google:test-user-${NUM_TEST_USERS}`);

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
  }
}

createTestUsers();
