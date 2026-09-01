import "server-only";
import { GoogleGenAI } from "@google/genai";
import Groq from "groq-sdk";
import { z } from "zod";
import { generationSchema, type ArticleGeneration } from "@/lib/articles/schema";

export type EnrichmentResult = {
  generation: ArticleGeneration;
  provider: "gemini" | "groq";
  model: string;
};

const responseJsonSchema = {
  type: "object",
  additionalProperties: false,
  required: ["summary", "suggestedActions", "visualPlan"],
  properties: {
    summary: {
      type: "object",
      additionalProperties: false,
      required: ["problem", "whyItMatters", "whatWeCanDo"],
      properties: {
        problem: { type: "string" },
        whyItMatters: { type: "string" },
        whatWeCanDo: { type: "string" },
      },
    },
    suggestedActions: {
      type: "array",
      minItems: 3,
      maxItems: 3,
      items: {
        type: "object",
        additionalProperties: false,
        required: ["id", "title", "instruction", "cadence", "evidence", "category", "factorId", "factorQuantity"],
        properties: {
          id: { type: "string" },
          title: { type: "string" },
          instruction: { type: "string" },
          cadence: { type: "string" },
          evidence: { type: "string" },
          category: {
            type: "string",
            enum: ["food", "transport", "energy", "waste", "nature", "water", "civic", "learning"],
          },
          factorId: { anyOf: [{ type: "string" }, { type: "null" }] },
          factorQuantity: { anyOf: [{ type: "number", minimum: 0.01, maximum: 1000 }, { type: "null" }] },
        },
      },
    },
    visualPlan: {
      type: "object",
      additionalProperties: false,
      required: ["searchQuery", "altText", "placement", "generationPrompt"],
      properties: {
        searchQuery: { type: "string" },
        altText: { type: "string" },
        placement: { type: "string", enum: ["cover", "after-introduction"] },
        generationPrompt: { type: "string" },
      },
    },
  },
} as const;

function promptForArticle(title: string, articleText: string) {
  return `You are preparing clearly labeled derivative material for The Climate Note, a climate publication for readers age 13 and older.

The source article is immutable. Do not rewrite, correct, extend, or quote it as though your output were part of the article.

Return JSON matching the supplied schema.

Summary rules:
- Explain the current problem, why it matters, and what people can do.
- Use plain, concise English understandable to a middle-school reader.
- Define unavoidable jargon in everyday language.
- Use only claims supported by the source article.

Action rules:
- Return exactly three actions.
- Every action must be specific, achievable, safe, inexpensive, and directly related to this article.
- Include a quantity or frequency in "cadence".
- "evidence" must be one exact, contiguous sentence copied from the source article. It is used internally for grounding and is not displayed.
- Numerical impact is an estimate calculated by the app, never by you. Use one of these factor IDs only when the action instruction explicitly includes the matching measurable quantity:
  - passenger-vehicle-mile-avoided-us: factorQuantity is miles of travel replaced, U.S. average passenger-vehicle tailpipe CO2 only.
  - electricity-kwh-avoided-us: factorQuantity is kWh that the instruction genuinely helps the user avoid, U.S. national marginal electricity estimate.
  - mixed-recyclables-pound-us: factorQuantity is pounds of eligible mixed recyclables recycled instead of landfilled.
- Otherwise set both factorId and factorQuantity to null. Never guess a quantity or convert minutes, objects, meals, water, or general habits into CO2.
- Use IDs action-1, action-2, and action-3.

Visual-plan rules:
- Choose whether the key visual belongs at the cover or after the introduction.
- Write a concise search query for a rights-cleared documentary photograph or scientific image.
- Write useful alt text without saying "image of".
- Write a generation prompt for a clean editorial illustration as a fallback.
- Do not request a numerical chart unless the article itself contains sufficient cited numerical data.

TITLE:
${title}

SOURCE ARTICLE:
${articleText}`;
}

function validateGrounding(articleText: string, generation: ArticleGeneration) {
  for (const action of generation.suggestedActions) {
    if (!articleText.includes(action.evidence.trim())) {
      throw new Error(`Action ${action.id} is not grounded in an exact source sentence.`);
    }
  }
}

function parseGeneration(raw: string, articleText: string) {
  const parsedJson: unknown = JSON.parse(raw);
  const generation = generationSchema.parse(parsedJson);
  validateGrounding(articleText, generation);
  return generation;
}

function isRetryableGenerationError(error: unknown) {
  const candidate = error as { status?: number; code?: number | string; message?: string };
  const status = Number(candidate?.status ?? candidate?.code);
  const message = candidate?.message?.toLowerCase() ?? "";
  return (
    status === 429 ||
    status === 500 ||
    status === 502 ||
    status === 503 ||
    status === 504 ||
    message.includes("rate limit") ||
    message.includes("resource exhausted") ||
    message.includes("temporarily unavailable")
  );
}

async function withGenerationRetry<T>(operation: () => Promise<T>) {
  const delays = [1_000, 3_000];
  let lastError: unknown;

  for (let attempt = 0; attempt <= delays.length; attempt += 1) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      if (!isRetryableGenerationError(error) || attempt === delays.length) throw error;
      await new Promise((resolve) => setTimeout(resolve, delays[attempt]));
    }
  }

  throw lastError;
}

async function generateWithGemini(title: string, articleText: string): Promise<EnrichmentResult> {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) throw new Error("Gemini is not configured.");
  const model = process.env.GEMINI_MODEL || "gemini-3.5-flash-lite";
  const ai = new GoogleGenAI({ apiKey });
  const response = await withGenerationRetry(() =>
    ai.models.generateContent({
      model,
      contents: promptForArticle(title, articleText),
      config: {
        responseMimeType: "application/json",
        responseJsonSchema,
      },
    }),
  );
  if (!response.text) throw new Error("Gemini returned an empty response.");
  return { generation: parseGeneration(response.text, articleText), provider: "gemini", model };
}

async function generateWithGroq(title: string, articleText: string): Promise<EnrichmentResult> {
  const apiKey = process.env.GROQ_API_KEY;
  if (!apiKey) throw new Error("Groq is not configured.");
  const model = process.env.GROQ_MODEL || "openai/gpt-oss-20b";
  const client = new Groq({ apiKey });
  const response = await client.chat.completions.create({
    model,
    temperature: 0.2,
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: "Return only valid JSON matching every requirement in the user message." },
      { role: "user", content: promptForArticle(title, articleText) },
    ],
  });
  const raw = response.choices[0]?.message.content;
  if (!raw) throw new Error("Groq returned an empty response.");
  return { generation: parseGeneration(raw, articleText), provider: "groq", model };
}

export async function enrichArticle(title: string, articleText: string): Promise<EnrichmentResult> {
  const errors: string[] = [];

  if (process.env.GEMINI_API_KEY) {
    try {
      return await generateWithGemini(title, articleText);
    } catch (error) {
      errors.push(`Gemini: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  if (process.env.GROQ_API_KEY) {
    try {
      return await generateWithGroq(title, articleText);
    } catch (error) {
      errors.push(`Groq: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  throw new Error(errors.length > 0 ? errors.join(" | ") : "No text-generation provider is configured.");
}

export function validateGeneration(value: unknown) {
  return generationSchema.parse(value);
}

export function enrichmentConfigurationStatus() {
  return z.object({ gemini: z.boolean(), groq: z.boolean() }).parse({
    gemini: Boolean(process.env.GEMINI_API_KEY),
    groq: Boolean(process.env.GROQ_API_KEY),
  });
}
