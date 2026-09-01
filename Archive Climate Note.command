#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="/Users/jp/Documents/Codex/2026-08-28/i-am-building-a-newsletter-platform-2"
IOS_ROOT="$PROJECT_ROOT/apps/ios"
ARCHIVE_STAMP=$(date '+%Y%m%d-%H%M%S')
ARCHIVE_PATH="$PROJECT_ROOT/outputs/ClimateNote-1.0.0-build-2-$ARCHIVE_STAMP.xcarchive"
LOG_PATH="$PROJECT_ROOT/outputs/ClimateNote-archive.log"

cd "$IOS_ROOT"

echo "The Climate Note — App Store archive"
echo "Checking the installed iOS simulator runtime…"
xcrun simctl list runtimes

echo "Archiving version 1.0.0 (build 2)…"
echo "The log will be saved to: $LOG_PATH"

xcodebuild \
  -project ClimateNote.xcodeproj \
  -scheme ClimateNote \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY='Apple Distribution' \
  PROVISIONING_PROFILE_SPECIFIER='The Climate Note App Store 2026' \
  clean archive 2>&1 | tee "$LOG_PATH"

echo
echo "Generating UUID-matched dSYMs for vendored frameworks…"
APP_PATH="$ARCHIVE_PATH/Products/Applications/The Climate Note.app"
DSYM_COUNT=0
for FRAMEWORK_PATH in "$APP_PATH"/Frameworks/*.framework; do
  FRAMEWORK_NAME=$(basename "$FRAMEWORK_PATH" .framework)
  FRAMEWORK_BINARY="$FRAMEWORK_PATH/$FRAMEWORK_NAME"
  if [[ -f "$FRAMEWORK_BINARY" ]]; then
    if ! xcrun dsymutil \
      "$FRAMEWORK_BINARY" \
      -o "$ARCHIVE_PATH/dSYMs/$FRAMEWORK_NAME.framework.dSYM" \
      >> "$LOG_PATH" 2>&1; then
      echo "Could not generate the dSYM for $FRAMEWORK_NAME."
      exit 1
    fi
    DSYM_COUNT=$((DSYM_COUNT + 1))
  fi
done
echo "Generated $DSYM_COUNT framework dSYMs."

echo
echo "Archive completed successfully. Opening it in Xcode Organizer…"
open "$ARCHIVE_PATH"
echo "You can close this Terminal window."
