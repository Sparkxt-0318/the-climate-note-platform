import type { CoverCrop } from "@/lib/media/types";

export type PexelsPhoto = {
  id: string;
  width: number;
  height: number;
  photoUrl: string;
  photographer: string;
  photographerUrl: string;
  imageUrl: string;
  alt: string;
};

export type ScoredPexelsPhoto = PexelsPhoto & {
  score: number;
};

const targetAspectRatio = 16 / 9;
const blockedMetadata = /\b(?:brand|billboard|label|logo|signage|text overlay|watermark)\b/i;
const personMetadata = /\b(?:baby|child|children|crowd|family|human|man|men|people|person|woman|women)\b/i;

function words(value: string) {
  return new Set(
    value
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, " ")
      .split(/\s+/)
      .filter((word) => word.length >= 3),
  );
}

export function normalizeVisualQuery(value: string) {
  return Array.from(words(value)).sort().join(" ");
}

export function isPexelsWebsiteUrl(value: string) {
  try {
    const url = new URL(value);
    return url.protocol === "https:" && (url.hostname === "pexels.com" || url.hostname.endsWith(".pexels.com"));
  } catch {
    return false;
  }
}

export function isPexelsImageUrl(value: string) {
  try {
    const url = new URL(value);
    return url.protocol === "https:" && url.hostname === "images.pexels.com";
  } catch {
    return false;
  }
}

/** A centre crop is deterministic and serializable for native clients. */
export function centeredCoverCrop(width: number, height: number): CoverCrop {
  const aspect = width / height;
  if (aspect >= targetAspectRatio) {
    const cropWidth = targetAspectRatio / aspect;
    return { x: (1 - cropWidth) / 2, y: 0, width: cropWidth, height: 1 };
  }

  const cropHeight = aspect / targetAspectRatio;
  return { x: 0, y: (1 - cropHeight) / 2, width: 1, height: cropHeight };
}

export function scorePexelsPhoto(
  candidate: PexelsPhoto,
  searchQuery: string,
  recentProviderAssetIds: ReadonlySet<string>,
): ScoredPexelsPhoto | null {
  if (
    candidate.width < 1_600 ||
    candidate.height < 900 ||
    !isPexelsWebsiteUrl(candidate.photoUrl) ||
    !isPexelsWebsiteUrl(candidate.photographerUrl) ||
    !isPexelsImageUrl(candidate.imageUrl) ||
    !candidate.photographer.trim() ||
    recentProviderAssetIds.has(candidate.id)
  ) {
    return null;
  }

  const metadata = candidate.alt.trim();
  if (blockedMetadata.test(metadata)) return null;
  // Fully automatic publication cannot verify model releases or contextual
  // endorsement. Keep recognizable-person imagery out of this path entirely.
  if (personMetadata.test(metadata)) return null;

  const queryWords = words(searchQuery);
  const candidateWords = words(metadata);
  const overlap = Array.from(queryWords).filter((word) => candidateWords.has(word)).length;
  if (queryWords.size === 0 || overlap === 0) return null;
  const relevance = queryWords.size === 0 ? 0 : Math.min(40, Math.round((overlap / queryWords.size) * 40));
  const aspectPenalty = Math.min(25, Math.round(Math.abs(Math.log((candidate.width / candidate.height) / targetAspectRatio)) * 50));
  const aspect = 25 - aspectPenalty;
  const resolution = Math.min(25, Math.round((candidate.width * candidate.height) / 1_920_000 * 25));
  const metadataQuality = metadata.length >= 12 ? 10 : 0;
  const score = relevance + aspect + resolution + metadataQuality;

  return score >= 60 ? { ...candidate, score } : null;
}

export function selectBestPexelsPhoto(
  candidates: readonly PexelsPhoto[],
  searchQuery: string,
  recentProviderAssetIds: ReadonlySet<string>,
) {
  return rankPexelsPhotos(candidates, searchQuery, recentProviderAssetIds)[0] ?? null;
}

export function rankPexelsPhotos(
  candidates: readonly PexelsPhoto[],
  searchQuery: string,
  recentProviderAssetIds: ReadonlySet<string>,
) {
  return candidates
    .map((candidate) => scorePexelsPhoto(candidate, searchQuery, recentProviderAssetIds))
    .filter((candidate): candidate is ScoredPexelsPhoto => candidate !== null)
    .sort((a, b) => b.score - a.score || a.id.localeCompare(b.id));
}

export type ExistingCoverForPolicy = {
  generated?: boolean;
  provider?: string;
} | null;

export type ExistingMediaStateForPolicy = {
  status?: string;
  selectionQuery?: string;
} | null;

/**
 * A prior cover remains stable unless it was generated, it has no trusted
 * provenance, or the visual query materially changed. A takedown always wins.
 */
export function shouldSelectNewCover(
  currentCover: ExistingCoverForPolicy,
  currentState: ExistingMediaStateForPolicy,
  nextSearchQuery: string,
) {
  if (currentState?.status === "removed") return false;
  if (currentState?.status === "replace-requested") return true;
  if (!currentCover || currentCover.generated) return true;
  if (currentCover.provider === "pexels" && !currentState?.selectionQuery) return false;
  if (!currentState?.selectionQuery) return false;
  return normalizeVisualQuery(currentState.selectionQuery) !== normalizeVisualQuery(nextSearchQuery);
}
