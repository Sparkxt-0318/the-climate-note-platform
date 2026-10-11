import { describe, expect, it } from "vitest";
import { resolveAttemptLimit } from "./limits";

describe("resolveAttemptLimit", () => {
  it("keeps the normal ingestion default deliberately small", () => {
    expect(resolveAttemptLimit({}, undefined)).toBe(1);
    expect(resolveAttemptLimit({}, "3")).toBe(3);
  });

  it("requires an explicit all scope to initialize the complete archive", () => {
    expect(resolveAttemptLimit({ maxDocuments: "all" }, "1")).toBe(Number.POSITIVE_INFINITY);
  });

  it("rejects invalid overrides", () => {
    expect(resolveAttemptLimit({ maxDocuments: 0 }, "invalid")).toBe(1);
  });
});
