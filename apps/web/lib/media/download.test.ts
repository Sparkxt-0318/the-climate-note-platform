import { describe, expect, it, vi } from "vitest";
import { downloadPexelsImage, PexelsImageDownloadError } from "./download";

describe("Pexels image download boundary", () => {
  it("rejects a non-Pexels host without issuing a request", async () => {
    const fetchImplementation = vi.fn<typeof fetch>();
    await expect(
      downloadPexelsImage("https://example.com/photo.jpg", fetchImplementation),
    ).rejects.toBeInstanceOf(PexelsImageDownloadError);
    expect(fetchImplementation).not.toHaveBeenCalled();
  });

  it("rejects a redirect that leaves the exact approved CDN host", async () => {
    const fetchImplementation = vi.fn<typeof fetch>().mockResolvedValue(
      new Response(null, {
        status: 302,
        headers: { location: "https://evil.example/photo.jpg" },
      }),
    );
    await expect(
      downloadPexelsImage("https://images.pexels.com/photos/123/photo.jpg", fetchImplementation),
    ).rejects.toThrow("Image URL is not an allowed Pexels image host.");
    expect(fetchImplementation).toHaveBeenCalledTimes(1);
  });

  it("accepts a bounded supported image response", async () => {
    const bytes = new Uint8Array(10_001).fill(1);
    const fetchImplementation = vi.fn<typeof fetch>().mockResolvedValue(
      new Response(bytes, {
        status: 200,
        headers: { "content-type": "image/jpeg", "content-length": String(bytes.byteLength) },
      }),
    );
    const result = await downloadPexelsImage(
      "https://images.pexels.com/photos/123/photo.jpg",
      fetchImplementation,
    );
    expect(result.contentType).toBe("image/jpeg");
    expect(result.bytes).toHaveLength(bytes.byteLength);
  });

  it("rejects an oversized declaration before reading the body", async () => {
    const fetchImplementation = vi.fn<typeof fetch>().mockResolvedValue(
      new Response(new Uint8Array(1), {
        status: 200,
        headers: { "content-type": "image/jpeg", "content-length": "12000001" },
      }),
    );
    await expect(
      downloadPexelsImage("https://images.pexels.com/photos/123/photo.jpg", fetchImplementation),
    ).rejects.toThrow("Image exceeds the 12 MB ingestion limit.");
  });
});
