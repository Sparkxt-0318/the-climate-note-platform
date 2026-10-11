import { NextRequest } from "next/server";
import { FieldValue } from "firebase-admin/firestore";
import { verifyUser } from "@/lib/auth/verify-user";
import { getAdminAuth, getAdminFirestore } from "@/lib/firebase/admin";
import {
  enforceUserRateLimit,
  noStoreJson,
  requireRecentAuthentication,
  SafeHttpError,
  safeErrorResponse,
} from "@/lib/http/security";

export const dynamic = "force-dynamic";

export async function POST(request: NextRequest) {
  try {
    const user = await verifyUser(request);
    if (request.headers.get("x-climate-note-confirm-delete") !== "delete-account") {
      throw new SafeHttpError(400, "Account deletion was not confirmed.", "deletion-confirmation-required");
    }
    requireRecentAuthentication(user);
    await enforceUserRateLimit(user.uid, "account-delete", 3, 60 * 60 * 1_000);
    const database = getAdminFirestore();
    await database.recursiveDelete(database.collection("users").doc(user.uid));
    // Create the reconciliation signal after private data is gone so the worker can only subtract
    // historical server receipts; it cannot accidentally rebuild them from a still-present log.
    await database.collection("impactAccountDeletionRequests").doc(user.uid).set({
      schemaVersion: 1,
      uid: user.uid,
      requestedAt: FieldValue.serverTimestamp(),
    });
    await getAdminAuth().deleteUser(user.uid);
    return noStoreJson({ deleted: true });
  } catch (error) {
    return safeErrorResponse(error, "Your account could not be deleted.");
  }
}
