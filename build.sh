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
flutter build web --release --web-renderer canvaskit --verbose

echo "===================================="
echo "Build complete!"
echo "===================================="
ls -la build/web/
