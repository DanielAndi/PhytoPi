#!/bin/bash
# Build script for Flutter Kiosk Mode (Linux)
# Usage: ./scripts/build_kiosk.sh
# 
# This builds the app in kiosk mode for Raspberry Pi or Linux desktop
# Set KIOSK_MODE=true to enable kiosk-specific features

set -e

echo "🖥️  Building PhytoPi Kiosk App (Linux)..."
echo "=========================================="

# Navigate to dashboard directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$DASHBOARD_DIR"

# Load environment variables from .env files
UTILS_DIR="$(cd "$SCRIPT_DIR/../utils" && pwd)"
if [ -f "$UTILS_DIR/load_env.sh" ]; then
    export PLATFORM="kiosk"
    source "$UTILS_DIR/load_env.sh"
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    exit 1
fi

# Check if Linux desktop is enabled
echo "📋 Checking Linux desktop support..."
flutter doctor -v | grep -i linux || echo "⚠️  Linux desktop support may not be enabled"

# Verify Flutter installation
echo "📋 Flutter version:"
flutter --version

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

# Kiosk mode flag
KIOSK_MODE="${KIOSK_MODE:-true}"

echo "📋 Build configuration:"
echo "   Platform: Linux (Kiosk Mode)"
echo "   KIOSK_MODE: $KIOSK_MODE"
echo "   SUPABASE_URL: $SUPABASE_URL"
echo "   SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:20}..."
echo ""

# Build for Linux with kiosk mode
echo "🔨 Building Flutter Linux app (Kiosk Mode)..."
flutter build linux --release \
    --dart-define=KIOSK_MODE="$KIOSK_MODE" \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

echo ""
echo "✅ Linux Kiosk build complete! Output in build/linux/x64/release/bundle/"
echo "📊 Build size:"
du -sh build/linux/x64/release/bundle || true
echo ""
echo "🚀 To run the kiosk app:"
echo "   cd build/linux/x64/release/bundle"
echo "   ./phytopi_dashboard"
echo ""
echo "📝 For Raspberry Pi deployment:"
echo "   1. Copy the bundle directory to your Raspberry Pi"
echo "   2. Set up autostart (see docs for systemd service)"
echo "   3. Configure display settings for kiosk mode"

