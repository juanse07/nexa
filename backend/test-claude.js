const axios = require('axios');

async function testClaude() {
  const claudeKey = process.env.CLAUDE_API_KEY;

  if (!claudeKey) {
    console.error('Please set CLAUDE_API_KEY environment variable');
    process.exit(1);
  }

  const requestBody = {
    model: 'claude-3-5-sonnet-20240620',
    max_tokens: 100,
    temperature: 0.7,
    system: 'You are a helpful AI assistant.',
    messages: [
      {
        role: 'user',
        content: 'Say hello and tell me the current date in a short message.'
      }
    ]
  };

  const headers = {
    'x-api-key': claudeKey,
    'anthropic-version': '2023-06-01',
    'Content-Type': 'application/json',
  };

  try {
    console.log('Testing Claude API with model:', requestBody.model);
    console.log('Making request to: https://api.anthropic.com/v1/messages');

    const response = await axios.post(
      'https://api.anthropic.com/v1/messages',
      requestBody,
      { headers, validateStatus: () => true }
    );

    console.log('Response status:', response.status);

    if (response.status === 200) {
      console.log('✅ Success! Response:', response.data.content[0].text);
      if (response.data.usage) {
        console.log('Token usage:', response.data.usage);
      }
    } else {
      console.error('❌ Error:', response.status, response.statusText);
      console.error('Error details:', JSON.stringify(response.data, null, 2));
    }
  } catch (error) {
    console.error('❌ Request failed:', error.message);
    if (error.response) {
      console.error('Error response:', error.response.data);
    }
  }
}

testClaude();