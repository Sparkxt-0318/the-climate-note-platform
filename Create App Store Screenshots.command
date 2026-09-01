#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="/Users/jp/Documents/Codex/2026-08-28/i-am-building-a-newsletter-platform-2"
IOS_ROOT="$PROJECT_ROOT/apps/ios"
OUTPUT_ROOT="$PROJECT_ROOT/outputs/app-store-screenshots-6.5-inch"
RAW_ROOT="$OUTPUT_ROOT/raw"
DERIVED_DATA="$PROJECT_ROOT/work/ScreenshotDerivedData"
DEVICE_NAME="Climate Note Screenshots 6.5-inch"
DEVICE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-13-Pro-Max"
RUNTIME="com.apple.CoreSimulator.SimRuntime.iOS-26-5"

mkdir -p "$OUTPUT_ROOT" "$RAW_ROOT"

DEVICE_ID=$(xcrun simctl list devices | sed -n "s/.*$DEVICE_NAME (\([0-9A-F-]*\)).*/\1/p" | head -1)
if [[ -z "$DEVICE_ID" ]]; then
  DEVICE_ID=$(xcrun simctl create "$DEVICE_NAME" "$DEVICE_TYPE" "$RUNTIME")
fi

xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE_ID" -b
xcrun simctl status_bar "$DEVICE_ID" override \
  --time '9:41' \
  --batteryState charged \
  --batteryLevel 100 \
  --wifiBars 3 \
  --cellularBars 4

cd "$IOS_ROOT"
xcodebuild \
  -project ClimateNote.xcodeproj \
  -scheme ClimateNote \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEVICE_ID" \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/The Climate Note.app"
xcrun simctl install "$DEVICE_ID" "$APP_PATH"

SCENES=(feed story summary actions progress)
FILENAMES=(01-weekly-climate-stories 02-original-article 03-simple-summary 04-specific-actions 05-weekly-progress)

for INDEX in {1..5}; do
  SCENE=${SCENES[$INDEX]}
  NAME=${FILENAMES[$INDEX]}
  xcrun simctl launch --terminate-running-process "$DEVICE_ID" com.theclimatenote.app \
    --args --climate-screenshot "$SCENE"
  sleep 2
  RAW_PATH="$RAW_ROOT/$NAME.png"
  FINAL_PATH="$OUTPUT_ROOT/$NAME.jpg"
  xcrun simctl io "$DEVICE_ID" screenshot "$RAW_PATH"
  sips -s format jpeg -s formatOptions 95 "$RAW_PATH" --out "$FINAL_PATH" >/dev/null

  WIDTH=$(sips -g pixelWidth "$FINAL_PATH" | awk '/pixelWidth/ { print $2 }')
  HEIGHT=$(sips -g pixelHeight "$FINAL_PATH" | awk '/pixelHeight/ { print $2 }')
  ALPHA=$(sips -g hasAlpha "$FINAL_PATH" | awk '/hasAlpha/ { print $2 }')
  if [[ "$WIDTH" != "1284" || "$HEIGHT" != "2778" || "$ALPHA" != "no" ]]; then
    echo "Screenshot validation failed for $FINAL_PATH ($WIDTH x $HEIGHT, alpha=$ALPHA)."
    exit 1
  fi
done

xcrun simctl status_bar "$DEVICE_ID" clear
echo "Created five real simulator screenshots validated at 1284 x 2778 in: $OUTPUT_ROOT"
open "$OUTPUT_ROOT"
