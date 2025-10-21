const axios = require('axios');

const API_URL = 'https://api.nexapymesoft.com';
const AUTH_TOKEN = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwMDE4NjEuNDdhZDAxODg4OGMyNDA1ZThjYWE4MDVmM2Q2OWU2NzEuMTc1MiIsInByb3ZpZGVyIjoiYXBwbGUiLCJlbWFpbCI6Imp1YW5zZWd6MDdzQGdtYWlsLmNvbSIsIm1hbmFnZXJJZCI6IjY4ZjA5ZmQ3YzI4ZGQxNzYwNmEzM2NiNSIsImlhdCI6MTc2MTAyODA3OCwiZXhwIjoxNzYxNjMyODc4fQ.iRLrQPgXrJKMmbyNCySweYK9alMypBCDjGuZeGJJw7A';

async function testAIChat() {
  try {
    // First get team members
    console.log('📋 Fetching team members...');
    const membersResponse = await axios.get(`${API_URL}/api/teams/68f5cd3ca683c8e8d5fac00c/members`, {
      headers: { Authorization: AUTH_TOKEN }
    });

    const members = membersResponse.data.members;
    console.log(`Found ${members.length} staff members\n`);

    // Test AI Chat
    console.log('🤖 Testing AI Chat with staff query...\n');
    const chatResponse = await axios.post(`${API_URL}/api/ai/chat/message`, {
      message: 'who are my staff make a list',
      context: {
        teams: [{
          id: '68f5cd3ca683c8e8d5fac00c',
          name: 'Mts',
          members: members
        }]
      }
    }, {
      headers: {
        Authorization: AUTH_TOKEN,
        'Content-Type': 'application/json'
      }
    });

    console.log('AI Response:');
    console.log(chatResponse.data.response);

  } catch (error) {
    console.error('Error:', error.response?.data || error.message);
  }
}

testAIChat();