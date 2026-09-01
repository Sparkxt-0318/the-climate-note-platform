import "server-only";
import { generateCloudflareImage } from "@/lib/media/cloudflare";
import { generateEditorialFallback } from "@/lib/media/editorial";
import { searchNasaImages } from "@/lib/media/nasa";
import type { VisualCandidate } from "@/lib/media/types";
import { searchWikimedia } from "@/lib/media/wikimedia";

export async function selectArticleVisual(searchQuery: string, generationPrompt: string): Promise<VisualCandidate> {
  const errors: string[] = [];
  for (const search of [searchWikimedia, searchNasaImages]) {
    try {
      const candidate = await search(searchQuery);
      if (candidate) return candidate;
    } catch (error) {
      errors.push(error instanceof Error ? error.message : String(error));
    }
  }

  try {
    return await generateCloudflareImage(
      `${generationPrompt} Landscape 16:9 composition. Clean youth-focused climate editorial style. No text, labels, logos, or photorealistic people.`,
    );
  } catch (error) {
    errors.push(error instanceof Error ? error.message : String(error));
  }

  return generateEditorialFallback(searchQuery, generationPrompt);
}
