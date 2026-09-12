import { NextResponse } from "next/server";
import { readCommunityImpact } from "@/lib/impact/community-repository";

export const dynamic = "force-dynamic";

export async function GET() {
  try {
    const snapshot = await readCommunityImpact();
    if (!snapshot) return NextResponse.json({ error: "Community totals are being prepared." }, { status: 503 });
    return NextResponse.json(snapshot, { headers: { "Cache-Control": "public, s-maxage=300, stale-while-revalidate=300" } });
  } catch {
    return NextResponse.json({ error: "Community totals are temporarily unavailable." }, { status: 503 });
  }
}
