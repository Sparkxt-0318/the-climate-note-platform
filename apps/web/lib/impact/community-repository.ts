import "server-only";
import { FieldPath } from "firebase-admin/firestore";
import { z } from "zod";
import { getAdminFirestore } from "../firebase/admin";
import { communityAccumulator, communityImpactSchema, type ActionTemplate } from "./community";

const templateSchema = z.object({ id: z.string(), factorId: z.string().nullable(), factorQuantity: z.number().nullable() });
const snapshotPath = "publicStats/communityImpact";

export async function readCommunityImpact() {
  const snapshot = await getAdminFirestore().doc(snapshotPath).get();
  const parsed = communityImpactSchema.safeParse(snapshot.data());
  return parsed.success ? parsed.data : null;
}

export async function refreshCommunityImpact() {
  const db = getAdminFirestore();
  const startedAt = new Date();
  const templates = new Map<string, ActionTemplate[]>();
  const articles = await db.collection("articles").select("generation.suggestedActions").get();
  for (const article of articles.docs) {
    const parsed = z.array(templateSchema).safeParse(article.data().generation?.suggestedActions);
    if (parsed.success) templates.set(article.id, parsed.data);
  }
  const accumulator = communityAccumulator(templates, startedAt);
  // Pagination includes historical records and avoids the per-reader cost of
  // scanning private logs. Failed/timed-out scans never publish partial totals.
  const query = db.collectionGroup("actionLogs").orderBy(FieldPath.documentId())
    .select("userID", "status", "articleID", "actionID", "createdAt", "completedAt");
  let cursor: FirebaseFirestore.QueryDocumentSnapshot | undefined;
  while (true) {
    if (Date.now() - startedAt.getTime() > 240_000) throw new Error("Community impact refresh timed out; previous totals retained.");
    const page = await (cursor ? query.startAfter(cursor) : query).limit(1000).get();
    for (const document of page.docs) accumulator.add({ path: document.ref.path, data: document.data() });
    if (page.size < 1000) break;
    cursor = page.docs[page.docs.length - 1];
  }
  const result = accumulator.result();
  await db.runTransaction(async (transaction) => {
    const reference = db.doc(snapshotPath);
    const previous = await transaction.get(reference);
    // A slower older refresh must not replace a newer snapshot.
    if ((previous.data()?.updatedAt ?? "") > result.updatedAt) return;
    transaction.set(reference, result);
  });
  return result;
}
