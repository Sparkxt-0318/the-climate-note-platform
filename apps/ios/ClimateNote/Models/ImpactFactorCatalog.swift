import Foundation

enum ImpactFactorCatalog {
    private struct Factor {
        let inputUnit: String
        let kgCO2ePerUnit: Double
        let label: String
        let methodology: String
        let version: String
    }

    private static let factors: [String: Factor] = [
        "passenger-vehicle-mile-avoided-us": Factor(
            inputUnit: "mile",
            kgCO2ePerUnit: 0.4,
            label: "estimated tailpipe CO₂ avoided",
            methodology: "U.S. EPA typical passenger vehicle: about 400 grams of CO₂ per mile.",
            version: "EPA-2023"
        ),
        "electricity-kwh-avoided-us": Factor(
            inputUnit: "kWh",
            kgCO2ePerUnit: 0.672,
            label: "estimated CO₂ avoided",
            methodology: "U.S. EPA eGRID national marginal rate including line losses.",
            version: "EPA-eGRID2022-2024"
        ),
        "mixed-recyclables-pound-us": Factor(
            inputUnit: "lb",
            kgCO2ePerUnit: 1.415,
            label: "estimated CO₂e avoided",
            methodology: "U.S. EPA WARM v16 recycling compared with landfilling.",
            version: "EPA-WARM16-2024"
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
            factorID: id
        )
    }
}
