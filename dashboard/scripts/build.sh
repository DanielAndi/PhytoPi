#!/bin/bash
# Build script for Vercel deployment
# This script builds the Flutter web app with production configuration

set -e

echo "🚀 Building PhytoPi Dashboard for production..."
echo "=============================================="

# Navigate to dashboard directory (script is in scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$DASHBOARD_DIR"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    echo "📦 Installing Flutter..."
    
    # Install Flutter using the official method
    # This is for Vercel's build environment
    FLUTTER_HOME="$HOME/flutter"
    export PATH="$PATH:$FLUTTER_HOME/bin"
    
    if [ ! -d "$FLUTTER_HOME" ]; then
        echo "📥 Downloading Flutter SDK (this may take a few minutes)..."
        cd $HOME
        git clone https://github.com/flutter/flutter.git -b stable --depth 1
        export PATH="$PATH:$FLUTTER_HOME/bin"
        
        # Accept licenses and install dependencies
        flutter doctor --android-licenses || true
        flutter precache --web
    fi
fi

# Verify Flutter installation
echo "📋 Flutter version:"
flutter --version

# Get dependencies
echo ""
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Build for web with production configuration
echo ""
echo "🔨 Building Flutter web app..."

# Check if environment variables are set (Vercel provides these)
if [ -z "$SUPABASE_URL" ]; then
    echo "⚠️  Warning: SUPABASE_URL not set, using default"
    echo "   This build will not work in production!"
    SUPABASE_URL="http://localhost:54321"
fi

if [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "⚠️  Warning: SUPABASE_ANON_KEY not set, using default"
    echo "   This build will not work in production!"
    SUPABASE_ANON_KEY="your-anon-key-here"
fi

echo "📋 Build configuration:"
echo "   SUPABASE_URL: $SUPABASE_URL"
echo "   SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:20}..."
echo ""

# Build with production configuration
flutter build web --release \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --base-href="/" \
    --web-renderer html

echo ""
echo "✅ Build complete! Output in build/web/"
echo "📊 Build size:"
du -sh build/web || true
echo ""
echo "📁 Build contents:"
ls -lh build/web/ | head -10

