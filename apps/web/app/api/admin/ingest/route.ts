import { NextRequest, NextResponse } from "next/server";
import { verifyAdmin } from "@/lib/auth/verify-admin";
import { runDriveIngestion } from "@/lib/ingestion/pipeline";

export const dynamic = "force-dynamic";
export const maxDuration = 300;

export async function POST(request: NextRequest) {
  try {
    await verifyAdmin(request);
    return NextResponse.json(await runDriveIngestion());
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Sync failed." },
      { status: 403 },
    );
  }
}
