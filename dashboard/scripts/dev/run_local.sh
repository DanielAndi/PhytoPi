#!/bin/bash
# Local development script
# Starts Supabase locally and runs the Flutter app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# Locate Supabase directory (supports repo layouts with infra outside dashboard)
if [ -d "$PROJECT_ROOT/infra/supabase" ]; then
    SUPABASE_DIR="$PROJECT_ROOT/infra/supabase"
elif [ -d "$PROJECT_ROOT/../infra/supabase" ]; then
    SUPABASE_DIR="$(cd "$PROJECT_ROOT/../infra/supabase" && pwd)"
else
    echo "❌ Could not find infra/supabase directory."
    echo "   Checked:"
    echo "     - $PROJECT_ROOT/infra/supabase"
    echo "     - $PROJECT_ROOT/../infra/supabase"
    echo ""
    echo "💡 Ensure you have the infra submodule checked out, or update run_local.sh."
    exit 1
fi
DASHBOARD_DIR="$SCRIPT_DIR/.."

echo "🌱 PhytoPi Local Development Setup"
echo "=================================="
echo ""

# Check if Supabase is running
echo "🔍 Checking Supabase status..."
cd "$SUPABASE_DIR"

if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI is not installed"
    echo "📦 Install it with: npm install -g supabase"
    exit 1
fi

# Get Supabase status
# Note: supabase status may return non-zero even when running (due to stopped services)
# So we always capture output and check if key information is present
STATUS_OUTPUT=$(cd "$SUPABASE_DIR" && supabase status 2>&1 || true)

# Check if Supabase is actually running by looking for API URL in output
if echo "$STATUS_OUTPUT" | grep -q "API URL"; then
    echo "✅ Supabase is running"
else
    echo "🚀 Starting Supabase..."
    cd "$SUPABASE_DIR"
    supabase start
    STATUS_OUTPUT=$(supabase status 2>&1 || true)
fi

# Parse Supabase configuration from status output
# Newer Supabase CLI uses "Publishable key" instead of "anon key"
# Extract Publishable key (supports both "Publishable key:" and "anon key" formats)
ANON_KEY=$(echo "$STATUS_OUTPUT" | grep -i "Publishable key" | awk -F': ' '{print $2}' | tr -d '[:space:]' | head -1)

# Fallback to old "anon key" format if new format not found
if [ -z "$ANON_KEY" ]; then
    ANON_KEY=$(echo "$STATUS_OUTPUT" | grep -i "anon key" | awk '{print $NF}' | head -1)
fi

# Get API URL (usually the last field on the line)
API_URL=$(echo "$STATUS_OUTPUT" | grep "API URL" | awk '{print $NF}' | head -1)

# Fallback to default if not found
if [ -z "$API_URL" ]; then
    API_URL="http://127.0.0.1:54321"
fi

# Validate we have the key
if [ -z "$ANON_KEY" ]; then
    echo "❌ Failed to get Supabase Publishable key"
    echo ""
    echo "📋 Supabase status output:"
    echo "$STATUS_OUTPUT"
    echo ""
    echo "💡 Troubleshooting:"
    echo "   1. Make sure Supabase is running: cd infra/supabase && supabase status"
    echo "   2. Try restarting: supabase stop && supabase start"
    echo "   3. Check for 'Publishable key' in the status output above"
    exit 1
fi

echo ""
echo "📋 Supabase Configuration:"
echo "   API URL: $API_URL"
echo "   Publishable Key: ${ANON_KEY:0:30}..."
echo "   Studio: http://127.0.0.1:54323"
echo ""

# Navigate to dashboard directory
cd "$DASHBOARD_DIR"

# Load environment variables from .env files (optional override)
# run_local.sh auto-detects Supabase, but .env can override if needed
UTILS_DIR="$(cd "$SCRIPT_DIR/../utils" && pwd)"
if [ -f "$UTILS_DIR/load_env.sh" ]; then
    # Force reload to check for .env overrides
        source "$UTILS_DIR/load_env.sh"
    
    # Explicitly check if the user has defined SUPABASE_URL in .env
    # The load_env.sh script exports variables, so we can check them here
        if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ]; then
        # Export to ensure they are available
        export API_URL="$SUPABASE_URL"
        export ANON_KEY="$SUPABASE_ANON_KEY"
        echo "📋 Using Supabase config from .env file:"
        echo "   URL: $API_URL"
        echo "   Key: ${ANON_KEY:0:10}..."
    fi
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed or not in PATH"
    exit 1
fi

# Get Flutter dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Check if Firefox is available for auto-opening
HAS_FIREFOX=false
if command -v firefox &> /dev/null; then
    HAS_FIREFOX=true
fi

# Run Flutter app using web-server (works with any browser: Firefox, Chrome, etc.)
echo ""
echo "🚀 Starting Flutter app..."
echo "   URL: http://localhost:3000"
echo "   Supabase: $API_URL"
echo "   Device: web-server (compatible with any browser)"
echo ""
if [ "$HAS_FIREFOX" = true ]; then
    echo "📱 The app will be available at http://localhost:3000"
    echo "   Firefox will open automatically in a few seconds..."
else
    echo "📱 The app will be available at http://localhost:3000"
    echo "   Open this URL in your browser (Firefox, Chrome, etc.)"
fi
echo ""
echo "Press Ctrl+C to stop"
echo ""

# Use web-server device - this starts a web server that works with any browser
# Automatically open Firefox if available
if [ "$HAS_FIREFOX" = true ]; then
    # Open Firefox after Flutter server starts (give it a few seconds)
    (
        sleep 5
        firefox http://localhost:3000 2>/dev/null &
    ) &
    BROWSER_PID=$!
fi

# Run Flutter app with web-server device
flutter run -d web-server --web-port 3000 \
    --dart-define=SUPABASE_URL="$API_URL" \
    --dart-define=SUPABASE_ANON_KEY="$ANON_KEY"

# Clean up browser process if script exits
if [ -n "$BROWSER_PID" ]; then
    kill $BROWSER_PID 2>/dev/null || true
fi

