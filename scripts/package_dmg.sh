#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/package_dmg.sh [--skip-build] [--output /path/to/TokenTracker.dmg] [--derived-data /path/to/build]

Options:
  --skip-build            Skip xcodebuild and only create dmg from existing .app
  --output <path>         Output dmg path (default: ./dist/TokenTracker.dmg)
  --derived-data <path>   DerivedData/build directory (default: ./build)
  -h, --help              Show this help
EOF
}

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_FILE="$PROJECT_ROOT/TokenTracker.xcodeproj"
SCHEME="TokenTracker"
CONFIGURATION="Release"
SDK="macosx"

SKIP_BUILD="false"
DERIVED_DATA_PATH="$PROJECT_ROOT/build"
OUTPUT_DMG_PATH="$PROJECT_ROOT/dist/TokenTracker.dmg"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build)
      SKIP_BUILD="true"
      shift
      ;;
    --output)
      OUTPUT_DMG_PATH="$2"
      shift 2
      ;;
    --derived-data)
      DERIVED_DATA_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

APP_NAME="TokenTracker"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/$APP_NAME.app"
OUTPUT_DIR="$(dirname "$OUTPUT_DMG_PATH")"
CUSTOM_ICON_PATH="$PROJECT_ROOT/packaging/TokenTrackerVolumeIcon.icns"
ICON_SOURCE_PATH="$APP_PATH/Contents/Resources/AppIcon.icns"
DEFAULT_ICON_PATH="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/GenericApplicationIcon.icns"

if [[ "$SKIP_BUILD" != "true" ]]; then
  echo "[1/5] Building $SCHEME ($CONFIGURATION)..."
  xcodebuild \
    -project "$PROJECT_FILE" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -sdk "$SDK" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    build
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH" >&2
  echo "Run without --skip-build or verify --derived-data path." >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -f "$OUTPUT_DMG_PATH"
rm -f "${OUTPUT_DMG_PATH%.dmg}.dmg"

STAGE_DIR="$(mktemp -d /tmp/tokentracker_dmg.XXXXXX)"
TMP_DMG_PATH="/tmp/tokentracker_dmg_rw.$$.dmg"
MOUNT_POINT=""
cleanup() {
  if [[ -n "${MOUNT_POINT:-}" ]] && [[ -d "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" -force >/dev/null 2>&1 || true
  fi
  rm -rf "$STAGE_DIR"
  rm -f "$TMP_DMG_PATH"
}
trap cleanup EXIT

echo "[2/5] Preparing staging folder..."
cp -R "$APP_PATH" "$STAGE_DIR/$APP_NAME.app"
ln -s /Applications "$STAGE_DIR/Applications"

if [[ -f "$CUSTOM_ICON_PATH" ]]; then
  ICON_SOURCE_PATH="$CUSTOM_ICON_PATH"
elif [[ ! -f "$ICON_SOURCE_PATH" ]]; then
  ICON_SOURCE_PATH="$DEFAULT_ICON_PATH"
fi

echo "[3/5] Creating writable dmg..."
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDRW \
  "$TMP_DMG_PATH"

echo "[4/5] Applying volume icon..."
ATTACH_OUTPUT="$(hdiutil attach -readwrite -noverify -noautoopen "$TMP_DMG_PATH")"
MOUNT_POINT="$(echo "$ATTACH_OUTPUT" | sed -n 's#^.*\(/Volumes/.*\)$#\1#p' | head -n 1)"
if [[ -z "$MOUNT_POINT" ]] || [[ ! -d "$MOUNT_POINT" ]]; then
  echo "Failed to mount temporary dmg." >&2
  echo "$ATTACH_OUTPUT" >&2
  exit 1
fi

if [[ -f "$ICON_SOURCE_PATH" ]]; then
  cp "$ICON_SOURCE_PATH" "$MOUNT_POINT/.VolumeIcon.icns"
  /usr/bin/SetFile -c icnC "$MOUNT_POINT/.VolumeIcon.icns" || true
  /usr/bin/SetFile -a C "$MOUNT_POINT" || true
fi

# Keep distribution volume clean from auto-generated metadata folders.
rm -rf "$MOUNT_POINT/.fseventsd" "$MOUNT_POINT/.Trashes"
rm -f "$MOUNT_POINT/.DS_Store"

sync
hdiutil detach "$MOUNT_POINT"
MOUNT_POINT=""

echo "[5/5] Converting to compressed dmg..."
CONVERT_OUTPUT_BASE="${OUTPUT_DMG_PATH%.dmg}"
hdiutil convert "$TMP_DMG_PATH" -format UDZO -ov -o "$CONVERT_OUTPUT_BASE"

if [[ "${CONVERT_OUTPUT_BASE}.dmg" != "$OUTPUT_DMG_PATH" ]]; then
  mv -f "${CONVERT_OUTPUT_BASE}.dmg" "$OUTPUT_DMG_PATH"
fi

echo "Done: $OUTPUT_DMG_PATH"
ls -lh "$OUTPUT_DMG_PATH"
shasum -a 256 "$OUTPUT_DMG_PATH"
