import { describe, expect, it } from "vitest";
import { NextRequest } from "next/server";
import type { DecodedIdToken } from "firebase-admin/auth";
import { nextRateLimitState, readBoundedJson, requireRecentAuthentication } from "./security";

describe("nextRateLimitState", () => {
  it("starts and increments a fixed window", () => {
    expect(nextRateLimitState(null, 1_000, 2, 60_000)).toEqual({
      allowed: true,
      state: { count: 1, windowStartedAtMs: 1_000 },
    });
    expect(nextRateLimitState({ count: 1, windowStartedAtMs: 1_000 }, 2_000, 2, 60_000)).toEqual({
      allowed: true,
      state: { count: 2, windowStartedAtMs: 1_000 },
    });
  });

  it("rejects requests beyond the limit and resets expired windows", () => {
    expect(nextRateLimitState({ count: 2, windowStartedAtMs: 1_000 }, 2_000, 2, 60_000).allowed).toBe(false);
    expect(nextRateLimitState({ count: 2, windowStartedAtMs: 1_000 }, 61_000, 2, 60_000)).toEqual({
      allowed: true,
      state: { count: 1, windowStartedAtMs: 61_000 },
    });
  });
});

describe("readBoundedJson", () => {
  it("parses JSON bodies within the byte limit", async () => {
    const request = new NextRequest("https://example.test/api", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ link: "https://example.test" }),
    });

    await expect(readBoundedJson(request, 128)).resolves.toEqual({ link: "https://example.test" });
  });

  it("stops an undeclared-length body as soon as the streamed cap is exceeded", async () => {
    const request = new NextRequest("https://example.test/api", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ value: "x".repeat(256) }),
    });
    expect(request.headers.has("content-length")).toBe(false);

    await expect(readBoundedJson(request, 64)).rejects.toMatchObject({
      status: 413,
      code: "request-too-large",
    });
  });
});

describe("requireRecentAuthentication", () => {
  function token(values: Partial<DecodedIdToken>): DecodedIdToken {
    return {
      aud: "project",
      auth_time: 100,
      exp: 10_000,
      firebase: { identities: {}, sign_in_provider: "google.com" },
      iat: 100,
      iss: "https://securetoken.google.com/project",
      sub: "user",
      uid: "user",
      ...values,
    } as DecodedIdToken;
  }

  it("uses reauthentication time for federated accounts", () => {
    const now = Math.floor(Date.now() / 1_000);
    expect(() => requireRecentAuthentication(token({ auth_time: now }), 300)).not.toThrow();
    expect(() => requireRecentAuthentication(token({ auth_time: now - 301 }), 300)).toThrowError(
      expect.objectContaining({ code: "recent-authentication-required" }),
    );
  });

  it("requires a freshly issued token for anonymous account deletion", () => {
    const now = Math.floor(Date.now() / 1_000);
    const firebase = { identities: {}, sign_in_provider: "anonymous" };
    expect(() => requireRecentAuthentication(token({ firebase, iat: now }), 300)).not.toThrow();
    expect(() => requireRecentAuthentication(token({ firebase, iat: now - 301 }), 300)).toThrowError(
      expect.objectContaining({ code: "recent-authentication-required" }),
    );
  });
});
