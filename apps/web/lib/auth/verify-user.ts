import "server-only";
import { NextRequest } from "next/server";
import { getAdminAuth } from "@/lib/firebase/admin";
import { SafeHttpError } from "@/lib/http/security";

export async function verifyUser(request: NextRequest) {
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) throw new SafeHttpError(401, "Authentication is required.", "authentication-required");
  try {
    return await getAdminAuth().verifyIdToken(token, true);
  } catch {
    throw new SafeHttpError(401, "Your session is invalid or expired.", "invalid-session");
  }
}
