import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

async function fixResponseField() {
  try {
    const mongoUri = process.env.MONGODB_URI;
    if (!mongoUri) {
      throw new Error('MONGODB_URI not found in environment');
    }

    await mongoose.connect(mongoUri);
    console.log('Connected to MongoDB');

    const db = mongoose.connection.db;
    if (!db) {
      throw new Error('Database connection not established');
    }

    // Update all events where accepted_staff has response: 'accepted'
    const result = await db.collection('events').updateMany(
      { 'accepted_staff.response': 'accepted' },
      { $set: { 'accepted_staff.$[elem].response': 'accept' } },
      { arrayFilters: [{ 'elem.response': 'accepted' }] }
    );

    console.log(`Updated ${result.modifiedCount} events`);
    console.log(`Matched ${result.matchedCount} events`);

    await mongoose.disconnect();
    console.log('Disconnected from MongoDB');
  } catch (error) {
    console.error('Error:', error);
    process.exit(1);
  }
}

fixResponseField();
