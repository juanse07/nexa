const axios = require('axios');

// Configuration
const API_URL = 'https://api.nexapymesoft.com';
const AUTH_TOKEN = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwMDE4NjEuNDdhZDAxODg0OGMyNDA1ZThjYWE4MDVmM2Q2OWU2NzEuMTc1MiIsInByb3ZpZGVyIjoiYXBwbGUiLCJlbWFpbCI6Imp1YW5zZWd6MDdzQGdtYWlsLmNvbSIsIm1hbmFnZXJJZCI6IjY4ZjA5ZmQ3YzI4ZGQxNzYwNmEzM2NiNSIsImlhdCI6MTc2MTAyODA3OCwiZXhwIjoxNzYxNjMyODc4fQ.iRLrQPgXrJKMmbyNCySweYK9alMypBCDjGuZeGJJw7A';

async function setupTeamWithMembers() {
  try {
    console.log('🔍 Checking existing teams...');

    // Fetch existing teams
    const teamsResponse = await axios.get(`${API_URL}/api/teams`, {
      headers: { Authorization: AUTH_TOKEN }
    });

    console.log('Teams found:', teamsResponse.data.teams.length);

    if (teamsResponse.data.teams.length > 0) {
      console.log('\n📋 Existing teams:');
      teamsResponse.data.teams.forEach(team => {
        console.log(`  - ${team.name} (ID: ${team.id})`);
        console.log(`    Members: ${team.memberCount}, Pending Invites: ${team.pendingInvites}`);
      });

      // Check members for the first team
      const firstTeam = teamsResponse.data.teams[0];
      const membersResponse = await axios.get(`${API_URL}/api/teams/${firstTeam.id}/members`, {
        headers: { Authorization: AUTH_TOKEN }
      });

      console.log(`\n👥 Members in "${firstTeam.name}":`, membersResponse.data.members.length);
      if (membersResponse.data.members.length > 0) {
        membersResponse.data.members.forEach(member => {
          console.log(`  - ${member.name || member.email || 'Unknown'} (${member.provider}:${member.subject})`);
          console.log(`    Status: ${member.status}, Joined: ${member.joinedAt || 'Not yet'}`);
        });
      }
    } else {
      console.log('\n⚠️ No teams found. Creating a default team...');

      // Create a new team
      const createTeamResponse = await axios.post(`${API_URL}/api/teams`, {
        name: 'Default Team',
        description: 'Main team for staff management'
      }, {
        headers: {
          Authorization: AUTH_TOKEN,
          'Content-Type': 'application/json'
        }
      });

      console.log('✅ Team created successfully!');
      console.log('  Team ID:', createTeamResponse.data.id);
      console.log('  Team Name:', createTeamResponse.data.name);
    }

    // Instructions for adding members
    console.log('\n📝 To add staff members to your team:');
    console.log('1. Have staff members sign up/login to the staff app');
    console.log('2. Get their provider and subject ID from their authentication');
    console.log('3. Add them to the team using the API or invite them via email');
    console.log('\nExample API call to add a member:');
    console.log('POST /api/teams/{teamId}/members');
    console.log('Body: {');
    console.log('  "provider": "google",');
    console.log('  "subject": "user_google_id",');
    console.log('  "email": "staff@example.com",');
    console.log('  "name": "Staff Name"');
    console.log('}');

  } catch (error) {
    console.error('❌ Error:', error.response?.data || error.message);
    if (error.response?.status === 401) {
      console.error('Authentication token may be expired. Please get a fresh token.');
    }
  }
}

// Run the setup
setupTeamWithMembers();