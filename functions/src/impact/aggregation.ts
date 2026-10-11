import {
  calculateContribution,
  type CalculatedContribution,
  isFinitePositiveQuantity,
} from "./factors.js";

export const IMPACT_SCHEMA_VERSION = 1;
export const COMMUNITY_IMPACT_MINIMUM_CONTRIBUTORS = 10;

export const COMMUNITY_IMPACT_METHODOLOGY =
  "Estimated kg CO₂e from self-reported completions of supported, article-specific actions using versioned server factors. Reflections, custom actions, and unsupported actions are excluded.";

export type FirestoreData = Record<string, unknown>;

export type FrozenReceipt = {
  schemaVersion: number;
  uid: string;
  logID: string;
  articleID: string;
  actionID: string;
  factorID: string;
  factorVersion: string;
  inputQuantity: number;
  inputUnit: string;
  kgCO2e: number;
  sourceURL: string;
  sourceFingerprint: string;
};

export type InternalImpact = {
  schemaVersion: number;
  totalKgCO2e: number;
  eligibleActionCount: number;
  contributorCount: number;
  factorVersionCounts: Record<string, number>;
};

export type ImpactContributor = {
  receiptCount: number;
  totalKgCO2e: number;
};

export type PublicCommunityImpact = {
  schemaVersion: number;
  visible: boolean;
  minimumContributors: number;
  methodology: {
    metric: "co2e";
    factorVersions: string[];
    description: string;
  };
  contributorCount?: number;
  eligibleActionCount?: number;
  estimatedKgCO2e?: number;
};

export type ReceiptTransition = {
  currentReceipt: FrozenReceipt | null;
  nextReceipt: FrozenReceipt | null;
  nextInternal: InternalImpact;
  nextContributor: ImpactContributor;
  shouldDeleteContributor: boolean;
  changed: boolean;
};

export function isRecord(value: unknown): value is FirestoreData {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function nonEmptyString(value: unknown): string | null {
  return typeof value === "string" && value.trim().length > 0 ? value : null;
}

function nonNegativeFiniteNumber(value: unknown) {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : 0;
}

function positiveFiniteNumber(value: unknown): value is number {
  return typeof value === "number" && Number.isFinite(value) && value > 0;
}

function nonNegativeInteger(value: unknown) {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 ? value : 0;
}

function roundToHundredth(value: number) {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

function fingerprint(articleID: string, actionID: string, contribution: CalculatedContribution) {
  return [
    "action-v1",
    articleID,
    actionID,
    contribution.factorID,
    contribution.factorVersion,
    contribution.inputQuantity,
  ].join(":");
}

export function normalizeReceipt(value: unknown): FrozenReceipt | null {
  if (!isRecord(value)) return null;

  const uid = nonEmptyString(value.uid);
  const logID = nonEmptyString(value.logID);
  const articleID = nonEmptyString(value.articleID);
  const actionID = nonEmptyString(value.actionID);
  const factorID = nonEmptyString(value.factorID);
  const factorVersion = nonEmptyString(value.factorVersion);
  const inputUnit = nonEmptyString(value.inputUnit);
  const sourceURL = nonEmptyString(value.sourceURL);
  const sourceFingerprint = nonEmptyString(value.sourceFingerprint);

  if (
    !uid ||
    !logID ||
    !articleID ||
    !actionID ||
    !factorID ||
    !factorVersion ||
    !inputUnit ||
    !sourceURL ||
    !sourceFingerprint ||
    !isFinitePositiveQuantity(value.inputQuantity) ||
    !positiveFiniteNumber(value.kgCO2e)
  ) {
    return null;
  }

  return {
    schemaVersion: nonNegativeInteger(value.schemaVersion) || IMPACT_SCHEMA_VERSION,
    uid,
    logID,
    articleID,
    actionID,
    factorID,
    factorVersion,
    inputQuantity: value.inputQuantity,
    inputUnit,
    kgCO2e: value.kgCO2e,
    sourceURL,
    sourceFingerprint,
  };
}

export function normalizeInternalImpact(value: unknown): InternalImpact {
  const data = isRecord(value) ? value : {};
  const rawVersions = isRecord(data.factorVersionCounts) ? data.factorVersionCounts : {};
  const factorVersionCounts = Object.fromEntries(
    Object.entries(rawVersions).flatMap(([version, count]) => {
      const safeCount = nonNegativeInteger(count);
      return safeCount > 0 ? [[version, safeCount]] : [];
    }),
  );

  return {
    schemaVersion: nonNegativeInteger(data.schemaVersion) || IMPACT_SCHEMA_VERSION,
    totalKgCO2e: roundToHundredth(nonNegativeFiniteNumber(data.totalKgCO2e)),
    eligibleActionCount: nonNegativeInteger(data.eligibleActionCount),
    contributorCount: nonNegativeInteger(data.contributorCount),
    factorVersionCounts,
  };
}

export function normalizeContributor(value: unknown): ImpactContributor {
  const data = isRecord(value) ? value : {};
  return {
    receiptCount: nonNegativeInteger(data.receiptCount),
    totalKgCO2e: roundToHundredth(nonNegativeFiniteNumber(data.totalKgCO2e)),
  };
}

function actionFromArticle(article: unknown, actionID: string): FirestoreData | null {
  if (!isRecord(article) || article.status !== "published") return null;
  const generation = isRecord(article.generation) ? article.generation : null;
  const suggestedActions = generation?.suggestedActions;
  if (!Array.isArray(suggestedActions)) return null;

  const action = suggestedActions.find(
    (candidate): candidate is FirestoreData =>
      isRecord(candidate) && candidate.id === actionID,
  );
  return action ?? null;
}

function matchesIdentity(receipt: FrozenReceipt, uid: string, logID: string, articleID: string, actionID: string) {
  return (
    receipt.uid === uid &&
    receipt.logID === logID &&
    receipt.articleID === articleID &&
    receipt.actionID === actionID
  );
}

/**
 * Builds a receipt solely from the currently stored action log, opt-in preference, article, and
 * server factor catalog. It intentionally never reads client-supplied impact fields.
 */
export function desiredReceipt({
  uid,
  logID,
  log,
  preference,
  article,
  existingReceipt,
}: {
  uid: string;
  logID: string;
  log: unknown;
  preference: unknown;
  article: unknown;
  existingReceipt: unknown;
}): FrozenReceipt | null {
  if (!isRecord(log) || !isRecord(preference)) return null;
  if (preference.includeInCommunityImpact !== true) return null;
  if (
    log.userID !== uid ||
    log.status !== "completed" ||
    (log.kind !== undefined && log.kind !== "action") ||
    log.category === "reflection" ||
    log.type === "reflection"
  ) {
    return null;
  }

  const articleID = nonEmptyString(log.articleID);
  const actionID = nonEmptyString(log.actionID);
  if (!articleID || !actionID || actionID === "custom") return null;

  const action = actionFromArticle(article, actionID);
  if (!action) return null;

  const contribution = calculateContribution(action.factorId, action.factorQuantity);
  if (!contribution) return null;

  const frozen = normalizeReceipt(existingReceipt);
  if (frozen && matchesIdentity(frozen, uid, logID, articleID, actionID)) {
    // Factor versions and accepted amounts are historical receipts. A future catalog change must
    // not rewrite an already accepted contribution.
    return frozen;
  }

  return {
    schemaVersion: IMPACT_SCHEMA_VERSION,
    uid,
    logID,
    articleID,
    actionID,
    factorID: contribution.factorID,
    factorVersion: contribution.factorVersion,
    inputQuantity: contribution.inputQuantity,
    inputUnit: contribution.inputUnit,
    kgCO2e: contribution.kgCO2e,
    sourceURL: contribution.sourceURL,
    sourceFingerprint: fingerprint(articleID, actionID, contribution),
  };
}

function sameReceipt(left: FrozenReceipt | null, right: FrozenReceipt | null) {
  if (left === right) return true;
  if (!left || !right) return false;
  return (
    left.uid === right.uid &&
    left.logID === right.logID &&
    left.articleID === right.articleID &&
    left.actionID === right.actionID &&
    left.factorID === right.factorID &&
    left.factorVersion === right.factorVersion &&
    left.inputQuantity === right.inputQuantity &&
    left.inputUnit === right.inputUnit &&
    left.kgCO2e === right.kgCO2e &&
    left.sourceURL === right.sourceURL &&
    left.sourceFingerprint === right.sourceFingerprint
  );
}

function updateVersionCount(
  current: Record<string, number>,
  version: string | null,
  delta: number,
) {
  if (!version || delta === 0) return current;
  const next = { ...current };
  const value = (next[version] ?? 0) + delta;
  if (value > 0) next[version] = value;
  else delete next[version];
  return next;
}

/**
 * Applies one receipt's delta to the internal aggregate and contributor document. The caller puts
 * this plan into one Firestore transaction with the receipt document, so duplicate/out-of-order
 * deliveries recompute the same zero-delta state.
 */
export function planReceiptTransition({
  currentReceipt,
  nextReceipt,
  internal,
  contributor,
}: {
  currentReceipt: unknown;
  nextReceipt: FrozenReceipt | null;
  internal: unknown;
  contributor: unknown;
}): ReceiptTransition {
  const current = normalizeReceipt(currentReceipt);
  const next = nextReceipt;
  const currentInternal = normalizeInternalImpact(internal);
  const currentContributor = normalizeContributor(contributor);
  const currentContribution = current?.kgCO2e ?? 0;
  const nextContribution = next?.kgCO2e ?? 0;
  const receiptCountDelta = (next ? 1 : 0) - (current ? 1 : 0);
  const contributionDelta = roundToHundredth(nextContribution - currentContribution);
  const nextReceiptCount = Math.max(0, currentContributor.receiptCount + receiptCountDelta);
  const nextContributorTotal = Math.max(
    0,
    roundToHundredth(currentContributor.totalKgCO2e + contributionDelta),
  );
  const contributorDelta = (nextReceiptCount > 0 ? 1 : 0) - (currentContributor.receiptCount > 0 ? 1 : 0);

  let factorVersionCounts = currentInternal.factorVersionCounts;
  factorVersionCounts = updateVersionCount(factorVersionCounts, current?.factorVersion ?? null, -1);
  factorVersionCounts = updateVersionCount(factorVersionCounts, next?.factorVersion ?? null, 1);

  const nextInternal: InternalImpact = {
    schemaVersion: IMPACT_SCHEMA_VERSION,
    totalKgCO2e: Math.max(0, roundToHundredth(currentInternal.totalKgCO2e + contributionDelta)),
    eligibleActionCount: Math.max(0, currentInternal.eligibleActionCount + receiptCountDelta),
    contributorCount: Math.max(0, currentInternal.contributorCount + contributorDelta),
    factorVersionCounts,
  };
  const nextContributor: ImpactContributor = {
    receiptCount: nextReceiptCount,
    totalKgCO2e: nextContributorTotal,
  };

  return {
    currentReceipt: current,
    nextReceipt: next,
    nextInternal,
    nextContributor,
    shouldDeleteContributor: nextReceiptCount === 0,
    changed:
      !sameReceipt(current, next) ||
      currentContributor.receiptCount !== nextReceiptCount ||
      currentContributor.totalKgCO2e !== nextContributorTotal ||
      currentInternal.totalKgCO2e !== nextInternal.totalKgCO2e ||
      currentInternal.eligibleActionCount !== nextInternal.eligibleActionCount ||
      currentInternal.contributorCount !== nextInternal.contributorCount,
  };
}

export function buildPublicCommunityImpact(internal: unknown): PublicCommunityImpact {
  const aggregate = normalizeInternalImpact(internal);
  const visible = aggregate.contributorCount >= COMMUNITY_IMPACT_MINIMUM_CONTRIBUTORS;
  const methodology = {
    metric: "co2e" as const,
    factorVersions: visible ? Object.keys(aggregate.factorVersionCounts).sort() : [],
    description: COMMUNITY_IMPACT_METHODOLOGY,
  };

  if (!visible) {
    return {
      schemaVersion: IMPACT_SCHEMA_VERSION,
      visible: false,
      minimumContributors: COMMUNITY_IMPACT_MINIMUM_CONTRIBUTORS,
      methodology,
    };
  }

  return {
    schemaVersion: IMPACT_SCHEMA_VERSION,
    visible: true,
    minimumContributors: COMMUNITY_IMPACT_MINIMUM_CONTRIBUTORS,
    contributorCount: aggregate.contributorCount,
    eligibleActionCount: aggregate.eligibleActionCount,
    estimatedKgCO2e: Math.round(aggregate.totalKgCO2e),
    methodology,
  };
}
