// Script to manually create team membership for user google:112603799149919213350
const mongoose = require('mongoose');

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/nexa';

async function main() {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('Connected to MongoDB');

    const TeamInviteModel = mongoose.model('TeamInvite', new mongoose.Schema({}, { strict: false, collection: 'team_invites' }));
    const TeamMemberModel = mongoose.model('TeamMember', new mongoose.Schema({}, { strict: false, collection: 'team_members' }));
    const TeamModel = mongoose.model('Team', new mongoose.Schema({}, { strict: false, collection: 'teams' }));

    // Find the CEHPCL invite
    const invite = await TeamInviteModel.findOne({
      shortCode: 'CEHPCL',
      inviteType: 'link'
    }).lean();

    if (!invite) {
      console.log('❌ Invite CEHPCL not found!');
      await mongoose.connection.close();
      return;
    }

    console.log('\n✅ Found invite:');
    console.log(`  Team ID: ${invite.teamId}`);
    console.log(`  Manager ID: ${invite.managerId}`);
    console.log(`  Status: ${invite.status}`);
    console.log(`  Used Count: ${invite.usedCount}`);

    // Get team info
    const team = await TeamModel.findById(invite.teamId).lean();
    if (!team) {
      console.log('❌ Team not found!');
      await mongoose.connection.close();
      return;
    }

    console.log(`\n✅ Team: ${team.name}`);

    // Check if member already exists
    const existingMember = await TeamMemberModel.findOne({
      teamId: invite.teamId,
      provider: 'google',
      subject: '112603799149919213350'
    }).lean();

    if (existingMember) {
      console.log('\n⚠️  Team member already exists:');
      console.log(`  Status: ${existingMember.status}`);
      console.log(`  Joined At: ${existingMember.joinedAt}`);

      if (existingMember.status !== 'active') {
        console.log('\n🔧 Updating status to "active"...');
        await TeamMemberModel.updateOne(
          { _id: existingMember._id },
          { $set: { status: 'active', updatedAt: new Date() } }
        );
        console.log('✅ Status updated to active!');
      }
    } else {
      console.log('\n🔧 Creating new team member...');

      const newMember = await TeamMemberModel.create({
        teamId: invite.teamId,
        managerId: invite.managerId,
        provider: 'google',
        subject: '112603799149919213350',
        email: 'juan.2007@gmail.com',
        name: 'juan gomez',
        status: 'active',
        joinedAt: new Date(),
        createdAt: new Date(),
        updatedAt: new Date()
      });

      console.log('✅ Team member created successfully!');
      console.log(`  Member ID: ${newMember._id}`);
      console.log(`  Status: ${newMember.status}`);
    }

    // Verify the member now shows up in query
    const verifyMember = await TeamMemberModel.findOne({
      provider: 'google',
      subject: '112603799149919213350',
      status: 'active'
    }).lean();

    if (verifyMember) {
      console.log('\n✅ Verification successful! Member can be found with active status.');
    } else {
      console.log('\n❌ Verification failed! Member still not found.');
    }

    await mongoose.connection.close();
    console.log('\nDisconnected from MongoDB');
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

main();
