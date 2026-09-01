# System Architecture

## Deployment decision

Use Vercel for the public website, admin portal, API endpoints, and daily ingestion trigger. Use Firebase for native authentication, Firestore, Cloud Storage, administrator claims, and push-notification integration.

This split keeps the public Next.js application simple while preserving first-class native Apple/Google authentication for iOS. The ingestion workload is small enough for a daily Vercel Hobby cron and a five-minute function window. The code isolates jobs so they can move to Cloud Run without changing the app if volume grows.

## Repository layout

```text
apps/
  ios/       SwiftUI application and Xcode project
  web/       Next.js website, admin portal, and API routes
firebase/    Firestore indexes/rules and Storage rules
docs/        Product and operational contracts
```

## Trust boundaries

```text
iPhone / Browser
        |
        | Firebase ID token or public read
        v
Next.js API routes -------- Firebase Admin SDK -------- Firestore / Storage
        |
        +-------- Google Drive API
        +-------- Gemini API
        +-------- Groq API
```

Provider credentials exist only in Vercel encrypted environment variables. No AI, Drive, or administrative secret is compiled into the iPhone app or sent to a browser.

## Firestore model

### `articles/{articleId}`

- `slug`, `title`, `author`, `excerpt`
- `status`: `draft | validating | ready | published | failed | archived`
- `contentBlocks`: immutable parsed blocks
- `plainText`, `wordCount`, `readingMinutes`
- `sourceFileId`, `sourceFileName`, `sourceModifiedTime`, `sourceChecksum`
- `sourceLinks[]`
- `publishedAt`, `createdAt`, `updatedAt`
- `externalLinks`: optional Instagram, Medium, Substack URLs
- `generationId`: pointer to the auditable derivative record
- denormalized approved `generation` snapshot used by the public web and iPhone clients

### `articleGenerations/{generationId}`

- `articleId`, `articleChecksum`
- `summary.problem`, `summary.whyItMatters`, `summary.whatWeCanDo`
- `suggestedActions[3]`
- `provider`, `model`
- `promptVersion`, `createdAt`, `validationResults`

Keeping this separate prevents AI output from mutating source content and makes regeneration auditable.

### `users/{uid}`

- `displayName`, `email`, `providerIds[]`
- `role`: `reader | editor | admin`
- notification preferences
- `createdAt`, `updatedAt`, `deletionRequestedAt`

### `users/{uid}/actionLogs/{logId}`

- `articleId`, `suggestedActionId` or private `customText`
- `status`: `planned | completed`
- private action/reflection text, article identity, and category
- optional deterministic impact estimate with factor identity and methodology
- `completedAt`, `createdAt`

### `impactFactors/{factorId}`

- canonical action and category
- input unit and output unit
- factor value, geography, valid dates
- citation URL, publisher, version, uncertainty note

### `ingestionJobs/{jobId}`

- Drive file identity, source checksum, state, attempts
- timestamps, validation errors, provider usage, final article ID

## Authorization

- Published articles and approved media are publicly readable.
- Drafts, jobs, audit logs, and generation metadata require editor/admin claims.
- User profile, note, and completion paths are readable and writable only by their owner and narrowly scoped server operations.
- Role changes require Firebase Admin privileges.
- Administrative mutations require a verified Firebase ID token and an admin custom claim.

## Reliability

- Source checksum makes ingestion idempotent.
- Each stage records its status before advancing.
- Provider calls have bounded retries and timeouts.
- Gemini failures fall back to Groq for text.
- Image search failures fall back to Cloudflare generation.
- Validation failure creates a draft and never publishes.
- Published articles continue working when every external AI provider is unavailable.
