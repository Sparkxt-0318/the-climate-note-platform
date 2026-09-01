# The Climate Note — Version 1 Product Specification

## Product promise

The Climate Note helps young readers understand one climate issue at a time and turn that understanding into one specific, achievable action.

## Audience and distribution

- Primary audience: middle-school through college-age readers
- Launch age floor: 13+
- Launch language: English
- Initial device family: iPhone
- Minimum deployment target: iOS 17
- Business model: free, without advertising, subscriptions, or in-app purchases

## Core experience

### Home

- Feature the newest weekly article.
- Show recent articles and lightweight topic filters.
- Display reading time and publication date.
- Permit complete guest access to published articles.

### Article

Display content in this order:

1. Title, author when supplied, publication date, and reading time
2. Immutable article body and source links
3. `The climate note` AI summary card:
   - What is happening?
   - Why is it a problem?
   - What can we do?
4. `Write your climate note!` action area:
   - Three article-specific suggested actions
   - One private custom note/action option

AI content must never replace, rewrite, silently correct, or append to the original article body.

### Impact

- Record self-reported completion of selected actions.
- Show a seven-day calendar with green completion states.
- Show habit streaks.
- Display numerical impact only when a versioned, cited factor supports the calculation.
- Label all numerical results as estimates.
- Fall back to completion-only tracking when no defensible factor exists.

### Profile and settings

- Sign in with Apple
- Sign in with Google
- Sign out
- Notification preferences
- Privacy policy and support contact
- Export private data
- Delete account and associated private data in the app

## Privacy defaults

- Reading does not require an account.
- Climate notes and completion history are private to their owner.
- No public profiles, comments, rankings, or social feed are included.
- No advertising SDKs are permitted.
- Private note text is not sent to a free-tier AI provider.
- Only the minimum account data needed for authentication and synchronization is stored.

## Notifications

- Weekly new-article notification: optional and off until permission is granted
- Action reminder: optional, user-scheduled, and local-first
- No promotional notifications

## Design system

The visual system uses Apple-native layout and interaction patterns with restrained Climate Note branding.

- Primary sage: `#5A8871`
- Pale sage: `#B4CEB6`
- Charcoal: `#404949`
- Warm background: `#F7F8F5`
- White surface: `#FFFFFF`
- Typography: Apple system type with Dynamic Type support
- Motion: short, interruptible transitions; Reduce Motion respected
- Controls: minimum 44-point touch targets
- Accessibility: VoiceOver labels, sufficient contrast, scalable text, descriptive image alt text

## Version 1 exclusions

- iPad-specific layout
- Public user-generated content
- Automated posting to Instagram, Medium, or Substack
- Paid content
- Advertising
- Social leaderboards
- PDF ingestion
- Article image search or generation

External publication URLs remain optional metadata fields on an article.

## Product acceptance criteria

- A reader can install the app, read every article, and follow sources without creating an account.
- Apple and Google authentication complete inside the native app flow and return to the app.
- Deleting an account removes private profile, note, and completion data.
- An eligible DOCX added to the Drive folder becomes a validated article without copying text manually.
- A failed ingestion cannot publish a partial or malformed article.
- The article body stored after ingestion matches the DOCX paragraph text.
- Every AI action is specific, measurable, related to article evidence, and safe for a young audience.
