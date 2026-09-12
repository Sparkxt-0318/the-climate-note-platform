import { z } from "zod";
import { estimateImpact } from "./factors";

export const communityImpactSchema = z.object({
  schemaVersion: z.literal(1),
  completedActions: z.number().int().nonnegative(),
  estimatedKgCO2e: z.number().finite().nonnegative(),
  estimatedActions: z.number().int().nonnegative(),
  updatedAt: z.iso.datetime(),
}).refine((value) => value.estimatedActions <= value.completedActions, "Estimated actions cannot exceed completions.");
export type CommunityImpact = z.infer<typeof communityImpactSchema>;
export type ActionTemplate = { id: string; factorId: string | null; factorQuantity: number | null };
export type Completion = { path: string; data: Record<string, unknown> };

function date(value: unknown): Date | null {
  if (!value || typeof value !== "object" || !("toDate" in value) || typeof value.toDate !== "function") return null;
  const result = value.toDate();
  return result instanceof Date && Number.isFinite(result.getTime()) ? result : null;
}

// No private text or client-provided impact values are used. A repeated save of
// the same article/action on the same UTC completion day counts only once.
export function communityAccumulator(templates: Map<string, ActionTemplate[]>, now = new Date()) {
  const seen = new Set<string>();
  let completedActions = 0;
  let estimatedActions = 0;
  let estimatedKgCO2e = 0;
  return {
    add({ path, data }: Completion) {
      const parts = path.split("/");
      const completedAt = date(data.completedAt);
      const createdAt = date(data.createdAt);
      if (parts.length !== 4 || parts[0] !== "users" || parts[2] !== "actionLogs" ||
        data.userID !== parts[1] || data.status !== "completed" ||
        typeof data.articleID !== "string" || !data.articleID ||
        typeof data.actionID !== "string" || !data.actionID ||
        !completedAt || !createdAt || createdAt > completedAt || completedAt > now) return;
      const key = JSON.stringify([parts[1], data.articleID, data.actionID, completedAt.toISOString().slice(0, 10)]);
      if (seen.has(key)) return;
      seen.add(key);
      completedActions += 1;
      const template = templates.get(data.articleID)?.find((action) => action.id === data.actionID);
      if (!template || !Number.isFinite(template.factorQuantity) ||
        template.factorQuantity === null || template.factorQuantity <= 0 || template.factorQuantity > 1000) return;
      const estimate = estimateImpact(template.factorId, template.factorQuantity);
      if (!estimate || !Number.isFinite(estimate.value) || estimate.value <= 0) return;
      estimatedActions += 1;
      estimatedKgCO2e += estimate.value;
    },
    result(): CommunityImpact {
      return { schemaVersion: 1, completedActions, estimatedActions,
        estimatedKgCO2e: Math.round(estimatedKgCO2e * 100) / 100, updatedAt: now.toISOString() };
    },
  };
}
