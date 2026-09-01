# iOS setup

The generated Xcode project targets iPhone on iOS 17 and later with bundle ID `com.theclimatenote.app`,
matching the publisher's existing Apple distribution profiles.
It uses Swift Package Manager to resolve Firebase Apple SDK 12.18.x and Google Sign-In 9.2.x.
This keeps downloaded frameworks out of Git and makes fresh clones reproducible.

Before running authenticated features:

1. Add the iOS app in Firebase and place `GoogleService-Info.plist` in `ClimateNote/Support/`.
2. Run `ruby ../../scripts/generate_xcodeproj.rb` only when project structure changes; the generator reads the reversed Google
   client ID from that plist and adds both values to the target.
3. Open `ClimateNote.xcodeproj`.
4. Confirm the Apple Developer team in Signing & Capabilities.
5. Enable Sign in with Apple and Push Notifications for the App ID.

After cloning, open the project and allow Xcode to resolve package dependencies. Do not commit
`Vendor`, DerivedData, provisioning profiles, certificates, or API keys.

Guest article reading remains available without an account.
