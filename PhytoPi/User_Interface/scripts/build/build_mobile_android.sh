#!/bin/bash
# Build script for Flutter Android Mobile App
# Usage: ./scripts/build_mobile_android.sh [apk|appbundle]

set -e

BUILD_TYPE="${1:-apk}"  # Default to apk if not specified

echo "📱 Building PhytoPi Mobile App for Android..."
echo "=============================================="

# Navigate to dashboard directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Script is in scripts/build, so go up one level to get to dashboard
DASHBOARD_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$DASHBOARD_DIR"

# Load environment variables from .env files
UTILS_DIR="$(cd "$DASHBOARD_DIR/scripts/utils" && pwd)"
if [ -f "$UTILS_DIR/load_env.sh" ]; then
    export PLATFORM="android"
    source "$UTILS_DIR/load_env.sh"
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    exit 1
fi

# Verify Flutter installation
echo "📋 Flutter version:"
flutter --version

# Check Android setup
echo ""
echo "📋 Checking Android setup..."
flutter doctor -v | grep -i android || echo "⚠️  Android setup may be incomplete"

# Get dependencies
echo ""
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Check environment variables (from .env or command line)
if [ -z "$SUPABASE_URL" ]; then
    echo "⚠️  Warning: SUPABASE_URL not set"
    echo "   Set it in .env file or export SUPABASE_URL"
    echo "   Using default: http://localhost:54321"
    SUPABASE_URL="http://localhost:54321"
fi

if [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "⚠️  Warning: SUPABASE_ANON_KEY not set"
    echo "   Set it in .env file or export SUPABASE_ANON_KEY"
    echo "   Using default placeholder"
    SUPABASE_ANON_KEY="your-anon-key-here"
fi

echo "📋 Build configuration:"
echo "   Platform: Android Mobile"
echo "   Build Type: $BUILD_TYPE"
echo "   SUPABASE_URL: $SUPABASE_URL"
echo "   SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:20}..."
echo ""

# Build for Android
echo "🔨 Building Flutter Android app..."
if [ "$BUILD_TYPE" == "appbundle" ]; then
    flutter build appbundle --release \
        --dart-define=SUPABASE_URL="$SUPABASE_URL" \
        --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
    echo ""
    echo "✅ Android App Bundle build complete! Output in build/app/outputs/bundle/release/"
else
    flutter build apk --release \
        --dart-define=SUPABASE_URL="$SUPABASE_URL" \
        --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
    echo ""
    echo "✅ Android APK build complete! Output in build/app/outputs/flutter-apk/"
    echo "📊 APK size:"
    ls -lh build/app/outputs/flutter-apk/app-release.apk || true
fi

