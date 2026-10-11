import { NextRequest } from "next/server";
import { z } from "zod";
import { verifyAdmin } from "@/lib/auth/verify-admin";
import { getAdminFirestore } from "@/lib/firebase/admin";
import {
  enforceUserRateLimit,
  noStoreJson,
  readBoundedJson,
  requireSafeDocumentID,
  safeErrorResponse,
} from "@/lib/http/security";

const httpsUrl = z.url().refine((value) => new URL(value).protocol === "https:", "Use an HTTPS URL.");

const linksSchema = z.object({
  instagram: z.union([httpsUrl, z.literal("")]).default(""),
  substack: z.union([httpsUrl, z.literal("")]).default(""),
  medium: z.union([httpsUrl, z.literal("")]).default(""),
}).strict();

export const dynamic = "force-dynamic";

export async function PATCH(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  try {
    const user = await verifyAdmin(request);
    await enforceUserRateLimit(user.uid, "admin-write", 60, 60 * 1_000);
    const { id: rawID } = await context.params;
    const id = requireSafeDocumentID(rawID);
    const links = linksSchema.parse(await readBoundedJson(request));
    await getAdminFirestore().collection("articles").doc(id).update({
      externalLinks: Object.fromEntries(Object.entries(links).filter(([, value]) => value)),
      updatedAt: new Date(),
    });
    return noStoreJson({ saved: true });
  } catch (error) {
    if (error instanceof z.ZodError) {
      return noStoreJson({ error: "Use valid HTTPS links only.", code: "invalid-links" }, { status: 400 });
    }
    return safeErrorResponse(error, "Links could not be saved.");
  }
}
