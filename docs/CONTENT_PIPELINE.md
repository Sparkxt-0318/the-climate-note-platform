# Automated Content Pipeline

## Source

- Google Drive folder ID: `1t4uZLN0hnI5CUYtN0DwJKqMEecXo7IVF`
- Version 1 accepts the Microsoft Word DOCX MIME type.
- PDF and other files are ignored and recorded as unsupported, not treated as failures.
- The worker lists files through a restricted Google service account with read-only Drive scope.

## Schedule

Vercel invokes `/api/cron/ingest` once per day. The endpoint is protected by `CRON_SECRET`. Administrators also have a `Sync now` control for an immediate run.

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

Article image search and generation are disabled for the initial App Store release. Articles publish
with their editor-approved text, AI summary, and grounded action suggestions, but without a cover or
inline image. A future release can reintroduce imagery after editorial relevance review is available.

## Publication gate

Automatic publication requires all of the following:

- non-empty title and article body
- stable checksum and no duplicate article
- valid block structure and source URLs
- summary schema passes
- exactly three grounded actions pass validation
- no provider error or unresolved safety flag

Otherwise the article remains a draft and the admin dashboard shows the exact failing stage.
