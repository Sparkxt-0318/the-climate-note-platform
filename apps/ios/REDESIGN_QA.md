# Climate Note redesign QA

## Checks performed on this Windows host

- Reviewed Swift source, Xcode project references, asset catalog entries, Info.plist, fonts, and
  deterministic-fixture isolation guards.
- Validated native QA harness syntax, help output, and its macOS-only rejection path.
- Confirmed capture scenes use production presentation components and the debug isolation path skips
  Firebase startup and store observation.

These are host source/resource checks only. They do not compile Swift, run XCTest, boot a simulator,
exercise a provider or network request, or establish pixel correctness.

## Required macOS command

From the nested iOS repository on a Mac with Xcode and an installed iOS Simulator runtime:

```text
python3 scripts/native_qa.py
```

The command creates dedicated small-phone, standard-phone, and iPad simulators, runs `xcodebuild test`
for `ClimateNote`, installs the compiled app identified by `CFBundleIdentifier`, and captures isolated
production-view scenes in light/dark and standard/largest accessibility-text variants. Inspect
`manifest.json`, `xcodebuild.log`, the `.xcresult`, and every PNG. The harness output is evidence for
review, never automatic pixel approval. The optional nested-repository GitHub Actions workflow
(`Native UI QA`) runs this same command manually; it has not run for this work.

The target is universal (`TARGETED_DEVICE_FAMILY = "1,2"`), so iPad captures exercise native
responsive layouts instead of an iPhone compatibility presentation.

## Required release gates

1. Resolve packages and build the `ClimateNote` scheme with the current Xcode and an iOS 17+
   simulator runtime; run `ClimateNoteTests`.
2. Review every device/appearance capture of `feed`, `feed-image-loading`, `feed-image-error`,
   `story`, `story-visual`, `story-no-generation`, `summary`, `actions`, `action-selected`, `reflection`,
   `reflection-keyboard`, `save-queued`, `save-error`, `save-synced`, `progress`, `journal-empty`, `journal-guest`, `account`, `privacy`,
   `signin-unavailable`, `feed-loading`, `feed-refreshing`, `feed-stale`, `feed-empty`, and
   `feed-error`, plus `impact-loading`, `impact-threshold`, `impact-populated`, `impact-stale`, and
   `impact-error`. The Reader scene must be pushed from Feed, never rooted directly.
3. Exercise live guest reading, article links, draft restore/account isolation, offline/reconnect
   and rejected save behavior, automatic continuation after an explicitly requested sign-in,
   duplicate prevention, completion undo, reminder schedule/edit/removal, notification
   enable/disable and preference-sync retry, sign-out, export, deletion, Apple sign-in, Google
   sign-in, licensed-photo attribution/takedown, community opt-in/out/reconciliation, and provider
   failures.
4. Test authenticated Account and My Note flows with live network data. These flows are not covered
   by the isolated fixtures. `signin-unavailable` only verifies unavailable-provider presentation.
5. Check keyboard avoidance, smallest supported iPhone, standard phone, and iPad widths,
   Accessibility Dynamic Type, VoiceOver destination focus, Reduce Motion, Increased Contrast,
   Bold Text, grayscale, light and dark appearance, 44pt touch targets, and physical-device
   font/icon rendering.
6. Verify the reference-direction addendum: opaque canvas on every screen, photography only within
   story content, the Geist 30pt Read heading and 25pt feature title, Newsreader Reader/My Note
   hierarchy, a 196pt feed
   lead, compact thumbnail archive rows with no excerpts, toolbar share, and wrapping controls at
   accessibility text sizes. In My Note, verify the calendar strip precedes planned actions,
   reflections, completed items, and progress.

## Current limitation

Windows has no Xcode, `swiftc`, iOS Simulator, code signing, or physical iPhone. No native build,
XCTest, runtime, provider, network, screenshot, or pixel-review result is claimed until the macOS
gates above complete.
