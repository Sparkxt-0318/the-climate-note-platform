import { createHash } from "node:crypto";
import sharp, { type Metadata } from "sharp";
import { centeredCoverCrop } from "@/lib/media/policy";
import type { CoverCrop } from "@/lib/media/types";

const maxDecodedPixels = 30_000_000;
const coverWidth = 1_600;
const coverHeight = 900;

export class ImageValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ImageValidationError";
  }
}

function orientedDimensions(width: number, height: number, orientation: number | undefined) {
  return orientation && [5, 6, 7, 8].includes(orientation) ? { width: height, height: width } : { width, height };
}

/**
 * Decodes untrusted bytes under a pixel limit, centre-crops them for the
 * approved 16:9 cover treatment, and re-encodes a JPEG without EXIF or other
 * input metadata. The resulting hash identifies precisely what was published.
 */
export async function sanitizePexelsImage(
  bytes: Buffer,
): Promise<{ bytes: Buffer; contentType: "image/jpeg"; width: number; height: number; crop: CoverCrop; contentHash: string }> {
  let metadata: Metadata;
  try {
    metadata = await sharp(bytes, { limitInputPixels: maxDecodedPixels, failOn: "error" }).metadata();
  } catch {
    throw new ImageValidationError("Image bytes could not be decoded safely.");
  }

  if (!metadata.width || !metadata.height) throw new ImageValidationError("Image dimensions are unavailable.");
  const dimensions = orientedDimensions(metadata.width, metadata.height, metadata.orientation);
  if (dimensions.width < 1_600 || dimensions.height < 900) {
    throw new ImageValidationError("Image does not meet the minimum 1600×900 cover size.");
  }
  if (dimensions.width * dimensions.height > maxDecodedPixels) {
    throw new ImageValidationError("Image exceeds the decoded-pixel safety limit.");
  }

  let sanitized: Buffer;
  try {
    sanitized = await sharp(bytes, { limitInputPixels: maxDecodedPixels, failOn: "error" })
      .rotate()
      .resize(coverWidth, coverHeight, { fit: "cover", position: "centre" })
      .jpeg({ quality: 84, mozjpeg: true })
      .toBuffer();
  } catch {
    throw new ImageValidationError("Image could not be normalized for publication.");
  }

  return {
    bytes: sanitized,
    contentType: "image/jpeg",
    width: coverWidth,
    height: coverHeight,
    crop: centeredCoverCrop(dimensions.width, dimensions.height),
    contentHash: createHash("sha256").update(sanitized).digest("hex"),
  };
}
