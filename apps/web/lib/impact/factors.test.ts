import { describe, expect, it } from "vitest";
import { estimateImpact } from "./factors";

describe("impact estimates", () => {
  it("uses deterministic versioned factors", () => {
    expect(estimateImpact("passenger-vehicle-mile-avoided-us", 2)?.value).toBe(0.8);
    expect(estimateImpact("electricity-kwh-avoided-us", 1)?.factorVersion).toBe("EPA-eGRID2022-2024");
  });

  it("returns no number for unsupported actions", () => {
    expect(estimateImpact(null, null)).toBeNull();
    expect(estimateImpact("unknown", 4)).toBeNull();
  });
});
