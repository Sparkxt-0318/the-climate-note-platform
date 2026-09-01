import "server-only";
import { NextRequest } from "next/server";
import { verifyUser } from "@/lib/auth/verify-user";

export async function verifyAdmin(request: NextRequest) {
  const user = await verifyUser(request);
  const emails = (process.env.ADMIN_EMAILS || "")
    .split(",")
    .map((email) => email.trim().toLowerCase())
    .filter(Boolean);
  if (user.admin === true || (user.email && emails.includes(user.email.toLowerCase()))) return user;
  throw new Error("Administrator access is required.");
}
