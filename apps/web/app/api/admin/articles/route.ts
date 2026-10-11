import { NextRequest } from "next/server";
import { verifyAdmin } from "@/lib/auth/verify-admin";
import { getAdminFirestore } from "@/lib/firebase/admin";
import { enforceUserRateLimit, noStoreJson, safeErrorResponse } from "@/lib/http/security";

export const dynamic = "force-dynamic";

export async function GET(request: NextRequest) {
  try {
    const user = await verifyAdmin(request);
    await enforceUserRateLimit(user.uid, "admin-read", 60, 60 * 1_000);
    const snapshot = await getAdminFirestore().collection("articles").orderBy("updatedAt", "desc").limit(50).get();
    return noStoreJson({
      articles: snapshot.docs.map((document) => ({
        id: document.id,
        title: document.get("title") as string,
        status: document.get("status") as string,
        externalLinks: document.get("externalLinks") ?? {},
      })),
    });
  } catch (error) {
    return safeErrorResponse(error, "Articles could not be loaded.");
  }
}
