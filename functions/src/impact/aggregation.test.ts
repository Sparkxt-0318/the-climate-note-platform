import { describe, expect, it } from "vitest";
import {
  buildPublicCommunityImpact,
  desiredReceipt,
  planReceiptTransition,
} from "./aggregation.js";

const article = {
  status: "published",
  generation: {
    suggestedActions: [{
      id: "walk-eight-miles",
      factorId: "passenger-vehicle-mile-avoided-us",
      factorQuantity: 8,
    }],
  },
};

const completedLog = {
  userID: "user-1",
  articleID: "article-1",
  actionID: "walk-eight-miles",
  kind: "action",
  status: "completed",
  impactEstimate: { value: 999_999, unit: "kg CO2e" },
};

describe("community impact aggregation", () => {
  it("recalculates a receipt from the trusted article action and ignores client impact values", () => {
    const receipt = desiredReceipt({
      uid: "user-1",
      logID: "log-1",
      log: completedLog,
      preference: { includeInCommunityImpact: true },
      article,
      existingReceipt: null,
    });

    expect(receipt).toMatchObject({
      uid: "user-1",
      logID: "log-1",
      factorID: "passenger-vehicle-mile-avoided-us",
      inputQuantity: 8,
      kgCO2e: 3.2,
    });
  });

  it.each([
    [{ ...completedLog, status: "planned" }],
    [{ ...completedLog, kind: "reflection" }],
    [{ ...completedLog, kind: "future-kind" }],
    [{ ...completedLog, actionID: "custom" }],
    [{ ...completedLog, userID: "someone-else" }],
  ])("excludes ineligible logs", (log) => {
    expect(desiredReceipt({
      uid: "user-1",
      logID: "log-1",
      log,
      preference: { includeInCommunityImpact: true },
      article,
      existingReceipt: null,
    })).toBeNull();
  });

  it("adds exactly once and subtracts on reopening", () => {
    const receipt = desiredReceipt({
      uid: "user-1",
      logID: "log-1",
      log: completedLog,
      preference: { includeInCommunityImpact: true },
      article,
      existingReceipt: null,
    });
    expect(receipt).not.toBeNull();

    const added = planReceiptTransition({
      currentReceipt: null,
      nextReceipt: receipt,
      internal: null,
      contributor: null,
    });
    expect(added.nextInternal).toMatchObject({
      totalKgCO2e: 3.2,
      eligibleActionCount: 1,
      contributorCount: 1,
    });

    const duplicate = planReceiptTransition({
      currentReceipt: receipt,
      nextReceipt: receipt,
      internal: added.nextInternal,
      contributor: added.nextContributor,
    });
    expect(duplicate.changed).toBe(false);
    expect(duplicate.nextInternal).toEqual(added.nextInternal);

    const removed = planReceiptTransition({
      currentReceipt: receipt,
      nextReceipt: null,
      internal: added.nextInternal,
      contributor: added.nextContributor,
    });
    expect(removed.nextInternal).toMatchObject({
      totalKgCO2e: 0,
      eligibleActionCount: 0,
      contributorCount: 0,
    });
    expect(removed.shouldDeleteContributor).toBe(true);
  });

  it("hides every total below ten contributors and publishes rounded values at the threshold", () => {
    const hidden = buildPublicCommunityImpact({
      totalKgCO2e: 88.4,
      eligibleActionCount: 9,
      contributorCount: 9,
      factorVersionCounts: { "EPA-2023": 9 },
    });
    expect(hidden.visible).toBe(false);
    expect(hidden.contributorCount).toBeUndefined();
    expect(hidden.estimatedKgCO2e).toBeUndefined();

    const visible = buildPublicCommunityImpact({
      totalKgCO2e: 88.4,
      eligibleActionCount: 14,
      contributorCount: 10,
      factorVersionCounts: { "EPA-2023": 14 },
    });
    expect(visible).toMatchObject({
      visible: true,
      contributorCount: 10,
      eligibleActionCount: 14,
      estimatedKgCO2e: 88,
    });
  });
});
