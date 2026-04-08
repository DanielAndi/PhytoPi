#!/bin/bash
# Build script for Flutter iOS Mobile App
# Usage: ./scripts/build_mobile_ios.sh

set -e

echo "📱 Building PhytoPi Mobile App for iOS..."
echo "=========================================="

# Navigate to dashboard directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$DASHBOARD_DIR"

# Load environment variables from .env files
UTILS_DIR="$(cd "$SCRIPT_DIR/../utils" && pwd)"
if [ -f "$UTILS_DIR/load_env.sh" ]; then
    export PLATFORM="ios"
    source "$UTILS_DIR/load_env.sh"
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    exit 1
fi

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ iOS builds can only be performed on macOS"
    exit 1
fi

# Verify Flutter installation
echo "📋 Flutter version:"
flutter --version

# Check iOS setup
echo ""
echo "📋 Checking iOS setup..."
flutter doctor -v | grep -i ios || echo "⚠️  iOS setup may be incomplete"

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
echo "   Platform: iOS Mobile"
echo "   SUPABASE_URL: $SUPABASE_URL"
echo "   SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:20}..."
echo ""

# Build for iOS
echo "🔨 Building Flutter iOS app..."
flutter build ios --release \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --no-codesign

echo ""
echo "✅ iOS build complete! Output in build/ios/iphoneos/"
echo "⚠️  Note: Code signing required for device deployment"
echo "   Use Xcode to sign and deploy to device"

