import "server-only";
import { NextRequest } from "next/server";
import { getAdminAuth } from "@/lib/firebase/admin";

export async function verifyUser(request: NextRequest) {
  const token = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) throw new Error("Missing Firebase ID token.");
  return getAdminAuth().verifyIdToken(token, true);
}
