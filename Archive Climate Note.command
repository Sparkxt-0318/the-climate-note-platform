#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="/Users/jp/Documents/Codex/2026-08-28/i-am-building-a-newsletter-platform-2"
IOS_ROOT="$PROJECT_ROOT/apps/ios"
ARCHIVE_STAMP=$(date '+%Y%m%d-%H%M%S')
LOG_PATH="$PROJECT_ROOT/outputs/ClimateNote-archive.log"

cd "$IOS_ROOT"

echo "The Climate Note — App Store archive"
"$PROJECT_ROOT/scripts/static_preflight.sh" --ios-only

echo "The archive will be checked again after Xcode creates the signed product."
echo "Checking the installed iOS simulator runtime…"
xcrun simctl list runtimes

BUILD_SETTINGS=$(xcodebuild -project ClimateNote.xcodeproj -scheme ClimateNote -configuration Release -showBuildSettings)
MARKETING_VERSION=$(printf '%s\n' "$BUILD_SETTINGS" | awk -F ' = ' '/^[[:space:]]*MARKETING_VERSION = / { print $2; exit }')
BUILD_NUMBER=$(printf '%s\n' "$BUILD_SETTINGS" | awk -F ' = ' '/^[[:space:]]*CURRENT_PROJECT_VERSION = / { print $2; exit }')
DEVICE_FAMILY=$(printf '%s\n' "$BUILD_SETTINGS" | awk -F ' = ' '/^[[:space:]]*TARGETED_DEVICE_FAMILY = / { print $2; exit }')

if [[ "$DEVICE_FAMILY" != "1" ]]; then
  echo "Archive stopped: TARGETED_DEVICE_FAMILY must be 1 (iPhone only), but it is '$DEVICE_FAMILY'."
  exit 1
fi

ARCHIVE_PATH="$PROJECT_ROOT/outputs/ClimateNote-$MARKETING_VERSION-build-$BUILD_NUMBER-$ARCHIVE_STAMP.xcarchive"

echo "Archiving version $MARKETING_VERSION (build $BUILD_NUMBER), iPhone only…"
echo "The log will be saved to: $LOG_PATH"

xcodebuild \
  -project ClimateNote.xcodeproj \
  -scheme ClimateNote \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  clean archive 2>&1 | tee "$LOG_PATH"

"$PROJECT_ROOT/scripts/prepare_archive_symbols.sh" "$ARCHIVE_PATH" "$LOG_PATH"

ARCHIVE_INFO="$ARCHIVE_PATH/Products/Applications/The Climate Note.app/Info.plist"
"$PROJECT_ROOT/scripts/verify_ios_product.sh" "$ARCHIVE_INFO"

echo
echo "Archive completed successfully. Opening it in Xcode Organizer…"
open "$ARCHIVE_PATH"
echo "You can close this Terminal window."
