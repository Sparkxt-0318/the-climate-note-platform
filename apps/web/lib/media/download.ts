import "server-only";
import { isPexelsImageUrl } from "@/lib/media/policy";

const allowedContentTypes = new Set(["image/jpeg", "image/png", "image/webp"] as const);
const maxBytes = 12_000_000;
const maxRedirects = 2;

export class PexelsImageDownloadError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "PexelsImageDownloadError";
  }
}

function assertAllowedPexelsImageUrl(value: string) {
  if (!isPexelsImageUrl(value)) {
    throw new PexelsImageDownloadError("Image URL is not an allowed Pexels image host.");
  }
  return new URL(value);
}

async function readBoundedBody(response: Response) {
  const declaredLength = Number(response.headers.get("content-length"));
  if (Number.isFinite(declaredLength) && declaredLength > maxBytes) {
    throw new PexelsImageDownloadError("Image exceeds the 12 MB ingestion limit.");
  }

  const reader = response.body?.getReader();
  if (!reader) throw new PexelsImageDownloadError("Image response has no body.");

  const chunks: Uint8Array[] = [];
  let total = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    total += value.byteLength;
    if (total > maxBytes) {
      await reader.cancel();
      throw new PexelsImageDownloadError("Image exceeds the 12 MB ingestion limit.");
    }
    chunks.push(value);
  }

  if (total < 10_000) throw new PexelsImageDownloadError("Image is unexpectedly small.");
  return Buffer.concat(chunks.map((chunk) => Buffer.from(chunk)));
}

/**
 * Keeps a provider-controlled redirect chain on the exact Pexels CDN host.
 * `redirect: manual` prevents a provider response from turning this endpoint
 * into an SSRF fetcher.
 */
export async function downloadPexelsImage(
  sourceUrl: string,
  fetchImplementation: typeof fetch = fetch,
): Promise<{ bytes: Buffer; contentType: "image/jpeg" | "image/png" | "image/webp" }> {
  let target = assertAllowedPexelsImageUrl(sourceUrl);

  for (let redirectCount = 0; redirectCount <= maxRedirects; redirectCount += 1) {
    let response: Response;
    try {
      response = await fetchImplementation(target, {
        headers: { "user-agent": "TheClimateNote/1.0" },
        redirect: "manual",
        signal: AbortSignal.timeout(20_000),
        cache: "no-store",
      });
    } catch {
      throw new PexelsImageDownloadError("Pexels image download was unavailable.");
    }

    if ([301, 302, 303, 307, 308].includes(response.status)) {
      const location = response.headers.get("location");
      if (!location || redirectCount === maxRedirects) {
        throw new PexelsImageDownloadError("Pexels image redirect is invalid.");
      }
      target = assertAllowedPexelsImageUrl(new URL(location, target).toString());
      continue;
    }

    if (!response.ok) throw new PexelsImageDownloadError(`Pexels image download failed with ${response.status}.`);
    const rawContentType = response.headers.get("content-type")?.split(";", 1)[0]?.trim().toLowerCase();
    if (!rawContentType || !allowedContentTypes.has(rawContentType as "image/jpeg" | "image/png" | "image/webp")) {
      throw new PexelsImageDownloadError(`Unsupported image type: ${rawContentType || "unknown"}.`);
    }

    return {
      bytes: await readBoundedBody(response),
      contentType: rawContentType as "image/jpeg" | "image/png" | "image/webp",
    };
  }

  throw new PexelsImageDownloadError("Pexels image redirect limit reached.");
}
