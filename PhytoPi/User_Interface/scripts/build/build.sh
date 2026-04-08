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

FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"

# Prefer the official "latest stable" alias for Linux.
# This avoids parsing JSON metadata during the build, which can fail in CI due
# to transient network/pipe issues.
if [[ "$FLUTTER_CHANNEL" == "stable" ]]; then
  FLUTTER_TARBALL_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_stable.tar.xz"
else
  FLUTTER_RELEASES_JSON_URL="https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"

  resolve_flutter_tarball_url() {
    local channel="$1"
    local tmp_json
    tmp_json="$(mktemp)"
    curl -fsSL --retry 3 --retry-delay 1 --connect-timeout 10 "$FLUTTER_RELEASES_JSON_URL" -o "$tmp_json"
    python3 - "$channel" "$tmp_json" <<'PY'
import json, sys

channel = sys.argv[1]
path = sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)

base_url = data.get("base_url")
current = data.get("current_release", {}).get(channel)
if not base_url or not current:
    raise SystemExit(f"Could not resolve Flutter {channel} release from metadata")

archive = None
for rel in data.get("releases", []):
    if rel.get("hash") == current:
        archive = rel.get("archive")
        break

if not archive:
    raise SystemExit(f"Could not find archive for Flutter {channel} hash {current}")

print(f"{base_url}/{archive}")
PY
    rm -f "$tmp_json"
  }

  FLUTTER_TARBALL_URL="$(resolve_flutter_tarball_url "$FLUTTER_CHANNEL")"
fi

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
export GIT_CONFIG_SYSTEM="${GIT_CONFIG_SYSTEM:-/dev/null}"
touch "$GIT_CONFIG_GLOBAL"
# Avoid relying on $HOME or git's idea of "global" when running as root.
# Git compares safe.directory against the repo path it sees (often absolute).
FLUTTER_SDK_DIR_REL="$FLUTTER_CACHE_DIR/flutter"
FLUTTER_SDK_DIR_ABS="$(cd "$FLUTTER_SDK_DIR_REL" && pwd -P)"
git config --file "$GIT_CONFIG_GLOBAL" --add safe.directory "$FLUTTER_SDK_DIR_REL" || true
git config --file "$GIT_CONFIG_GLOBAL" --add safe.directory "$FLUTTER_SDK_DIR_ABS" || true

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
