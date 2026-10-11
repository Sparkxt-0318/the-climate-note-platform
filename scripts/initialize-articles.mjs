const args = new Set(process.argv.slice(2));
const baseURL = (process.env.CLIMATE_NOTE_ADMIN_URL ?? "http://localhost:3000").replace(/\/$/, "");
const token = process.env.CLIMATE_NOTE_ADMIN_ID_TOKEN;
const target = new URL("/api/admin/ingest?scope=all", baseURL);
const isLocal = ["localhost", "127.0.0.1", "::1"].includes(target.hostname);

if (!token) {
  throw new Error("CLIMATE_NOTE_ADMIN_ID_TOKEN is required. Sign in as an approved administrator and provide a fresh Firebase ID token.");
}
if (!isLocal && (!args.has("--allow-remote") || process.env.CONFIRM_ARTICLE_INITIALIZATION !== "YES")) {
  throw new Error("Remote initialization is blocked. Pass --allow-remote and set CONFIRM_ARTICLE_INITIALIZATION=YES for an intentional admin run.");
}

const response = await fetch(target, {
  method: "POST",
  headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
  signal: AbortSignal.timeout(10 * 60_000),
});
const body = await response.json();
if (!response.ok) throw new Error(body.error ?? `Initialization failed with HTTP ${response.status}.`);

console.log(JSON.stringify({
  target: target.origin,
  startedAt: body.startedAt,
  finishedAt: body.finishedAt,
  counts: body.counts,
  articles: body.items,
}, null, 2));

if (body.counts?.failed > 0) process.exitCode = 1;
