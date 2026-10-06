# The Climate Note — App Store Optimization Plan

## Scope and current problems

The product has a distinct proposition—calm, cited climate reporting followed by one private, practical action—but its store presence must make that promise searchable and instantly understandable. Likely discoverability risks are a generic name, insufficient use of high-intent phrases in metadata and screenshots, unclear differentiation from news aggregators and habit trackers, and no planned measurement loop.

Source changes can improve the in-app experience, onboarding, review timing, deep-link destinations, and attribution support. They **do not by themselves set App Store metadata, publish screenshots, choose categories, or guarantee App Store ranking**. Those items require App Store Connect work and ongoing experimentation.

## Target search intent

Prioritize readers who want understandable climate news, trustworthy environmental context, and an achievable personal response. Primary intent clusters:

- climate news and climate change news
- environmental news and sustainability news
- climate action and eco-friendly habits
- climate education and climate learning
- mindful news / constructive news

Avoid competing for broad, misleading terms such as "weather," "carbon calculator," or "breaking news" unless the product actually adds those capabilities.

## App-name recommendation

Recommended display name: **The Climate Note: Climate News**

It retains the editorial brand while adding the highest-value, truthful category phrase. At 30 characters, it fits Apple's current app-name limit; confirm trademark availability before submitting.

## Subtitle options

1. Climate news. One small action
2. Climate stories made practical
3. Understand climate. Act calmly

Use option 1 for the first launch because it combines the core content and action promise. Test the others sequentially, not concurrently, so results are interpretable.

## Keyword field strategy

Use the 100-byte keyword field for relevant terms not already repeated in the app name or subtitle. Start with a comma-separated set such as:

`environmental,sustainability,eco habits,climate action,green living,science,education`

Rules:

- Do not repeat words present in the name/subtitle; Apple can combine indexed terms across fields.
- Prefer singular roots where they cover variants; omit spaces after commas to save characters.
- Avoid competitor names, unrelated trending terms, subjective claims (for example, "best"), and terms unsupported by the app.
- Keep a dated record of every keyword change, country, and accompanying creative change.

## Alternate keyword strategy

For a later, controlled metadata test, use a more learning-led set:

`environment,climate learning,climate science,earth,conservation,eco friendly,explainer`

Run one storefront/metadata experiment at a time and leave it live long enough to collect a meaningful impression-to-download sample. Choose the winner on qualified installs and retention, not search impressions alone.

## App Store description

### Promotional opening

The Climate Note makes climate reporting easier to understand—and easier to respond to. Read a clear note on a timely story, explore its sources, then choose one small action or reflection that fits your life.

### Full description

**Climate news, without the noise.**

The Climate Note is a calm place to read climate and environmental stories with context. Each note is designed to help you understand what is happening, why it matters, and one thoughtful way to respond.

With The Climate Note, you can:

- Read clear, focused climate and environmental reporting
- Review cited sources and visit the original articles
- See clearly labeled AI-generated summaries while original articles remain unchanged
- Choose an article-specific action or write your own private reflection
- Keep a personal record of planned and completed actions
- See impact estimates only when an action has a supported, measurable factor
- Control weekly article notifications and optional action reminders

Your note is personal. Reflections, chosen actions, completion history, and impact estimates are kept private to your account. The app does not sell personal data, show behavioral ads, or use private notes to train public AI models.

The Climate Note is designed for readers age 13 and older.

Read with curiosity. Notice what matters. Take one considered next step.

## Promotional text

New climate notes pair trusted context with one small, private next step. Read, reflect, and act thoughtfully.

Refresh this field to support seasonal editorial packages or major feature launches without changing the binary. Do not use it to make unverified environmental-impact claims.

## Category recommendation

- Primary: **News**
- Secondary: **Education**

News best matches the recurring editorial reading experience; Education captures the explanatory and source-led value. Before submission, compare the competitive results and available categories in App Store Connect for each target territory. Do not choose Lifestyle merely because of the actions feature—the core job remains informed reading.

## App Tags strategy

Use App Store Connect’s available tag picker to reinforce, rather than duplicate, the page:

- Climate / Environment (if available)
- News
- Education
- Sustainability / Green Living (if available and accurately represented)

Select only tags present in App Store Connect that describe shipped functionality. Review the assigned tags in each localization; availability can vary by storefront.

## Screenshot sequence

Build the six final portrait screenshots from the deterministic DEBUG scenes at an accepted 6.9-inch size (for example, 1320 × 2868, 1290 × 2796, or 1260 × 2736 pixels). Apple currently permits one to ten screenshots, requires JPEG or PNG without alpha, and can scale the highest-resolution set down when the interface is unchanged. The project currently targets iPhone only, so iPad screenshots become required only if iPad support is added. Verify the current matrix in [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/) before upload.

Use large readable editorial headlines, the tan / dark-pine / mint system, and no tiny legal copy. The `PreviewScreenshots-v4` files are art-direction concepts, not App Store-ready evidence of the shipped binary; replace them with real Xcode Simulator or device captures after the app builds on macOS.

| Order | Headline | Screen / purpose |
| --- | --- | --- |
| 1 | **Climate news, made clear** | Feed scene: establish the calm editorial product and topic range. |
| 2 | **Understand the story in minutes** | Story scene: show readable long-form reporting and source-led context. |
| 3 | **A clear note on what matters** | Summary scene: communicate the labeled, concise explainer value. |
| 4 | **Choose one thoughtful next step** | Actions scene: show article-specific choices and the private reflection input. |
| 5 | **Keep a private record of progress** | Progress scene: show completed actions and transparent estimates. |
| 6 | **Your reflections stay yours** | Account/privacy composition: reinforce privacy, controls, and notifications. |

Keep each image focused on one promise. Make the first three screenshots independently understandable because not all visitors swipe to the end. Add localized headline overlays for every supported storefront, and verify contrast/legibility on small devices.

## Preview video storyboard (15–30 seconds)

1. **0–3s:** Feed scroll; title card: “Climate news, made clear.”
2. **3–8s:** Open a story and pause on the headline/byline/sources; title card: “Read the context.”
3. **8–13s:** Reveal the labeled summary; title card: “Understand what matters.”
4. **13–20s:** Select one practical action or type a reflection; title card: “Choose one next step.”
5. **20–26s:** Show My Note completion/progress; title card: “Keep a private record.”
6. **26–30s:** End on the masthead and app icon: “Learn. Notice. Act.”

Use real on-device capture, readable type, natural motion, and captions. Avoid claims that an action offsets emissions unless the shown estimate is explicitly qualified.

Apple currently permits up to three previews, each up to 30 seconds. The first seconds must work without sound because previews may autoplay muted. See [Apple's product-page guidance](https://developer.apple.com/app-store/product-page/).

## Icon recommendations

- Preserve the new simple, high-contrast bracket-and-horizon mark that reads at 60 px; it is stronger and more ownable than a literal notebook or leaf.
- Use near-black pine, warm ivory, and a single mint accent; avoid neon green, text, thin lines, and tiny environmental symbols.
- Test at App Store search size, on light/dark home-screen backgrounds, and beside competing News icons.
- Prepare all required opaque 1024 px artwork and platform variants; do not bake rounded corners into the supplied App Store icon.

## Ratings and review prompt strategy

Ask only after a positive, completed moment: for example, after a reader has completed two actions on separate days or has returned to read several notes. Never interrupt article reading, account deletion/export, sign-in, errors, or the first action save.

Use the native review prompt sparingly, honor platform quotas, and provide an in-app “Send feedback” route. Track prompt exposure, rating conversion where available, sentiment, and support themes. Reply to reviews in App Store Connect with a concise, human response and route bug reports to support.

## Localization opportunities

Start with metadata, screenshots, promotional text, privacy/support pages, and in-app editorial UI for markets where source coverage and support can be maintained. Candidate first expansions: English (UK), English (Australia), French (France/Canada), Spanish (Mexico/Spain), and German (Germany). Localize climate terminology and calls to action rather than translating word-for-word. Maintain human review for source names, legal/privacy text, and environmental claims.

## Deep-linking opportunities

- `climatenote://article/{slug}` or Universal Links to a published article
- `climatenote://note/{action-id}` to an existing private action only after authentication
- `climatenote://privacy` and `climatenote://support` for account/help routes
- Campaign links from newsletters, source partners, and the website with UTM parameters preserved through the web-to-app fallback

Implement Universal Links and a safe web fallback only in a later scoped source/configuration project; they require associated-domain setup, route handling, and privacy review. Do not deep-link to private content without an authenticated, permission-checked destination.

## Website-to-App-Store strategy

Create a focused landing page for each high-intent editorial theme (for example, “pharmaceutical pollution explained”) with a readable web note, citations, an explicit App Store badge, and a short explanation of the private action feature. Use campaign-tagged links, smart banner/deep-link fallback where supported, and a clear web path for visitors who do not install. Link back to the relevant in-app article after install once deep links are implemented. Keep claims and privacy language identical across web and store listings.

## Measurement plan

Track the full funnel by country, device, acquisition source, metadata/screenshot version, and app version:

| Stage | Primary measures | Decision use |
| --- | --- | --- |
| Store visibility | impressions, product-page views, search-term trends | Identify discoverability opportunities. |
| Conversion | page-view-to-download rate, first-open rate | Evaluate name, subtitle, icon, and screenshot tests. |
| Activation | first article read, source opened, action picker opened, first note saved | Verify the store promise matches onboarding. |
| Engagement | D1/D7/D30 retention, weekly note readers, completed actions | Separate durable readership from curiosity installs. |
| Trust | review rating, review themes, support tickets, privacy-setting changes | Detect misleading expectations or confidence gaps. |

Define event privacy rules before implementation: minimize data, avoid logging reflection text or identifiable private notes, document retention, and obtain any required consent. Review results monthly; change one variable per experiment and record the hypothesis, period, audience, and outcome.

## Manual App Store Connect actions

These actions cannot be completed by source code alone and must be performed manually by an authorized App Store Connect user:

1. Confirm the final app name, subtitle, primary/secondary category, age rating, support URL, marketing URL, and privacy answers.
2. Enter the selected description, promotional text, keyword set, and available App Tags for each localization.
3. Upload the validated app icon and every required screenshot size; order screenshots according to the sequence above.
4. Upload the preview video and localized poster frame/captions if used.
5. Configure pricing/availability, countries, copyright, contact information, and review notes/demo account details if applicable.
6. Complete App Privacy disclosures and verify them against the shipped Firebase/auth/analytics behavior.
7. Create and monitor Product Page Optimization or Custom Product Page tests where available; change one creative or metadata variable at a time.
8. Review App Analytics, ratings, reviews, crashes, and support feedback on a monthly cadence; update copy/creative only when supported by evidence.
