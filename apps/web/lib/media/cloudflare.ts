import "server-only";
import { z } from "zod";
import type { VisualCandidate } from "@/lib/media/types";

const cloudflareResponseSchema = z.object({
  success: z.boolean(),
  result: z.object({ image: z.string() }).optional(),
  errors: z.array(z.object({ message: z.string().optional() })).optional(),
});

export function cloudflareImageConfigured() {
  return Boolean(process.env.CLOUDFLARE_ACCOUNT_ID && process.env.CLOUDFLARE_API_TOKEN);
}

export async function generateCloudflareImage(prompt: string): Promise<VisualCandidate> {
  const accountId = process.env.CLOUDFLARE_ACCOUNT_ID;
  const token = process.env.CLOUDFLARE_API_TOKEN;
  if (!accountId || !token) throw new Error("Cloudflare image generation is not configured.");

  const model = "@cf/black-forest-labs/flux-1-schnell";
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${encodeURIComponent(accountId)}/ai/run/${model}`,
    {
      method: "POST",
      headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
      body: JSON.stringify({ prompt, steps: 8 }),
      signal: AbortSignal.timeout(90_000),
    },
  );
  const raw: unknown = await response.json();
  const parsed = cloudflareResponseSchema.parse(raw);
  if (!response.ok || !parsed.success || !parsed.result?.image) {
    const detail = parsed.errors?.map((error) => error.message).filter(Boolean).join("; ");
    throw new Error(`Cloudflare image generation failed${detail ? `: ${detail}` : ` with ${response.status}`}.`);
  }

  const bytes = Buffer.from(parsed.result.image, "base64");
  if (bytes.length < 10_000) throw new Error("Cloudflare returned an unexpectedly small image.");
  return {
    bytes,
    contentType: "image/jpeg",
    caption: "Editorial illustration generated for this Climate Note.",
    attribution: "AI-generated with Cloudflare Workers AI",
    license: "Generated for The Climate Note",
    sourceUrl: null,
    generated: true,
  };
}
