import { describe, expect, it } from "vitest";
import sharp from "sharp";
import { ImageValidationError, sanitizePexelsImage } from "./image";

describe("licensed image normalization", () => {
  it("decodes, crops, strips source metadata, and produces a stable published hash", async () => {
    const source = await sharp({
      create: {
        width: 2_400,
        height: 1_600,
        channels: 3,
        background: "#2e624c",
      },
    })
      .withMetadata({ orientation: 6 })
      .png()
      .toBuffer();

    const first = await sanitizePexelsImage(source);
    const second = await sanitizePexelsImage(source);
    const metadata = await sharp(first.bytes).metadata();

    expect(first.contentType).toBe("image/jpeg");
    expect(first.width).toBe(1_600);
    expect(first.height).toBe(900);
    expect(first.crop).toEqual(second.crop);
    expect(first.contentHash).toBe(second.contentHash);
    expect(first.contentHash).toMatch(/^[a-f0-9]{64}$/);
    expect(metadata.width).toBe(1_600);
    expect(metadata.height).toBe(900);
    expect(metadata.orientation).toBeUndefined();
  });

  it("rejects a valid image that cannot satisfy the approved cover size", async () => {
    const source = await sharp({
      create: {
        width: 800,
        height: 450,
        channels: 3,
        background: "#2e624c",
      },
    })
      .jpeg()
      .toBuffer();

    await expect(sanitizePexelsImage(source)).rejects.toThrow(ImageValidationError);
  });

  it("rejects malformed bytes before publication", async () => {
    await expect(sanitizePexelsImage(Buffer.from("not an image"))).rejects.toThrow(
      "Image bytes could not be decoded safely.",
    );
  });
});
