import "server-only";
import { randomUUID } from "node:crypto";
import { del, put } from "@vercel/blob";

export type StoredImage = {
  url: string;
  path: string;
};

function extensionFor(contentType: string) {
  if (contentType === "image/png") return "png";
  if (contentType === "image/webp") return "webp";
  return "jpg";
}

export async function storeArticleImage(
  articleId: string,
  image: Buffer,
  contentType: string,
  stableID?: string,
): Promise<StoredImage> {
  const safeStableID = stableID?.replace(/[^a-f0-9]/gi, "").slice(0, 64);
  const path = `articles/${articleId}/cover-${safeStableID || randomUUID()}.${extensionFor(contentType)}`;
  const blob = await put(path, image, {
    access: "public",
    addRandomSuffix: false,
    cacheControlMaxAge: 31_536_000,
    contentType,
  });

  return { url: blob.url, path: blob.pathname };
}

export async function deleteArticleImage(urlOrPath: string) {
  await del(urlOrPath);
}
