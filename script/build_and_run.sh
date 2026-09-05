#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 [run|--build-only|--debug|--logs|--telemetry|--verify]" >&2
}

if [[ $# -gt 1 ]]; then
  usage
  exit 2
fi

MODE="${1:-run}"
case "$MODE" in
  run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify) ;;
  --build-only|build-only) MODE="build-only" ;;
  --help|-h) usage; exit 0 ;;
  *) usage; exit 2 ;;
esac

case "${CONFIGURATION:-Debug}" in
  debug|Debug) CONFIGURATION="Debug" ;;
  release|Release) CONFIGURATION="Release" ;;
  *) echo "CONFIGURATION must be Debug or Release." >&2; exit 2 ;;
esac

for setting in VERSION BUILD_NUMBER; do
  value="${!setting:-}"
  if [[ -n "$value" && ! "$value" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "$setting must contain one to three dot-separated numbers." >&2
    exit 2
  fi
done

if [[ -n "${BUNDLE_ID:-}" && ! "$BUNDLE_ID" =~ ^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$ ]]; then
  echo "BUNDLE_ID must be a reverse-DNS identifier." >&2
  exit 2
fi

APP_NAME="CoreBar"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-$ROOT_DIR/.build/xcode}"
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# The Xcode project owns the app's plist, resources, version and entitlements.
# Override individual settings only when requested by the caller.
BUILD_SETTINGS=(
  "CODE_SIGN_STYLE=Manual"
  "CODE_SIGN_IDENTITY=$CODESIGN_IDENTITY"
  "DEVELOPMENT_TEAM=${DEVELOPMENT_TEAM:-}"
  "CODE_SIGNING_ALLOWED=YES"
  "CODE_SIGNING_REQUIRED=YES"
)
[[ -z "${VERSION:-}" ]] || BUILD_SETTINGS+=("MARKETING_VERSION=$VERSION")
[[ -z "${BUILD_NUMBER:-}" ]] || BUILD_SETTINGS+=("CURRENT_PROJECT_VERSION=$BUILD_NUMBER")
[[ -z "${BUNDLE_ID:-}" ]] || BUILD_SETTINGS+=("PRODUCT_BUNDLE_IDENTIFIER=$BUNDLE_ID")
if [[ "$CODESIGN_IDENTITY" != "-" ]]; then
  BUILD_SETTINGS+=("OTHER_CODE_SIGN_FLAGS=--options runtime --timestamp")
fi

xcodebuild -quiet \
  -project "$ROOT_DIR/CoreBar.xcodeproj" \
  -scheme "$APP_NAME" \
  -configuration "$CONFIGURATION" \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  "${BUILD_SETTINGS[@]}" \
  build

BUILT_APP="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
if [[ ! -x "$BUILT_APP/Contents/MacOS/$APP_NAME" ]]; then
  echo "The build did not produce $BUILT_APP." >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
STAGING_DIR="$(mktemp -d "$DIST_DIR/.corebar-build.XXXXXX")"
cleanup() {
  local result=$?
  # Restore the prior bundle if publishing was interrupted between the moves.
  if [[ ( -e "$STAGING_DIR/previous.app" || -L "$STAGING_DIR/previous.app" ) && ! -e "$APP_BUNDLE" && ! -L "$APP_BUNDLE" ]]; then
    mv "$STAGING_DIR/previous.app" "$APP_BUNDLE"
  fi
  rm -rf "$STAGING_DIR"
  return "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

STAGED_APP="$STAGING_DIR/$APP_NAME.app"
ditto "$BUILT_APP" "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"
RESOLVED_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$STAGED_APP/Contents/Info.plist")"

# Keep the current app running throughout compilation and signature validation.
if [[ "$MODE" != "build-only" ]]; then
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  for ((attempt = 0; attempt < 30; attempt++)); do
    if ! pgrep -x "$APP_NAME" >/dev/null; then
      break
    fi
    sleep 0.1
  done
  if pgrep -x "$APP_NAME" >/dev/null; then
    echo "$APP_NAME is still running; the existing app bundle was kept." >&2
    exit 1
  fi
fi

if [[ -e "$APP_BUNDLE" || -L "$APP_BUNDLE" ]]; then
  mv "$APP_BUNDLE" "$STAGING_DIR/previous.app"
fi
mv "$STAGED_APP" "$APP_BUNDLE"
echo "Built $APP_BUNDLE ($CONFIGURATION)"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  build-only)
    ;;
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$RESOLVED_BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
esac
