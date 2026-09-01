import "server-only";
import { createSign } from "node:crypto";
import { z } from "zod";

export const docxMimeType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document";

const driveFileSchema = z.object({
  id: z.string(),
  name: z.string(),
  mimeType: z.string(),
  modifiedTime: z.string(),
  md5Checksum: z.string().optional(),
  size: z.string().optional(),
  webViewLink: z.string().optional(),
});

const driveListSchema = z.object({
  nextPageToken: z.string().optional(),
  files: z.array(driveFileSchema),
});

export type DriveFile = z.infer<typeof driveFileSchema>;

function base64Url(value: string | Buffer) {
  return Buffer.from(value).toString("base64url");
}

function normalizePrivateKey(value: string | undefined) {
  return value?.replace(/\\n/g, "\n");
}

async function serviceAccountAccessToken() {
  const clientEmail = process.env.GOOGLE_DRIVE_CLIENT_EMAIL;
  const privateKey = normalizePrivateKey(process.env.GOOGLE_DRIVE_PRIVATE_KEY);
  if (!clientEmail || !privateKey) throw new Error("Google Drive service-account credentials are missing.");

  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = base64Url(
    JSON.stringify({
      iss: clientEmail,
      scope: "https://www.googleapis.com/auth/drive.readonly",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsigned = `${header}.${payload}`;
  const signer = createSign("RSA-SHA256");
  signer.update(unsigned);
  signer.end();
  const assertion = `${unsigned}.${signer.sign(privateKey).toString("base64url")}`;

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) throw new Error(`Google OAuth failed with ${response.status}.`);
  const token = z.object({ access_token: z.string() }).parse(await response.json());
  return token.access_token;
}

async function driveFetch(path: string, init?: RequestInit) {
  const token = await serviceAccountAccessToken();
  const response = await fetch(`https://www.googleapis.com${path}`, {
    ...init,
    headers: {
      authorization: `Bearer ${token}`,
      ...init?.headers,
    },
    signal: init?.signal ?? AbortSignal.timeout(30_000),
  });
  if (!response.ok) {
    const detail = (await response.text()).slice(0, 400);
    throw new Error(`Google Drive request failed with ${response.status}: ${detail}`);
  }
  return response;
}

export async function listSourceDocuments(): Promise<DriveFile[]> {
  const folderId = process.env.GOOGLE_DRIVE_FOLDER_ID;
  if (!folderId) throw new Error("GOOGLE_DRIVE_FOLDER_ID is missing.");

  const files: DriveFile[] = [];
  let pageToken: string | undefined;
  do {
    const params = new URLSearchParams({
      q: `'${folderId}' in parents and trashed = false`,
      orderBy: "modifiedTime asc",
      pageSize: "100",
      fields: "nextPageToken,files(id,name,mimeType,modifiedTime,md5Checksum,size,webViewLink)",
      supportsAllDrives: "true",
      includeItemsFromAllDrives: "true",
    });
    if (pageToken) params.set("pageToken", pageToken);

    const response = await driveFetch(`/drive/v3/files?${params}`);
    const page = driveListSchema.parse(await response.json());
    files.push(...page.files);
    pageToken = page.nextPageToken;
  } while (pageToken);

  return files;
}

export async function downloadDriveFile(fileId: string) {
  const response = await driveFetch(`/drive/v3/files/${encodeURIComponent(fileId)}?alt=media&supportsAllDrives=true`);
  return Buffer.from(await response.arrayBuffer());
}
