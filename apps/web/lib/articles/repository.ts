import "server-only";
import { Timestamp } from "firebase-admin/firestore";
import { articleSchema, type Article } from "./schema";
import { firebaseAdminConfigured, getAdminFirestore } from "@/lib/firebase/admin";

function serializeTimestamp(value: unknown): string | null {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (typeof value === "string") return value;
  if (value instanceof Date) return value.toISOString();
  return null;
}

function parseArticle(id: string, data: Record<string, unknown>): Article {
  return articleSchema.parse({
    ...data,
    id,
    publishedAt: serializeTimestamp(data.publishedAt),
    generation: data.generation ?? null,
    author: data.author ?? null,
    sourceLinks: data.sourceLinks ?? [],
    externalLinks: data.externalLinks ?? {},
    contentBlocks: data.contentBlocks ?? [],
    coverAsset: data.coverAsset ?? null,
    readingMinutes: data.readingMinutes ?? 1,
  });
}

export async function listPublishedArticles({ limit }: { limit: number }): Promise<Article[]> {
  if (!firebaseAdminConfigured()) return [];

  const snapshot = await getAdminFirestore()
    .collection("articles")
    .where("status", "==", "published")
    .orderBy("publishedAt", "desc")
    .limit(limit)
    .get();

  return snapshot.docs.map((document) => parseArticle(document.id, document.data()));
}

export async function getPublishedArticleBySlug(slug: string): Promise<Article | null> {
  if (!firebaseAdminConfigured()) return null;

  const snapshot = await getAdminFirestore()
    .collection("articles")
    .where("status", "==", "published")
    .where("slug", "==", slug)
    .limit(1)
    .get();

  const document = snapshot.docs.at(0);
  return document ? parseArticle(document.id, document.data()) : null;
}
