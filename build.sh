#!/bin/bash
set -e

echo "===================================="
echo "Installing Flutter SDK..."
echo "===================================="

# Clone Flutter SDK (cached by Cloudflare between builds)
if [ ! -d "/opt/buildhome/.flutter" ]; then
  echo "Cloning Flutter SDK (stable branch)..."
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /opt/buildhome/.flutter
else
  echo "Using cached Flutter SDK"
fi

# Add Flutter to PATH
export PATH="/opt/buildhome/.flutter/bin:$PATH"
export PATH="/opt/buildhome/.flutter/bin/cache/dart-sdk/bin:$PATH"

# Verify installation
echo "Flutter version:"
flutter --version

# Precache web components (output is minimal)
echo "===================================="
echo "Precaching web components..."
echo "===================================="
flutter precache --web 2>&1 | grep -E "(Downloading|done)" || true

# Enable web (silent)
flutter config --enable-web --no-analytics > /dev/null 2>&1

# Get dependencies
echo "===================================="
echo "Getting dependencies..."
echo "===================================="
flutter pub get

# Build for web
echo "===================================="
echo "Building Flutter web (release mode)..."
echo "This takes 2-3 minutes. Progress:"
echo "===================================="

# Build WITHOUT --verbose to prevent log overflow
# Capture output and show only important lines
flutter build web --release \
  --dart-define=API_BASE_URL="${API_BASE_URL:-https://api.nexapymesoft.com}" \
  --dart-define=API_PATH_PREFIX="${API_PATH_PREFIX:-/api}" \
  --dart-define=GOOGLE_CLIENT_ID_WEB="${GOOGLE_CLIENT_ID_WEB}" \
  --dart-define=GOOGLE_SERVER_CLIENT_ID="${GOOGLE_SERVER_CLIENT_ID}" \
  --dart-define=APPLE_SERVICE_ID="${APPLE_SERVICE_ID}" \
  --dart-define=APPLE_REDIRECT_URI="${APPLE_REDIRECT_URI}" \
  --dart-define=PLACES_BIAS_LAT="${PLACES_BIAS_LAT:-39.7392}" \
  --dart-define=PLACES_BIAS_LNG="${PLACES_BIAS_LNG:--104.9903}" \
  --dart-define=PLACES_COMPONENTS="${PLACES_COMPONENTS:-country:us}" \
  2>&1 | grep -E "(Compiling|Building|Finalizing|✓)" || true

echo ""
echo "===================================="
echo "✓ Build complete!"
echo "Build timestamp: $(date)"
echo "===================================="
echo "Output files:"
ls -lh build/web/ | head -15
