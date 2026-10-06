# Manager design approval — 28 September 2026

## Baseline and evidence

Work in `outputs/ClimateNote-iOS`, the newer native implementation with bundled licensed fonts and nature assets. The original monorepo app is an older snapshot. Do not overwrite either copy wholesale. The reference website was opened and visually inspected live: local web source is stale and must not determine the palette.

Live reference: https://web-navy-theta-34.vercel.app/

Verified tokens: charcoal/pine #12110E, raised #1A1814/#24201A, ivory #F2EEE4, secondary #C9C3B5, muted #948D7E, mint #7FBF9C/#9BD4B7. Geist interface, Newsreader reading, Geist Mono metadata. Radius 4/10/18. Website timing 140/240/420/700ms; mobile retains only purposeful short transitions. Native SF Symbols remain appropriate.

## Approved architecture

Keep native Read / My Note / Account tabs, NavigationStack, system share sheet, provider sign-in controls, and destructive confirmation. Reading remains available to guests. Preserve article blocks, source links, AI labeling, suggested/custom actions, private journals, completion, impact factors, notification preferences, export, and deletion.

Read: one dominant current story, readable date/topic metadata, compact introduction, open archive rows. Avoid calling an old article “this week.” Distinguish empty, loading, failure, and stale-content states. Images must be bounded independently of their intrinsic dimensions.

Reader: uninterrupted prose with sufficient width; sources remain accessible. Summary and actions are reachable without requiring a full article scroll, while original prose remains unchanged. No invented data or decorative graphs. The action composer must make suggested action vs custom reflection explicit, retain drafts through sign-in, prevent duplicate saves, and show honest success/error.

My Note: compact title and privacy context, planned actions before retrospective metrics, actionable empty state leading to Read, completion status in words and icons, honest estimates only. No large marketing manifesto above everyday controls.

Account: compact identity/settings layout with clear grouping. Keep native toggles and provider buttons. Show pending operations; keep destructive actions isolated and explicitly confirmed. Privacy uses the same production view in captures.

## Component system

Use existing ClimateTheme and reusable styles. Light functional canvas becomes warm ivory; dark stays pine. Nature photography is concentrated in story and sign-in moments, rather than behind every control. Ordinary sections use whitespace and dividers; bounded cards only for meaningful selection/content objects. Semantic error/warning/success tokens must meet contrast. Labels and metadata must remain readable, not uppercase everywhere. Typography scales with Dynamic Type, touch targets >=44pt, reduced motion honored. Minimum control heights may grow with text.

## Assignment and validation

Component specialist: tokens, primitives, Account/Privacy/SignIn.
Reading specialist: Feed, Article, summary, action composer.
UX specialist: Root navigation, journal, small service fixes only where required for retry/loading/notification truth.
Manager: integration, shared screenshot fixtures, build/capture preparation, independent review.

Use actual production presentational views in deterministic screenshot scenes, not parallel mock implementations. Keep fixtures DEBUG-only and prevent backend writes in capture mode. No concept image or HTML imitation is evidence of a rendered SwiftUI app.

## Current validation limit

Windows has no Xcode, Swift compiler, or iOS Simulator. GitHub CLI's available login is invalid. Existing IPA predates this work. Native compilation, runtime flows, and final pixel review remain explicit release gates; source checks cannot substitute for them. Prepare reproducible macOS capture/testing tooling, and do not claim these gates pass until run.
