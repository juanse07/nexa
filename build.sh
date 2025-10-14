#!/bin/bash
set -e

echo "===================================="
echo "Installing Flutter SDK..."
echo "===================================="

# Clone Flutter SDK
if [ ! -d "/opt/buildhome/.flutter" ]; then
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /opt/buildhome/.flutter
fi

# Add Flutter to PATH
export PATH="/opt/buildhome/.flutter/bin:$PATH"
export PATH="/opt/buildhome/.flutter/bin/cache/dart-sdk/bin:$PATH"

# Verify installation
echo "Flutter version:"
flutter --version

# Precache web components
echo "===================================="
echo "Precaching web components..."
echo "===================================="
flutter precache --web

# Enable web
flutter config --enable-web --no-analytics

# Get dependencies
echo "===================================="
echo "Getting dependencies..."
echo "===================================="
flutter pub get

# Build for web
echo "===================================="
echo "Building Flutter web..."
echo "===================================="

# Build with environment variables passed as compile-time constants
# These will be read by Environment class using String.fromEnvironment()
flutter build web --release --verbose \
  --dart-define=API_BASE_URL="${API_BASE_URL:-https://api.nexapymesoft.com}" \
  --dart-define=API_PATH_PREFIX="${API_PATH_PREFIX:-/api}" \
  --dart-define=GOOGLE_MAPS_API_KEY="${GOOGLE_MAPS_API_KEY}" \
  --dart-define=GOOGLE_CLIENT_ID_WEB="${GOOGLE_CLIENT_ID_WEB}" \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID}" \
  --dart-define=PLACES_BIAS_LAT="${PLACES_BIAS_LAT:-39.7392}" \
  --dart-define=PLACES_BIAS_LNG="${PLACES_BIAS_LNG:--104.9903}" \
  --dart-define=PLACES_COMPONENTS="${PLACES_COMPONENTS:-country:us}" \
  --dart-define=OPENAI_API_KEY="${OPENAI_API_KEY}"

echo "===================================="
echo "Build complete!"
echo "Build timestamp: $(date)"
echo "===================================="
ls -la build/web/
