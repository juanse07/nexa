/**
 * Add Test Users to a Team
 *
 * This script adds all test users to a specified team so they can
 * receive team-based event invitations.
 */

require('dotenv').config();
const mongoose = require('mongoose');

const TEAM_ID = process.env.TEAM_ID || '';

async function addUsersToTeam() {
  try {
    if (!TEAM_ID) {
      console.error('❌ ERROR: TEAM_ID not set!');
      console.error('\nUsage:');
      console.error('  TEAM_ID=your-team-id node scripts/add-test-users-to-team.js\n');
      process.exit(1);
    }

    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/nexa');
    console.log('✅ Connected to MongoDB\n');

    const TeamSchema = new mongoose.Schema({}, { strict: false });
    const Team = mongoose.models.Team || mongoose.model('Team', TeamSchema);

    const UserSchema = new mongoose.Schema({}, { strict: false });
    const User = mongoose.models.User || mongoose.model('User', UserSchema);

    // Get the team
    const team = await Team.findById(TEAM_ID);
    if (!team) {
      console.error(`❌ Team not found: ${TEAM_ID}`);
      process.exit(1);
    }

    console.log(`Found team: ${team.name || 'Unnamed Team'}`);

    // Get all test users
    const testUsers = await User.find({
      email: /loadtest\.example\.com/
    });

    console.log(`Found ${testUsers.length} test users`);

    // Add test users to team
    const userKeys = testUsers.map(u => `${u.provider}:${u.subject}`);

    const result = await Team.updateOne(
      { _id: TEAM_ID },
      { $addToSet: { member_user_keys: { $each: userKeys } } }
    );

    console.log(`\n✅ Added ${testUsers.length} test users to team`);
    console.log(`   Team ID: ${TEAM_ID}`);
    console.log(`   Team Name: ${team.name || 'Unnamed Team'}`);

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
  }
}

addUsersToTeam();
