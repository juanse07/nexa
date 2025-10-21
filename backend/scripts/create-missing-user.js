// Script to create missing user record for google:112603799149919213350
const mongoose = require('mongoose');

const MONGODB_URI = process.env.MONGO_URI || process.env.MONGODB_URI || 'mongodb://localhost:27017/nexa';

async function main() {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log('Connected to MongoDB');

    const UserModel = mongoose.model('User', new mongoose.Schema({}, { strict: false, collection: 'users' }));

    // Check if user already exists
    const existingUser = await UserModel.findOne({
      provider: 'google',
      subject: '112603799149919213350'
    }).lean();

    if (existingUser) {
      console.log('\n✅ User record already exists:');
      console.log(`  _id: ${existingUser._id}`);
      console.log(`  provider: ${existingUser.provider}`);
      console.log(`  subject: ${existingUser.subject}`);
      console.log(`  email: ${existingUser.email}`);
      console.log(`  name: ${existingUser.name}`);
      console.log(`  first_name: ${existingUser.first_name}`);
      console.log(`  last_name: ${existingUser.last_name}`);
    } else {
      console.log('\n⚠️  User record does NOT exist. Creating now...');

      const newUser = await UserModel.create({
        provider: 'google',
        subject: '112603799149919213350',
        email: 'juan.2007@gmail.com',
        name: 'juan gomez',
        first_name: 'juan',
        last_name: 'gomez',
        createdAt: new Date(),
        updatedAt: new Date()
      });

      console.log('\n✅ User record created successfully!');
      console.log(`  _id: ${newUser._id}`);
      console.log(`  provider: ${newUser.provider}`);
      console.log(`  subject: ${newUser.subject}`);
      console.log(`  email: ${newUser.email}`);
      console.log(`  name: ${newUser.name}`);
      console.log(`  first_name: ${newUser.first_name}`);
      console.log(`  last_name: ${newUser.last_name}`);
    }

    // Verify user can be found by the chat lookup query
    const verifyUser = await UserModel.findOne({
      provider: 'google',
      subject: '112603799149919213350'
    }).lean();

    if (verifyUser) {
      console.log('\n✅ Verification successful! User can be found by chat queries.');
    } else {
      console.log('\n❌ Verification failed! User still cannot be found.');
    }

    await mongoose.connection.close();
    console.log('\nDisconnected from MongoDB');
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

main();
