import { NextRequest, NextResponse } from "next/server";
import { verifyAdmin } from "@/lib/auth/verify-admin";
import { getAdminFirestore } from "@/lib/firebase/admin";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  try {
    await verifyAdmin(request);
    const snapshot = await getAdminFirestore().collection("articles").orderBy("updatedAt", "desc").limit(50).get();
    return NextResponse.json({
      articles: snapshot.docs.map((document) => ({
        id: document.id,
        title: document.get("title") as string,
        status: document.get("status") as string,
        externalLinks: document.get("externalLinks") ?? {},
      })),
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Articles could not be loaded." },
      { status: 403 },
    );
  }
}
