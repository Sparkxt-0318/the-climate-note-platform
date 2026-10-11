import { timingSafeEqual } from "node:crypto";
import { NextRequest } from "next/server";
import { runDriveIngestion } from "@/lib/ingestion/pipeline";
import { noStoreJson } from "@/lib/http/security";

export const dynamic = "force-dynamic";
export const maxDuration = 300;

function authorized(request: NextRequest) {
  const expected = process.env.CRON_SECRET;
  const supplied = request.headers.get("authorization")?.replace(/^Bearer\s+/i, "");
  if (!expected || !supplied) return false;
  const expectedBytes = Buffer.from(expected);
  const suppliedBytes = Buffer.from(supplied);
  return expectedBytes.length === suppliedBytes.length && timingSafeEqual(expectedBytes, suppliedBytes);
}

export async function GET(request: NextRequest) {
  if (!authorized(request)) return noStoreJson({ error: "Unauthorized" }, { status: 401 });
  try {
    return noStoreJson(await runDriveIngestion());
  } catch {
    return noStoreJson({ error: "Ingestion failed." }, { status: 500 });
  }
}
