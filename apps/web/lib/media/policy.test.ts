import { describe, expect, it } from "vitest";
import {
  centeredCoverCrop,
  rankPexelsPhotos,
  scorePexelsPhoto,
  selectBestPexelsPhoto,
  shouldSelectNewCover,
  type PexelsPhoto,
} from "./policy";

const photo: PexelsPhoto = {
  id: "123",
  width: 2_400,
  height: 1_350,
  photoUrl: "https://www.pexels.com/photo/river-water-123/",
  photographer: "Licensed Photographer",
  photographerUrl: "https://www.pexels.com/@licensed-photographer/",
  imageUrl: "https://images.pexels.com/photos/123/river.jpeg",
  alt: "pharmaceutical pollution research in river water",
};

describe("automatic licensed-photo policy", () => {
  it("selects a relevant landscape candidate and produces a normalized crop", () => {
    const selected = selectBestPexelsPhoto(
      [photo, { ...photo, id: "456", alt: "generic landscape" }],
      "pharmaceutical pollution river water",
      new Set(),
    );
    expect(selected?.id).toBe("123");
    expect(centeredCoverCrop(photo.width, photo.height)).toEqual({ x: 0, y: 0, width: 1, height: 1 });
    expect(rankPexelsPhotos(
      [{ ...photo, id: "456", width: 1_600, height: 900 }, photo],
      "pharmaceutical pollution river water",
      new Set(),
    ).map((candidate) => candidate.id)).toEqual(["123", "456"]);
  });

  it("rejects reused, branded, undersized, and person-led sensitive images", () => {
    expect(scorePexelsPhoto(photo, "river water", new Set(["123"]))).toBeNull();
    expect(scorePexelsPhoto({ ...photo, alt: "brand logo billboard river" }, "river water", new Set())).toBeNull();
    expect(scorePexelsPhoto({ ...photo, width: 900 }, "river water", new Set())).toBeNull();
    expect(scorePexelsPhoto({ ...photo, alt: "person taking medicine" }, "pharmaceutical medicine", new Set())).toBeNull();
    expect(scorePexelsPhoto({ ...photo, alt: "people beside a wind turbine" }, "wind turbine", new Set())).toBeNull();
    expect(scorePexelsPhoto({ ...photo, alt: "generic mountain landscape" }, "river water", new Set())).toBeNull();
  });

  it("preserves approved covers until the query changes and respects takedowns", () => {
    const cover = { generated: false, provider: "pexels" };
    expect(shouldSelectNewCover(cover, { status: "selected", selectionQuery: "clean river" }, "clean river")).toBe(false);
    expect(shouldSelectNewCover(cover, { status: "selected", selectionQuery: "clean river" }, "offshore wind power")).toBe(true);
    expect(shouldSelectNewCover(cover, { status: "removed", selectionQuery: "clean river" }, "offshore wind power")).toBe(false);
    expect(shouldSelectNewCover(cover, { status: "replace-requested", selectionQuery: "clean river" }, "clean river")).toBe(true);
  });
});
