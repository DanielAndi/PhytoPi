#!/bin/bash
# Production build script
# Builds the Flutter app for production deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="$SCRIPT_DIR/.."

echo "🏗️  Building PhytoPi Dashboard for Production"
echo "=============================================="
echo ""

cd "$DASHBOARD_DIR"

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    exit 1
fi

# Check for required environment variables
if [ -z "$SUPABASE_URL" ]; then
    echo "❌ Error: SUPABASE_URL environment variable is not set"
    echo "📝 Set it with: export SUPABASE_URL=https://your-project.supabase.co"
    exit 1
fi

if [ -z "$SUPABASE_ANON_KEY" ]; then
    echo "❌ Error: SUPABASE_ANON_KEY environment variable is not set"
    echo "📝 Set it with: export SUPABASE_ANON_KEY=your-anon-key"
    exit 1
fi

echo "📋 Build Configuration:"
echo "   Supabase URL: $SUPABASE_URL"
echo "   Anon Key: ${SUPABASE_ANON_KEY:0:20}..."
echo ""

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Clean previous build
echo "🧹 Cleaning previous build..."
flutter clean

# Build for web
echo "🔨 Building Flutter web app..."
flutter build web --release \
    --dart-define=SUPABASE_URL="$SUPABASE_URL" \
    --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
    --base-href="/"

echo ""
echo "✅ Build complete!"
echo "📊 Build output: build/web/"
echo ""
echo "📏 Build size:"
du -sh build/web

echo ""
echo "🚀 Next steps:"
echo "   1. Test the build locally:"
echo "      cd build/web && python3 -m http.server 8000"
echo "   2. Deploy to Vercel:"
echo "      vercel --prod"
echo "   3. Or deploy build/web to your hosting platform"

