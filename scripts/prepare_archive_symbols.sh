#!/bin/zsh

set -euo pipefail

ARCHIVE_PATH=${1:-}
LOG_PATH=${2:-/dev/null}
APP_PATH="$ARCHIVE_PATH/Products/Applications/The Climate Note.app"

if [[ -z "$ARCHIVE_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Usage: $0 /path/to/ClimateNote.xcarchive [/path/to/archive.log]" >&2
  exit 1
fi

mkdir -p "$ARCHIVE_PATH/dSYMs"
DSYM_COUNT=0

for FRAMEWORK_PATH in "$APP_PATH"/Frameworks/*.framework; do
  FRAMEWORK_NAME=$(basename "$FRAMEWORK_PATH" .framework)
  FRAMEWORK_BINARY="$FRAMEWORK_PATH/$FRAMEWORK_NAME"
  DSYM_PATH="$ARCHIVE_PATH/dSYMs/$FRAMEWORK_NAME.framework.dSYM"

  [[ -f "$FRAMEWORK_BINARY" ]] || continue

  xcrun dsymutil "$FRAMEWORK_BINARY" -o "$DSYM_PATH" >> "$LOG_PATH" 2>&1

  while read -r _ BINARY_UUID _; do
    if ! xcrun dwarfdump --uuid "$DSYM_PATH" | grep -q "$BINARY_UUID"; then
      echo "FAIL: Generated dSYM UUID does not match $FRAMEWORK_NAME ($BINARY_UUID)." >&2
      exit 1
    fi
  done < <(xcrun dwarfdump --uuid "$FRAMEWORK_BINARY")

  DSYM_COUNT=$((DSYM_COUNT + 1))
done

echo "Generated and UUID-verified $DSYM_COUNT embedded-framework dSYMs."
