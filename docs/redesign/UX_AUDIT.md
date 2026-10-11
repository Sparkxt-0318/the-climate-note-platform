# Climate Note: product and interaction audit

## Scope and evidence

Reviewed all production SwiftUI view files, screenshot fixtures, shared theme, article/action models, and article, reflection, notification, and authentication service contracts. This is a source-based product audit, not a claim of rendered visual QA. The manager's website analysis determines final colors and type. Apply these recommendations only after manager approval.

Skills consulted: `redesign-existing-projects`, `ui-ux-pro-max`, and its native-app `pro-rules.md`. The optional SwiftUI database search could not run because the configured Windows Python alias was unavailable; native guidance below comes from the loaded rules and source inspection, not a claimed database result.

## Product contract

The core journey is **read a credible climate story → understand it → choose a manageable action → keep a private record → mark the action complete**. The app is a reading and private reflection product, not a carbon dashboard, social network, or habit game.

Reading is public and must never require authentication. Authentication is contextual to private saving and account controls. Original authored articles and source citations remain distinguishable from AI summaries and suggested actions. Impact estimates must remain qualified estimates, limited to supported action factors. Existing native navigation and authentication affordances are assets worth retaining.

## Screen and state inventory

| Screen / surface | Purpose and primary action | Current issues | Desired hierarchy and redesign opportunity |
|---|---|---|---|
| Root tabs | Move between reading, private notes, account. Primary: choose a destination. | Three destinations are appropriate; generic leaf for private journal contributes to superficial theming. No clear first-run product introduction beyond feed. | Retain three native tabs: **Read / My Note / Account**. Use a journal/book semantic symbol for My Note. Preserve independent navigation stacks, tab selection, safe areas and native back swipe. |
| Read: populated | Discover and open a published article. | Every article receives identical large shadowed card treatment. Article topic uses repeated uppercase labels. No distinction between latest and archive; single list feels like a template. | Brand masthead and short reading invitation → latest article with strong image/title/excerpt → earlier articles as compact editorial rows separated by rules. Put date and reading time together. Whole article row is one link. |
| Read: initial loading | Explain that content is arriving. | Uncomposed centered spinner; no relationship to actual layout. | Keep masthead and a quiet content-shaped placeholder, with one accessible loading label. Avoid endless shimmer. |
| Read: empty | Explain no published content yet. | “First note is on its way” also masks network/configuration errors. | Empty publication state: “A new note is on its way” with honest weekly cadence. Error gets its own title and explanation. Never present a service configuration message as a public empty-state description. |
| Read: error / stale content | Let readers understand a failure and continue when cached content exists. | Error disappears if old articles remain; no recovery model. `ArticleStore.start()` cannot retry an existing listener. | Inline connection notice above retained articles. For no articles, dedicated error state. Do not add a nonfunctional Retry button; explicit listener restart needs a small, separately reviewed service change. |
| Article reader | Read original story. Primary: read/scroll, then consider an action. | Similar weight among topic, excerpt, body, sources, AI panel and action picker. Broad large rectangles compete with content. Image placeholder has unstable reserved size. Cover placement depends on generation visual plan. | Quiet navigation title → topic/date → editorial title → brief deck → byline/read time → intentional source image → original body. Keep supplied block order, list numbering, attribution and visual placement semantics. Constrain reading width on iPad. |
| Article: Sources disclosure | Verify claims. Primary: expand and open a citation. | Existing disclosure is useful but easy to miss and external links are visually noisy bordered buttons. | A ruled reference section with count, clear expanded state, readable full-width citation rows. Group “Also published on” as lower-priority outbound links. Never remove sources or attribution. |
| Article: AI summary | Understand problem, significance and possible response. | Sparkle-led large card gives a generic AI aesthetic; AI label appears at the end. | Clear “In brief” heading and visible AI label before the three concise sections. Use a soft surface or left rule, not nested cards. Preserve all three fields verbatim and say the original article is unchanged. |
| Article: action composer | Choose one suggested action or write a private reflection. Primary: save. | Nested cards, exclamation headline, placeholder-only custom field; selected state lacks explicit accessibility trait. Save lacks pending state and can duplicate on rapid taps. `saved` never resets if selection/text changes. | “Make it your note” → calm instruction → single-choice rows with readable cadence → labeled “Your own reflection or action” multiline field → Save. Selected row has check + border/surface. Button transitions Save → Saving… → Saved. Disable during request, keep draft on failure. Saved-state changes need deliberate behavior. |
| Sign-in sheet | Authenticate to keep notes private. Primary: Apple or Google authentication. | Giant symbol plus centered slogan competes with provider buttons. Overlay progress can obscure content; text not scrollable at large sizes. | Short contextual title → privacy benefit → official provider buttons → visible in-progress status → privacy link. “Not now” stays available except where the provider owns presentation. Use scrollable layout; native provider visuals remain intact. Preserve draft when sheet dismisses. After successful sign-in, clearly invite Save again unless explicit auto-resume is implemented. |
| My Note: guest | Explain private journal value. Primary: sign in; secondary: keep reading. | Generic ContentUnavailableView behaves like a blocked utility page; leaf imagery. | A considered quiet journal introduction, actual benefit and privacy copy, Sign in CTA. A reading link can switch to Read only when real tab-selection routing exists. Do not show fake user data. |
| My Note: signed-in empty | Help a new reader create first action. | Currently displays empty calendar, zero-impact card and no next step. | “Your first note starts with a story” → explanation → real Read navigation. Suppress oversized zero-impact presentation. Date strip may remain secondary. No invented completed actions or environmental equivalencies. |
| My Note: populated | See planned actions and complete them. | Calendar and impact precede actionable work; all logs share equal cards; completed and planned mixed chronologically. | Journal heading → quiet week strip → **Up next** planned actions → **Your progress** compact verified totals → **Completed** history. Planned actions are the priority; history uses smaller rows. Zero planned with some history has an honest success state. |
| Action row: planned | Complete an action or schedule reminder. Primary: mark complete. | No pending guard, no completion feedback beyond eventual store update; Remind me has no acknowledgment. | Title/detail/source article → one primary completion button → secondary reminder. Completion pending state disables repeated mutation. On successful snapshot completion, move to history with restrained transition and announcement. Preserve originating article title. |
| Action row: completed | Recall completed work. | Only icon changes; status can be too implicit. | Check symbol plus “Completed” and completion date; retain detail. Optional impact disclosure can expose existing methodology; never manufacture an estimate for custom actions. |
| Account: guest / signed-in | Manage identity, reminders, privacy and data. | All native rows look similarly weighted; exported file has no preparing state; long account email may overflow. | Identity block → Notifications → Privacy and data → Help → About. Keep sign-out accessible; visually separate destructive Delete account. Native grouped-row behavior with branded typography/background is preferable to decorative cards. |
| Notification preferences | Opt in to weekly articles. Primary: toggle. | Async toggle lacks busy state; permission refusal only in alert. Reminder refusal silently returns. | Weekly description explicitly says off by default. Disable toggle during request; retain authoritative value. If denied, explain Settings access. Do not claim enabled until service confirms. Action reminders and weekly preference remain distinct. |
| Privacy | Explain public/private boundary. Primary: read policy or contact support. | Default list with plain sections has no editorial hierarchy. | Short privacy promise → clearly separated public/private/not-collected explanations → full policy/support. Preserve every existing claim and policy destination. |
| Export share sheet | Export personal data. Primary: share/save JSON. | No request-specific progress or duplicate request guard. | “Preparing export…” inline in Account, then native share sheet. Failure keeps user in Account with retry via original action. Retain authenticated export endpoint, temporary file and native sharing. |
| Delete confirmation / reauthentication | Confirm irreversible account removal. Primary: cancel or explicitly delete. | Current destructive alert is appropriate; working context not always visible. | Preserve explicit account/private-notes/history deletion wording and cancel. Show progress on Account; keep Apple/Google reauthentication and server deletion contract. Never add swipe-to-delete account. |
| Screenshot scenes | Deterministic visual documentation. | Feed, summary and progress duplicate production layout, while story/actions reuse production components. Thus marketing renders can diverge from app. | Share data-driven presentational views with live screens. Fixture data must remain isolated to explicit screenshot launch mode; do not introduce demo values into authenticated production state. |

## Navigation and layout architecture for approval

1. Retain `TabView` and one `NavigationStack` per tab. No new onboarding carousel or fourth tab.
2. Read remains a public editorial entry point. The first article receives visual prominence without changing Firestore order or filtering semantics. Older articles stay fully accessible.
3. Reader retains authored content as the principal surface. AI summary and action composer follow content and citations in a clearly distinguished reflection section. A lightweight “Reflect” jump is optional only if it scrolls to the actual composer without hiding article content.
4. My Note becomes a journal with a clear immediate action. Use visual grouping for planned and completed logs rather than inventing additional backend states.
5. Account remains native settings with clear groups. Sign-in remains a sheet, and export remains the system share sheet.
6. Avoid a persistent custom bottom CTA unless it has a clear state-specific role and respects keyboard/tab safe areas. Inline Save is sufficient for this short composer.

## Shared component requirements

- Adaptive screen background and content container with readable iPad measure.
- Editorial screen title, section heading, metadata row, plain list row and one featured story treatment.
- Primary, secondary and text button roles; disabled and busy states are real semantics.
- Labeled multiline note input with focus state and keyboard dismissal.
- Single-choice action row exposing selected state to VoiceOver.
- Notice, loading, empty and error presentations with optional functional action.
- Restrained completion/estimate row; no arbitrary progress charts or streak gamification.
- Semantic colors for primary text, secondary text, accent, background, surface, rule, success and destructive action. Use website-derived palette approved by the manager.

## Functionality protection checklist

### Authentication and account

- [ ] Public reading works signed out; no startup sign-in requirement.
- [ ] Apple request nonce, credential processing, cancellation handling and native provider button survive unchanged.
- [ ] Google official button/presentation, token exchange and cancellation handling survive unchanged.
- [ ] Provider buttons disable when working or configuration unavailable.
- [ ] Successful auth dismisses sheet and `ReflectionStore.observe` switches to correct user.
- [ ] Signing out clears visible private logs via the existing observer lifecycle.
- [ ] Export uses existing authenticated `/api/account/export` and native share flow.
- [ ] Delete keeps confirmation, provider reauthentication/revocation, authenticated `/api/account/delete`, messaging cleanup and sign-out.
- [ ] Privacy/support URLs and age/AI disclosures remain reachable.

### Content and private actions

- [ ] Article query remains published-only, newest first, real-time listener based.
- [ ] All article paragraph/heading/bulleted/numbered block content survives unchanged.
- [ ] All source links, cross-publication URLs, image alt/caption/attribution remain intact.
- [ ] AI generated additions remain labeled and never replace authored content.
- [ ] Suggested selection and custom draft remain mutually exclusive.
- [ ] Empty/whitespace drafts cannot create records.
- [ ] Save continues to call existing `plan` with article, selection, custom text and current UID.
- [ ] Logs retain article ID/title, action ID/category, creation date, completion date and impact estimate.
- [ ] Complete continues to use existing document ID/user path and update status/timestamp.
- [ ] Pending UI prevents rapid double save/complete without changing database schema.
- [ ] Failure retains draft and does not show a successful result.
- [ ] Completed count includes only completed logs; estimated CO₂ totals only sum nonnil supported estimates on completed logs.
- [ ] Calendar uses local dates/week start and completed timestamps; future/planned actions do not render completed.
- [ ] **No existing edit, per-action delete, undo completion, bookmark, search or reminder reschedule API exists. Do not introduce decorative controls claiming these capabilities.** Whole-account deletion exists; action CRUD is currently create/read/update-completed only.

### Notifications

- [ ] Weekly messaging is opt-in; original UserDefaults key, FCM topic and user preference write remain.
- [ ] Turning off weekly messaging unsubscribes and deletes messaging data as currently designed.
- [ ] Action reminder requires explicit tap and targets the existing next-day 17:00 behavior.
- [ ] Permission refusal is not falsely reported as success.
- [ ] Existing service failures remain surfaced; accessibility announcements describe actual result.

## Interaction, accessibility and state acceptance

- Standard iOS back gesture and sheet dismissal remain available. Use native controls for VoiceOver roles and keyboard focus.
- Minimum 44pt target; secondary text links need the same usable hit region. Do not rely on swipe-only actions.
- Body and secondary text require 4.5:1 contrast, meaningful control boundaries 3:1. Measure website-derived colors in both themes; original sage with white small text requires review.
- Dynamic Type scales headings, body, row heights and buttons. Avoid fixed-height multiline button clipping; use minimum height. Large type stacks metadata/buttons and allows a larger readable calendar layout.
- Heading accessibility traits; selected action traits; full day/date/status on week strip; status labels supplement color. Hide decorative symbols beside already labeled controls.
- Announce success/failure once. Preserve current content while saving; keep focus near composer after an error. Auth dismissal should not erase drafts.
- Use short 100–150ms press opacity feedback, native navigation/sheet transitions, and a restrained approximately 200ms selection or successful completion transition. No continuous atmospheric animation, bouncing leaves or gamified confetti.
- Respect Reduce Motion: no scale or movement required to perceive state. Retain immediate color/check/text changes.
- Async image failure gets a stable, intentional fallback region rather than an eternal spinner. Keep meaningful alt text and attribution visible where supplied.
- Loading, empty, error, pending, success and permission denial must be separate observed states. Do not invent success solely because an async function returned without throwing.

## Small behavior fixes requiring explicit engineering review

These are justified user-feedback fixes, separate from visual refactoring:

1. Add local per-operation pending guards for Save, Complete, Export and notification toggle.
2. Reset `saved` when the composer changes, or deliberately freeze the composer after save and provide a clear new-note action. Current code lets users edit a disabled saved form.
3. `NotificationService.scheduleActionReminder` returns silently on denial. Return an explicit result or surface an error before displaying reminder confirmation.
4. `ReflectionStore` has no loading indicator and clears logs during observer switches. A correct initial-loading state requires a small store contract addition; until then, do not fake a delayed spinner or claim an empty snapshot is confirmed.
5. `ArticleStore.start` ignores a second start while a listener exists. Functional retry requires a deliberate restart operation; do not merely wire Retry to a no-op.
6. Current plan uses `setData(from:)` without awaited server acknowledgment. Preserve semantics unless reviewed; avoid claiming a server-confirmed save beyond what the service guarantees.

## Required rendered review matrix

Capture production-shared screens at a small iPhone width, typical iPhone and iPad reading width; capture large Dynamic Type, dark appearance and Reduce Motion where supported. Required scenes: populated feed, feed loading/empty/error, article first screen/body/sources, summary, selected custom/suggested composer, keyboard, pending/save failure/success, guest and empty journal, planned/completed journal, account, sign-in, privacy, delete confirmation. Fixture screenshots must exercise the same visual components. Source inspection alone cannot close these gates.
