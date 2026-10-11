# Automated Content Pipeline

## Source

- Google Drive folder ID: `1t4uZLN0hnI5CUYtN0DwJKqMEecXo7IVF`
- Version 1 accepts the Microsoft Word DOCX MIME type.
- PDF and other files are ignored and recorded as unsupported, not treated as failures.
- The worker lists files through a restricted Google service account with read-only Drive scope.

## Schedule

Vercel invokes `/api/cron/ingest` once per day. The endpoint is protected by `CRON_SECRET`. Administrators also have a `Sync now` control for an immediate run.

## Initializing the complete archive

The normal cron and **Sync Drive now** action intentionally attempt only
`INGEST_MAX_DOCUMENTS_PER_RUN` new or failed documents (one by default). An approved
administrator can choose **Initialize all articles** in the admin workspace to process every eligible
DOCX currently visible to the restricted Drive service account. The operation uses the same
`drive-{fileId}` document identity and `(fileId, checksum)` ingestion job identity as routine syncs, so
running it again skips unchanged work.

For local administration, start the web app, obtain a fresh Firebase ID token for an email in
`ADMIN_EMAILS`, and run:

```powershell
$env:CLIMATE_NOTE_ADMIN_ID_TOKEN = "<fresh-admin-id-token>"
pnpm articles:initialize
```

The command targets `http://localhost:3000` by default. Remote initialization is blocked unless the
operator sets `CLIMATE_NOTE_ADMIN_URL`, sets `CONFIRM_ARTICLE_INITIALIZATION=YES`, and passes
`--allow-remote`. This is a server-side admin operation; the iPhone client never seeds Firestore.

## State machine

```text
discovered
  -> downloaded
  -> parsed
  -> enriched
  -> validated
  -> published

Any stage -> failed draft + diagnostic record
```

## DOCX parsing contract

1. Download the original bytes and compute SHA-256.
2. Skip an existing `(Drive file ID, checksum)` pair.
3. Read OOXML text directly; do not use PDF rendering or OCR.
4. Preserve paragraph text, hyperlinks, and list order.
5. Treat the first non-empty paragraph as the title unless an admin title override exists.
6. Detect headings from explicit Word styles first, then short bold/underlined paragraphs.
7. Preserve real numbered and bulleted lists.
8. Detect a final `Sources`, `References`, or citation-link block and store its links.
9. Store the original DOCX in protected Cloud Storage for audit and reprocessing.
10. Never apply grammar correction to source text.

The representative Philippines file demonstrates that rendered Word lines can visually split words while the underlying OOXML text remains intact. Direct OOXML extraction avoids importing those rendering artifacts.

## AI enrichment contract

Text generation receives the immutable article text and returns structured JSON only.

### Summary

- `problem`: plain-language description of what is happening
- `whyItMatters`: concrete human/ecological consequence
- `whatWeCanDo`: concise response grounded in the article

Each field has a strict length limit and a readability validation pass. Jargon must be defined or replaced.

### Suggested actions

Return exactly three actions. Each includes:

- short title
- one-sentence instruction
- quantity or frequency
- relevance evidence copied from a source paragraph for internal validation
- category and optional approved `factorId`
- optional measurable `factorQuantity`, accepted only for a matching approved factor
- safety and accessibility flags

Reject actions that are vague, expensive, dangerous, location-inappropriate, unverifiable, or unrelated to article evidence.

Impact arithmetic is deterministic rather than generative. Version 1 supports U.S. EPA factors for passenger-vehicle miles avoided, electricity avoided, and eligible mixed recyclables diverted from landfill. If the AI cannot map an action and a literal quantity to one of those exact units, both factor fields remain null and the app reports completion without a numerical carbon claim.

### Article imagery

The server automatically searches Pexels for licensed editorial photography. It retrieves up to 12
landscape candidates and ranks them by article relevance, 16:9 crop suitability, resolution, metadata
quality, and recent reuse. It rejects undersized files, recently reused assets, metadata that suggests
logos or watermarks, and metadata indicating recognizable people. Fully automatic publishing avoids
person-led imagery because it cannot independently verify model releases or contextual endorsement. The highest-scoring
eligible candidate becomes the cover. If it fails download or decoding, the system tries the remaining
top-three shortlist in rank order; if none clears every gate, the article publishes text-only.

The provider key is server-side only. Downloads may come only from the exact Pexels image CDN host,
with a two-redirect limit, a 12 MB transfer limit, a 30 megapixel decoded-image limit, and JPEG/PNG/WebP
content types. Every accepted file is decoded, center-cropped to 1600×900, re-encoded as a JPEG without
source metadata, and addressed by its SHA-256 content hash before storage.

The public cover keeps the photographer, Pexels source page, license link, provider asset ID, retrieval
time, crop, dimensions, and content hash. A private media record preserves the search query and selection
decision for provenance. Reprocessing preserves a valid approved cover unless its search query changes or
an administrator requests replacement. An administrator can remove a cover immediately or request a new
selection on the next ingestion run. Provider, network, validation, or storage failures preserve a valid
existing cover and otherwise fall back to text-only publishing.

Pexels images remain copyrighted and are used under the provider license; they are not described as
“copyright-free.” Attribution and provenance reduce licensing risk, while the removal control supports a
prompt takedown response. Legal approval of the provider terms and planned use remains a release gate.

## Publication gate

Automatic publication requires all of the following:

- non-empty title and article body
- stable checksum and no duplicate article
- valid block structure and source URLs
- summary schema passes
- exactly three grounded actions pass validation
- no unresolved text-enrichment provider error or safety flag

The photo provider is not a publication blocker: an image failure produces a warning and the text-only
article may still publish when every editorial and safety requirement above passes.

Otherwise the article remains a draft and the admin dashboard shows the exact failing stage.
