const axios = require('axios');

// Configuration
const API_URL = 'https://api.nexapymesoft.com';
const AUTH_TOKEN = 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIwMDE4NjEuNDdhZDAxODg0OGMyNDA1ZThjYWE4MDVmM2Q2OWU2NzEuMTc1MiIsInByb3ZpZGVyIjoiYXBwbGUiLCJlbWFpbCI6Imp1YW5zZWd6MDdzQGdtYWlsLmNvbSIsIm1hbmFnZXJJZCI6IjY4ZjA5ZmQ3YzI4ZGQxNzYwNmEzM2NiNSIsImlhdCI6MTc2MTAyODA3OCwiZXhwIjoxNzYxNjMyODc4fQ.iRLrQPgXrJKMmbyNCySweYK9alMypBCDjGuZeGJJw7A';
const TEAM_ID = '68f5cd3ca683c8e8d5fac00c'; // Your "Mts" team

// Test staff members to add
const testStaffMembers = [
  {
    provider: 'test',
    subject: 'staff_001',
    email: 'john.doe@example.com',
    name: 'John Doe - Server'
  },
  {
    provider: 'test',
    subject: 'staff_002',
    email: 'jane.smith@example.com',
    name: 'Jane Smith - Bartender'
  },
  {
    provider: 'test',
    subject: 'staff_003',
    email: 'mike.wilson@example.com',
    name: 'Mike Wilson - Host'
  },
  {
    provider: 'test',
    subject: 'staff_004',
    email: 'sarah.johnson@example.com',
    name: 'Sarah Johnson - Server'
  },
  {
    provider: 'test',
    subject: 'staff_005',
    email: 'david.brown@example.com',
    name: 'David Brown - Bartender'
  }
];

async function addTestMembers() {
  console.log('🚀 Adding test staff members to your team...\n');

  for (const member of testStaffMembers) {
    try {
      const response = await axios.post(
        `${API_URL}/api/teams/${TEAM_ID}/members`,
        member,
        {
          headers: {
            Authorization: AUTH_TOKEN,
            'Content-Type': 'application/json'
          }
        }
      );

      console.log(`✅ Added: ${member.name}`);
      console.log(`   Email: ${member.email}`);
      console.log(`   ID: ${response.data.id}\n`);
    } catch (error) {
      if (error.response?.status === 409) {
        console.log(`⏭️  Skipped: ${member.name} (already exists)\n`);
      } else {
        console.error(`❌ Failed to add ${member.name}:`, error.response?.data || error.message);
      }
    }
  }

  // Verify the members were added
  try {
    console.log('\n📋 Verifying team members...');
    const membersResponse = await axios.get(`${API_URL}/api/teams/${TEAM_ID}/members`, {
      headers: { Authorization: AUTH_TOKEN }
    });

    console.log(`\nTotal members in team: ${membersResponse.data.members.length}`);
    membersResponse.data.members.forEach(member => {
      console.log(`  ✓ ${member.name || member.email} - ${member.status}`);
    });

    console.log('\n🎉 Test staff members have been added successfully!');
    console.log('You should now be able to see them in your app.');
  } catch (error) {
    console.error('Failed to verify members:', error.response?.data || error.message);
  }
}

// Run the script
addTestMembers();