import { NextRequest } from "next/server";
import { Timestamp } from "firebase-admin/firestore";
import { verifyUser } from "@/lib/auth/verify-user";
import { getAdminAuth, getAdminFirestore } from "@/lib/firebase/admin";
import { enforceUserRateLimit, noStoreJson, safeErrorResponse } from "@/lib/http/security";

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
    await enforceUserRateLimit(user.uid, "account-export", 5, 60 * 60 * 1_000);
    const database = getAdminFirestore();
    const userRef = database.collection("users").doc(user.uid);
    const [
      authAccount,
      profile,
      notes,
      actionLogs,
      impactPreference,
      securityRateLimits,
      impactReceipts,
      impactContributor,
      reconciliationJobs,
    ] = await Promise.all([
      getAdminAuth().getUser(user.uid),
      userRef.get(),
      userRef.collection("notes").get(),
      userRef.collection("actionLogs").get(),
      userRef.collection("preferences").doc("impact").get(),
      userRef.collection("_securityRateLimits").get(),
      database.collection("impactReceipts").where("uid", "==", user.uid).get(),
      database.collection("impactContributors").doc(user.uid).get(),
      database.collection("impactReconciliationJobs").where("uid", "==", user.uid).get(),
    ]);
    return noStoreJson({
      exportedAt: new Date().toISOString(),
      scope: "Synced account data held by The Climate Note. Unfinished local-only drafts remain on the device.",
      account: {
        uid: authAccount.uid,
        email: authAccount.email ?? null,
        displayName: authAccount.displayName ?? null,
        phoneNumber: authAccount.phoneNumber ?? null,
        photoURL: authAccount.photoURL ?? null,
        disabled: authAccount.disabled,
        createdAt: authAccount.metadata.creationTime ?? null,
        lastSignInAt: authAccount.metadata.lastSignInTime ?? null,
        providers: authAccount.providerData.map((provider) => ({
          providerId: provider.providerId,
          uid: provider.uid,
          email: provider.email ?? null,
          displayName: provider.displayName ?? null,
          phoneNumber: provider.phoneNumber ?? null,
          photoURL: provider.photoURL ?? null,
        })),
      },
      profile: profile.exists ? serialize(profile.data()) : null,
      notes: notes.docs.map((document) => ({ id: document.id, data: serialize(document.data()) })),
      actionLogs: actionLogs.docs.map((document) => ({ id: document.id, data: serialize(document.data()) })),
      impactPreference: impactPreference.exists
        ? serialize(impactPreference.data())
        : { includeInCommunityImpact: false },
      securityRateLimits: securityRateLimits.docs.map((document) => ({
        operation: document.id,
        data: serialize(document.data()),
      })),
      communityImpact: {
        receipts: impactReceipts.docs.map((document) => ({ id: document.id, data: serialize(document.data()) })),
        contributor: impactContributor.exists ? serialize(impactContributor.data()) : null,
        pendingReconciliation: reconciliationJobs.docs.map((document) => ({
          id: document.id,
          data: serialize(document.data()),
        })),
      },
    }, {
      headers: { "Content-Disposition": 'attachment; filename="the-climate-note-export.json"' },
    });
  } catch (error) {
    return safeErrorResponse(error, "Your account export could not be prepared.");
  }
}
