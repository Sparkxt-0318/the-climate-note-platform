# Native QA handoff

## Status

Source and resource review was performed on Windows. Native build, XCTest, Simulator runtime,
network/provider flow, and pixel-review gates remain pending because this host has no Xcode,
`swiftc`, or iOS Simulator.

## Run on macOS

From `outputs/ClimateNote-iOS` in the nested iOS repository:

```text
python3 scripts/native_qa.py
```

The script creates and later deletes isolated iPhone SE (3rd generation), iPhone 16, and iPad Pro
13-inch (M4) simulators, runs `xcodebuild test` first on the iPhone SE, then captures production
views on every device. Use repeated `--device` arguments to choose other installed device types.
The target supports both iPhone and iPad (`TARGETED_DEVICE_FAMILY = "1,2"`), so the iPad set is a
native universal layout check rather than an iPhone compatibility capture.
It writes a manifest with hashes for Swift, project, package resolution, Info.plists, and resources.
A manual `Native UI QA` GitHub Actions workflow also runs this command, but it has not been run for
this redesign.

## Evidence to review

Review the build log, XCTest result bundle, manifest, and every capture. Each device receives light,
dark, light accessibility-text, and dark accessibility-text variants of: feed, feed-image-loading,
feed-image-error, story, story-visual, story-no-generation, summary, actions, action-selected, reflection,
reflection-keyboard, save-queued, save-error, save-synced, progress, journal-empty, journal-guest, account, privacy,
signin-unavailable, feed-loading, feed-refreshing, feed-stale, feed-empty, feed-error, impact-loading,
impact-threshold, impact-populated, impact-stale, and impact-error.

The production-component fixture uses an explicit story-local placeholder through the normal image
component; it does not misrepresent an unrelated bundled photograph as an approved cover. The story
scene starts at Feed and pushes its article through the same value-based NavigationStack route as
production, so the back affordance is part of the evidence. Inspect image-loading and missing-image
states as deliberately rendered states, then test live licensed-image networking, attribution, and
takedown separately. `story-visual`
uses the production Reader scroll anchor to show its in-article image and caption below the intro.
The three save-state scenes use a DEBUG-only signed-in presentation with a stable operation ID; the
synced scene must show “View in My Note,” while none may make a network write.

`signin-unavailable` is deliberately isolated from Firebase and shows unavailable-provider UI. It
does not demonstrate an authenticated user, Apple/Google provider health, or an end-to-end sign-in.
The isolated account and journal fixtures also do not cover authenticated Account or live-network
flows.

## Reference-direction addendum

Review the capture set against the editorial direction: every app screen has an opaque ivory canvas
(or its opaque dark appearance), with no forest photo, veil, or gradient behind app content. Photos
may appear only as a lead or in-article story visual. Confirm the Geist 26pt Read heading, Geist
30pt Read heading, 25pt Feed headline, Newsreader 34pt Reader headline, 196pt story-local feed lead, and compact
thumbnail archive rows that omit excerpts. At accessibility text sizes, controls must stack without
clipping. In `progress`, confirm the weekly calendar strip comes before planned actions,
reflections, completed entries, and progress. Re-check account and sign-in spacing against the
shared 24pt gutter and opaque surfaces.

## Manual release pass

Run guest and authenticated reading, provider sign-in (successful, cancelled, and failed), sign-out,
draft restore and account isolation, offline/reconnect/rejected note saves, duplicate taps,
notifications (including a remote-preference sync retry), reminder scheduling/editing/removal,
completion undo, source links, and failure states. Check keyboard avoidance, VoiceOver order and
destination focus, Reduce Motion, Dynamic Type, contrast settings, 44pt targets, and physical-device
font/icon rendering. Exercise community opt-in/out, threshold behavior, stale recovery, receipt
subtraction after reopen/deletion, and links from My Note and Account. Confirm Pexels credits and
license links open correctly, removed images disappear, and provider failure publishes text-only.
Complete human pixel review before using captures for App Store material.
