import { readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { normalizeCandidates, parseDocx } from "./docx";

describe("normalizeCandidates", () => {
  it("separates article content from a numbered source block", () => {
    const result = normalizeCandidates([
      { kind: "paragraph", text: "A Climate Story", bold: true, links: [] },
      { kind: "paragraph", text: "The original body remains unchanged.", bold: false, links: [] },
      { kind: "paragraph", text: "Sources:", bold: false, links: [] },
      {
        kind: "paragraph",
        text: "[1] - https://example.org/report",
        bold: false,
        links: [{ label: "https://example.org/report", url: "https://example.org/report" }],
      },
    ]);

    expect(result.title).toBe("A Climate Story");
    expect(result.blocks).toEqual([{ type: "paragraph", text: "The original body remains unchanged." }]);
    expect(result.sourceLinks).toHaveLength(1);
  });

  it("uses the DOCX file name when the first paragraph is article content", () => {
    const opening = "This is article content, not a title. ".repeat(8).trim();
    const result = normalizeCandidates(
      [
        { kind: "paragraph", text: opening, bold: false, links: [] },
        { kind: "paragraph", text: "The second body paragraph.", bold: false, links: [] },
      ],
      "A Descriptive Climate Title.docx",
    );

    expect(result.title).toBe("A Descriptive Climate Title");
    expect(result.blocks[0]).toEqual({ type: "paragraph", text: opening });
  });

  it("omits insecure citations before an article can be published", () => {
    const result = normalizeCandidates([
      { kind: "paragraph", text: "A Climate Story", bold: true, links: [] },
      { kind: "paragraph", text: "The original body remains unchanged.", bold: false, links: [] },
      { kind: "paragraph", text: "Sources:", bold: false, links: [] },
      {
        kind: "paragraph",
        text: "[1] - http://example.org/legacy",
        bold: false,
        links: [{ label: "Legacy source", url: "http://example.org/legacy" }],
      },
      {
        kind: "paragraph",
        text: "[2] - https://example.org/current",
        bold: false,
        links: [{ label: "Current source", url: "https://example.org/current" }],
      },
    ]);

    expect(result.sourceLinks).toEqual([{ label: "Current source", url: "https://example.org/current" }]);
    expect(result.warnings).toContain("1 insecure source link was omitted; sources must use HTTPS.");
  });
});

const woodSample = process.env.CLIMATE_NOTE_SAMPLE_WOOD;
const philippinesSample = process.env.CLIMATE_NOTE_SAMPLE_PHILIPPINES;

describe.skipIf(!woodSample || !existsSync(woodSample))("Wood-Wide Web sample", () => {
  it("preserves the title, bullets, and seven source links", async () => {
    const article = await parseDocx(await readFile(woodSample!));
    expect(article.title).toBe("Wood-Wide Web");
    expect(article.blocks.some((block) => block.type === "bulletedList")).toBe(true);
    expect(article.sourceLinks).toHaveLength(7);
  });
});

describe.skipIf(!philippinesSample || !existsSync(philippinesSample))("Philippines sample", () => {
  it("extracts intact text rather than rendered line-break artifacts", async () => {
    const article = await parseDocx(await readFile(philippinesSample!));
    expect(article.title).toBe("Unregulated coastal aquaculture waste (Yeseo)");
    expect(article.plainText).toContain("Sounds like a green solution");
    expect(article.plainText).toContain("impossible to hold anyone liable");
    expect(article.sourceLinks).toHaveLength(3);
  });
});
