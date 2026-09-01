import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { verifyAdmin } from "@/lib/auth/verify-admin";
import { getAdminFirestore } from "@/lib/firebase/admin";

const linksSchema = z.object({
  instagram: z.union([z.url(), z.literal("")]).default(""),
  substack: z.union([z.url(), z.literal("")]).default(""),
  medium: z.union([z.url(), z.literal("")]).default(""),
});

export const dynamic = "force-dynamic";

export async function PATCH(request: NextRequest, context: { params: Promise<{ id: string }> }) {
  try {
    await verifyAdmin(request);
    const { id } = await context.params;
    const links = linksSchema.parse(await request.json());
    await getAdminFirestore().collection("articles").doc(id).update({
      externalLinks: Object.fromEntries(Object.entries(links).filter(([, value]) => value)),
      updatedAt: new Date(),
    });
    return NextResponse.json({ saved: true });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Links could not be saved." },
      { status: 400 },
    );
  }
}
