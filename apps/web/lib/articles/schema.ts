import { z } from "zod";

const httpsUrlSchema = z.url().refine((value) => new URL(value).protocol === "https:", "Use an HTTPS URL.");

export const articleBlockSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("paragraph"), text: z.string().min(1).max(20_000) }).strict(),
  z.object({
    type: z.literal("heading"),
    level: z.union([z.literal(2), z.literal(3)]),
    text: z.string().min(1).max(300),
  }).strict(),
  z.object({
    type: z.literal("bulletedList"),
    items: z.array(z.string().min(1).max(2_000)).min(1).max(100),
  }).strict(),
  z.object({
    type: z.literal("numberedList"),
    items: z.array(z.string().min(1).max(2_000)).min(1).max(100),
  }).strict(),
]);

export const sourceLinkSchema = z.object({
  label: z.string().min(1).max(500),
  url: httpsUrlSchema,
}).strict();

export const suggestedActionSchema = z.object({
  id: z.string().min(1),
  title: z.string().min(3).max(80),
  instruction: z.string().min(10).max(240),
  cadence: z.string().min(2).max(80),
  evidence: z.string().min(10).max(2_000),
  category: z.enum(["food", "transport", "energy", "waste", "nature", "water", "civic", "learning"]),
  factorId: z.string().min(1).nullable(),
  factorQuantity: z.number().positive().max(1_000).nullable().default(null),
});

export const generationSchema = z.object({
  summary: z.object({
    problem: z.string().min(20).max(500),
    whyItMatters: z.string().min(20).max(500),
    whatWeCanDo: z.string().min(20).max(500),
  }),
  suggestedActions: z.array(suggestedActionSchema).length(3),
  visualPlan: z.object({
    searchQuery: z.string().min(3).max(120),
    altText: z.string().min(10).max(220),
    placement: z.enum(["cover", "after-introduction"]),
    generationPrompt: z.string().min(20).max(700),
  }),
});

export const articleSchema = z.object({
  id: z.string().min(1).max(200),
  slug: z.string().min(1).max(200).regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/),
  title: z.string().min(1).max(180),
  author: z.string().max(160).nullable(),
  topic: z.string().max(80).default("Climate"),
  excerpt: z.string().min(1).max(500),
  status: z.enum(["draft", "validating", "ready", "published", "failed", "archived"]),
  contentBlocks: z.array(articleBlockSchema).max(500),
  sourceLinks: z.array(sourceLinkSchema).max(100),
  externalLinks: z
    .object({
      instagram: httpsUrlSchema.optional(),
      substack: httpsUrlSchema.optional(),
      medium: httpsUrlSchema.optional(),
    })
    .default({}),
  readingMinutes: z.number().int().positive(),
  publishedAt: z.string().nullable(),
  generation: generationSchema.nullable(),
  coverAsset: z
    .object({
      url: httpsUrlSchema,
      altText: z.string().max(500),
      caption: z.string().max(500),
      attribution: z.string().max(500),
      license: z.string().max(200),
      licenseUrl: httpsUrlSchema.optional(),
      sourceUrl: httpsUrlSchema.nullable(),
      generated: z.boolean(),
      provider: z.string().max(80).optional(),
      providerAssetId: z.string().max(200).optional(),
      photographer: z.string().max(200).optional(),
      contentHash: z.string().max(128).optional(),
      contentType: z.string().max(100).optional(),
      retrievedAt: z.string().max(80).optional(),
      crop: z.object({
        x: z.number().min(0).max(1),
        y: z.number().min(0).max(1),
        width: z.number().positive().max(1),
        height: z.number().positive().max(1),
      }).optional(),
    })
    .nullable()
    .default(null),
});

export type Article = z.infer<typeof articleSchema>;
export type ArticleBlock = z.infer<typeof articleBlockSchema>;
export type ArticleGeneration = z.infer<typeof generationSchema>;
