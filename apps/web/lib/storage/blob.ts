import "server-only";
import { randomUUID } from "node:crypto";
import { put } from "@vercel/blob";

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
): Promise<StoredImage> {
  const path = `articles/${articleId}/cover-${randomUUID()}.${extensionFor(contentType)}`;
  const blob = await put(path, image, {
    access: "public",
    addRandomSuffix: false,
    cacheControlMaxAge: 31_536_000,
    contentType,
  });

  return { url: blob.url, path: blob.pathname };
}
