import { NextRequest } from "next/server";
import { verifyAdmin } from "@/lib/auth/verify-admin";
import { runDriveIngestion } from "@/lib/ingestion/pipeline";
import { enforceUserRateLimit, noStoreJson, safeErrorResponse } from "@/lib/http/security";

export const dynamic = "force-dynamic";
export const maxDuration = 300;

export async function POST(request: NextRequest) {
  try {
    const user = await verifyAdmin(request);
    await enforceUserRateLimit(user.uid, "admin-ingest", 5, 15 * 60 * 1_000);
    const scope = request.nextUrl.searchParams.get("scope");
    return noStoreJson(await runDriveIngestion({ maxDocuments: scope === "all" ? "all" : undefined }));
  } catch (error) {
    return safeErrorResponse(error, "Article synchronization failed.");
  }
}
