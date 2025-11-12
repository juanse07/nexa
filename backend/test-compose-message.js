/**
 * Test script for /api/ai/staff/compose-message endpoint
 * Tests all scenarios: late, timeoff, question, custom, translate, polish
 */

const axios = require('axios');

const API_URL = 'http://localhost:3000/api/ai/staff/compose-message';

// You'll need a valid auth token - get it from your app or create a test user
const AUTH_TOKEN = 'YOUR_AUTH_TOKEN_HERE';

const testScenarios = [
  {
    name: '1. Running Late (English)',
    data: {
      scenario: 'late',
      context: {
        details: 'I will be 15 minutes late due to traffic',
        language: 'en'
      }
    }
  },
  {
    name: '2. Running Late (Spanish)',
    data: {
      scenario: 'late',
      context: {
        details: 'Llegaré 10 minutos tarde',
        language: 'es'
      }
    }
  },
  {
    name: '3. Time Off Request',
    data: {
      scenario: 'timeoff',
      context: {
        details: 'I need to request November 25-27 off for Thanksgiving',
        language: 'en'
      }
    }
  },
  {
    name: '4. Question About Shift',
    data: {
      scenario: 'question',
      context: {
        details: 'What is the dress code for tomorrow evening event?',
        language: 'en'
      }
    }
  },
  {
    name: '5. Custom Message',
    data: {
      scenario: 'custom',
      context: {
        message: 'I want to thank my manager for the great schedule this week',
        language: 'en'
      }
    }
  },
  {
    name: '6. Translate Spanish to English',
    data: {
      scenario: 'translate',
      context: {
        message: 'Hola, no podré asistir al evento de mañana porque tengo una emergencia familiar',
        language: 'auto'
      }
    }
  },
  {
    name: '7. Polish Unprofessional Message',
    data: {
      scenario: 'polish',
      context: {
        message: 'hey, cant make it tmrw, got stuff to do',
        language: 'en'
      }
    }
  }
];

async function testCompose() {
  console.log('🧪 Testing AI Message Composition Endpoint\n');
  console.log('=' .repeat(60));

  for (const test of testScenarios) {
    console.log(`\n📝 ${test.name}`);
    console.log('Input:', JSON.stringify(test.data, null, 2));

    try {
      const response = await axios.post(API_URL, test.data, {
        headers: {
          'Authorization': `Bearer ${AUTH_TOKEN}`,
          'Content-Type': 'application/json'
        },
        timeout: 15000
      });

      console.log('\n✅ Response:');
      console.log(`   Language: ${response.data.language}`);
      console.log(`   Original: "${response.data.original}"`);
      if (response.data.translation) {
        console.log(`   Translation: "${response.data.translation}"`);
      }

    } catch (error) {
      console.error('\n❌ Error:', error.response?.data || error.message);
    }

    console.log('\n' + '-'.repeat(60));
  }

  console.log('\n✨ Test complete!\n');
}

// Run tests
if (AUTH_TOKEN === 'YOUR_AUTH_TOKEN_HERE') {
  console.log('⚠️  Please set a valid AUTH_TOKEN in the script');
  console.log('   You can get this from your Flutter app or create a test user');
  process.exit(1);
}

testCompose().catch(console.error);
