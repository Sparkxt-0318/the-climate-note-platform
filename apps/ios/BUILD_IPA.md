# Building the Climate Note IPA

This is a native SwiftUI iOS project. It cannot produce an Android `.apk` without a separate Android
implementation. Building any iOS binary requires Apple’s SDK and therefore macOS with Xcode.

## Fastest artifact: unsigned IPA from GitHub Actions

The included `.github/workflows/build-ios-ipa.yml` workflow compiles the app twice: once for the iOS
Simulator as a compile check, then once for a physical iPhone target. It packages the device build as
`ClimateNote-unsigned.ipa` and uploads the IPA plus both build logs as a workflow artifact.

1. Put this folder at the root of a GitHub repository.
2. Push the source and open **Actions > Build iOS IPA > Run workflow**.
3. When the job completes, download the `ClimateNote-unsigned-ipa` artifact.

The unsigned IPA is not directly installable. It must be re-signed with an Apple Development or
Distribution identity and a provisioning profile that matches `com.theclimatenote.app`. Personal
device-install tools may re-sign it with the user’s own Apple ID; App Store/TestFlight distribution
requires the publisher’s Apple Developer credentials.

## Signed TestFlight or App Store build

The Xcode project is configured for Apple team `F8X3YXYMWH` and release provisioning profile
`The Climate Note App Store 2026`. On a trusted Mac that has the matching certificate and profile:

1. Open `ClimateNote.xcodeproj` and let Swift Package Manager finish resolving dependencies.
2. Select **Any iOS Device (arm64)** as the run destination.
3. Choose **Product > Archive**.
4. In Organizer, run **Validate App** and address every signing or entitlement error.
5. Choose **Distribute App** for TestFlight/App Store Connect, or **Export** to create a signed IPA.

Do not upload Apple certificates, private keys, provisioning profiles, or App Store Connect API keys
to the repository. If CI signing is later required, store each secret only in encrypted repository or
organization secrets and limit the workflow’s permissions.

## Release gate

Do not distribute the build until the checks in `REDESIGN_QA.md` pass on macOS and a physical iPhone.
The current Windows workspace can validate source structure and assets, but it cannot run Xcode,
the iOS Simulator, code signing, archive validation, or device installation.
