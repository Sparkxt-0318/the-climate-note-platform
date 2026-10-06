# Climate Note — native design system

This is the implementation guide for the native app in `outputs/ClimateNote-iOS`. The approved direction comes from the rendered publication website, documented in `docs/redesign/brand-reference-audit.md`, and the manager decision in `review/DESIGN_APPROVAL.md`.

## Product and hierarchy

Learn → Notice → Act. Use one dominant story, a quiet reader, and a practical private journal. Everyday Account, Privacy and My Note headings are compact page titles with short supporting context. Ordinary sections use whitespace and thin rules; reserve bounded containers for selected actions, meaningful content objects and authentication.

Preserve the native Read / My Note / Account tabs, NavigationStack, native share sheet, Apple and Google provider controls, toggle semantics and explicit destructive confirmation. Reading never requires authentication.

## Color tokens

| Role | Light | Dark |
|---|---|---|
| Canvas / reading surface | #F7F3EC | #12110E |
| Surface | #F1ECE2 | #1A1814 |
| Elevated surface | #E8E1D4 | #24201A |
| Primary ink | #1A1815 | #F2EEE4 |
| Secondary ink | #46423B | #C9C3B5 |
| Muted ink | #6B6659 | #948D7E |
| Accent / success | #2F5D46 | #7FBF9C |
| On accent | #FFFFFF | #12130F |
| Warning | #7A4B0C | #ECC070 |
| Error | #A02D28 | #F59F95 |

Warning and error are deliberate native semantic additions; they were not extracted from the reference website. Pair status color with an explicit message and symbol. Primary button foreground/background are an adaptive pair. Existing static pine/mint roles remain for navigation chrome and deliberately bounded dark brand panels.

`ClimateBackdrop()` is an opaque functional canvas in both appearances. It never renders a global photo, veil, or gradient. Photography belongs only to an individual story cover or in-article visual; body copy never sits directly on a variable image.

## Typography

Bundled licensed fonts are used with Dynamic Type relative sizing, not system substitutes:

- Geist: Read heading 30 semibold, Feed feature headline 25 semibold, section 20, row title 17, interface body 17 and supporting copy 15–16pt.
- Newsreader: Reader headline 34 medium, My Note heading 30 medium, deck 20–22, native long-form reading role 19, secondary editorial copy 16pt. This native reading choice is not a claim that the live website uses Newsreader for all article body text.
- Geist Mono: metadata 12–13pt, editorial numbering and occasional labels. Do not uppercase all interface labels.
- SF Symbols: consistent native line icons; decorative icons are hidden from accessibility.

Allow labels and headings to wrap and grow. Do not shrink text to fit a fixed-height control. Use sentence case for functional labels.

## Geometry

Spacing: 4 / 8 / 12 / 16 / 24 / 32 / 48 / 64pt. Everyday screen gutters are 24pt; constrained content centers on iPad. A row needs at least 44pt of touch area and may grow with Dynamic Type. Radius: 4 / 10 / 18pt. Capsules are intentional for primary actions, not every content container. Hairlines and whitespace supply ordinary grouping; no decorative shadows or glass.

## Shared components

- `ClimatePageHeader(title:subtitle:)`: compact adaptive heading with header semantics and natural wrapping.
- `ClimateInlineStatus(message:kind:)`: information, success, warning or error with text and a distinct symbol. Uses semantic colors against an opaque surface.
- `ClimatePrimaryButtonStyle`: adaptive accent capsule, 52pt minimum height and clear disabled styling.
- `ClimateSecondaryButtonStyle`: quiet outlined capsule with minimum native target.
- `ClimateArticleLinkStyle`: unobtrusive pressed feedback for editorial and settings rows.
- `ClimateSheet` / `ClimatePinePanel`: reserved bounded content containers, not default section scaffolding.

The reference addendum favors compact editorial hierarchy: a 196pt story-local lead image directly after the Read introduction; its title, serif deck, metadata, and inline reading cue stay together. Archive rows use a compact cover thumbnail only when a story has cover data, with title and date/read time; they omit excerpts. Story media preserves its caption, photographer/provider credit, source link and license link; loading and missing-image space remains stable. The reader uses its serif article title/deck, toolbar share control, and quiet summary/action shortcuts. My Note begins with an open weekly strip, then planned actions, reflections, completed entries, and progress. Account uses open ruled groups, visible pending export/notification/deletion states and guards set before launching asynchronous tasks. Export, sign-out, deletion and notification preference changes cannot overlap from this screen. Deletion retains native confirmation. Provider authentication buttons remain official controls, propagate disabled state and retain privacy access. Privacy is a production view shared by normal navigation and screenshot scenes.

## Content and state

The feed distinguishes loading, empty, failure, retained refreshing, and stale content. Pull-to-refresh remains active until Firestore delivers a non-cache server snapshot, fails, is cancelled, or reaches a 15-second timeout; a cached empty snapshot never clears retained reading. The reader keeps original prose and source attribution intact; generated summaries/actions remain labeled. Drafts persist through sign-in and save paths reject duplicate submissions. My Note prioritizes planned actions over retrospective totals. Completion is communicated in words and symbols. Personal impact counts only completed actions with supported factors. Reflections and unknown future entry kinds never contribute. Community Impact has explicit loading, privacy-threshold, populated, stale, and error states. Its opt-in is off by default, and public totals never reveal sub-threshold counts. Do not invent graphs, equivalencies, emissions savings, or progress.

## Motion and accessibility

Press: 120ms; state: 220ms; entrance: 360ms. Use transform/opacity without reflow. Honor Reduce Motion; screenshots disable decorative entrances. Functional screens have no perpetual motion. Native controls, navigation and system safe areas remain intact. Body text must meet 4.5:1 contrast, meaningful controls/icons 3:1. Disabled appearance and VoiceOver semantics must agree.

## Validation boundary

Content widths are tokenized: feed 720pt, reading/journal/account/privacy 680pt, empty state 560pt, and authentication 500pt. Phone gutters are 24pt, related elements use 8–12pt gaps, and sections use 24–32pt separation. The native target supports iPhone and iPad, so the same widths are centered rather than stretched on iPad. Source review can verify token pairs, reuse, state guards and layout intent. Windows has no Xcode or iOS Simulator: native compilation, visual captures, Dynamic Type, VoiceOver, landscape and actual authentication/notification/data operations remain macOS/device validation gates. The HTML prototype and prior concept PNGs are illustrative only; do not present them as proof of this implementation.
