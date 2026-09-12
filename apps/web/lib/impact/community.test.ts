import { describe, expect, it } from "vitest";
import { communityAccumulator, communityImpactSchema } from "./community";

const now = new Date("2026-09-12T12:00:00Z");
const stamp = (value = "2026-09-10T10:00:00Z") => ({ toDate: () => new Date(value) });
const templates = new Map([["article", [{ id: "walk", factorId: "passenger-vehicle-mile-avoided-us", factorQuantity: 2 }]]]);
const completion = (id: string, overrides: Record<string, unknown> = {}, user = "user") => ({
  path: `users/${user}/actionLogs/${id}`,
  data: { userID: user, articleID: "article", actionID: "walk", status: "completed",
    createdAt: stamp("2026-09-09T10:00:00Z"), completedAt: stamp(), ...overrides },
});

describe("community totals", () => {
  it("backfills completed actions across users and counts custom actions without carbon", () => {
    const totals = communityAccumulator(templates, now);
    totals.add(completion("one"));
    totals.add(completion("two", {}, "another"));
    totals.add(completion("custom", { actionID: "custom" }));
    totals.add(completion("planned", { status: "planned" }));
    expect(totals.result()).toEqual({ schemaVersion: 1, completedActions: 3, estimatedActions: 2, estimatedKgCO2e: 1.6, updatedAt: now.toISOString() });
  });
  it("deduplicates repeated saves, but counts subsequent completion days", () => {
    const totals = communityAccumulator(templates, now);
    totals.add(completion("one"));
    totals.add(completion("double-tap"));
    totals.add(completion("next-day", { completedAt: stamp("2026-09-11T10:00:00Z") }));
    expect(totals.result().completedActions).toBe(2);
  });
  it("ignores forged impact amounts and only uses article templates", () => {
    const totals = communityAccumulator(templates, now);
    totals.add(completion("one", { impactEstimate: { value: 999999999, unit: "kg CO₂e" }, detail: "Private reflection" }));
    totals.add(completion("unknown", { actionID: "unknown" }));
    expect(totals.result().estimatedKgCO2e).toBe(0.8);
    expect(JSON.stringify(totals.result())).not.toContain("Private");
    expect(totals.result().estimatedActions).toBe(1);
  });
  it("rejects wrong owners, invalid dates, future completions, and unrelated paths", () => {
    const totals = communityAccumulator(templates, now);
    totals.add(completion("owner", { userID: "wrong" }));
    totals.add(completion("date", { completedAt: "not a timestamp" }));
    totals.add(completion("future", { completedAt: stamp("2027-01-01T00:00:00Z") }));
    totals.add(completion("backwards", { completedAt: stamp("2026-09-01T00:00:00Z") }));
    totals.add({ ...completion("other"), path: "other/user/actionLogs/other" });
    expect(totals.result().completedActions).toBe(0);
  });
  it("rebuild removes deleted records and excludes invalid factor quantities", () => {
    const bad = new Map([["article", [{ id: "walk", factorId: "passenger-vehicle-mile-avoided-us", factorQuantity: Infinity }]]]);
    const totals = communityAccumulator(bad, now);
    totals.add(completion("one"));
    expect(totals.result().estimatedActions).toBe(0);
    expect(communityAccumulator(templates, now).result().completedActions).toBe(0);
  });
  it("public schema strips private fields and rejects corrupt totals", () => {
    const result = communityAccumulator(templates, now).result();
    expect(communityImpactSchema.parse({ ...result, userID: "private" })).toEqual(result);
    expect(communityImpactSchema.safeParse({ ...result, completedActions: -1 }).success).toBe(false);
  });
});
