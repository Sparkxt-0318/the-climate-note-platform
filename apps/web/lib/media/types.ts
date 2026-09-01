export type VisualCandidate = {
  bytes: Buffer;
  contentType: "image/jpeg" | "image/png" | "image/webp";
  caption: string;
  attribution: string;
  license: string;
  sourceUrl: string | null;
  generated: boolean;
};
