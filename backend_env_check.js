#!/usr/bin/env node

/**
 * Backend Environment Variable Checker
 * Run this script on your backend server to verify Apple Sign In configuration
 *
 * Usage: node backend_env_check.js
 */

require('dotenv').config();

console.log('========================================');
console.log('Backend Environment Variables Check');
console.log('========================================\n');

const checks = [
  {
    name: 'PORT',
    required: true,
    value: process.env.PORT,
    expected: '4000 (or your configured port)',
  },
  {
    name: 'MONGO_URI',
    required: true,
    value: process.env.MONGO_URI,
    expected: 'mongodb+srv://...',
    hideValue: true,
  },
  {
    name: 'BACKEND_JWT_SECRET',
    required: true,
    value: process.env.BACKEND_JWT_SECRET,
    expected: 'A long random string',
    hideValue: true,
  },
  {
    name: 'APPLE_BUNDLE_ID',
    required: true,
    value: process.env.APPLE_BUNDLE_ID,
    expected: 'com.pymesoft.nexa',
  },
  {
    name: 'APPLE_SERVICE_ID',
    required: true,
    value: process.env.APPLE_SERVICE_ID,
    expected: 'com.pymesoft.nexa.web',
    critical: true, // This is the one causing your issue!
  },
  {
    name: 'GOOGLE_CLIENT_ID_WEB',
    required: false,
    value: process.env.GOOGLE_CLIENT_ID_WEB,
    expected: 'Your Google web client ID',
  },
  {
    name: 'GOOGLE_SERVER_CLIENT_ID',
    required: false,
    value: process.env.GOOGLE_SERVER_CLIENT_ID,
    expected: 'Your Google server client ID',
  },
];

let hasErrors = false;
let hasCriticalErrors = false;

checks.forEach(check => {
  const status = check.value ? '✅' : '❌';
  const displayValue = check.hideValue
    ? (check.value ? '[CONFIGURED]' : '[NOT SET]')
    : (check.value || '[NOT SET]');

  console.log(`${status} ${check.name}`);
  console.log(`   Value: ${displayValue}`);
  console.log(`   Expected: ${check.expected}`);

  if (!check.value && check.required) {
    console.log(`   ⚠️  WARNING: This variable is required!`);
    hasErrors = true;
    if (check.critical) {
      console.log(`   🚨 CRITICAL: This is causing your Apple Sign In to fail!`);
      hasCriticalErrors = true;
    }
  }

  console.log('');
});

console.log('========================================');
console.log('Summary');
console.log('========================================\n');

if (hasCriticalErrors) {
  console.log('🚨 CRITICAL ISSUES FOUND!');
  console.log('');
  console.log('Your APPLE_SERVICE_ID is not set.');
  console.log('This is why you\'re getting "Apple auth failed" errors.');
  console.log('');
  console.log('To fix:');
  console.log('1. Add this to your .env file:');
  console.log('   APPLE_SERVICE_ID=com.pymesoft.nexa.web');
  console.log('');
  console.log('2. Restart your backend server:');
  console.log('   pm2 restart all');
  console.log('   (or equivalent for your setup)');
  console.log('');
} else if (hasErrors) {
  console.log('⚠️  Some required variables are missing.');
  console.log('Please review the warnings above.');
  console.log('');
} else {
  console.log('✅ All required environment variables are set!');
  console.log('');
  console.log('Apple Sign In should work now.');
  console.log('If it still fails, check:');
  console.log('1. Backend server has been restarted');
  console.log('2. Apple Developer Console configuration');
  console.log('3. Backend logs for specific error details');
  console.log('');
}

// Parse and display Apple audience IDs like the backend does
const appleBundleIds = (process.env.APPLE_BUNDLE_ID || '').split(',').map(v => v.trim()).filter(Boolean);
const appleServiceIds = (process.env.APPLE_SERVICE_ID || '').split(',').map(v => v.trim()).filter(Boolean);
const appleAudienceIds = [...new Set([...appleBundleIds, ...appleServiceIds])];

console.log('========================================');
console.log('Parsed Apple Audience IDs');
console.log('========================================\n');
console.log('The backend will accept tokens with these audience values:');
if (appleAudienceIds.length === 0) {
  console.log('❌ NONE - This is the problem!');
} else {
  appleAudienceIds.forEach(id => {
    console.log(`  - ${id}`);
  });
}
console.log('');

console.log('For web sign-in to work, this list MUST include:');
console.log('  - com.pymesoft.nexa.web');
console.log('');

if (appleAudienceIds.includes('com.pymesoft.nexa.web')) {
  console.log('✅ Web Service ID is configured correctly!');
} else {
  console.log('❌ Web Service ID is MISSING!');
  console.log('   Add APPLE_SERVICE_ID=com.pymesoft.nexa.web to your .env');
}

console.log('');
