#!/bin/sh

set -eu

INFO_PLIST=${1:-}

if [ -z "$INFO_PLIST" ] || [ ! -f "$INFO_PLIST" ]; then
  echo "Usage: $0 /path/to/The Climate Note.app/Info.plist" >&2
  exit 1
fi

read_plist() {
  /usr/libexec/PlistBuddy -c "Print :$1" "$INFO_PLIST" 2>/dev/null
}

device_family=$(read_plist "UIDeviceFamily:0")
build_number=$(read_plist "CFBundleVersion")
version_number=$(read_plist "CFBundleShortVersionString")

[ "$device_family" = "1" ] || {
  echo "FAIL: Built product is not iPhone-only (UIDeviceFamily[0]=$device_family)." >&2
  exit 1
}

if /usr/libexec/PlistBuddy -c "Print :UIDeviceFamily:1" "$INFO_PLIST" >/dev/null 2>&1; then
  echo "FAIL: Built product declares an additional device family." >&2
  exit 1
fi

[ "$version_number" = "1.0.0" ] || {
  echo "FAIL: Built product version is $version_number, expected 1.0.0." >&2
  exit 1
}

[ "$build_number" = "3" ] || {
  echo "FAIL: Built product build number is $build_number, expected 3." >&2
  exit 1
}

echo "Verified iPhone-only product: version $version_number, build $build_number, UIDeviceFamily [1]."
