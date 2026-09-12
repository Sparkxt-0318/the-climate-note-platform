# Community impact

The native **Our Impact** tab shows the all-time accumulation of self-reported
completed actions, including custom actions. A separate carbon estimate includes
only completions whose article action maps to the server's supported EPA catalog.
This is not a verified emissions reduction, offset, or leaderboard.

## Counting and privacy

- Only `completed` records with matching owner/path and valid creation/completion
  timestamps count. Planned, malformed, and future-dated records do not count.
- One user/article/action/UTC completion day counts once, even if saved repeatedly.
  Different days and different users count separately. Custom actions from the
  same article/day also count once. This is intentional duplicate protection,
  not proof that users actually performed the activity.
- Server calculations use article action quantities, never user-written impact
  values. Unsupported/custom actions still count as participation, not carbon.
- The job selects identifiers/status/timestamps only; no reflection text or
  names are read or published. Its public result has only aggregate values,
  schema version, and refresh time. Private Firestore rules remain unchanged.
- Rebuilding removes deleted history at the next refresh. Totals can decrease
  after deletions, corrections, or changed article factors. Retained article
  templates are used for historical records; this is a current-factor estimate,
  not an immutable historical carbon ledger.

## Backend and release

1. Deploy the web backend through the existing GitHub/Vercel workflow.
2. The existing authenticated daily `/api/cron/ingest` also refreshes impact,
   independently of Drive/AI success. No second paid/extra cron is required.
3. Initialize immediately with authenticated administrator `POST /api/admin/impact`
   (Firebase ID token, same admin authorization as other admin routes), or wait
   for the first scheduled run. No credentials belong in GitHub.
4. Verify public `GET /api/impact/community` returns a 200 snapshot. Before
   initialization or during configuration failure it returns 503, never fake
   zero totals. The app shows retry/unavailable states.
5. Test the native Our Impact tab on device, then archive a **new build number**
   for an App Store update. A GitHub push does not update installed iPhone apps.
   Review updated privacy-policy language and App Store disclosures for release.

Snapshots live at `publicStats/communityImpact`, server-write-only and served via
the API. Clients cannot write totals or read other users' action logs. The public
API reads one snapshot and uses a five-minute CDN cache; pull-to-refresh does not
rescan private data. The app shows the snapshot timestamp and daily refresh note.
The job paginates all historical logs in 1,000-document batches, writes only after
a successful full scan, retains the previous snapshot on failure, and prevents an
older overlapping job from replacing a newer snapshot. This scan is not an atomic
point-in-time database snapshot; writes during a run appear by the next daily run.

## Tests and scaling

Vitest covers cross-user totals, custom actions, duplicate saves, repeated days,
untrusted impact values, invalid records, deletions, and public schema stripping.
XCTest covers snapshot decoding and invalid totals. No new AI calls are required.

Daily rebuild reads each action-log document and each article once. Monitor
Firestore read cost and cron failures as usage grows. A 240-second scan budget
fails without publishing partial totals; migrate to event-driven, transactional
aggregation plus reconciliation before the full scan exceeds the job budget.
Current completions remain self-reported and owner-editable; filtering and
deduplication are not anti-fraud verification. Do not use these totals for carbon
credits or externally audited impact claims.
