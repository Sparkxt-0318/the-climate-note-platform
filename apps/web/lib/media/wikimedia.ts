import "server-only";
import sanitizeHtml from "sanitize-html";
import { z } from "zod";
import { downloadImage } from "@/lib/media/download";
import type { VisualCandidate } from "@/lib/media/types";

const metadataValue = z.object({ value: z.string() }).optional();
const responseSchema = z.object({
  query: z
    .object({
      pages: z.record(
        z.string(),
        z.object({
          title: z.string(),
          imageinfo: z
            .array(
              z.object({
                url: z.url(),
                descriptionurl: z.url().optional(),
                width: z.number(),
                height: z.number(),
                mime: z.string(),
                extmetadata: z
                  .object({
                    LicenseShortName: metadataValue,
                    Artist: metadataValue,
                    Credit: metadataValue,
                    ImageDescription: metadataValue,
                  })
                  .optional(),
              }),
            )
            .optional(),
        }),
      ),
    })
    .optional(),
});

const allowedLicenses = /^(CC0|Public domain|PD|CC BY(?:-SA)?(?: \d\.\d)?)$/i;

function plain(value: string | undefined) {
  return sanitizeHtml(value || "", { allowedTags: [], allowedAttributes: {} })
    .replace(/\s+/g, " ")
    .trim();
}

export async function searchWikimedia(query: string): Promise<VisualCandidate | null> {
  const params = new URLSearchParams({
    action: "query",
    generator: "search",
    gsrsearch: query,
    gsrnamespace: "6",
    gsrlimit: "12",
    prop: "imageinfo",
    iiprop: "url|size|mime|extmetadata",
    format: "json",
    origin: "*",
  });
  const response = await fetch(`https://commons.wikimedia.org/w/api.php?${params}`, {
    headers: { "user-agent": "TheClimateNote/1.0 (theclimatenote@gmail.com)" },
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new Error(`Wikimedia search failed with ${response.status}.`);
  const result = responseSchema.parse(await response.json());
  const pages = Object.values(result.query?.pages ?? {});

  for (const page of pages) {
    const info = page.imageinfo?.[0];
    if (!info || info.width < 1_000 || info.height < 600 || info.width / info.height < 1.15) continue;
    if (!new Set(["image/jpeg", "image/png", "image/webp"]).has(info.mime)) continue;

    const license = plain(info.extmetadata?.LicenseShortName?.value);
    if (!allowedLicenses.test(license)) continue;

    try {
      const image = await downloadImage(info.url);
      const attribution = plain(info.extmetadata?.Artist?.value) || plain(info.extmetadata?.Credit?.value) || "Wikimedia Commons contributor";
      return {
        ...image,
        caption: plain(info.extmetadata?.ImageDescription?.value) || page.title.replace(/^File:/, ""),
        attribution,
        license,
        sourceUrl: info.descriptionurl ?? null,
        generated: false,
      };
    } catch {
      // Try the next rights-cleared result.
    }
  }

  return null;
}
