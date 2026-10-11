export const MAX_FACTOR_INPUT_QUANTITY = 1_000;

export const impactFactors = {
  "passenger-vehicle-mile-avoided-us": {
    inputUnit: "mile",
    kgCO2ePerUnit: 0.4,
    sourceUrl: "https://www.epa.gov/greenvehicles/greenhouse-gas-emissions-typical-passenger-vehicle",
    version: "EPA-2023",
  },
  "electricity-kwh-avoided-us": {
    inputUnit: "kWh",
    kgCO2ePerUnit: 0.672,
    sourceUrl: "https://www.epa.gov/energy/greenhouse-gas-equivalencies-calculator-calculations-and-references#kilowatt",
    version: "EPA-eGRID2022-2024",
  },
  "mixed-recyclables-pound-us": {
    inputUnit: "lb",
    kgCO2ePerUnit: 1.415,
    sourceUrl: "https://www.epa.gov/energy/greenhouse-gas-equivalencies-calculator-calculations-and-references#recycle",
    version: "EPA-WARM16-2024",
  },
} as const;

export type ImpactFactorID = keyof typeof impactFactors;

export type CalculatedContribution = {
  factorID: ImpactFactorID;
  factorVersion: string;
  inputQuantity: number;
  inputUnit: string;
  kgCO2e: number;
  sourceURL: string;
};

function roundToHundredth(value: number) {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

export function isFinitePositiveQuantity(value: unknown): value is number {
  return (
    typeof value === "number" &&
    Number.isFinite(value) &&
    value > 0 &&
    value <= MAX_FACTOR_INPUT_QUANTITY
  );
}

export function calculateContribution(
  factorID: unknown,
  inputQuantity: unknown,
): CalculatedContribution | null {
  if (
    typeof factorID !== "string" ||
    !Object.prototype.hasOwnProperty.call(impactFactors, factorID) ||
    !isFinitePositiveQuantity(inputQuantity)
  ) {
    return null;
  }

  const factor = impactFactors[factorID as ImpactFactorID];
  const kgCO2e = roundToHundredth(inputQuantity * factor.kgCO2ePerUnit);

  // Do not create a receipt that would imply an impact while contributing no measurable amount.
  if (!Number.isFinite(kgCO2e) || kgCO2e <= 0) return null;

  return {
    factorID: factorID as ImpactFactorID,
    factorVersion: factor.version,
    inputQuantity,
    inputUnit: factor.inputUnit,
    kgCO2e,
    sourceURL: factor.sourceUrl,
  };
}
