# App Review response - version 1.0, build 3

Thank you for the detailed review feedback.

We addressed both issues in the new binary, version 1.0 (build 3):

1. The app now targets iPhone only. Its submitted binary declares `UIDeviceFamily` value `1`; native iPad, Mac Catalyst, and Designed for iPad on Mac support are disabled for this release. Please review this build on an iPhone.
2. Sign in is completed from inside the app. Sign in with Apple uses Apple's native AuthenticationServices interface. Google Sign-In uses Google's supported iOS SDK, which presents an `ASWebAuthenticationSession` from the app rather than opening the standalone Safari app.
3. We hardened presentation-window selection and prevented repeated taps while authentication is active. If authentication cannot start, the app displays a clear retry message and remains fully usable for reading without an account.
4. Account deletion remains available inside the app under Account > Delete account.

Review steps:

1. Install version 1.0 (build 3) as a fresh installation on an iPhone running iOS 17 or later.
2. Open the Account tab.
3. Tap "Sign in or create an account."
4. Choose "Continue with Apple" or the Google button. The authentication interface is presented from within The Climate Note.
5. After signing in, Account > Delete account can be used to permanently delete the account and private app data.

The app does not require an account to read articles. Reviewers may tap "Not now" and use all reading features without signing in.
