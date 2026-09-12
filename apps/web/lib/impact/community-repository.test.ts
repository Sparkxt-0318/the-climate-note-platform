import { beforeEach, describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));
const mocks = vi.hoisted(() => ({ db: vi.fn() }));
vi.mock("../firebase/admin", () => ({ getAdminFirestore: mocks.db }));
import { readCommunityImpact, refreshCommunityImpact } from "./community-repository";

const stamp = { toDate: () => new Date("2026-01-01T00:00:00Z") };
function database(pages: unknown[]) {
  const get = vi.fn();
  for (const page of pages) {
    if (page instanceof Error) get.mockRejectedValueOnce(page);
    else get.mockResolvedValueOnce(page);
  }
  const query = { orderBy: vi.fn(), select: vi.fn(), startAfter: vi.fn(), limit: vi.fn(), get };
  for (const key of ["orderBy", "select", "startAfter", "limit"] as const) query[key].mockReturnValue(query);
  const transaction = { get: vi.fn().mockResolvedValue({ data: () => undefined }), set: vi.fn() };
  const doc = { get: vi.fn() };
  mocks.db.mockReturnValue({
    collection: () => ({ select: () => ({ get: async () => ({ docs: [] }) }) }),
    collectionGroup: () => query,
    doc: () => doc,
    runTransaction: async (fn: (value: typeof transaction) => Promise<void>) => fn(transaction),
  });
  return { query, transaction, doc };
}
const record = (id: string) => ({ ref: { path: `users/${id}/actionLogs/log` },
  data: () => ({ userID: id, status: "completed", articleID: "article", actionID: "custom", createdAt: stamp, completedAt: stamp }) });

describe("community snapshot repository", () => {
  beforeEach(() => vi.clearAllMocks());
  it("paginates all records before publishing a complete snapshot", async () => {
    const first = Array.from({ length: 1000 }, (_, index) => record(String(index)));
    const db = database([{ size: 1000, docs: first }, { size: 1, docs: [record("last")] }]);
    const result = await refreshCommunityImpact();
    expect(result.completedActions).toBe(1001);
    expect(db.query.startAfter).toHaveBeenCalledWith(first[999]);
    expect(db.transaction.set).toHaveBeenCalledOnce();
    expect(db.query.select).toHaveBeenCalledWith("userID", "status", "articleID", "actionID", "createdAt", "completedAt");
  });
  it("retains the previous snapshot when a later page fails", async () => {
    const db = database([{ size: 1000, docs: Array.from({ length: 1000 }, (_, i) => record(String(i))) }, new Error("Firestore unavailable")]);
    await expect(refreshCommunityImpact()).rejects.toThrow("Firestore unavailable");
    expect(db.transaction.set).not.toHaveBeenCalled();
  });
  it("does not let an older scan overwrite a newer snapshot", async () => {
    const db = database([{ size: 0, docs: [] }]);
    db.transaction.get.mockResolvedValue({ data: () => ({ updatedAt: "9999-01-01T00:00:00.000Z" }) } as never);
    await refreshCommunityImpact();
    expect(db.transaction.set).not.toHaveBeenCalled();
  });
  it("returns unavailable for uninitialized or corrupt snapshots and strips private fields", async () => {
    const db = database([]);
    db.doc.get.mockResolvedValue({ data: () => undefined });
    expect(await readCommunityImpact()).toBeNull();
    db.doc.get.mockResolvedValue({ data: () => ({ schemaVersion: 1, completedActions: -1 }) });
    expect(await readCommunityImpact()).toBeNull();
    const value = { schemaVersion: 1, completedActions: 1, estimatedActions: 0, estimatedKgCO2e: 0, updatedAt: "2026-09-12T00:00:00.000Z" };
    db.doc.get.mockResolvedValue({ data: () => ({ ...value, userID: "private" }) });
    expect(await readCommunityImpact()).toEqual(value);
  });
});
