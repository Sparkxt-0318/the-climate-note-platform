# The Climate Note for iOS

This native SwiftUI project targets iPhone on iOS 17 and later with bundle ID
`com.theclimatenote.app`. It uses Firebase Apple SDK 12.18.x and Google Sign-In 9.2.x through
Swift Package Manager. Guest article reading works without an account.

## Setup

1. Add the iOS app in Firebase and put `GoogleService-Info.plist` in `ClimateNote/Support/`.
2. Run `ruby ../../scripts/generate_xcodeproj.rb` only when the project structure changes.
3. Open `ClimateNote.xcodeproj`, resolve packages, select the Apple Developer team, and enable
   Sign in with Apple and Push Notifications for the App ID.

Do not commit generated dependencies, DerivedData, provisioning profiles, certificates, or API
keys. See [BUILD_IPA.md](BUILD_IPA.md) for archive and signing requirements.

## Design

The reference-direction addendum uses opaque ivory reading screens with no global forest or photo
backdrop. Photography is reserved for a story’s own cover or in-article visual. Geist carries
navigation and controls, Newsreader carries lead/article title and deck hierarchy, and Geist Mono
carries metadata. The licensed fonts and their OFL licenses are bundled in
`ClimateNote/Resources/Fonts/`.

Motion is short and purposeful, respects Reduce Motion, and is not a substitute for native visual
QA. Reading content uses bounded imagery and a comfortable, Dynamic Type-aware measure.

## Deterministic native capture scenes

Debug capture mode uses production presentation views with isolated data and disabled interaction.
It does not initialize Firebase or write backend data. Run the harness on macOS after Xcode and an
iOS Simulator runtime are available:

```text
python3 scripts/native_qa.py --device "iPhone 16"
```

The harness captures 30 scenes in light/dark and standard/accessibility-text variants. They cover
Feed and Reader image loading/failure, Reader navigation and no-generation articles, writing and
keyboard states, queued/failed/synced saves, journal/account/privacy/sign-in surfaces, retained and
stale feed refreshes, plus loading, privacy-threshold, populated, stale, and error presentations for
Community Impact. The `signin-unavailable` scene deliberately covers isolated, unavailable-provider
UI; it does not validate Apple or Google authentication.

Each capture manifest hashes Swift, the Xcode project, `Package.resolved`, Info.plists, and bundled
resources. Captures still require human pixel review. Concept images in `PreviewScreenshots-v4/`
predate this native work and are art direction only, never compiled-app evidence.

## Native validation status

This Windows workspace has not run Xcode, XCTest, the iOS Simulator, authentication, network,
provider, or pixel-review gates. The nested iOS repository's GitHub Actions workflow is manual only
and has not run. See [REDESIGN_QA.md](REDESIGN_QA.md) and
[review/NATIVE_QA_HANDOFF.md](review/NATIVE_QA_HANDOFF.md) for exact host checks, macOS commands,
and remaining release gates.
