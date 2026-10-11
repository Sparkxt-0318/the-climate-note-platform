import "server-only";
import { downloadPexelsImage } from "@/lib/media/download";
import { sanitizePexelsImage } from "@/lib/media/image";
import { rankPexelsPhotos } from "@/lib/media/policy";
import { searchPexelsPhotos } from "@/lib/media/pexels";
import { PEXELS_LICENSE_URL, type LicensedVisualCandidate } from "@/lib/media/types";

export async function selectArticleVisual({
  searchQuery,
  altText,
  recentProviderAssetIds,
}: {
  searchQuery: string;
  altText: string;
  recentProviderAssetIds: ReadonlySet<string>;
}): Promise<LicensedVisualCandidate | null> {
  const photos = await searchPexelsPhotos(searchQuery);
  const ranked = rankPexelsPhotos(photos, searchQuery, recentProviderAssetIds).slice(0, 3);

  for (const photo of ranked) {
    try {
      const downloaded = await downloadPexelsImage(photo.imageUrl);
      const normalized = await sanitizePexelsImage(downloaded.bytes);
      const retrievedAt = new Date().toISOString();
      const caption = photo.alt || `Pexels photograph selected for ${searchQuery}.`;

      return {
        ...normalized,
        altText,
        caption,
        attribution: `Photo by ${photo.photographer} via Pexels`,
        license: "Pexels License",
        licenseUrl: PEXELS_LICENSE_URL,
        sourceUrl: photo.photoUrl,
        generated: false,
        provider: "pexels",
        providerAssetId: photo.id,
        photographer: photo.photographer,
        retrievedAt,
        selectionQuery: searchQuery,
        selectionScore: photo.score,
      };
    } catch {
      // A candidate may disappear or fail decoding after search. Continue only
      // through the already-ranked licensed shortlist, then publish text-only.
    }
  }

  return null;
}
