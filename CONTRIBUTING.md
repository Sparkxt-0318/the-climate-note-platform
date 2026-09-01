# Contributing to The Climate Note

Thank you for helping build The Climate Note. This repository contains a native iPhone app and a
Next.js website/backend. Keep changes small, reviewable, and safe for the production audience.

## First-time setup

1. Clone the repository.
2. Install Node.js 22, enable Corepack, and run `pnpm install --frozen-lockfile`.
3. Copy `apps/web/.env.example` to `apps/web/.env.local` only if you need local backend access.
4. Ask a project administrator for development-only credentials through an approved password
   manager. Never request or share secrets in GitHub issues, pull requests, chat, or source files.
5. Open `apps/ios/ClimateNote.xcodeproj` and allow Xcode to resolve Swift packages.

Guest reading and most UI work should remain possible without production credentials.

## Workflow

1. Start from an updated `main` branch.
2. Create a short-lived branch such as `feature/bookmarks`, `fix/article-layout`, or
   `docs/editor-guide`.
3. Make one focused change and add or update tests.
4. Run `pnpm test`, `pnpm typecheck`, `pnpm lint`, and `pnpm build`.
5. For iOS changes, build and run the app in an iPhone simulator and test authentication changes on
   a physical device when applicable.
6. Open a pull request using the repository template. Do not merge your own change without review.
7. Merge only after required checks pass. Delete the branch after merging.

## Product safeguards

- Never rewrite the editor-approved article body with AI.
- Keep AI summaries and action suggestions clearly labeled and separate.
- Do not send private reflections to article-enrichment providers.
- Do not add advertising, tracking, public profiles, or public user content without an approved
  product and privacy review.
- Numerical climate-impact claims require a versioned, cited deterministic factor.
- Article imagery is disabled for version 1.

## Release discipline

- Web production deploys from `main` through Vercel after review.
- iOS releases require a version/build increment, TestFlight smoke test, App Store metadata review,
  and explicit approval from an App Store Connect App Manager or Account Holder.
- Tag approved releases as `vMAJOR.MINOR.PATCH` after the App Store build is accepted.
