#!/bin/bash
set -e

# Install Flutter
echo "Installing Flutter..."
git clone --depth 1 --branch stable https://github.com/flutter/flutter.git /opt/flutter
export PATH="/opt/flutter/bin:$PATH"

# Verify Flutter installation
flutter --version

# Enable web support
flutter config --enable-web

# Get dependencies
echo "Getting Flutter dependencies..."
flutter pub get

# Build web
echo "Building Flutter web..."
flutter build web --release --web-renderer canvaskit

echo "Build complete!"
