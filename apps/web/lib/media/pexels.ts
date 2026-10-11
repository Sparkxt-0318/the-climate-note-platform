import "server-only";
import { z } from "zod";
import { isPexelsImageUrl, isPexelsWebsiteUrl, type PexelsPhoto } from "@/lib/media/policy";

const pexelsSearchSchema = z.object({
  photos: z.array(
    z.object({
      id: z.number().int().positive(),
      width: z.number().int().positive(),
      height: z.number().int().positive(),
      url: z.url(),
      photographer: z.string(),
      photographer_url: z.url(),
      alt: z.string().optional().default(""),
      src: z.object({ large2x: z.url().optional(), large: z.url().optional() }),
    }),
  ),
});

export class PexelsProviderError extends Error {
  constructor(
    readonly code: "not-configured" | "timeout" | "rate-limited" | "unavailable" | "invalid-response",
    message: string,
  ) {
    super(message);
    this.name = "PexelsProviderError";
  }
}

type FetchLike = typeof fetch;

function safePexelsPhoto(value: z.infer<typeof pexelsSearchSchema>["photos"][number]): PexelsPhoto | null {
  const imageUrl = value.src.large2x ?? value.src.large;
  if (!imageUrl || !isPexelsWebsiteUrl(value.url) || !isPexelsWebsiteUrl(value.photographer_url) || !isPexelsImageUrl(imageUrl)) {
    return null;
  }

  return {
    id: String(value.id),
    width: value.width,
    height: value.height,
    photoUrl: value.url,
    photographer: value.photographer.trim(),
    photographerUrl: value.photographer_url,
    imageUrl,
    alt: value.alt.replace(/\s+/g, " ").trim(),
  };
}

export async function searchPexelsPhotos(
  searchQuery: string,
  options: { apiKey?: string; fetchImplementation?: FetchLike } = {},
): Promise<PexelsPhoto[]> {
  const apiKey = options.apiKey ?? process.env.PEXELS_API_KEY;
  if (!apiKey) throw new PexelsProviderError("not-configured", "Pexels image search is not configured.");

  const params = new URLSearchParams({
    query: searchQuery,
    orientation: "landscape",
    size: "large",
    per_page: "12",
    page: "1",
  });

  let response: Response;
  try {
    response = await (options.fetchImplementation ?? fetch)(`https://api.pexels.com/v1/search?${params}`, {
      headers: { authorization: apiKey, "user-agent": "TheClimateNote/1.0" },
      signal: AbortSignal.timeout(15_000),
      cache: "no-store",
    });
  } catch (error) {
    const name = error instanceof Error ? error.name : "";
    throw new PexelsProviderError(name === "TimeoutError" || name === "AbortError" ? "timeout" : "unavailable", "Pexels image search was unavailable.");
  }

  if (response.status === 429) throw new PexelsProviderError("rate-limited", "Pexels image search is rate limited.");
  if (!response.ok) throw new PexelsProviderError("unavailable", `Pexels image search failed with ${response.status}.`);

  let parsed: z.infer<typeof pexelsSearchSchema>;
  try {
    parsed = pexelsSearchSchema.parse(await response.json());
  } catch {
    throw new PexelsProviderError("invalid-response", "Pexels returned invalid image metadata.");
  }

  return parsed.photos.map(safePexelsPhoto).filter((photo): photo is PexelsPhoto => photo !== null);
}
