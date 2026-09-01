import { NextRequest, NextResponse } from "next/server";
import { verifyUser } from "@/lib/auth/verify-user";
import { getAdminAuth, getAdminFirestore } from "@/lib/firebase/admin";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  try {
    const user = await verifyUser(request);
    const database = getAdminFirestore();
    await database.recursiveDelete(database.collection("users").doc(user.uid));
    await getAdminAuth().deleteUser(user.uid);
    return NextResponse.json({ deleted: true });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Account deletion failed." },
      { status: 401 },
    );
  }
}
