import "server-only";

const allowedTypes = new Set(["image/jpeg", "image/png", "image/webp"] as const);

export async function downloadImage(url: string) {
  const response = await fetch(url, {
    headers: { "user-agent": "TheClimateNote/1.0 (theclimatenote@gmail.com)" },
    redirect: "follow",
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new Error(`Image download failed with ${response.status}.`);

  const rawContentType = response.headers.get("content-type")?.split(";")[0].trim().toLowerCase();
  if (!rawContentType || !allowedTypes.has(rawContentType as "image/jpeg" | "image/png" | "image/webp")) {
    throw new Error(`Unsupported image type: ${rawContentType || "unknown"}.`);
  }

  const bytes = Buffer.from(await response.arrayBuffer());
  if (bytes.length < 10_000) throw new Error("Image is unexpectedly small.");
  if (bytes.length > 12_000_000) throw new Error("Image exceeds the 12 MB ingestion limit.");

  return {
    bytes,
    contentType: rawContentType as "image/jpeg" | "image/png" | "image/webp",
  };
}
