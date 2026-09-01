# The Climate Note

The Climate Note is a native iPhone reading and climate-action app backed by a public website, a private admin portal, and an automated Google Drive publishing pipeline.

## Product surfaces

- `apps/ios` — native SwiftUI iPhone application
- `apps/web` — public Next.js website, admin portal, and Vercel API jobs
- `firebase` — Firestore, Storage, and authentication security configuration
- `docs` — product, architecture, and publishing contracts

## Approved launch defaults

- Audience: ages 13+
- Platform: iPhone first, iOS 17+
- Pricing: free, no ads or in-app purchases
- Reading: available without an account
- Accounts: required only for private climate notes and impact tracking
- Reflections: private; no public user-generated content
- Publishing: automated from the approved Google Drive folder with validation gates
- AI: Gemini primary with Groq text fallback; article image generation is disabled for version 1
- Hosting: Vercel for the website/admin/jobs; Firebase for auth, private data, and notifications
- Support: theclimatenote@gmail.com

The original article body is immutable. AI-generated summaries and action suggestions are stored as separate derivative records.

## Development setup

Requirements:

- Node.js 22 (see `.node-version`)
- Corepack and pnpm 11
- Xcode 26.2 or later for iOS development
- Ruby with the `xcodeproj` gem only when regenerating the Xcode project

```bash
corepack enable
pnpm install --frozen-lockfile
pnpm test
pnpm typecheck
pnpm lint
```

Open `apps/ios/ClimateNote.xcodeproj` in Xcode. Firebase and Google Sign-In are resolved with
Swift Package Manager. Production secrets stay in Vercel and are never committed to this repository.

See `CONTRIBUTING.md` for the team workflow and `docs/TEAM_OPERATIONS.md` for service access and releases.
