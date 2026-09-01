export const impactFactors = {
  "passenger-vehicle-mile-avoided-us": {
    inputUnit: "mile",
    kgCO2ePerUnit: 0.4,
    label: "estimated tailpipe CO₂ avoided",
    methodology: "U.S. EPA typical passenger vehicle: about 400 grams of CO₂ per mile.",
    sourceUrl: "https://www.epa.gov/greenvehicles/greenhouse-gas-emissions-typical-passenger-vehicle",
    version: "EPA-2023",
  },
  "electricity-kwh-avoided-us": {
    inputUnit: "kWh",
    kgCO2ePerUnit: 0.672,
    label: "estimated CO₂ avoided",
    methodology: "U.S. EPA eGRID national marginal rate including line losses: 6.72e-4 metric tons CO₂ per kWh.",
    sourceUrl: "https://www.epa.gov/energy/greenhouse-gas-equivalencies-calculator-calculations-and-references#kilowatt",
    version: "EPA-eGRID2022-2024",
  },
  "mixed-recyclables-pound-us": {
    inputUnit: "lb",
    kgCO2ePerUnit: 1.415,
    label: "estimated CO₂e avoided",
    methodology: "U.S. EPA WARM v16: 2.83 metric tons CO₂e per short ton recycled instead of landfilled.",
    sourceUrl: "https://www.epa.gov/energy/greenhouse-gas-equivalencies-calculator-calculations-and-references#recycle",
    version: "EPA-WARM16-2024",
  },
} as const;

export type ImpactFactorId = keyof typeof impactFactors;

export function estimateImpact(factorId: string | null, quantity: number | null) {
  if (!factorId || quantity === null || !(factorId in impactFactors)) return null;
  const factor = impactFactors[factorId as ImpactFactorId];
  return {
    value: Math.round(quantity * factor.kgCO2ePerUnit * 100) / 100,
    unit: "kg CO₂e",
    label: factor.label,
    methodology: factor.methodology,
    factorId,
    factorVersion: factor.version,
    sourceUrl: factor.sourceUrl,
    inputQuantity: quantity,
    inputUnit: factor.inputUnit,
  };
}
