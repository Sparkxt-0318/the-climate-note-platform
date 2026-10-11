import { describe, expect, it } from "vitest";
import { PexelsProviderError, searchPexelsPhotos } from "./pexels";

const validPhoto = {
  id: 123,
  width: 2400,
  height: 1350,
  url: "https://www.pexels.com/photo/river-123/",
  photographer: "Licensed Photographer",
  photographer_url: "https://www.pexels.com/@licensed-photographer/",
  alt: "A clean river landscape",
  src: { large2x: "https://images.pexels.com/photos/123/river.jpeg" },
};

describe("Pexels provider", () => {
  it("requests landscape candidates and drops untrusted provenance URLs", async () => {
    const calls: string[] = [];
    const photos = await searchPexelsPhotos("clean river", {
      apiKey: "test-key",
      fetchImplementation: async (input) => {
        calls.push(String(input));
        return new Response(JSON.stringify({
          photos: [validPhoto, { ...validPhoto, id: 456, src: { large2x: "https://example.com/not-pexels.jpg" } }],
        }), { status: 200, headers: { "content-type": "application/json" } });
      },
    });
    expect(calls[0]).toContain("orientation=landscape");
    expect(calls[0]).toContain("per_page=12");
    expect(photos.map((photo) => photo.id)).toEqual(["123"]);
  });

  it("reports missing configuration, rate limits, and invalid responses with typed errors", async () => {
    await expect(searchPexelsPhotos("river", { apiKey: "" })).rejects.toMatchObject({ code: "not-configured" });
    await expect(searchPexelsPhotos("river", {
      apiKey: "key",
      fetchImplementation: async () => new Response("", { status: 429 }),
    })).rejects.toMatchObject({ code: "rate-limited" });
    await expect(searchPexelsPhotos("river", {
      apiKey: "key",
      fetchImplementation: async () => new Response(JSON.stringify({ photos: "bad" }), { status: 200 }),
    })).rejects.toBeInstanceOf(PexelsProviderError);
  });
});
