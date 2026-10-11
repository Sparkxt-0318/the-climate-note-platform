import { createHash } from "node:crypto";
import { getApps, initializeApp } from "firebase-admin/app";
import {
  FieldPath,
  FieldValue,
  getFirestore,
  type Firestore,
} from "firebase-admin/firestore";
import {
  onDocumentCreated,
  onDocumentDeleted,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import {
  buildPublicCommunityImpact,
  desiredReceipt,
  isRecord,
  normalizeReceipt,
  planReceiptTransition,
  type FirestoreData,
} from "./impact/aggregation.js";

const REGION = "us-central1";
const RECONCILIATION_PAGE_SIZE = 100;
const RECONCILIATION_JOBS = "impactReconciliationJobs";
const RECEIPTS = "impactReceipts";
const CONTRIBUTORS = "impactContributors";
const INTERNAL_TOTAL = "impactInternal/current";
const PUBLIC_TOTAL = "communityImpact/current";
const ACCOUNT_DELETION_REQUESTS = "impactAccountDeletionRequests";

if (getApps().length === 0) initializeApp();

type ReconciliationKind = "logs" | "receipts";

type ReconciliationJob = {
  kind: ReconciliationKind;
  uid: string;
  runID: string;
  cursor: string | null;
};

function database() {
  return getFirestore();
}

function stableDocumentID(...parts: string[]) {
  return createHash("sha256").update(parts.join("\u0000")).digest("hex");
}

function receiptDocumentID(uid: string, logID: string) {
  return stableDocumentID("receipt", uid, logID);
}

function hasErrorCode(error: unknown, code: number) {
  return isRecord(error) && error.code === code;
}

function nonEmptyString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value : null;
}

function jobFromData(value: unknown): ReconciliationJob | null {
  if (!isRecord(value)) return null;
  const kind = value.kind;
  const uid = nonEmptyString(value.uid);
  const runID = nonEmptyString(value.runID);
  const cursor = value.cursor === null ? null : nonEmptyString(value.cursor);
  if ((kind !== "logs" && kind !== "receipts") || !uid || !runID || cursor === null && value.cursor !== null) {
    return null;
  }
  return { kind, uid, runID, cursor };
}

async function enqueueReconciliation(
  db: Firestore,
  kind: ReconciliationKind,
  uid: string,
  runID: string,
  cursor: string | null,
) {
  const jobID = stableDocumentID("impact-reconcile", kind, uid, runID, cursor ?? "first-page");
  const jobRef = db.collection(RECONCILIATION_JOBS).doc(jobID);

  try {
    await jobRef.create({
      schemaVersion: 1,
      kind,
      uid,
      runID,
      cursor,
      status: "pending",
      createdAt: FieldValue.serverTimestamp(),
    });
  } catch (error) {
    // A retried event tries to enqueue the same deterministic page. The first job is enough.
    if (!hasErrorCode(error, 6)) throw error;
  }
}

async function ensureCommunityImpactDocument(db: Firestore) {
  const internalRef = db.doc(INTERNAL_TOTAL);
  const publicRef = db.doc(PUBLIC_TOTAL);
  await db.runTransaction(async (transaction) => {
    const [internal, summary] = await Promise.all([
      transaction.get(internalRef),
      transaction.get(publicRef),
    ]);
    if (summary.exists) return;
    transaction.set(publicRef, {
      ...buildPublicCommunityImpact(internal.exists ? internal.data() : null),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

function sourceArticleID(log: unknown) {
  return isRecord(log) ? nonEmptyString(log.articleID) : null;
}

/**
 * Re-reads the current action log, preference, article, receipt, contributor, and totals inside a
 * transaction. Event snapshots are deliberately ignored: events can be duplicated, delayed, or
 * delivered after a later user edit.
 */
export async function reconcileCurrentActionLog(db: Firestore, uid: string, logID: string) {
  const userRef = db.collection("users").doc(uid);
  const logRef = userRef.collection("actionLogs").doc(logID);
  const preferenceRef = userRef.collection("preferences").doc("impact");
  const receiptRef = db.collection(RECEIPTS).doc(receiptDocumentID(uid, logID));
  const contributorRef = db.collection(CONTRIBUTORS).doc(uid);
  const internalRef = db.doc(INTERNAL_TOTAL);
  const publicRef = db.doc(PUBLIC_TOTAL);

  await db.runTransaction(async (transaction) => {
    const [logSnapshot, preferenceSnapshot, receiptSnapshot, contributorSnapshot, internalSnapshot] =
      await Promise.all([
        transaction.get(logRef),
        transaction.get(preferenceRef),
        transaction.get(receiptRef),
        transaction.get(contributorRef),
        transaction.get(internalRef),
      ]);

    const log = logSnapshot.exists ? logSnapshot.data() : null;
    const articleID = sourceArticleID(log);
    const articleSnapshot = articleID
      ? await transaction.get(db.collection("articles").doc(articleID))
      : null;
    const article = articleSnapshot?.exists ? articleSnapshot.data() : null;
    const preference = preferenceSnapshot.exists ? preferenceSnapshot.data() : null;
    const rawReceipt = receiptSnapshot.exists ? receiptSnapshot.data() : null;
    const nextReceipt = desiredReceipt({
      uid,
      logID,
      log,
      preference,
      article,
      existingReceipt: rawReceipt,
    });
    const transition = planReceiptTransition({
      currentReceipt: rawReceipt,
      nextReceipt,
      internal: internalSnapshot.exists ? internalSnapshot.data() : null,
      contributor: contributorSnapshot.exists ? contributorSnapshot.data() : null,
    });
    const malformedReceiptNeedsRemoval = receiptSnapshot.exists && !normalizeReceipt(rawReceipt) && !nextReceipt;

    if (!transition.changed && !malformedReceiptNeedsRemoval) return;

    if (transition.nextReceipt) {
      const previousReceipt = rawReceipt && isRecord(rawReceipt) ? rawReceipt : {};
      transaction.set(receiptRef, {
        ...transition.nextReceipt,
        acceptedAt: previousReceipt.acceptedAt ?? FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else if (receiptSnapshot.exists) {
      transaction.delete(receiptRef);
    }

    if (transition.shouldDeleteContributor) {
      if (contributorSnapshot.exists) transaction.delete(contributorRef);
    } else {
      const previousContributor = contributorSnapshot.exists ? (contributorSnapshot.data() ?? {}) : {};
      transaction.set(contributorRef, {
        schemaVersion: 1,
        uid,
        ...transition.nextContributor,
        createdAt: previousContributor.createdAt ?? FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    const previousInternal = internalSnapshot.exists ? (internalSnapshot.data() ?? {}) : {};
    transaction.set(internalRef, {
      ...transition.nextInternal,
      createdAt: previousInternal.createdAt ?? FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(publicRef, {
      ...buildPublicCommunityImpact(transition.nextInternal),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
}

async function reconcileLogPage(db: Firestore, job: ReconciliationJob) {
  let query = db
    .collection("users")
    .doc(job.uid)
    .collection("actionLogs")
    .orderBy(FieldPath.documentId())
    .limit(RECONCILIATION_PAGE_SIZE);
  if (job.cursor) query = query.startAfter(job.cursor);

  const page = await query.get();
  for (const document of page.docs) {
    await reconcileCurrentActionLog(db, job.uid, document.id);
  }
  await ensureCommunityImpactDocument(db);

  const last = page.docs.at(-1);
  if (page.size === RECONCILIATION_PAGE_SIZE && last) {
    await enqueueReconciliation(db, "logs", job.uid, job.runID, last.id);
  }
}

async function reconcileReceiptPage(db: Firestore, job: ReconciliationJob) {
  let query = db
    .collection(RECEIPTS)
    .where("uid", "==", job.uid)
    .orderBy("logID")
    .limit(RECONCILIATION_PAGE_SIZE);
  if (job.cursor) query = query.startAfter(job.cursor);

  const page = await query.get();
  for (const receipt of page.docs) {
    const logID = nonEmptyString(receipt.data().logID);
    if (logID) await reconcileCurrentActionLog(db, job.uid, logID);
  }

  const lastLogID = page.docs.at(-1) && nonEmptyString(page.docs.at(-1)?.data().logID);
  if (page.size === RECONCILIATION_PAGE_SIZE && lastLogID) {
    await enqueueReconciliation(db, "receipts", job.uid, job.runID, lastLogID);
  } else {
    await db.collection(ACCOUNT_DELETION_REQUESTS).doc(job.uid).delete().catch(() => undefined);
  }
}

export const reconcileImpactActionLog = onDocumentWritten(
  {
    document: "users/{uid}/actionLogs/{logID}",
    region: REGION,
    retry: true,
  },
  async (event) => {
    await reconcileCurrentActionLog(database(), event.params.uid, event.params.logID);
  },
);

export const enqueueImpactPreferenceReconciliation = onDocumentWritten(
  {
    document: "users/{uid}/preferences/impact",
    region: REGION,
    retry: true,
  },
  async (event) => {
    await enqueueReconciliation(database(), "logs", event.params.uid, event.id, null);
  },
);

export const reconcileDeletedAccountImpact = onDocumentDeleted(
  {
    document: "users/{uid}",
    region: REGION,
    retry: true,
  },
  async (event) => {
    // The user document and action logs can already be gone. Receipts retain the server-accepted
    // values needed to subtract their contribution safely.
    await enqueueReconciliation(database(), "receipts", event.params.uid, event.id, null);
  },
);

export const reconcileRequestedAccountDeletionImpact = onDocumentCreated(
  {
    document: `${ACCOUNT_DELETION_REQUESTS}/{uid}`,
    region: REGION,
    retry: true,
  },
  async (event) => {
    await enqueueReconciliation(database(), "receipts", event.params.uid, event.id, null);
  },
);

export const processImpactReconciliationPage = onDocumentCreated(
  {
    document: `${RECONCILIATION_JOBS}/{jobID}`,
    region: REGION,
    retry: true,
  },
  async (event) => {
    const jobRef = event.data?.ref;
    if (!jobRef) return;
    const job = jobFromData(event.data?.data());
    if (!job) {
      await jobRef.delete();
      return;
    }

    if (job.kind === "logs") await reconcileLogPage(database(), job);
    else await reconcileReceiptPage(database(), job);

    // The deterministic document ID already provides retry deduplication while
    // the job is pending. Remove raw account identifiers and cursors immediately
    // after successful, idempotent reconciliation.
    await jobRef.delete();
  },
);

/**
 * A bounded, paginated safety net for opted-in accounts. It covers pre-existing preferences and
 * any event delivery gap without ever using a client-provided impact amount.
 */
export const backfillOptedInImpact = onSchedule(
  {
    schedule: "every 24 hours",
    region: REGION,
    timeZone: "Etc/UTC",
  },
  async () => {
    const db = database();
    await ensureCommunityImpactDocument(db);
    const checkpointRef = db.doc("impactBackfill/current");
    const checkpoint = await checkpointRef.get();
    const rawCheckpoint = checkpoint.data();
    const checkpointData: FirestoreData = checkpoint.exists && isRecord(rawCheckpoint) ? rawCheckpoint : {};
    const cursorPath = nonEmptyString(checkpointData.cursorPath);

    let query = db
      .collectionGroup("preferences")
      .where("includeInCommunityImpact", "==", true)
      .orderBy(FieldPath.documentId())
      .limit(RECONCILIATION_PAGE_SIZE);
    if (cursorPath) query = query.startAfter(cursorPath);

    const page = await query.get();
    const runID = `scheduled-${Date.now()}`;
    for (const preference of page.docs) {
      const user = preference.ref.parent.parent;
      if (preference.id === "impact" && user) {
        await enqueueReconciliation(db, "logs", user.id, runID, null);
      }
    }

    const last = page.docs.at(-1);
    if (last && page.size === RECONCILIATION_PAGE_SIZE) {
      await checkpointRef.set({ cursorPath: last.ref.path, updatedAt: FieldValue.serverTimestamp() });
    } else {
      await checkpointRef.delete();
    }
  },
);
