import Foundation

enum ImpactFactorCatalog {
    private struct Factor {
        let inputUnit: String
        let kgCO2ePerUnit: Double
        let label: String
        let methodology: String
        let version: String
        /// When set, reported input quantity also contributes to diverted waste (in this unit).
        let wasteInputUnit: String?
    }

    private static let factors: [String: Factor] = [
        "passenger-vehicle-mile-avoided-us": Factor(
            inputUnit: "mile",
            kgCO2ePerUnit: 0.4,
            label: "estimated tailpipe CO₂ from a reported mile not driven",
            methodology: "U.S. EPA typical passenger vehicle: about 400 grams of CO₂ per mile. Directional only; completions are self-reported.",
            version: "EPA-2023",
            wasteInputUnit: nil
        ),
        "electricity-kwh-avoided-us": Factor(
            inputUnit: "kWh",
            kgCO2ePerUnit: 0.672,
            label: "estimated CO₂ from reported electricity not used",
            methodology: "U.S. EPA eGRID national marginal rate including line losses. Directional only; completions are self-reported.",
            version: "EPA-eGRID2022-2024",
            wasteInputUnit: nil
        ),
        "mixed-recyclables-pound-us": Factor(
            inputUnit: "lb",
            kgCO2ePerUnit: 1.415,
            label: "estimated CO₂e from reported recycling",
            methodology: "U.S. EPA WARM v16 recycling compared with landfilling. Directional only; completions are self-reported.",
            version: "EPA-WARM16-2024",
            wasteInputUnit: "lb"
        ),
    ]

    static func estimate(for action: SuggestedAction?) -> ImpactEstimate? {
        guard
            let id = action?.factorId,
            let quantity = action?.factorQuantity,
            let factor = factors[id]
        else { return nil }

        let value = (quantity * factor.kgCO2ePerUnit * 100).rounded() / 100
        return ImpactEstimate(
            value: value,
            unit: "kg CO₂e",
            label: factor.label,
            methodology: "\(factor.methodology) Input: \(quantity.formatted()) \(factor.inputUnit). Factor version: \(factor.version).",
            factorID: id,
            metric: "co2e",
            factorVersion: factor.version,
            input: ImpactInput(quantity: quantity, unit: factor.inputUnit)
        )
    }

    /// Converts a supported estimate's reported input into kilograms of waste when applicable.
    static func wasteKilograms(from estimate: ImpactEstimate) -> Double? {
        guard
            let factor = factors[estimate.factorID],
            let wasteUnit = factor.wasteInputUnit,
            let input = estimate.input,
            input.unit.caseInsensitiveCompare(wasteUnit) == .orderedSame
        else { return nil }

        let kilograms: Double
        switch wasteUnit.lowercased() {
        case "lb", "lbs", "pound", "pounds":
            kilograms = input.quantity * 0.45359237
        case "kg":
            kilograms = input.quantity
        default:
            return nil
        }
        return (kilograms * 100).rounded() / 100
    }
}
