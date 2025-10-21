// Script to check and fix team membership for user google:112603799149919213350
const mongoose = require('mongoose');

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/nexa';

async function main() {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('Connected to MongoDB');

    const TeamMemberModel = mongoose.model('TeamMember', new mongoose.Schema({}, { strict: false, collection: 'team_members' }));

    // Find all team memberships for this user
    const memberships = await TeamMemberModel.find({
      provider: 'google',
      subject: '112603799149919213350'
    }).lean();

    console.log(`\nFound ${memberships.length} team membership(s):`);
    memberships.forEach((member, index) => {
      console.log(`\n[${index + 1}] Membership:`);
      console.log(`  _id: ${member._id}`);
      console.log(`  teamId: ${member.teamId}`);
      console.log(`  provider: ${member.provider}`);
      console.log(`  subject: ${member.subject}`);
      console.log(`  email: ${member.email}`);
      console.log(`  name: ${member.name}`);
      console.log(`  status: ${member.status}`);
      console.log(`  joinedAt: ${member.joinedAt}`);
      console.log(`  managerId: ${member.managerId}`);
    });

    // Check if any membership needs to be fixed (status not 'active')
    const inactiveMemberships = memberships.filter(m => m.status !== 'active');

    if (inactiveMemberships.length > 0) {
      console.log(`\n⚠️  Found ${inactiveMemberships.length} membership(s) with status other than 'active'`);

      for (const member of inactiveMemberships) {
        console.log(`\nFixing membership ${member._id}: changing status from '${member.status}' to 'active'`);
        await TeamMemberModel.updateOne(
          { _id: member._id },
          { $set: { status: 'active', updatedAt: new Date() } }
        );
        console.log('✅ Fixed!');
      }
    } else if (memberships.length === 0) {
      console.log('\n⚠️  No team memberships found for this user!');
      console.log('The team member record was not created during invite redemption.');
    } else {
      console.log('\n✅ All memberships are already active');
    }

    await mongoose.connection.close();
    console.log('\nDisconnected from MongoDB');
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

main();
