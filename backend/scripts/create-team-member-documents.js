/**
 * Create TeamMember Documents for Test Users
 *
 * This creates proper TeamMember documents in the teammembers collection
 * so test users can receive events.
 */

require('dotenv').config();
const mongoose = require('mongoose');

const TEAM_ID = process.env.TEAM_ID || '6907fa71ec68bd830b060a9d';

async function createTeamMemberDocuments() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/nexa');
    console.log('✅ Connected to MongoDB\n');

    // Define schemas
    const TeamMemberSchema = new mongoose.Schema({
      teamId: mongoose.Schema.Types.ObjectId,
      managerId: mongoose.Schema.Types.ObjectId,
      provider: String,
      subject: String,
      email: String,
      name: String,
      invitedBy: mongoose.Schema.Types.ObjectId,
      joinedAt: Date,
      status: String,
    }, { timestamps: true });

    const TeamSchema = new mongoose.Schema({}, { strict: false });
    const UserSchema = new mongoose.Schema({}, { strict: false });

    const TeamMember = mongoose.models.TeamMember || mongoose.model('TeamMember', TeamMemberSchema);
    const Team = mongoose.models.Team || mongoose.model('Team', TeamSchema);
    const User = mongoose.models.User || mongoose.model('User', UserSchema);

    // Get the team
    const team = await Team.findById(TEAM_ID);
    if (!team) {
      console.error(`❌ Team not found: ${TEAM_ID}`);
      process.exit(1);
    }

    console.log(`Found team: ${team.name || 'Unnamed'}`);
    console.log(`Manager ID: ${team.managerId}`);

    // Get all test users
    const testUsers = await User.find({
      email: /loadtest\.example\.com/
    });

    console.log(`Found ${testUsers.length} test users\n`);

    // Create TeamMember documents
    console.log('Creating TeamMember documents...');

    const operations = [];
    for (const user of testUsers) {
      operations.push({
        updateOne: {
          filter: {
            teamId: new mongoose.Types.ObjectId(TEAM_ID),
            provider: user.provider,
            subject: user.subject,
          },
          update: {
            $set: {
              teamId: new mongoose.Types.ObjectId(TEAM_ID),
              managerId: team.managerId,
              provider: user.provider,
              subject: user.subject,
              email: user.email,
              name: user.name,
              status: 'active',
              joinedAt: new Date(),
            }
          },
          upsert: true,
        }
      });
    }

    const result = await TeamMember.bulkWrite(operations);

    console.log('\n✅ TeamMember documents created!');
    console.log(`   Inserted: ${result.upsertedCount}`);
    console.log(`   Modified: ${result.modifiedCount}`);
    console.log(`   Total: ${result.upsertedCount + result.modifiedCount}`);

    // Verify
    const count = await TeamMember.countDocuments({ teamId: TEAM_ID });
    console.log(`\n📊 Total team members in database: ${count}`);

  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  } finally {
    await mongoose.disconnect();
  }
}

createTeamMemberDocuments();
