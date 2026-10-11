import { randomUUID } from "node:crypto";
import { NextRequest } from "next/server";
import { verifyAdmin } from "@/lib/auth/verify-admin";
import { getAdminFirestore } from "@/lib/firebase/admin";
import { deleteArticleImage } from "@/lib/storage/blob";
import {
  enforceUserRateLimit,
  noStoreJson,
  requireSafeDocumentID,
  safeErrorResponse,
} from "@/lib/http/security";

export const dynamic = "force-dynamic";

export async function DELETE(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  try {
    const user = await verifyAdmin(request);
    await enforceUserRateLimit(user.uid, "admin-write", 60, 60 * 1_000);
    const { id: rawID } = await context.params;
    const id = requireSafeDocumentID(rawID);
    const database = getAdminFirestore();
    const articleRef = database.collection("articles").doc(id);
    const mediaRef = database.collection("articleMedia").doc(id);
    const media = await mediaRef.get();
    const blobPath = media.get("blobPath");

    // Remove the hosted derivative first so a rights/takedown request cannot
    // leave the old licensed asset publicly reachable through our storage.
    if (typeof blobPath === "string" && blobPath.length > 0) {
      await deleteArticleImage(blobPath);
    }

    const now = new Date();
    const batch = database.batch();
    batch.update(articleRef, { coverAsset: null, updatedAt: now });
    batch.set(mediaRef, {
      status: "removed",
      blobPath: null,
      removedAt: now,
      updatedAt: now,
    }, { merge: true });
    batch.set(mediaRef.collection("events").doc(randomUUID()), {
      outcome: "removed",
      articleId: id,
      createdAt: now,
    });
    await batch.commit();
    return noStoreJson({ removed: true });
  } catch (error) {
    return safeErrorResponse(error, "The story image could not be removed.");
  }
}

export async function POST(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  try {
    const user = await verifyAdmin(request);
    await enforceUserRateLimit(user.uid, "admin-write", 60, 60 * 1_000);
    const { id: rawID } = await context.params;
    const id = requireSafeDocumentID(rawID);
    const database = getAdminFirestore();
    const articleRef = database.collection("articles").doc(id);
    const mediaRef = database.collection("articleMedia").doc(id);
    const [article, media] = await Promise.all([articleRef.get(), mediaRef.get()]);
    if (!article.exists) return noStoreJson({ error: "Article not found.", code: "article-not-found" }, { status: 404 });

    const blobPath = media.get("blobPath");
    if (typeof blobPath === "string" && blobPath.length > 0) {
      await deleteArticleImage(blobPath);
    }

    const now = new Date();
    const batch = database.batch();
    batch.update(articleRef, { coverAsset: null, updatedAt: now });
    batch.set(mediaRef, { status: "replace-requested", blobPath: null, updatedAt: now }, { merge: true });
    batch.set(mediaRef.collection("events").doc(randomUUID()), {
      outcome: "replacement-requested",
      articleId: id,
      createdAt: now,
    });
    await batch.commit();
    return noStoreJson({ replacementRequested: true });
  } catch (error) {
    return safeErrorResponse(error, "The story image could not be replaced.");
  }
}
