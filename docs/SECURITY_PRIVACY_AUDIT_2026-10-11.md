# The Climate Note — Security, Privacy, and Legal Readiness Audit

**Assessment date:** October 11, 2026

**Scope:** repository source, local build/test configuration, iOS client, Next.js website and APIs, Firebase Functions, Firestore rules/indexes, dependency graph, public privacy/support copy, and store-facing source artifacts.

**Assessment type:** authorized, non-destructive source and local-runtime review. No production system or real user data was accessed.

This report is engineering and compliance-readiness work, not legal advice, a penetration-test certificate, or a guarantee of security. Production Firebase/Vercel configuration, provider contracts, store-console declarations, runtime data, logs, backups, and deployed rules were not accessible and remain explicitly unverified.

## A. Executive security summary

The repository is materially safer after this pass. The most urgent confirmed issue was a production dependency graph containing a critical Next.js advisory plus several high-severity transitive advisories. The affected packages were upgraded or safely overridden, and the final online production audit reported **0 critical, 0 high, 1 moderate** advisory. Authentication and authorization already used revocation-checked Firebase bearer tokens and owner-scoped Firestore paths, but administrative email authorization accepted an unverified email claim, sensitive endpoints had no rate/request-size controls, Firestore accepted overly broad owner writes, deletion did not purge account-scoped local drafts, and API errors disclosed internal exception messages.

Those issues were remediated in source. Security headers, bounded streaming input, HTTPS-only links, server-side rate limits, recent-authentication checks, expanded data export, local protected-file cleanup, Firestore field/state validation, server-only aggregate collections, dependency gates, and CI coverage were added. Independent reviewers found and rejected three first-pass regressions: the CSP blocked Firebase Google sign-in, the JSON limit buffered the whole body, and HTTP citations could be published then fail strict reads. Each was corrected and regression-tested.

The current engineering posture is **moderate residual risk, not release-approved yet**. Release blockers are external: compile and exercise Firestore rules in an emulator and deploy them; run the iOS suite on macOS/device; verify deletion and export against a staging Firebase project; verify Google and Apple sign-in under the production CSP; enable/configure Firebase App Check; confirm provider retention, data-processing terms, and international-transfer mechanisms; reconcile App Store Connect privacy answers; and obtain legal review for jurisdiction, children/teen use, privacy notice, and terms.

### Final disposition

| Category | Meaning |
|---|---|
| Verified fixed locally | Regression test, typecheck/build, or local runtime evidence exists. |
| Implemented; external verification required | Source fix exists, but Firebase, Apple, or deployment behavior cannot be proven locally. |
| Mitigated but not eliminated | Residual framework/dependency risk remains. |
| Open / requires owner action | Needs external configuration, operational evidence, or legal decision. |

No cross-user data access, arbitrary code execution, XSS sink, SSRF bypass, committed private key, or exposed server credential was confirmed in the reviewed source. This is not proof that none exists in production or repository history.

## B. Architecture and threat model

### System map

| Component | Role | Sensitive assets | Primary controls |
|---|---|---|---|
| SwiftUI iOS app | Article reading, federated/guest auth, private reflections/actions, reminders, export/delete | ID tokens, UID/email/provider profile, reflections, action history, local drafts, notification state | iOS sandbox, complete file protection, backup exclusion, Firebase Auth, Firestore rules, explicit destructive confirmation |
| Next.js 16 web app | Public publication, admin UI, account APIs, ingestion APIs | Admin tokens, user export/delete operations, article/admin data, service credentials in environment | Revocation-checked bearer tokens, verified admin allowlist/custom claim, validation, rate limits, CSP/security headers |
| Firebase Auth | Apple, Google, and anonymous identities | UID, provider metadata, auth/refresh state | Provider authentication, token signature/expiry, revocation checks, recent-auth enforcement for deletion |
| Firestore | Articles, user profile/action data, impact preferences and aggregates | Private notes/actions, preferences, internal receipts/contributors/jobs | Owner-scoped rules, server-only internal collections, schema/state constraints, Admin SDK boundary |
| Firebase Functions | Reconciles opt-in community impact | UID-linked receipts, contributors, job cursors, aggregate | Server credentials, idempotent transactions, source-of-truth factor validation, post-success job deletion |
| Google Drive | Editor-controlled DOCX source | Source documents and metadata | Read-only service account scope, folder selection, size/count limits |
| Gemini or Groq | Article-only summary/actions | Public/editorial article text | No private reflection path, strict output schema, exact-sentence grounding for actions |
| Pexels + Vercel Blob | Licensed cover discovery/storage | Editorial query, licensed image, attribution | Exact-host allowlist, manual redirect validation, byte/pixel limits, metadata stripping, provenance |
| Vercel / Firebase hosting | Web/API/function execution and logs | Request metadata, operational logs, deployed secrets | Platform controls; production settings and retention not inspected |

### Trust boundaries and data flows

1. **Untrusted public browser → public Next pages:** only published article data should cross this boundary.
2. **Authenticated iOS/admin client → Firebase or Next APIs:** bearer tokens are attacker-controlled input until verified; UID/resource ownership must come from the verified token, never the request body.
3. **Next/Firebase Functions → Admin SDK:** bypasses Firestore client rules and is therefore a privileged boundary requiring endpoint authorization and bounded input.
4. **Editor Drive documents → parser/AI/media pipeline:** DOCX, links, provider responses, and AI output are untrusted even though the Drive folder is controlled.
5. **Backend → third parties:** editorial article text goes to configured AI providers; article topics go to Pexels; private reflections must never enter either flow.
6. **Private per-user data → anonymous aggregate:** server code must recompute eligibility and amounts, enforce opt-in, suppress small cohorts, and remove contributions on opt-out/deletion.
7. **Device local storage → share sheet/deletion:** unfinished text and exports require device protection, backup exclusion, explicit sharing, and account-scoped purge.

### Principal threat actors and scenarios

| Actor | Goal | Important attack paths | Result after remediation |
|---|---|---|---|
| Unauthenticated internet attacker | Abuse APIs, leak errors, frame site, exploit dependency | Missing auth, oversized body, vulnerable Next, absent headers | Auth required; critical/high dependency advisories removed; bounded bodies and headers added |
| Authenticated malicious user | Read another account, poison data, inflate aggregate, exhaust storage | IDOR, broad Firestore writes, client-provided impact | Owner rules; exact schemas; immutable identity fields; server factor validation; App Check still open |
| Compromised admin account | Publish/change content, trigger costly ingestion | Email spoofing, excessive ingestion, unsafe links/media | Verified email/custom claim; rate limits; HTTPS validation; media allowlist; MFA/claim governance external |
| Malicious/compromised provider response | SSRF, decompression bomb, unsafe image, injected AI output | Redirects, huge bodies/pixels, invalid JSON | Exact hosts/manual redirects; byte/pixel limits; re-encode; strict AI schema |
| Stolen bearer token | Export/delete account | Long-lived/revoked token, no step-up | Revocation checks; recent provider reauth or fresh anonymous token; confirmation header; rate limit |
| Insider/provider | Excess collection or retention | Logs/backups/contracts, broad service roles | Minimized code paths and clearer notice; contracts, console settings, and retention remain unverified |

## C. Vulnerability report

### Summary table

| ID | Severity | Finding | Status |
|---|---|---|---|
| SEC-001 | Critical | Critical/high production dependency advisories | **Verified fixed locally**; one moderate remains |
| SEC-002 | Medium | Firestore owner writes lacked schema/state integrity | **Implemented; external verification required** |
| SEC-003 | High | Account deletion lacked recent-auth assurance and local draft purge | **Implemented; external verification required** |
| SEC-004 | Medium | Sensitive/admin endpoints lacked rate and request-size limits | **Verified fixed locally** |
| SEC-005 | Medium | Raw server errors and cacheable sensitive responses | **Verified fixed locally** |
| SEC-006 | Medium | Missing browser security headers | **Verified fixed locally**; CSP has documented residual |
| SEC-007 | Medium | Ingestion accepted unbounded/inconsistent untrusted content | **Verified fixed locally** |
| SEC-008 | Medium | Admin email allowlist did not require verified email | **Verified fixed locally** |
| SEC-009 | Medium | Account export/deletion and privacy disclosure were incomplete | **Implemented; legal/external verification required** |
| SEC-010 | Medium | Completed reconciliation jobs retained raw UID/cursor | **Verified fixed in source**; staging trigger test required |
| SEC-011 | Medium | Security regressions and vulnerable dependencies lacked CI gates | **Implemented; GitHub execution unverified** |
| SEC-012 | Medium | `sprintf-js` transitive DoS advisory remains | **Mitigated, open upstream** |
| SEC-013 | Medium | Firebase App Check/abuse attestation not configured | **Open** |
| SEC-014 | Medium | Jurisdiction, retention, children, transfer, and controller disclosures incomplete | **Requires legal review** |
| SEC-015 | Low | Accessibility conformance not formally verified | **Open** |
| SEC-016 | Low | Full git-history secret scan and deployed-secret review not performed | **Requires external verification** |

### SEC-001 — Critical/high production dependency advisories

- **Location:** `apps/web/package.json`, `functions/package.json`, `pnpm-lock.yaml`, `pnpm-workspace.yaml`
- **Description:** the initial online production audit identified a critical Next.js advisory and high-severity issues in Next.js, Sharp, gRPC, node-forge, and Undici dependency paths.
- **Impact:** depending on the advisory and reachable code path, remote compromise, SSRF/cache manipulation, denial of service, or cryptographic weakness.
- **Evidence:** baseline `pnpm audit --prod --json`; lock-graph inspection; successful build after upgrades.
- **Root cause:** pinned vulnerable versions and vulnerable transitives without an enforced audit gate.
- **Remediation:** upgraded Next `16.3.3 → 16.3.8`, Firebase web/admin, Firebase Functions, Sharp, Mammoth, sanitize-html, and Vercel Blob; added narrowly scoped overrides for vulnerable gRPC, brace-expansion, Sharp, source-map-js, Undici, and UUID ranges.
- **Verification:** final online production audit reported 0 critical, 0 high, 0 low, and 1 moderate advisory; web/functions tests, typechecks, and web production build passed.
- **Status:** **Verified fixed locally** for critical/high advisories. Re-run the audit in CI and before release.

### SEC-002 — Firestore owner writes lacked schema/state integrity

- **Location:** `firestore.rules`
- **Description:** owner authorization existed, but a user could previously write arbitrary profile/action-log fields and inconsistent state. The unused legacy `notes` collection was an unbounded write surface.
- **Impact:** corrupted private records, abusive storage, misleading completion state, attempted role field manipulation, and aggregate-processing edge cases. No cross-user read/write was confirmed.
- **Evidence:** original rules allowed `read, create, update` on the user document and `read, write` on action logs/notes based only on UID ownership.
- **Root cause:** authorization without schema and state-transition validation.
- **Remediation:** exact-key/type/length checks; role creation/update restrictions; email tied to token claim; immutable article/action identity; valid planned/completed transitions; server-only aggregate collections; exact impact preference shape; legacy notes made read-only.
- **Verification:** manual rule review and client-write compatibility review. The rule file could not be compiled in the Firebase emulator because Firebase CLI/modern Java were unavailable.
- **Status:** **Implemented; external verification required.** Emulator tests and staging deployment are release blockers.

### SEC-003 — Account deletion lacked recent-auth assurance and local purge

- **Location:** `apps/web/app/api/account/delete/route.ts`, `apps/web/lib/http/security.ts`, `apps/ios/ClimateNote/Services/AuthService.swift`, `DraftOperationStore.swift`
- **Description:** a valid bearer token could delete an account without step-up age checks; account-scoped protected drafts/retries survived successful server deletion.
- **Impact:** a stolen token could cause destructive account loss, and supposedly deleted writing could remain locally.
- **Evidence:** source trace of the original endpoint and device archive lifecycle.
- **Root cause:** deletion relied only on ordinary bearer authentication and server cleanup.
- **Remediation:** explicit confirmation header; revocation-checked token; five-minute provider reauthentication or fresh anonymous token; forced token refresh in the client; provider token revocation/disconnect; recursive server deletion; local account-scoped purge; messaging token deletion.
- **Verification:** recent-auth unit tests cover federated and anonymous cases; local purge regression test was added; TypeScript tests/typecheck pass.
- **Status:** **Implemented; external verification required** on iOS and staging providers. Apple token revocation happens before server deletion, so a transient server failure may require the user to authorize again; no data is silently reported as deleted.

### SEC-004 — No rate/request-size controls

- **Location:** account/admin API routes and `apps/web/lib/http/security.ts`
- **Description:** authenticated users/admins could repeatedly invoke export, deletion, reads, writes, and costly Drive/AI ingestion; JSON body limits initially buffered the full body.
- **Impact:** resource exhaustion, third-party cost amplification, and avoidable availability risk.
- **Evidence:** endpoint enumeration and independent critic reproduction of the whole-body buffering flaw.
- **Root cause:** no shared API-abuse control.
- **Remediation:** transactional fixed-window per-user limits; 8 KiB JSON cap; content-type enforcement; declared-length precheck; streaming cancellation at the byte cap; TTL field policy for limit records.
- **Verification:** unit tests for window behavior, valid JSON, and undeclared-length oversized bodies; 429/413 safe responses inspected.
- **Status:** **Verified fixed locally.** Firestore TTL policy activation remains deployment verification.

### SEC-005 — Raw errors and sensitive response caching

- **Location:** all account/admin/cron routes
- **Description:** original routes returned internal exception messages and did not consistently prohibit caching of exports/errors.
- **Impact:** information disclosure and persistence of sensitive responses in intermediary/client caches.
- **Evidence:** direct source review; baseline account routes returned `error.message`.
- **Root cause:** route-specific ad hoc error handling.
- **Remediation:** shared safe public errors/codes; `Cache-Control: no-store, max-age=0`; `Pragma: no-cache`; attachment response for export.
- **Verification:** local Next runtime probe returned generic unauthenticated errors and no-store headers.
- **Status:** **Verified fixed locally.**

### SEC-006 — Missing browser security headers

- **Location:** `apps/web/next.config.ts`
- **Description:** no CSP, HSTS, frame restriction, nosniff, referrer, permissions, COOP, or CORP policy existed.
- **Impact:** weaker defense against script injection, clickjacking, MIME confusion, referrer leakage, and unnecessary browser capabilities.
- **Evidence:** baseline config and live-header comparison.
- **Root cause:** security headers were never configured.
- **Remediation:** route-wide headers and an allowlist matched to Firebase sign-in and approved media. Independent review caught and corrected a CSP that omitted `https://apis.google.com` and would have broken Firebase Google popup auth.
- **Verification:** production build and local `/privacy` header probe passed.
- **Status:** **Verified fixed locally.** `unsafe-inline` remains for current Next rendering compatibility; nonce-based CSP is a future hardening item. Production Google sign-in must be exercised.

### SEC-007 — Unbounded/inconsistent ingestion inputs

- **Location:** Drive/DOCX pipeline, article schema, media download/image normalization
- **Description:** large source/provider bodies and very large parsed content were insufficiently bounded; HTTP citations could be published but then rejected by strict article reads; external image handling needed explicit SSRF/decompression controls.
- **Impact:** memory/CPU exhaustion, feed failure from malformed published data, unsafe redirects, or image parser abuse.
- **Evidence:** source path analysis; critic demonstrated parser/schema inconsistency.
- **Root cause:** validation occurred at different layers with inconsistent policies.
- **Remediation:** 10 MB DOCX streaming cap, 1,000-source cap, 20,000-word/500-block/100-link bounds, strict article schema, HTTPS-only source/external/media URLs, warning and omission of insecure citations, exact Pexels image host across manual redirects, 12 MB download cap, 30 MP decode cap, metadata-stripping re-encode.
- **Verification:** ingestion, media policy/download/image, and insecure-citation tests pass; build/typecheck pass.
- **Status:** **Verified fixed locally.** Existing production documents should be migrated/validated before strict code is deployed.

### SEC-008 — Admin allowlist accepted unverified email

- **Location:** `apps/web/lib/auth/verify-admin.ts`
- **Description:** an allowlisted email claim was accepted without checking `email_verified`.
- **Impact:** if an identity provider/token path supplied an unverified matching email, administrative access could be granted.
- **Evidence:** original authorization predicate.
- **Root cause:** email ownership and token validity were conflated.
- **Remediation:** admin custom claim remains authoritative; email allowlist now requires `email_verified === true`.
- **Verification:** source review and TypeScript checks. Tokens are verified with revocation enabled.
- **Status:** **Verified fixed locally.** Prefer custom claims plus enforced administrator MFA in Firebase/IdP operations.

### SEC-009 — Incomplete export/deletion disclosure

- **Location:** account export API, iOS Account/Auth/Draft views/services, privacy page
- **Description:** export omitted provider metadata and UID-linked impact records; UI called a server-only export “all private data”; privacy copy did not accurately describe local drafts, queued impact removal, provider profile data, or all processors.
- **Impact:** incomplete data-subject response and misleading user expectation.
- **Evidence:** field-by-field inventory against export payload and local archive.
- **Root cause:** product behavior expanded without synchronized privacy/export scope.
- **Remediation:** export now includes sanitized Firebase account/provider metadata, synced notes/actions/preferences, security-limit metadata, impact receipts/contributor/pending reconciliation; UI says “synced account data”; policy names local-only exclusions, deletion behavior, profile data, Gemini/Groq, Pexels, Vercel, and provider retention uncertainty.
- **Verification:** route typecheck/build; copy parity validators; manual inventory review.
- **Status:** **Implemented; legal/external verification required.** Local-only unfinished drafts are disclosed but not portable in the server export. Counsel must approve the notice and decide whether an in-app local export is required.

### SEC-010 — Reconciliation jobs retained raw identity

- **Location:** `functions/src/index.ts`
- **Description:** completed jobs retained raw UID, run ID, and cursor indefinitely.
- **Impact:** unnecessary persistence of linkable operational metadata after work completed.
- **Evidence:** completed jobs were only marked with `completedAt`.
- **Root cause:** deduplication record doubled as permanent history.
- **Remediation:** malformed jobs and successfully completed idempotent jobs are deleted immediately; pending jobs retain identity only while needed.
- **Verification:** Functions unit tests/typecheck pass; source path review confirms deletion is after successful processing.
- **Status:** **Verified fixed in source; staging trigger/retry test required.**

### SEC-011 — Missing CI security/regression gates

- **Location:** `.github/workflows/ci.yml`, `.github/dependabot.yml`
- **Description:** no repository workflow enforced production audit, build, tests, lint, or Functions checks.
- **Impact:** vulnerable dependencies and security regressions could merge unnoticed.
- **Evidence:** baseline workflow inventory.
- **Root cause:** local-only verification.
- **Remediation:** read-only, SHA-pinned GitHub Actions; frozen install; high-severity production audit; web test/typecheck/lint/build; Node 22 Functions test/typecheck; weekly npm/actions Dependabot.
- **Verification:** YAML/source review; equivalent local commands passed.
- **Status:** **Implemented; GitHub execution unverified.** Branch protection and required status checks must be configured externally.

### SEC-012 — Remaining `sprintf-js` advisory

- **Location:** `mammoth → argparse → sprintf-js 1.0.3`
- **Description:** the final audit reports a moderate unbounded-precision format-string denial-of-service advisory. The advisory claims a fixed version not published in the registry at assessment time.
- **Impact:** CPU/memory denial of service if attacker-controlled format strings reach the vulnerable formatter.
- **Evidence:** final online production audit and registry resolution attempts.
- **Root cause:** unresolved transitive upstream dependency.
- **Remediation:** no forced nonexistent override. The application invokes Mammoth as a library, does not expose its CLI formatter, and bounds DOCX size/count/content before further processing.
- **Verification:** lock graph and reachable application call path reviewed; ingestion tests pass.
- **Status:** **Mitigated, not eliminated.** Monitor Mammoth/argparse and replace/upgrade when a real patched graph exists.

### SEC-013 — Firebase App Check absent

- **Location:** Firebase/iOS/web deployment configuration
- **Description:** authenticated and anonymous client traffic is not attested with App Check in reviewed source/config.
- **Impact:** scripted clients can create guest accounts and exercise permitted Firestore operations, increasing abuse/cost risk even though they cannot cross UID boundaries.
- **Evidence:** no App Check SDK/enforcement configuration found; production console inaccessible.
- **Root cause:** abuse attestation was not included in the repository setup.
- **Remediation:** configure App Attest/DeviceCheck for iOS and reCAPTCHA Enterprise or appropriate web provider, monitor metrics, then enforce on Firestore/Auth-supported surfaces after staged rollout.
- **Verification:** console enforcement and rejected synthetic unattested request.
- **Status:** **Open; owner/platform action required.**

### SEC-014 — Legal/privacy program gaps

- **Location:** privacy page, store metadata, operational/provider records
- **Description:** operator legal identity/location, lawful bases, detailed rights/appeal/complaint routes, international transfers, processor agreements, exact retention schedules, backup deletion, incident response, jurisdiction/user-volume facts, and teen/child strategy are not evidenced.
- **Impact:** privacy notice or operations may not meet applicable law/store requirements.
- **Evidence:** repository policy compared with official sources; no contracts, records of processing, console answers, or business facts available.
- **Root cause:** technical policy copy exists without a completed legal/operational privacy program.
- **Remediation:** counsel-led applicability assessment; data-processing/transfer agreements; retention schedule; DSR and incident runbooks; age/territory strategy; store disclosure reconciliation.
- **Verification:** signed-off records, console screenshots/exports, tabletop exercise, and periodic review.
- **Status:** **Requires legal review.**

### SEC-015 — Accessibility not formally verified

- **Location:** iOS and web user interfaces
- **Description:** semantic controls, Dynamic Type/VoiceOver labels, visible tab labels, contrast-aware design tokens, and keyboard-friendly web elements exist, but no complete WCAG 2.2 AA or assistive-technology audit was run.
- **Impact:** users may encounter inaccessible flows; legal applicability varies by jurisdiction/entity.
- **Evidence:** source review only; no VoiceOver/Switch Control/device run or automated web accessibility report in this environment.
- **Root cause:** visual/feature validation was not paired with formal accessibility conformance testing.
- **Remediation:** run axe plus keyboard/zoom/reflow testing on web and VoiceOver/Dynamic Type/Reduce Motion/Switch Control tests on iOS; remediate and document results.
- **Verification:** issue log and human assistive-technology retest.
- **Status:** **Open.**

### SEC-016 — Secret/deployment review incomplete

- **Location:** git history, Vercel/Firebase/GitHub settings
- **Description:** tracked-source filename/pattern review found no private credential literal, but dedicated secret scanners were unavailable and production secret stores/history were not accessible.
- **Impact:** an old or externally configured secret could remain exposed or over-privileged.
- **Evidence:** tracked-file search, `.gitignore`, `.env.example`, and expected public Firebase plist review; no gitleaks/trufflehog/osv-scanner installed.
- **Root cause:** tooling and external-console access limits.
- **Remediation:** run gitleaks over full history in CI; inventory/rotate credentials; use least-privilege service accounts; verify GitHub/Vercel/Firebase environment scopes and audit logs.
- **Verification:** scanner artifacts and provider-console review without printing secret values.
- **Status:** **Requires external verification.**

## D. Code changes

Security-relevant changes are concentrated in:

- `apps/web/lib/http/security.ts` and tests — safe errors, no-store JSON, bounded streaming JSON, safe IDs, recent auth, rate limits.
- Account/admin/cron route handlers — consistent authentication, authorization, limits, validation, and response policy.
- `apps/web/lib/auth/verify-user.ts` / `verify-admin.ts` — revocation and verified-admin identity.
- `firestore.rules` / `firestore.indexes.json` — owner schema/state validation, server-only collections, TTL field policy, legacy note write closure.
- `apps/web/lib/articles/schema.ts` and ingestion/media modules — bounded content, HTTPS URLs, exact provider hosts, safe image decode/re-encode.
- `apps/web/next.config.ts` — CSP and security headers compatible with Firebase Google popup auth.
- `apps/ios/ClimateNote/Services/AuthService.swift` / `DraftOperationStore.swift` — provider step-up/revocation, protected exports, backup exclusion, local purge, minimized Apple scope.
- `functions/src/index.ts` — idempotent server-side aggregate reconciliation and post-success identity cleanup.
- `apps/web/app/privacy/page.tsx` / Account copy — behavior-aligned draft privacy notice and export scope.
- dependency manifests/lockfile/overrides — production advisory remediation.
- `.github/workflows/ci.yml` / Dependabot — automated regression and advisory gates.

Unrelated pre-existing UI/content work in the dirty working tree was preserved and is not represented as security work in this report.

## E. Security testing and limitations

### Executed successfully

| Test | Result |
|---|---|
| Web Vitest baseline | 19 passed, 2 skipped |
| Web Vitest after final remediation | 26 passed, 2 skipped across 8 files |
| Web TypeScript | Passed after final changes |
| Web ESLint | Passed with zero warnings after final changes |
| Next production build | Passed on Next 16.3.8 after final changes; all expected static/dynamic routes emitted |
| Functions Vitest | 8 passed |
| Functions TypeScript | Passed |
| Local runtime header probe | `/privacy` returned security headers; unauthenticated export/delete returned generic no-store 401 responses |
| Online production dependency audit | 0 critical, 0 high, 1 moderate |
| iOS feature parity validator | Passed 95 source checks after final export wording |
| Screenshot preview validator | Passed 37 deterministic states / 11 verified articles after final wording |
| Diff whitespace check | Passed; line-ending warnings only |

### Not executed / not proven

- Firestore rules compiler/emulator and adversarial cross-UID rule tests (Firebase CLI absent; installed Java 8 is inadequate for current emulator tooling).
- Xcode/iOS build, XCTest, simulator/device, Keychain, notification, VoiceOver, and provider reauthentication tests (Windows host).
- Production or staging Firebase/Vercel tests, including Auth revocation, Apple token revoke, Google disconnect, recursive deletion, aggregate reconciliation, TTL, App Check, and live CORS/CSP behavior.
- Destructive, load, fuzz, DAST, or production penetration testing.
- Full repository-history secret scan with a dedicated tool.
- Formal accessibility conformance test.

The package script runner attempted an automatic node_modules/store reconciliation and stopped in the non-interactive environment before tests ran. Verification used the already-installed Vitest/TypeScript/ESLint/Next binaries directly; this environment issue is not represented as a test failure.

## F. Legal and privacy compliance matrix

Applicability cannot be concluded without business location, entity type, revenue, user counts/locations, targeting, and actual store territories. The entries below are conditional readiness assessments, not legal determinations.

| Regime / policy | Applicability assessment | Relevant requirement | Current technical evidence | Gap / action | Legal review |
|---|---|---|---|---|---|
| [EU GDPR](https://eur-lex.europa.eu/eli/reg/2016/679/oj) | Conditional if established in, offering to, or monitoring people in the EEA | Principles, lawful basis, transparent notice, processor/transfer controls, security, and data-subject rights; child consent rules depend on member-state age | Minimization, private-by-default storage, opt-in aggregate, export/delete, owner rules, provider inventory | Identify controller and lawful bases; document rights/complaint route, retention, transfers, DPAs, breach process, Article 8/territory approach | **Yes** |
| [UK GDPR / ICO child consent](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/childrens-information/children-and-the-uk-gdpr/what-are-the-rules-about-an-iss-and-consent/) and [Children’s code](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/childrens-information/childrens-code-guidance-and-resources/introduction-to-the-childrens-code) | Conditional if UK establishment/targeting; Children’s code may apply if likely accessed by under-18s | UK child consent age is 13 when relying on consent; child-accessible services require age-appropriate design consideration | 13+ policy, guest/public reading, aggregate off by default | “13+” text alone is not age assurance. Decide UK availability, lawful basis, DPIA, age-appropriate notice/design and parental-consent strategy | **Yes** |
| [CCPA/CPRA and 2026 regulations](https://cppa.ca.gov/regulations/) | Unknown; depends on for-profit status, California nexus and thresholds | Notice, purpose limitation, consumer rights, request methods/verification, contracts, and sale/share choices if applicable | No sale/share/behavioral ads by design; export/delete/support contact | Determine applicability. Current indexed revenue threshold is [$26,625,000](https://cppa.ca.gov/regulations/cpi_adjustment.html); other statutory thresholds must also be assessed. Add complete notices/request procedures if applicable | **Yes** |
| Other U.S. state privacy laws | Unknown; state thresholds and exemptions differ | Consumer rights, notices, processor contracts, minimization/security | Common export/delete/minimization controls support readiness | Counsel must map user/business facts to current state laws and sensitive/teen-data rules | **Yes** |
| [COPPA](https://www.ftc.gov/legal-library/browse/rules/childrens-online-privacy-protection-rule-coppa) | Likely not triggered if genuinely general-audience 13+ with no actual knowledge of under-13 users; facts could change | Applies to child-directed under-13 services or actual knowledge of under-13 collection | Policy says 13+; no ads/tracking; no date of birth | Climate/education content may attract children. Document audience analysis, support deletion reports, and avoid collecting after actual knowledge without compliant parental process | **Yes** |
| [FTC data-security/consumer-protection guidance](https://www.ftc.gov/business-guidance/resources/start-security-guide-business) | Potentially relevant to U.S. commercial practices and representations | Reasonable security and truthful privacy/security claims; collect/retain only what is needed | This audit, minimization, access controls, dependency/CI controls, corrected notice | Establish incident response, retention schedule, monitoring, vendor governance, and evidence that every public claim is true in production | **Yes** |
| [India DPDP Rules 2025 Gazette](https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf) | Conditional if processing covered Indian users; commencement is phased | Clear notice/withdrawal/rights, safeguards, breach duties, retention/log rules, verifiable parental consent for children | Consent withdrawal for aggregate, export/delete, security controls | As of assessment, Rules 1, 2 and 17–21 commenced at publication; Rule 4 commences Nov. 13, 2026; Rules 3, 5–16, 22, 23 commence May 13, 2027. Confirm Act commencement, India availability, child definition, notice and one-year log/retention duties with Indian counsel | **Yes** |
| [CAN-SPAM](https://www.ftc.gov/business-guidance/resources/can-spam-act-compliance-guide-business) | Not currently evidenced: repository sends local/push reminders, not commercial email | Commercial email identification, address, opt-out, timely honoring | No marketing-email system found | Reassess before adding any commercial email; build unsubscribe/suppression and sender-address controls first | If email added |
| [WCAG 2.2](https://www.w3.org/TR/WCAG22/) / accessibility law | WCAG is a technical standard; legal obligation depends on operator, jurisdiction, and offering | Perceivable, operable, understandable, robust content; often target AA | Semantic HTML/native controls, Dynamic Type, VoiceOver labels and 44pt design intent | Run formal AA/device testing; legal counsel determines ADA/Section 508/EAA or other applicability | **Yes** for applicability |
| [Apple App Review Guidelines 5.1.1](https://developer.apple.com/app-store/review/guidelines/uk/) and [account deletion guidance](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion) | Applicable to iOS distribution | Accessible privacy policy, accurate data handling/retention, data minimization, guest access where appropriate, in-app deletion, Sign in with Apple revocation | Public reading without login; privacy link; Apple/Google/guest; in-app export/delete; Apple revoke; minimized Apple scope; standard EULA | Exercise end-to-end deletion; tell users if asynchronous work remains; review merged SDK privacy report and App Store Connect answers; verify provider protection/retention language | **Yes / App Store owner** |
| [App Store Connect privacy answers](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy) | Applicable to iOS distribution | Answers must cover app and integrated third-party partner collection and remain current | Privacy manifest lists core categories; code/provider inventory completed | The console cannot be inspected. Reconcile Firebase/Google Sign-In/Messaging SDK data, provider profile/name, identifiers, diagnostics and coarse location using the merged Xcode privacy report and current SDK disclosures | **App Store owner** |
| [Google Play account deletion](https://support.google.com/googleplay/android-developer/answer/13327111?hl=en) / Data Safety | Not currently applicable: no Android app was found | If Android/account creation is added, both in-app and external web deletion plus accurate Data Safety are required | In-app iOS deletion exists; support/privacy pages exist but no Android/external authenticated deletion flow | Treat as a pre-launch Android requirement, not current compliance | If Android planned |

### Data inventory

| Data | Purpose | Storage / recipients | Access | Retention status |
|---|---|---|---|---|
| Firebase UID, email/private relay, provider/profile metadata | Authentication and account display/export | Firebase Auth; limited profile fields in Firestore | User, authorized backend, provider | Account lifetime; provider logs/backups unverified |
| Reflections, actions, completion, impact estimate | Private journal/progress | Firestore `users/{uid}/actionLogs`; protected local retry archive | Owner and Admin SDK; local app | Account lifetime or user deletion; local unfinished drafts until discard/save/delete |
| Notification preference and messaging token/device identifiers | User-requested reminders/push | Firestore/profile, Firebase Messaging, local defaults | Owner/backend/provider | Token deleted locally on account deletion; provider retention unverified |
| Community-impact preference/receipt/contributor | Opt-in anonymous aggregate integrity | Firestore private server collections; public thresholded aggregate | Backend only; user export includes own records | Receipt removed on opt-out/delete via asynchronous reconciliation; successful jobs deleted |
| Security rate-limit record | Prevent endpoint abuse | Private Firestore rate-limit document | Backend only; included in export | `expiresAt` TTL policy added; deployment not verified |
| Public article/source/AI derivative content | Publication | Drive, Firestore, AI provider, website | Public after publication; editors/backend | Editorial retention policy not defined |
| Editorial cover/query/provenance | Licensed imagery | Pexels, Vercel Blob, Firestore | Public asset/attribution; backend metadata | Replacement/takedown path exists; provider/blob retention unverified |
| Request/diagnostic logs | Reliability/security | Vercel/Firebase/provider systems | Provider/operator admins | Exact fields and schedules unverified |

## G. Dependency and infrastructure review

- Lockfile is present; production packages are pinned and transitive overrides are narrow and documented by name/range.
- Current web baseline is Node 24 (`.node-version`); web declares Node `>=22.12.0`; Functions declares Firebase runtime Node 22 and CI switches to Node 22 for Functions verification.
- GitHub Actions are SHA-pinned with read-only repository permissions and concurrency cancellation.
- Dependabot covers npm workspace and Actions weekly.
- `.env*`, certificates, mobile provisioning profiles, node_modules, and build outputs are ignored; `.env.example` contains names only.
- Public Firebase client configuration is not a server secret. Firebase Admin/Drive/AI/media credentials remain server environment variables.
- No analytics, behavioral advertising, payment flow, password database, or custom session cookie was found.
- Production HTTPS, HSTS delivery, environment separation, branch protection, administrator MFA, key rotation, logging/alerting, backups, Firebase project IAM, Vercel roles, and GitHub environment protections were not inspectable.

## H. Remaining risk register

| Risk | Priority | Owner | Required action | Exit evidence |
|---|---|---|---|---|
| Firestore rule syntax/behavior not emulator-tested or deployed | Release blocker | Backend/Firebase owner | Add rules-unit-testing emulator cases for owner/other/anonymous/admin and state transitions; deploy to staging | Passing emulator artifact + staging rule version |
| iOS security/deletion changes not compiled/device-tested | Release blocker | iOS owner | Xcode build/XCTest; Apple/Google/guest deletion; offline draft purge; export share/cleanup | CI/device run and test record |
| Production/staging end-to-end auth/export/delete/aggregate unverified | Release blocker | QA/backend | Synthetic accounts only; verify revocation, no cross-user access, async receipt removal, generic errors | Signed test evidence |
| Firebase App Check absent | High | Firebase/mobile/web owner | Staged attestation rollout and enforcement | Console config + unattested denial test |
| Provider contracts/transfers/retention/backups unknown | High | Privacy/legal + operations | Inventory DPAs/SCCs/terms/locations and deletion schedules | Approved vendor register and retention schedule |
| Children/teen/jurisdiction applicability unknown | High | Legal/product | Decide audience and territories; DPIA/age strategy as applicable | Counsel memo/product decision |
| App Store privacy answers and SDK manifests unverified | High | App Store owner | Generate merged privacy report; reconcile live App Store Connect answers | Published answer export/screenshots |
| Moderate `sprintf-js` advisory | Medium | Dependency owner | Monitor upstream; replace/upgrade when feasible | Clean production audit or accepted risk review |
| CSP needs `unsafe-inline` | Low | Web owner | Evaluate Next nonce/hash CSP without breaking Firebase popup | Browser integration tests with stricter CSP |
| Secret/history and console scan incomplete | Medium | DevOps/security | Gitleaks full history; IAM/environment audit; rotate if needed | Redacted scanner/console review artifacts |
| Accessibility conformance unknown | Medium | Design/QA/legal | WCAG 2.2 AA + iOS assistive-tech testing | Audited issue log and retest |
| Incident response/DSR operations undocumented | High | Operations/privacy | Create breach, access, deletion, correction, appeal, and identity-verification runbooks | Approved runbooks/tabletop record |

## I. Final verification classification

### Verified fixed

- Critical/high production dependency findings in the locally audited lock graph.
- Verified-email requirement for admin allowlist and revocation-checked tokens.
- Generic no-store account/admin error responses.
- Streaming JSON request cap and endpoint rate-limit logic.
- HTTPS source-link normalization and media host/size/pixel protections.
- Browser security headers in local production runtime.
- Reconciliation job identity deletion in source after success.
- Expanded server export structure and synchronized UI/privacy wording at source level.

### Mitigated but not eliminated

- Moderate `sprintf-js` transitive advisory: bounded/unreachable in reviewed application path, but vulnerable package remains.
- CSP: strong directives added, but `unsafe-inline` remains for framework compatibility.

### Requires external verification

- Firestore rule compilation/emulator behavior, TTL activation, indexes, deployment.
- iOS build/tests and provider authentication/deletion on real Apple tooling.
- Production/staging CSP Google popup, Firebase Auth revocation, recursive deletion, export completeness, aggregate reconciliation.
- CI workflow execution/branch protection, App Check, IAM, secrets, logs, backups, retention.
- Existing production article compatibility with the stricter schema.

### Requires legal review

- GDPR/UK GDPR/CCPA/state-law/DPDP applicability and notices.
- Children/teen access, consent, and age-appropriate design.
- Controller identity, lawful bases, processor/transfer contracts, exact retention and backup statements.
- Consumer-protection claims, incident/DSR procedures, and final privacy policy/terms.

### Not assessed

- Production cloud consoles/data/logs; real-user records; network perimeter; organization security program; vendor contractual compliance; Android application (none present); payment/commerce (none present); marketing email operations (none present).

## Independent review note

Three read-only independent review streams examined application/auth/data, privacy/legal, and infrastructure/dependencies. They identified the CSP/Firebase incompatibility, non-streaming body limit, parser/schema URL mismatch, local deletion gap, retained reconciliation identifiers, export/disclosure gaps, and Node runtime alignment issue. Their formal final sign-off was interrupted by the platform usage limit. The lead reviewer incorporated each delivered finding, repeated the source audit, and reran focused tests. Therefore this report records **independent findings incorporated**, not a complete independent certification.
