// Test script to check AI update format
const https = require('https');
const http = require('http');

// Simple fetch implementation
function fetch(url, options = {}) {
  return new Promise((resolve, reject) => {
    const urlObj = new URL(url);
    const protocol = urlObj.protocol === 'https:' ? https : http;

    const reqOptions = {
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.pathname + urlObj.search,
      method: options.method || 'GET',
      headers: options.headers || {}
    };

    const req = protocol.request(reqOptions, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        const response = {
          status: res.statusCode,
          statusText: res.statusMessage,
          data: data ? JSON.parse(data) : null
        };
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve(response);
        } else {
          const error = new Error(`HTTP ${res.statusCode}`);
          error.response = response;
          reject(error);
        }
      });
    });

    req.on('error', reject);

    if (options.body) {
      req.write(typeof options.body === 'string' ? options.body : JSON.stringify(options.body));
    }

    req.end();
  });
}

const JWT_TOKEN = process.env.JWT_TOKEN;
const BASE_URL = 'https://app.joinnexa.com';

async function testAIUpdate() {
  try {
    // First, get the list of events to find an event ID
    console.log('Fetching events...');
    const eventsResponse = await fetch(`${BASE_URL}/events`, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${JWT_TOKEN}`,
        'Accept': 'application/json'
      }
    });

    const events = eventsResponse.data.events || [];
    if (events.length === 0) {
      console.log('No events found');
      return;
    }

    const testEvent = events[0];
    console.log('\nTest Event:', {
      id: testEvent.id || testEvent._id,
      name: testEvent.event_name,
      date: testEvent.date
    });

    // Now simulate an AI update request
    const eventId = testEvent.id || testEvent._id;
    const eventName = testEvent.event_name;

    console.log('\n--- Testing AI Update ---');
    console.log('Sending message: "Update the headcount to 50 for', eventName, '"');

    const chatResponse = await fetch(
      `${BASE_URL}/ai/chat/message`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${JWT_TOKEN}`,
          'Content-Type': 'application/json'
        },
        body: {
          messages: [
            {
              role: 'system',
              content: `You help update events. When user wants to update an event, respond with "EVENT_UPDATE" followed by a JSON object:
{
  "eventId": "the event ID",
  "updates": {
    "field_name": "new_value"
  }
}

Available events:
- ID: ${eventId} | "${eventName}" | Date: ${testEvent.date}
`
            },
            {
              role: 'user',
              content: `Update the headcount to 50 for "${eventName}"`
            }
          ],
          temperature: 0.7,
          maxTokens: 500,
          provider: 'claude'
        }
      }
    );

    console.log('\nAI Response:');
    console.log(chatResponse.data.content);

    // Try to parse the EVENT_UPDATE
    const content = chatResponse.data.content;
    if (content.includes('EVENT_UPDATE')) {
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        const updateData = JSON.parse(jsonMatch[0]);
        console.log('\nParsed Update Data:');
        console.log(JSON.stringify(updateData, null, 2));

        // Now test the actual update
        console.log('\n--- Testing Backend Update ---');
        console.log('PATCH /events/' + updateData.eventId);
        console.log('Body:', updateData.updates);

        const updateResponse = await fetch(
          `${BASE_URL}/events/${updateData.eventId}`,
          {
            method: 'PATCH',
            headers: {
              'Authorization': `Bearer ${JWT_TOKEN}`,
              'Content-Type': 'application/json'
            },
            body: updateData.updates
          }
        );

        console.log('\n✓ Update successful!');
        console.log('Response:', {
          id: updateResponse.data.id || updateResponse.data._id,
          event_name: updateResponse.data.event_name,
          headcount_total: updateResponse.data.headcount_total
        });
      }
    }

  } catch (error) {
    if (error.response) {
      console.error('\n✗ Error:', error.response.status, error.response.statusText);
      console.error('Details:', error.response.data);
    } else {
      console.error('\n✗ Error:', error.message);
    }
  }
}

testAIUpdate();
