import { timingSafeEqual } from "node:crypto";
import { NextRequest, NextResponse } from "next/server";
import { runDriveIngestion } from "@/lib/ingestion/pipeline";
import { refreshCommunityImpact } from "@/lib/impact/community-repository";

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
  if (!authorized(request)) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  // Start independently: Drive/AI failure must not prevent impact refresh.
  const [ingestion, impact] = await Promise.allSettled([runDriveIngestion(), refreshCommunityImpact()]);
  try {
    if (ingestion.status === "rejected") throw ingestion.reason;
    if (impact.status === "rejected") throw new Error("Community impact refresh failed; previous totals retained.");
    return NextResponse.json({ ...ingestion.value, communityImpact: impact.value });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Ingestion failed." },
      { status: 500 },
    );
  }
}
