import { NextRequest, NextResponse } from "next/server";
import { Timestamp } from "firebase-admin/firestore";
import { verifyUser } from "@/lib/auth/verify-user";
import { getAdminFirestore } from "@/lib/firebase/admin";

export const dynamic = "force-dynamic";

function serialize(value: unknown): unknown {
  if (value instanceof Timestamp) return value.toDate().toISOString();
  if (Array.isArray(value)) return value.map(serialize);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, serialize(item)]));
  }
  return value;
}

export async function GET(request: NextRequest) {
  try {
    const user = await verifyUser(request);
    const database = getAdminFirestore();
    const userRef = database.collection("users").doc(user.uid);
    const [profile, notes, actionLogs] = await Promise.all([
      userRef.get(),
      userRef.collection("notes").get(),
      userRef.collection("actionLogs").get(),
    ]);
    return NextResponse.json({
      exportedAt: new Date().toISOString(),
      account: { uid: user.uid, email: user.email ?? null },
      profile: profile.exists ? serialize(profile.data()) : null,
      notes: notes.docs.map((document) => ({ id: document.id, data: serialize(document.data()) })),
      actionLogs: actionLogs.docs.map((document) => ({ id: document.id, data: serialize(document.data()) })),
    });
  } catch (error) {
    return NextResponse.json(
      { error: error instanceof Error ? error.message : "Export failed." },
      { status: 401 },
    );
  }
}
