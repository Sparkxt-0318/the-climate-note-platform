import "server-only";
import { createHash } from "node:crypto";
import { revalidatePath } from "next/cache";
import { enrichArticle } from "@/lib/ai/enrichment";
import { getAdminFirestore, getAdminMessaging } from "@/lib/firebase/admin";
import { docxMimeType, downloadDriveFile, listSourceDocuments, type DriveFile } from "@/lib/ingestion/drive";
import { parseDocx, type ParsedDocx } from "@/lib/ingestion/docx";

type ItemResult = {
  fileId: string;
  name: string;
  status: "published" | "unchanged" | "failed" | "ignored";
  detail?: string;
};

export type PipelineResult = {
  startedAt: string;
  finishedAt: string;
  items: ItemResult[];
  counts: Record<ItemResult["status"], number>;
};

function slugify(value: string) {
  return value
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 90) || "climate-note";
}

function articleIdFor(fileId: string) {
  return `drive-${fileId}`;
}

function jobIdFor(fileId: string, checksum: string) {
  return createHash("sha256").update(`${fileId}:${checksum}`).digest("hex");
}

function safeError(error: unknown) {
  return (error instanceof Error ? error.message : String(error)).slice(0, 1_500);
}

function validateSource(parsed: ParsedDocx) {
  if (parsed.wordCount < 150) throw new Error("Article body must contain at least 150 words.");
  if (parsed.title.length > 180) throw new Error("Article title exceeds 180 characters.");
  if (parsed.blocks.filter((block) => block.type === "paragraph").length < 2) {
    throw new Error("Article needs at least two readable paragraphs.");
  }
}

async function uniqueSlug(title: string, articleId: string, fileId: string) {
  const base = slugify(title);
  const matches = await getAdminFirestore().collection("articles").where("slug", "==", base).limit(2).get();
  if (matches.empty || matches.docs.every((document) => document.id === articleId)) return base;
  return `${base}-${fileId.slice(0, 6).toLowerCase()}`;
}

async function processDocument(file: DriveFile): Promise<ItemResult> {
  const database = getAdminFirestore();
  const articleId = articleIdFor(file.id);

  try {
    const sourceDocument = await downloadDriveFile(file.id);
    const parsed = await parseDocx(sourceDocument, file.name);
    validateSource(parsed);
    const jobId = jobIdFor(file.id, parsed.checksum);
    const jobRef = database.collection("ingestionJobs").doc(jobId);
    const claimed = await database.runTransaction(async (transaction) => {
      const job = await transaction.get(jobRef);
      if (job.get("status") === "completed") return false;

      const updatedAt = job.get("updatedAt") as { toMillis?: () => number } | undefined;
      const recentlyStarted =
        job.get("status") === "processing" &&
        typeof updatedAt?.toMillis === "function" &&
        Date.now() - updatedAt.toMillis() < 15 * 60 * 1_000;
      if (recentlyStarted) return false;

      const now = new Date();
      transaction.set(
        jobRef,
        {
          source: "google-drive",
          sourceFileId: file.id,
          sourceFileName: file.name,
          checksum: parsed.checksum,
          status: "processing",
          startedAt: now,
          updatedAt: now,
        },
        { merge: true },
      );
      return true;
    });
    if (!claimed) {
      return { fileId: file.id, name: file.name, status: "unchanged", detail: "Already published or processing." };
    }

    try {
      const enrichment = await enrichArticle(parsed.title, parsed.plainText);
      const articleRef = database.collection("articles").doc(articleId);
      const current = await articleRef.get();
      const slug = await uniqueSlug(parsed.title, articleId, file.id);
      const now = new Date();
      const publishedAt = current.get("publishedAt") ?? now;
      const generationRef = database.collection("articleGenerations").doc(jobId);

      const batch = database.batch();
      batch.set(generationRef, {
        articleId,
        articleChecksum: parsed.checksum,
        generation: enrichment.generation,
        provider: enrichment.provider,
        model: enrichment.model,
        promptVersion: "2026-08-28-v1",
        createdAt: now,
      });
      batch.set(articleRef, {
        slug,
        title: parsed.title,
        author: parsed.author,
        topic: "Climate",
        excerpt: parsed.excerpt,
        status: "published",
        contentBlocks: parsed.blocks,
        plainText: parsed.plainText,
        wordCount: parsed.wordCount,
        sourceLinks: parsed.sourceLinks,
        externalLinks: current.get("externalLinks") ?? {},
        readingMinutes: parsed.readingMinutes,
        generation: enrichment.generation,
        // Article imagery is intentionally disabled for the initial release.
        // Keeping an explicit null also removes an older cover when a source
        // document is reprocessed.
        coverAsset: null,
        source: {
          kind: "google-drive",
          fileId: file.id,
          fileName: file.name,
          modifiedTime: file.modifiedTime,
          checksum: parsed.checksum,
          webViewLink: file.webViewLink ?? null,
        },
        ai: { provider: enrichment.provider, model: enrichment.model },
        generationId: jobId,
        warnings: parsed.warnings,
        publishedAt,
        createdAt: current.get("createdAt") ?? now,
        updatedAt: now,
      });
      batch.set(
        jobRef,
        {
          status: "completed",
          articleId,
          finishedAt: now,
          updatedAt: now,
        },
        { merge: true },
      );
      await batch.commit();

      // Publishing must become visible immediately. Without explicit
      // invalidation, a pre-rendered empty archive can remain at the edge
      // until its time-based revalidation window expires.
      revalidatePath("/");
      revalidatePath("/articles");
      revalidatePath(`/articles/${slug}`);

      if (!current.exists) {
        try {
          await getAdminMessaging().send({
            topic: "weekly-articles",
            notification: { title: "A new Climate Note", body: parsed.title },
            data: { articleId, slug },
            apns: { payload: { aps: { sound: "default" } } },
          });
        } catch (error) {
          await jobRef.set({ notificationWarning: safeError(error), updatedAt: new Date() }, { merge: true });
        }
      }

      return { fileId: file.id, name: file.name, status: "published" };
    } catch (error) {
      await jobRef.set(
        { status: "failed", error: safeError(error), finishedAt: new Date(), updatedAt: new Date() },
        { merge: true },
      );
      throw error;
    }
  } catch (error) {
    return { fileId: file.id, name: file.name, status: "failed", detail: safeError(error) };
  }
}

export async function runDriveIngestion(): Promise<PipelineResult> {
  const startedAt = new Date().toISOString();
  const files = await listSourceDocuments();
  const items: ItemResult[] = [];
  // Free AI tiers are reliable for the weekly cadence when work is queued.
  // Completed documents are cheap to check, but only one new/failed document
  // is allowed to reach enrichment during a run unless explicitly overridden.
  const configuredLimit = Number.parseInt(process.env.INGEST_MAX_DOCUMENTS_PER_RUN ?? "1", 10);
  const attemptLimit = Number.isFinite(configuredLimit) && configuredLimit > 0 ? configuredLimit : 1;
  let attemptedDocuments = 0;

  for (const file of files) {
    if (file.mimeType !== docxMimeType) {
      items.push({ fileId: file.id, name: file.name, status: "ignored", detail: "Only DOCX files are ingested." });
      continue;
    }
    if (attemptedDocuments >= attemptLimit) {
      items.push({ fileId: file.id, name: file.name, status: "ignored", detail: "Queued for a future ingestion run." });
      continue;
    }

    const result = await processDocument(file);
    items.push(result);
    if (result.status === "published" || result.status === "failed") attemptedDocuments += 1;
  }

  const counts: PipelineResult["counts"] = { published: 0, unchanged: 0, failed: 0, ignored: 0 };
  for (const item of items) counts[item.status] += 1;
  return { startedAt, finishedAt: new Date().toISOString(), items, counts };
}
