/**
 * Jest setup file for MongoDB Memory Server
 * This file runs before all tests to set up an in-memory MongoDB instance
 */

import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';

let mongoServer: MongoMemoryServer;

// Setup before all tests
beforeAll(async () => {
  // Close any existing connections
  if (mongoose.connection.readyState !== 0) {
    await mongoose.disconnect();
  }

  // Create in-memory MongoDB server
  mongoServer = await MongoMemoryServer.create();
  const mongoUri = mongoServer.getUri();

  // Connect to the in-memory database
  await mongoose.connect(mongoUri);

  console.log('✅ MongoDB Memory Server connected');
});

// Cleanup after all tests
afterAll(async () => {
  // Disconnect from the in-memory database
  await mongoose.disconnect();

  // Stop the in-memory MongoDB server
  if (mongoServer) {
    await mongoServer.stop();
  }

  console.log('✅ MongoDB Memory Server stopped');
});

// Clear all collections after each test
afterEach(async () => {
  const collections = mongoose.connection.collections;

  for (const key in collections) {
    const collection = collections[key];
    await collection.deleteMany({});
  }
});
