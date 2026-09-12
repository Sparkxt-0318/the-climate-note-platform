import { NextRequest, NextResponse } from "next/server";
import { verifyAdmin } from "@/lib/auth/verify-admin";
import { refreshCommunityImpact } from "@/lib/impact/community-repository";

export const dynamic = "force-dynamic";
export const maxDuration = 300;

export async function POST(request: NextRequest) {
  try { await verifyAdmin(request); }
  catch { return NextResponse.json({ error: "Unauthorized" }, { status: 403 }); }
  try { return NextResponse.json(await refreshCommunityImpact()); }
  catch { return NextResponse.json({ error: "Refresh failed; previous totals retained." }, { status: 500 }); }
}
