export const PEXELS_LICENSE_URL = "https://www.pexels.com/license/";
export const PEXELS_PROVIDER_URL = "https://www.pexels.com/";

export type CoverCrop = {
  x: number;
  y: number;
  width: number;
  height: number;
};

/** A licensed Pexels selection after provenance, relevance, and image checks. */
export type LicensedVisualCandidate = {
  bytes: Buffer;
  contentType: "image/jpeg";
  caption: string;
  altText: string;
  attribution: string;
  width: number;
  height: number;
  crop: CoverCrop;
  contentHash: string;
  license: "Pexels License";
  licenseUrl: string;
  sourceUrl: string;
  generated: false;
  provider: "pexels";
  providerAssetId: string;
  photographer: string;
  retrievedAt: string;
  selectionQuery: string;
  selectionScore: number;
};

export type PublicCoverAsset = Omit<LicensedVisualCandidate, "bytes" | "width" | "height" | "selectionQuery" | "selectionScore"> & {
  url: string;
};
