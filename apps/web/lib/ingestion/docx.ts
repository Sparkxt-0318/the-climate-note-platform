import { createHash } from "node:crypto";
import * as cheerio from "cheerio";
import mammoth from "mammoth";
import type { ArticleBlock } from "@/lib/articles/schema";

export type ParsedSourceLink = { label: string; url: string };

export type ParsedDocx = {
  checksum: string;
  title: string;
  author: string | null;
  excerpt: string;
  blocks: ArticleBlock[];
  plainText: string;
  sourceLinks: ParsedSourceLink[];
  warnings: string[];
  wordCount: number;
  readingMinutes: number;
};

type Candidate =
  | { kind: "paragraph"; text: string; bold: boolean; links: ParsedSourceLink[] }
  | { kind: "heading"; level: 2 | 3; text: string; links: ParsedSourceLink[] }
  | { kind: "bulletedList"; items: string[]; links: ParsedSourceLink[] }
  | { kind: "numberedList"; items: string[]; links: ParsedSourceLink[] };

const sourceHeadingPattern = /^(sources?|references?|works cited)\s*:?[\s]*$/i;
const citationParagraphPattern = /^\[?\d+\]?\s*[-–—:]?\s*https?:\/\//i;
const urlPattern = /https?:\/\/[^\s<>)\]]+/g;

function cleanText(value: string) {
  return value.replace(/\u00a0/g, " ").replace(/[ \t]+/g, " ").trim();
}

function elementLinks($: cheerio.CheerioAPI, node: Parameters<cheerio.CheerioAPI>[0]): ParsedSourceLink[] {
  const links: ParsedSourceLink[] = [];
  $(node)
    .find("a[href]")
    .each((_, anchor) => {
      const url = $(anchor).attr("href");
      if (!url || !/^https?:\/\//i.test(url)) return;
      links.push({ label: cleanText($(anchor).text()) || url, url });
    });
  return links;
}

function linksFromText(text: string): ParsedSourceLink[] {
  return [...text.matchAll(urlPattern)].map(([url]) => ({ label: url, url }));
}

function isSemanticHeadingTag(tagName: string): tagName is "h1" | "h2" | "h3" {
  return tagName === "h1" || tagName === "h2" || tagName === "h3";
}

function candidatesFromHtml(html: string): Candidate[] {
  const $ = cheerio.load(`<main>${html}</main>`);
  const candidates: Candidate[] = [];

  $("main")
    .children()
    .each((_, rawNode) => {
      if (rawNode.type !== "tag") return;
      const tagName = rawNode.tagName.toLowerCase();
      const text = cleanText($(rawNode).text());
      if (!text) return;

      if (tagName === "ul" || tagName === "ol") {
        const items = $(rawNode)
          .children("li")
          .toArray()
          .map((item) => cleanText($(item).text()))
          .filter(Boolean);
        if (items.length > 0) {
          candidates.push({
            kind: tagName === "ul" ? "bulletedList" : "numberedList",
            items,
            links: elementLinks($, rawNode),
          });
        }
        return;
      }

      const links = [...elementLinks($, rawNode), ...linksFromText(text)];
      const uniqueLinks = [...new Map(links.map((link) => [link.url, link])).values()];

      if (isSemanticHeadingTag(tagName)) {
        candidates.push({ kind: "heading", level: tagName === "h3" ? 3 : 2, text, links: uniqueLinks });
        return;
      }

      if (tagName !== "p") return;
      const meaningfulChildren = $(rawNode).children().toArray();
      const strongText = cleanText($(rawNode).find("strong, b").text());
      const bold = strongText.length > 0 && strongText === text;
      const looksLikeHeading = bold && text.length <= 100 && !/[.!?]$/.test(text);

      if (looksLikeHeading) {
        candidates.push({ kind: "heading", level: 2, text, links: uniqueLinks });
      } else {
        candidates.push({
          kind: "paragraph",
          text,
          bold: meaningfulChildren.length > 0 && bold,
          links: uniqueLinks,
        });
      }
    });

  return candidates;
}

function dedupeLinks(links: ParsedSourceLink[]) {
  return [...new Map(links.map((link) => [link.url, link])).values()];
}

export function normalizeCandidates(candidates: Candidate[], fallbackTitle?: string) {
  const firstContentIndex = candidates.findIndex((candidate) => "text" in candidate && candidate.text.length > 0);
  if (firstContentIndex < 0) throw new Error("The DOCX does not contain readable text.");

  const titleCandidate = candidates[firstContentIndex];
  if (!("text" in titleCandidate)) throw new Error("The DOCX title could not be determined.");
  const firstContentIsTitle = titleCandidate.text.length <= 180;
  const cleanedFallback = cleanText(fallbackTitle?.replace(/\.docx$/i, "") ?? "");
  const title = firstContentIsTitle ? titleCandidate.text : cleanedFallback;
  if (!title) throw new Error("The DOCX needs a title or a descriptive file name.");
  const blocks: ArticleBlock[] = [];
  const sourceLinks: ParsedSourceLink[] = [];
  const warnings: string[] = [];
  let inSources = false;

  for (const [index, candidate] of candidates.entries()) {
    if (firstContentIsTitle && index === firstContentIndex) continue;

    if ("text" in candidate && sourceHeadingPattern.test(candidate.text)) {
      inSources = true;
      sourceLinks.push(...candidate.links);
      continue;
    }

    const isCitation =
      "text" in candidate &&
      (citationParagraphPattern.test(candidate.text) ||
        (candidate.links.length > 0 && /^\[?\d+\]?\s*[-–—:]?/.test(candidate.text)));

    if (inSources || isCitation) {
      sourceLinks.push(...candidate.links);
      if (candidate.links.length === 0 && "text" in candidate) {
        sourceLinks.push(...linksFromText(candidate.text));
      }
      continue;
    }

    if (candidate.kind === "heading") {
      blocks.push({ type: "heading", level: candidate.level, text: candidate.text });
    } else if (candidate.kind === "bulletedList") {
      blocks.push({ type: "bulletedList", items: candidate.items });
    } else if (candidate.kind === "numberedList") {
      blocks.push({ type: "numberedList", items: candidate.items });
    } else {
      blocks.push({ type: "paragraph", text: candidate.text });
    }
  }

  if (blocks.length === 0) throw new Error("The DOCX contains a title but no article body.");
  if (sourceLinks.length === 0) warnings.push("No source links were detected.");

  return { title, blocks, sourceLinks: dedupeLinks(sourceLinks), warnings };
}

function blockText(block: ArticleBlock) {
  if (block.type === "bulletedList" || block.type === "numberedList") return block.items.join("\n");
  return block.text;
}

function makeExcerpt(blocks: ArticleBlock[]) {
  const paragraph = blocks.find((block) => block.type === "paragraph");
  if (!paragraph || paragraph.type !== "paragraph") return "A new climate note.";
  if (paragraph.text.length <= 180) return paragraph.text;
  const shortened = paragraph.text.slice(0, 177).replace(/\s+\S*$/, "");
  return `${shortened}…`;
}

export async function parseDocx(buffer: Buffer, fallbackTitle?: string): Promise<ParsedDocx> {
  const checksum = createHash("sha256").update(buffer).digest("hex");
  const result = await mammoth.convertToHtml(
    { buffer },
    {
      styleMap: [
        "p[style-name='Title'] => h1:fresh",
        "p[style-name='Heading 1'] => h2:fresh",
        "p[style-name='Heading 2'] => h3:fresh",
      ],
      includeDefaultStyleMap: true,
    },
  );

  const normalized = normalizeCandidates(candidatesFromHtml(result.value), fallbackTitle);
  const plainText = normalized.blocks.map(blockText).join("\n\n");
  const wordCount = plainText.split(/\s+/).filter(Boolean).length;

  return {
    checksum,
    title: normalized.title,
    author: null,
    excerpt: makeExcerpt(normalized.blocks),
    blocks: normalized.blocks,
    plainText,
    sourceLinks: normalized.sourceLinks,
    warnings: [...result.messages.map((message) => message.message), ...normalized.warnings],
    wordCount,
    readingMinutes: Math.max(1, Math.ceil(wordCount / 220)),
  };
}
