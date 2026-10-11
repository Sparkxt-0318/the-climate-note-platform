export type IngestionScope = { maxDocuments?: number | "all" };

export function resolveAttemptLimit(options: IngestionScope, configuredValue: string | undefined) {
  if (options.maxDocuments === "all") return Number.POSITIVE_INFINITY;
  if (typeof options.maxDocuments === "number" && Number.isFinite(options.maxDocuments) && options.maxDocuments > 0) {
    return Math.floor(options.maxDocuments);
  }
  const configured = Number.parseInt(configuredValue ?? "1", 10);
  return Number.isFinite(configured) && configured > 0 ? configured : 1;
}
