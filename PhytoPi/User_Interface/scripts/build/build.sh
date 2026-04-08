#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${SUPABASE_URL:-}" ]]; then
  echo "Missing required env var: SUPABASE_URL" >&2
  exit 1
fi

if [[ -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "Missing required env var: SUPABASE_ANON_KEY" >&2
  exit 1
fi

VERCEL_CACHE_DIR="${VERCEL_CACHE_DIR:-.vercel/cache}"
FLUTTER_CACHE_DIR="$VERCEL_CACHE_DIR/flutter"
FLUTTER_VERSION_FILE="$FLUTTER_CACHE_DIR/.flutter-version"

FLUTTER_VERSION="${FLUTTER_VERSION:-stable}"
FLUTTER_TARBALL_URL="https://storage.googleapis.com/flutter_infra_release/releases/${FLUTTER_VERSION}/linux/flutter_linux_3.22.3-stable.tar.xz"

mkdir -p "$FLUTTER_CACHE_DIR"

need_flutter_install=true
if [[ -d "$FLUTTER_CACHE_DIR/flutter" && -f "$FLUTTER_VERSION_FILE" ]]; then
  if [[ "$(cat "$FLUTTER_VERSION_FILE")" == "$FLUTTER_TARBALL_URL" ]]; then
    need_flutter_install=false
  fi
fi

if [[ "$need_flutter_install" == "true" ]]; then
  echo "Installing Flutter SDK (cached in $FLUTTER_CACHE_DIR)..."
  rm -rf "$FLUTTER_CACHE_DIR/flutter"

  tmp_dir="$(mktemp -d)"
  trap 'rm -rf "$tmp_dir"' EXIT

  curl -fsSL "$FLUTTER_TARBALL_URL" -o "$tmp_dir/flutter.tar.xz"
  tar -xJf "$tmp_dir/flutter.tar.xz" -C "$FLUTTER_CACHE_DIR"
  echo "$FLUTTER_TARBALL_URL" > "$FLUTTER_VERSION_FILE"
fi

export PATH="$FLUTTER_CACHE_DIR/flutter/bin:$PATH"

#
# Vercel builds run in a containerized environment (often as root). Flutter's SDK
# is a git repository, and git can refuse to operate if it considers the repo
# ownership "dubious". Keep this build self-contained by writing to a temporary
# global gitconfig for this build process and marking the Flutter SDK checkout as
# safe.
#
export GIT_CONFIG_GLOBAL="${GIT_CONFIG_GLOBAL:-/tmp/gitconfig}"
touch "$GIT_CONFIG_GLOBAL"
git config --global --add safe.directory "$FLUTTER_CACHE_DIR/flutter" || true

flutter --version
flutter config --no-analytics >/dev/null
flutter config --enable-web >/dev/null

flutter pub get

flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  ${PHYTOPI_STREAM_URL:+--dart-define=PHYTOPI_STREAM_URL="$PHYTOPI_STREAM_URL"} \
  ${KIOSK_MODE:+--dart-define=KIOSK_MODE="$KIOSK_MODE"}

echo "Build complete: $(pwd)/build/web"
