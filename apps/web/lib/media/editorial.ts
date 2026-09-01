import "server-only";
import { createHash } from "node:crypto";
import { deflateSync } from "node:zlib";
import type { VisualCandidate } from "@/lib/media/types";

const width = 1_600;
const height = 900;

function crc32(bytes: Buffer) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) crc = (crc >>> 1) ^ (0xedb88320 & -(crc & 1));
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type: string, data: Buffer) {
  const name = Buffer.from(type);
  const length = Buffer.alloc(4);
  const checksum = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  checksum.writeUInt32BE(crc32(Buffer.concat([name, data])));
  return Buffer.concat([length, name, data, checksum]);
}

function encodePng(pixels: Buffer) {
  const raw = Buffer.alloc((width * 4 + 1) * height);
  for (let y = 0; y < height; y += 1) {
    const row = y * (width * 4 + 1);
    raw[row] = 0;
    pixels.copy(raw, row + 1, y * width * 4, (y + 1) * width * 4);
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8;
  header[9] = 6;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", header),
    chunk("IDAT", deflateSync(raw, { level: 9 })),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

function paintCircle(pixels: Buffer, cx: number, cy: number, radius: number, color: number[]) {
  const minX = Math.max(0, Math.floor(cx - radius));
  const maxX = Math.min(width - 1, Math.ceil(cx + radius));
  const minY = Math.max(0, Math.floor(cy - radius));
  const maxY = Math.min(height - 1, Math.ceil(cy + radius));
  const squared = radius * radius;
  for (let y = minY; y <= maxY; y += 1) {
    for (let x = minX; x <= maxX; x += 1) {
      if ((x - cx) ** 2 + (y - cy) ** 2 > squared) continue;
      const offset = (y * width + x) * 4;
      pixels[offset] = color[0];
      pixels[offset + 1] = color[1];
      pixels[offset + 2] = color[2];
      pixels[offset + 3] = 255;
    }
  }
}

export function generateEditorialFallback(searchQuery: string, generationPrompt: string): VisualCandidate {
  const seed = createHash("sha256").update(`${searchQuery}:${generationPrompt}`).digest();
  const pixels = Buffer.alloc(width * height * 4);
  for (let y = 0; y < height; y += 1) {
    const blend = y / height;
    for (let x = 0; x < width; x += 1) {
      const offset = (y * width + x) * 4;
      pixels[offset] = 238 - Math.round(22 * blend);
      pixels[offset + 1] = 246 - Math.round(13 * blend);
      pixels[offset + 2] = 238 - Math.round(18 * blend);
      pixels[offset + 3] = 255;
    }
  }

  const palette = [
    [70, 119, 86],
    [111, 157, 124],
    [169, 197, 169],
    [47, 68, 64],
    [207, 222, 197],
  ];
  for (let index = 0; index < 18; index += 1) {
    const cx = 80 + ((seed[index] * 79 + index * 173) % 1_440);
    const cy = 70 + ((seed[index + 10] * 47 + index * 89) % 760);
    const radius = 35 + (seed[index + 5] % 125);
    paintCircle(pixels, cx, cy, radius, palette[index % palette.length]);
  }

  const lowerQuery = searchQuery.toLowerCase();
  const circularMotif = /(tire|wheel|cycle|transport|plastic|waste)/.test(lowerQuery);
  if (circularMotif) {
    paintCircle(pixels, 800, 450, 245, [47, 68, 64]);
    paintCircle(pixels, 800, 450, 135, [238, 246, 238]);
  } else {
    paintCircle(pixels, 800, 420, 210, [70, 119, 86]);
    paintCircle(pixels, 720, 350, 110, [169, 197, 169]);
    paintCircle(pixels, 900, 330, 130, [111, 157, 124]);
  }

  return {
    bytes: encodePng(pixels),
    contentType: "image/png",
    caption: "AI-directed editorial illustration created from this article’s visual plan.",
    attribution: "The Climate Note editorial system",
    license: "Original work for The Climate Note",
    sourceUrl: null,
    generated: true,
  };
}
