#!/bin/sh

set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$PROJECT_ROOT"
IOS_ONLY=false
if [ "${1:-}" = "--ios-only" ]; then
  IOS_ONLY=true
fi

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

echo "Checking release identifiers and Apple metadata"
grep -q 'PRODUCT_BUNDLE_IDENTIFIER.*com.theclimatenote.app' apps/ios/ClimateNote.xcodeproj/project.pbxproj \
  || fail "The iOS bundle identifier is not com.theclimatenote.app."
grep -q 'PRODUCT_BUNDLE_IDENTIFIER.*com.theclimatenote.app.tests' apps/ios/ClimateNote.xcodeproj/project.pbxproj \
  || fail "The iOS test bundle identifier is incorrect."
grep -q 'CURRENT_PROJECT_VERSION = 3;' apps/ios/ClimateNote.xcodeproj/project.pbxproj \
  || fail "The App Store build number is not 3."
targeted_device_family_count=$(grep -c 'TARGETED_DEVICE_FAMILY = 1;' apps/ios/ClimateNote.xcodeproj/project.pbxproj || true)
[ "$targeted_device_family_count" -eq 2 ] \
  || fail "Both app configurations must target iPhone only (TARGETED_DEVICE_FAMILY = 1)."
if grep -q 'TARGETED_DEVICE_FAMILY = .*2' apps/ios/ClimateNote.xcodeproj/project.pbxproj; then
  fail "The iOS project still declares iPad support."
fi
grep -q 'SUPPORTS_MACCATALYST = NO;' apps/ios/ClimateNote.xcodeproj/project.pbxproj \
  || fail "Mac Catalyst must remain disabled for the iPhone-only release."
grep -q 'com.apple.SignInWithApple' apps/ios/ClimateNote.xcodeproj/project.pbxproj \
  || fail "The Sign in with Apple capability is not declared in the Xcode project."

for plist in \
  apps/ios/ClimateNote/Support/Info.plist \
  apps/ios/ClimateNote/Support/ClimateNote.entitlements \
  apps/ios/ClimateNote/Support/PrivacyInfo.xcprivacy
do
  plutil -lint "$plist" >/dev/null || fail "Invalid property list: $plist"
done

grep -q '<key>ITSAppUsesNonExemptEncryption</key>' apps/ios/ClimateNote/Support/Info.plist \
  || fail "Export-compliance declaration is missing."
grep -q '<key>NSPrivacyTracking</key>' apps/ios/ClimateNote/Support/PrivacyInfo.xcprivacy \
  || fail "App privacy manifest is missing tracking disclosure."
grep -q '<key>com.apple.developer.applesignin</key>' apps/ios/ClimateNote/Support/ClimateNote.entitlements \
  || fail "Sign in with Apple entitlement is missing."
grep -q '<key>CFBundleURLSchemes</key>' apps/ios/ClimateNote/Support/Info.plist \
  || fail "Google Sign-In callback URL scheme is missing."

if rg -n 'UIApplication\.shared\.open|openURL\(|SFSafariViewController' \
  apps/ios/ClimateNote/Services/AuthService.swift apps/ios/ClimateNote/Views/SignInView.swift; then
  fail "Authentication must not launch an external browser or a custom web-login controller."
fi
grep -q 'signIn(withPresenting:' apps/ios/ClimateNote/Services/AuthService.swift \
  || fail "Google Sign-In is not using the SDK's in-app authentication session."
grep -q 'Button("Delete account"' apps/ios/ClimateNote/Views/AccountView.swift \
  || fail "In-app account deletion is missing."

echo "Checking app icon variants"
for icon in \
  apps/ios/ClimateNote/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png \
  apps/ios/ClimateNote/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-dark.png \
  apps/ios/ClimateNote/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024-tinted.png
do
  [ -f "$icon" ] || fail "Missing app icon: $icon"
  dimensions=$(sips -g pixelWidth -g pixelHeight "$icon" 2>/dev/null)
  echo "$dimensions" | grep -q 'pixelWidth: 1024' || fail "App icon is not 1024 px wide: $icon"
  echo "$dimensions" | grep -q 'pixelHeight: 1024' || fail "App icon is not 1024 px high: $icon"
  alpha=$(sips -g hasAlpha "$icon" 2>/dev/null)
  echo "$alpha" | grep -q 'hasAlpha: no' || fail "App icon contains an alpha channel: $icon"
done

echo "Checking configuration files"
jq -e . firestore.indexes.json >/dev/null || fail "Invalid Firestore indexes JSON."
jq -e . apps/web/vercel.json >/dev/null || fail "Invalid Vercel configuration JSON."
find apps/ios/ClimateNote/Resources/Assets.xcassets -name Contents.json -print0 \
  | xargs -0 -n1 jq -e . >/dev/null || fail "Invalid asset catalog JSON."

if rg -n 'org\.theclimatenote\.app|REPLACE_ME|YOUR_API_KEY' \
  --glob '!apps/ios/Vendor/**' --glob '!work/**' --glob '!node_modules/**' \
  --glob '!scripts/static_preflight.sh' .
then
  fail "A release placeholder or obsolete bundle identifier remains."
fi

echo "Parsing Swift sources"
find apps/ios/ClimateNote apps/ios/ClimateNoteTests -name '*.swift' -print0 \
  | xargs -0 -n1 xcrun swiftc -frontend -parse

zsh -n "Archive Climate Note.command" scripts/prepare_archive_symbols.sh
sh -n scripts/verify_ios_product.sh

if [ "$IOS_ONLY" = true ]; then
  echo "iOS release preflight passed."
  exit 0
fi

echo "Running web checks"
CLIMATE_NOTE_PNPM=$(which -a pnpm 2>/dev/null | awk '/codex-primary-runtime/ { print; exit }')
if [ -z "$CLIMATE_NOTE_PNPM" ]; then
  CLIMATE_NOTE_NODE=$(command -v node || true)
else
  CLIMATE_NOTE_NODE=$(CDPATH= cd -- "$(dirname -- "$CLIMATE_NOTE_PNPM")/../../node/bin" && pwd)/node
fi
[ -n "$CLIMATE_NOTE_NODE" ] || fail "Node.js is not installed."

(
  cd apps/web
  "$CLIMATE_NOTE_NODE" node_modules/typescript/bin/tsc --noEmit
  "$CLIMATE_NOTE_NODE" node_modules/eslint/bin/eslint.js . --max-warnings=0
  "$CLIMATE_NOTE_NODE" node_modules/vitest/vitest.mjs run
  "$CLIMATE_NOTE_NODE" node_modules/next/dist/bin/next build
)

echo "Static release preflight passed."
