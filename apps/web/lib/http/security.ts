import "server-only";
import { NextRequest, NextResponse } from "next/server";
import type { DecodedIdToken } from "firebase-admin/auth";
import { getAdminFirestore } from "@/lib/firebase/admin";

export class SafeHttpError extends Error {
  constructor(
    readonly status: number,
    readonly publicMessage: string,
    readonly code: string,
  ) {
    super(code);
    this.name = "SafeHttpError";
  }
}

export function noStoreJson(body: unknown, init: ResponseInit = {}) {
  const headers = new Headers(init.headers);
  headers.set("Cache-Control", "no-store, max-age=0");
  headers.set("Pragma", "no-cache");
  return NextResponse.json(body, { ...init, headers });
}

export function safeErrorResponse(error: unknown, fallback = "The request could not be completed.") {
  if (error instanceof SafeHttpError) {
    return noStoreJson({ error: error.publicMessage, code: error.code }, { status: error.status });
  }
  return noStoreJson({ error: fallback, code: "internal-error" }, { status: 500 });
}

export async function readBoundedJson(request: NextRequest, maximumBytes = 8_192): Promise<unknown> {
  const contentType = request.headers.get("content-type")?.split(";", 1)[0]?.trim().toLowerCase();
  if (contentType !== "application/json") {
    throw new SafeHttpError(415, "Content-Type must be application/json.", "unsupported-media-type");
  }

  const declaredLength = Number(request.headers.get("content-length"));
  if (Number.isFinite(declaredLength) && declaredLength > maximumBytes) {
    throw new SafeHttpError(413, "The request is too large.", "request-too-large");
  }

  const reader = request.body?.getReader();
  const chunks: Uint8Array[] = [];
  let receivedBytes = 0;

  if (reader) {
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        receivedBytes += value.byteLength;
        if (receivedBytes > maximumBytes) {
          await reader.cancel("request-too-large").catch(() => undefined);
          throw new SafeHttpError(413, "The request is too large.", "request-too-large");
        }
        chunks.push(value);
      }
    } finally {
      reader.releaseLock();
    }
  }

  const body = Buffer.concat(chunks.map((chunk) => Buffer.from(chunk))).toString("utf8");

  try {
    return JSON.parse(body) as unknown;
  } catch {
    throw new SafeHttpError(400, "The request body is not valid JSON.", "invalid-json");
  }
}

export function requireSafeDocumentID(value: string) {
  if (!/^[A-Za-z0-9_-]{1,160}$/.test(value)) {
    throw new SafeHttpError(400, "The requested article identifier is invalid.", "invalid-article-id");
  }
  return value;
}

export function requireRecentAuthentication(user: DecodedIdToken, maximumAgeSeconds = 300) {
  const provider = user.firebase?.sign_in_provider;
  // Federated accounts must have reauthenticated recently. Anonymous accounts
  // have no reusable provider credential, so require a freshly issued token.
  const authenticationTime = provider === "anonymous" ? user.iat : user.auth_time;
  const age = Math.floor(Date.now() / 1_000) - authenticationTime;
  if (!Number.isFinite(age) || age < 0 || age > maximumAgeSeconds) {
    throw new SafeHttpError(
      401,
      "Please sign in again before deleting your account.",
      "recent-authentication-required",
    );
  }
}

type RateLimitState = { count: number; windowStartedAtMs: number };

export function nextRateLimitState(
  current: RateLimitState | null,
  nowMs: number,
  limit: number,
  windowMs: number,
) {
  const active = current && nowMs - current.windowStartedAtMs >= 0 && nowMs - current.windowStartedAtMs < windowMs;
  if (!active) return { allowed: true, state: { count: 1, windowStartedAtMs: nowMs } } as const;
  if (current.count >= limit) return { allowed: false, state: current } as const;
  return {
    allowed: true,
    state: { count: current.count + 1, windowStartedAtMs: current.windowStartedAtMs },
  } as const;
}

export async function enforceUserRateLimit(
  uid: string,
  operation: "account-export" | "account-delete" | "admin-ingest" | "admin-write" | "admin-read",
  limit: number,
  windowMs: number,
) {
  const reference = getAdminFirestore()
    .collection("users")
    .doc(uid)
    .collection("_securityRateLimits")
    .doc(operation);
  const nowMs = Date.now();

  const allowed = await getAdminFirestore().runTransaction(async (transaction) => {
    const snapshot = await transaction.get(reference);
    const raw = snapshot.data();
    const current = raw && typeof raw.count === "number" && typeof raw.windowStartedAtMs === "number"
      ? { count: raw.count, windowStartedAtMs: raw.windowStartedAtMs }
      : null;
    const decision = nextRateLimitState(current, nowMs, limit, windowMs);
    if (decision.allowed) {
      transaction.set(reference, {
        ...decision.state,
        expiresAt: new Date(decision.state.windowStartedAtMs + windowMs),
      });
    }
    return decision.allowed;
  });

  if (!allowed) {
    throw new SafeHttpError(429, "Too many requests. Please wait and try again.", "rate-limited");
  }
}
