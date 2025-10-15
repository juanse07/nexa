#!/bin/bash

# Test script to verify Apple Sign In backend configuration
# This helps debug the "Apple auth failed" error

echo "=================================="
echo "Apple Sign In Backend Test"
echo "=================================="
echo ""

# Test 1: Check if backend is reachable
echo "Test 1: Checking if backend is reachable..."
BACKEND_URL="https://api.nexapymesoft.com/api"

if curl -s -o /dev/null -w "%{http_code}" "$BACKEND_URL" | grep -q "404\|200"; then
  echo "✅ Backend is reachable at $BACKEND_URL"
else
  echo "❌ Backend is NOT reachable at $BACKEND_URL"
  echo "   Please check if your backend is running"
  exit 1
fi

echo ""

# Test 2: Check backend environment variables (via a test endpoint if you have one)
echo "Test 2: What to verify on your backend server..."
echo ""
echo "SSH into your backend server and run:"
echo ""
echo "  cd /path/to/backend"
echo "  cat .env | grep APPLE"
echo ""
echo "You should see:"
echo "  APPLE_BUNDLE_ID=com.pymesoft.nexa"
echo "  APPLE_SERVICE_ID=com.pymesoft.nexa.web"
echo ""
echo "Then check the backend logs:"
echo ""
echo "  # If using pm2:"
echo "  pm2 logs"
echo ""
echo "  # If using systemd:"
echo "  journalctl -u your-backend-service -f"
echo ""
echo "  # Look for this warning at startup:"
echo "  [auth] No Apple audience configured..."
echo ""
echo "  # If you see that warning, the environment variables aren't being loaded!"
echo ""
echo "=================================="
echo "Common Issues:"
echo "=================================="
echo ""
echo "1. Environment variables not loaded:"
echo "   - Make sure .env file is in the backend root directory"
echo "   - Restart the backend service after updating .env"
echo "   - Some deployment platforms need explicit env var configuration"
echo ""
echo "2. Wrong APPLE_SERVICE_ID value:"
echo "   - Must be exactly: com.pymesoft.nexa.web"
echo "   - No extra spaces or quotes"
echo ""
echo "3. Backend not restarted after changes:"
echo "   - Run: pm2 restart all  (or equivalent for your setup)"
echo ""
echo "4. Check backend logs for Apple verification errors:"
echo "   - Look for: [auth] Apple verification failed:"
echo "   - This will tell you the exact reason Apple rejected the token"
echo ""
