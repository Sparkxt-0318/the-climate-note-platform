import "server-only";
import { z } from "zod";
import { downloadImage } from "@/lib/media/download";
import type { VisualCandidate } from "@/lib/media/types";

const searchSchema = z.object({
  collection: z.object({
    items: z.array(
      z.object({
        href: z.url(),
        data: z.array(
          z.object({
            nasa_id: z.string(),
            title: z.string(),
            description: z.string().optional(),
            photographer: z.string().optional(),
            secondary_creator: z.string().optional(),
            media_type: z.literal("image"),
          }),
        ),
      }),
    ),
  }),
});

const assetSchema = z.object({
  collection: z.object({ items: z.array(z.object({ href: z.url() })) }),
});

export async function searchNasaImages(query: string): Promise<VisualCandidate | null> {
  const params = new URLSearchParams({ q: query, media_type: "image", page_size: "8" });
  const response = await fetch(`https://images-api.nasa.gov/search?${params}`, {
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new Error(`NASA image search failed with ${response.status}.`);
  const search = searchSchema.parse(await response.json());

  for (const item of search.collection.items) {
    const metadata = item.data[0];
    if (!metadata) continue;
    try {
      const assetsResponse = await fetch(item.href, { signal: AbortSignal.timeout(15_000) });
      if (!assetsResponse.ok) continue;
      const assets = assetSchema.parse(await assetsResponse.json());
      const href = assets.collection.items
        .map((asset) => asset.href)
        .find((url) => /\.(?:jpe?g|png|webp)$/i.test(new URL(url).pathname) && !/~(?:orig|large)\./i.test(url));
      if (!href) continue;
      const image = await downloadImage(href);
      return {
        ...image,
        caption: metadata.description?.replace(/\s+/g, " ").trim().slice(0, 500) || metadata.title,
        attribution: metadata.photographer || metadata.secondary_creator || "NASA",
        license: "NASA Media Usage Guidelines",
        sourceUrl: `https://images.nasa.gov/details/${encodeURIComponent(metadata.nasa_id)}`,
        generated: false,
      };
    } catch {
      // Try the next official NASA asset.
    }
  }

  return null;
}
