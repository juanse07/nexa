#!/bin/bash
set -e

echo "===================================="
echo "Building Android Release"
echo "===================================="

# Load environment variables from .env.local
if [ -f .env.local ]; then
  echo "Loading environment from .env.local..."
  export $(cat .env.local | grep -v '^#' | grep -v '^$' | xargs)
else
  echo "ERROR: .env.local not found!"
  echo "Please create .env.local with your production credentials"
  exit 1
fi

# Build Android release with environment variables
echo "Building Android APK with production configuration..."

flutter build apk --release \
  --dart-define=API_BASE_URL="${API_BASE_URL}" \
  --dart-define=API_PATH_PREFIX="${API_PATH_PREFIX}" \
  --dart-define=GOOGLE_CLIENT_ID_ANDROID="${GOOGLE_CLIENT_ID_ANDROID}" \
  --dart-define=GOOGLE_CLIENT_ID_IOS="${GOOGLE_CLIENT_ID_IOS}" \
  --dart-define=GOOGLE_CLIENT_ID_WEB="${GOOGLE_CLIENT_ID_WEB}" \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID}" \
  --dart-define=APPLE_BUNDLE_ID="${APPLE_BUNDLE_ID}" \
  --dart-define=APPLE_SERVICE_ID="${APPLE_SERVICE_ID}" \
  --dart-define=APPLE_REDIRECT_URI="${APPLE_REDIRECT_URI}" \
  --dart-define=GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY}" \
  --dart-define=GOOGLE_MAPS_IOS_SDK_KEY="${GOOGLE_MAPS_IOS_SDK_KEY}" \
  --dart-define=OPENAI_API_KEY="${OPENAI_API_KEY:-}" \
  --dart-define=OPENAI_BASE_URL="${OPENAI_BASE_URL:-https://api.openai.com/v1}" \
  --dart-define=OPENAI_VISION_MODEL="${OPENAI_VISION_MODEL:-gpt-4o-mini}" \
  --dart-define=OPENAI_TEXT_MODEL="${OPENAI_TEXT_MODEL:-gpt-4.1-mini}" \
  --dart-define=PLACES_BIAS_LAT="${PLACES_BIAS_LAT:-39.7392}" \
  --dart-define=PLACES_BIAS_LNG="${PLACES_BIAS_LNG:--104.9903}" \
  --dart-define=PLACES_COMPONENTS="${PLACES_COMPONENTS:-country:us}"

echo "===================================="
echo "Build complete!"
echo "APK location: build/app/outputs/flutter-apk/app-release.apk"
echo "===================================="
