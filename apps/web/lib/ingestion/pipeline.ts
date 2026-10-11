import "server-only";
import { createHash } from "node:crypto";
import { revalidatePath } from "next/cache";
import { enrichArticle } from "@/lib/ai/enrichment";
import { getAdminFirestore, getAdminMessaging } from "@/lib/firebase/admin";
import {
  docxMimeType,
  downloadDriveFile,
  listSourceDocuments,
  maximumDocxBytes,
  type DriveFile,
} from "@/lib/ingestion/drive";
import { parseDocx, type ParsedDocx } from "@/lib/ingestion/docx";
import { resolveAttemptLimit, type IngestionScope } from "@/lib/ingestion/limits";
import { shouldSelectNewCover } from "@/lib/media/policy";
import { selectArticleVisual } from "@/lib/media/select";
import type { LicensedVisualCandidate, PublicCoverAsset } from "@/lib/media/types";
import { deleteArticleImage, storeArticleImage } from "@/lib/storage/blob";

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
  return (error instanceof Error ? error.message : String(error))
    .replace(
      /-----BEGIN(?: [A-Z]+)? PRIVATE KEY-----[\s\S]*?-----END(?: [A-Z]+)? PRIVATE KEY-----/gi,
      "[redacted-private-key]",
    )
    .replace(/([?&](?:key|token|api_key|access_token)=)[^&\s]+/gi, "$1[redacted]")
    .replace(/\b(authorization|api[_-]?key|token|secret|private[_-]?key)\s*[:=]\s*[^\s,;]+/gi, "$1=[redacted]")
    .slice(0, 1_500);
}

function record(value: unknown): Record<string, unknown> | null {
  return typeof value === "object" && value !== null && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

async function recentPexelsAssetIDs(articleId: string) {
  const snapshot = await getAdminFirestore()
    .collection("articles")
    .orderBy("publishedAt", "desc")
    .limit(30)
    .get();
  return new Set(
    snapshot.docs.flatMap((document) => {
      if (document.id === articleId) return [];
      const cover = record(document.get("coverAsset"));
      return cover?.provider === "pexels" && typeof cover.providerAssetId === "string"
        ? [cover.providerAssetId]
        : [];
    }),
  );
}

function publicCover(candidate: LicensedVisualCandidate, url: string): PublicCoverAsset {
  return {
    url,
    contentType: candidate.contentType,
    caption: candidate.caption,
    altText: candidate.altText,
    attribution: candidate.attribution,
    license: candidate.license,
    licenseUrl: candidate.licenseUrl,
    sourceUrl: candidate.sourceUrl,
    generated: candidate.generated,
    provider: candidate.provider,
    providerAssetId: candidate.providerAssetId,
    photographer: candidate.photographer,
    retrievedAt: candidate.retrievedAt,
    crop: candidate.crop,
    contentHash: candidate.contentHash,
  };
}

type PreparedMedia = {
  coverAsset: Record<string, unknown> | PublicCoverAsset | null;
  state: Record<string, unknown> | null;
  audit: Record<string, unknown> | null;
  warning: string | null;
  replacedBlobPath: string | null;
};

async function prepareAutomatedCover({
  articleId,
  currentCover,
  currentMediaState,
  searchQuery,
  altText,
}: {
  articleId: string;
  currentCover: Record<string, unknown> | null;
  currentMediaState: Record<string, unknown> | null;
  searchQuery: string;
  altText: string;
}): Promise<PreparedMedia> {
  if (!shouldSelectNewCover(currentCover, currentMediaState, searchQuery)) {
    return { coverAsset: currentCover, state: null, audit: null, warning: null, replacedBlobPath: null };
  }

  const reusableCover = currentCover?.generated === true ? null : currentCover;
  const selectedAt = new Date();
  try {
    const recentIDs = await recentPexelsAssetIDs(articleId);
    const candidate = await selectArticleVisual({ searchQuery, altText, recentProviderAssetIds: recentIDs });
    if (!candidate) {
      return {
        coverAsset: reusableCover,
        state: {
          status: reusableCover ? "preserved" : "text-only",
          selectionQuery: searchQuery,
          reason: "no-eligible-candidate",
          updatedAt: selectedAt,
        },
        audit: { outcome: "no-eligible-candidate", selectionQuery: searchQuery, createdAt: selectedAt },
        warning: "No licensed Pexels photograph passed the automatic relevance and safety checks.",
        replacedBlobPath: null,
      };
    }

    const stored = await storeArticleImage(articleId, candidate.bytes, candidate.contentType, candidate.contentHash);
    const cover = publicCover(candidate, stored.url);
    return {
      coverAsset: cover,
      state: {
        status: "selected",
        provider: candidate.provider,
        providerAssetId: candidate.providerAssetId,
        photographer: candidate.photographer,
        selectionQuery: candidate.selectionQuery,
        selectionScore: candidate.selectionScore,
        contentHash: candidate.contentHash,
        blobPath: stored.path,
        license: candidate.license,
        licenseUrl: candidate.licenseUrl,
        sourceUrl: candidate.sourceUrl,
        retrievedAt: candidate.retrievedAt,
        updatedAt: selectedAt,
      },
      audit: {
        outcome: "selected",
        provider: candidate.provider,
        providerAssetId: candidate.providerAssetId,
        photographer: candidate.photographer,
        selectionQuery: candidate.selectionQuery,
        selectionScore: candidate.selectionScore,
        contentHash: candidate.contentHash,
        blobPath: stored.path,
        license: candidate.license,
        licenseUrl: candidate.licenseUrl,
        sourceUrl: candidate.sourceUrl,
        retrievedAt: candidate.retrievedAt,
        createdAt: selectedAt,
      },
      warning: null,
      replacedBlobPath:
        typeof currentMediaState?.blobPath === "string" && currentMediaState.blobPath !== stored.path
          ? currentMediaState.blobPath
          : null,
    };
  } catch (error) {
    const detail = safeError(error);
    return {
      coverAsset: reusableCover,
      state: {
        status: reusableCover ? "preserved" : "text-only",
        selectionQuery: searchQuery,
        reason: "selection-error",
        error: detail,
        updatedAt: selectedAt,
      },
      audit: { outcome: "selection-error", selectionQuery: searchQuery, error: detail, createdAt: selectedAt },
      warning: `Automatic licensed-photo selection did not complete: ${detail}`,
      replacedBlobPath: null,
    };
  }
}

function validateSource(parsed: ParsedDocx) {
  if (parsed.wordCount < 150) throw new Error("Article body must contain at least 150 words.");
  if (parsed.wordCount > 20_000) throw new Error("Article body exceeds the 20,000-word ingestion limit.");
  if (parsed.title.length > 180) throw new Error("Article title exceeds 180 characters.");
  if (parsed.blocks.length > 500) throw new Error("Article exceeds the 500-block ingestion limit.");
  if (parsed.sourceLinks.length > 100) throw new Error("Article exceeds the 100-source ingestion limit.");
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
    const declaredBytes = Number(file.size);
    if (Number.isFinite(declaredBytes) && declaredBytes > maximumDocxBytes) {
      throw new Error("The source DOCX exceeds the 10 MB ingestion limit.");
    }
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
      const mediaRef = database.collection("articleMedia").doc(articleId);
      const currentMedia = await mediaRef.get();
      const slug = await uniqueSlug(parsed.title, articleId, file.id);
      const now = new Date();
      const publishedAt = current.get("publishedAt") ?? now;
      const generationRef = database.collection("articleGenerations").doc(jobId);
      const media = await prepareAutomatedCover({
        articleId,
        currentCover: record(current.get("coverAsset")),
        currentMediaState: currentMedia.exists ? record(currentMedia.data()) : null,
        searchQuery: enrichment.generation.visualPlan.searchQuery,
        altText: enrichment.generation.visualPlan.altText,
      });

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
        coverAsset: media.coverAsset,
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
        warnings: media.warning ? [...parsed.warnings, media.warning] : parsed.warnings,
        publishedAt,
        createdAt: current.get("createdAt") ?? now,
        updatedAt: now,
      });
      if (media.state) batch.set(mediaRef, media.state, { merge: true });
      if (media.audit) {
        batch.set(mediaRef.collection("events").doc(jobId), {
          ...media.audit,
          articleId,
          sourceChecksum: parsed.checksum,
        });
      }
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

      if (media.replacedBlobPath) {
        try {
          await deleteArticleImage(media.replacedBlobPath);
        } catch (error) {
          await jobRef.set({ mediaCleanupWarning: safeError(error), updatedAt: new Date() }, { merge: true });
        }
      }

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

export async function runDriveIngestion(options: IngestionScope = {}): Promise<PipelineResult> {
  const startedAt = new Date().toISOString();
  const files = await listSourceDocuments();
  const items: ItemResult[] = [];
  // Free AI tiers are reliable for the weekly cadence when work is queued.
  // Completed documents are cheap to check, but only one new/failed document
  // is allowed to reach enrichment during a run unless explicitly overridden.
  const attemptLimit = resolveAttemptLimit(options, process.env.INGEST_MAX_DOCUMENTS_PER_RUN);
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
