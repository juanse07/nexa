#!/bin/bash

# Test build script to verify TypeScript compilation works correctly

echo "🔍 Testing TypeScript build..."
echo "================================"

# Clean previous build
echo "📦 Cleaning dist directory..."
rm -rf dist

# Run TypeScript compiler
echo "🔨 Running TypeScript compiler..."
npm run build

# Check if build succeeded
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    echo ""
    echo "📊 Build output:"
    ls -la dist/services/notificationService.* 2>/dev/null
    echo ""
    echo "🎉 TypeScript compilation successful - ready for Docker build and deployment!"
    exit 0
else
    echo "❌ Build failed!"
    exit 1
fi