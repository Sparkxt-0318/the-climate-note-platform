import { z } from "zod";

export const articleBlockSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("paragraph"), text: z.string().min(1) }),
  z.object({ type: z.literal("heading"), level: z.union([z.literal(2), z.literal(3)]), text: z.string().min(1) }),
  z.object({ type: z.literal("bulletedList"), items: z.array(z.string().min(1)).min(1) }),
  z.object({ type: z.literal("numberedList"), items: z.array(z.string().min(1)).min(1) }),
]);

export const sourceLinkSchema = z.object({
  label: z.string().min(1),
  url: z.url(),
});

export const suggestedActionSchema = z.object({
  id: z.string().min(1),
  title: z.string().min(3).max(80),
  instruction: z.string().min(10).max(240),
  cadence: z.string().min(2).max(80),
  evidence: z.string().min(10),
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
  id: z.string().min(1),
  slug: z.string().min(1),
  title: z.string().min(1),
  author: z.string().nullable(),
  topic: z.string().default("Climate"),
  excerpt: z.string().min(1),
  status: z.enum(["draft", "validating", "ready", "published", "failed", "archived"]),
  contentBlocks: z.array(articleBlockSchema),
  sourceLinks: z.array(sourceLinkSchema),
  externalLinks: z
    .object({
      instagram: z.url().optional(),
      substack: z.url().optional(),
      medium: z.url().optional(),
    })
    .default({}),
  readingMinutes: z.number().int().positive(),
  publishedAt: z.string().nullable(),
  generation: generationSchema.nullable(),
  coverAsset: z
    .object({
      url: z.url(),
      altText: z.string(),
      caption: z.string(),
      attribution: z.string(),
      license: z.string(),
      sourceUrl: z.url().nullable(),
      generated: z.boolean(),
    })
    .nullable()
    .default(null),
});

export type Article = z.infer<typeof articleSchema>;
export type ArticleBlock = z.infer<typeof articleBlockSchema>;
export type ArticleGeneration = z.infer<typeof generationSchema>;
