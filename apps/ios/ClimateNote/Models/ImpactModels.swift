import Foundation

/// The only public aggregate document the app reads. Counts and estimates are
/// deliberately absent until the server's minimum-contributor threshold is met.
struct CommunityImpactDocument: Codable, Hashable, Sendable {
    let schemaVersion: Int
    let visible: Bool
    let minimumContributors: Int
    let contributorCount: Int?
    let eligibleActionCount: Int?
    let estimatedKgCO2e: Double?
    let updatedAt: Date?
    let methodology: CommunityImpactMethodology
}

struct CommunityImpactMethodology: Codable, Hashable, Sendable {
    let metric: String
    let factorVersions: [String]
    let description: String
}

/// This is the sole client-writable impact preference. The aggregate worker
/// owns receipts, contributor counts, and every public total.
struct CommunityImpactPreference: Codable, Hashable, Sendable {
    let includeInCommunityImpact: Bool

    init(includeInCommunityImpact: Bool = false) {
        self.includeInCommunityImpact = includeInCommunityImpact
    }
}

struct PersonalImpactSummary: Hashable, Sendable {
    let completedActionCount: Int
    let supportedActionCount: Int
    let estimatedKgCO2e: Double?
    let estimatedKgWaste: Double?
    let factorVersions: [String]

    init(logs: [ActionLog]) {
        let completedActions = logs.filter { $0.kind == .action && $0.status == .completed }
        let estimates = completedActions.compactMap(\.impactEstimate)
        let supportedEstimates = estimates.filter(\.isCarbonDioxideEquivalent)
        let wasteValues = estimates.compactMap(ImpactFactorCatalog.wasteKilograms(from:))

        completedActionCount = completedActions.count
        supportedActionCount = supportedEstimates.count
        estimatedKgCO2e = supportedEstimates.isEmpty
            ? nil
            : supportedEstimates.reduce(0) { $0 + $1.value }
        estimatedKgWaste = wasteValues.isEmpty
            ? nil
            : (wasteValues.reduce(0, +) * 100).rounded() / 100
        factorVersions = Array(Set(supportedEstimates.compactMap(\.factorVersion))).sorted()
    }

    var hasContent: Bool { completedActionCount > 0 }
}

enum CommunityImpactPresentation: Equatable {
    case loading
    case threshold(CommunityImpactDocument)
    case populated(CommunityImpactDocument, isStale: Bool)
    case error(String)
}

enum CommunityImpactPresentationResolver {
    static let staleAfter: TimeInterval = 7 * 24 * 60 * 60

    static func presentation(
        for document: CommunityImpactDocument,
        isFromCache: Bool,
        now: Date = Date(),
        staleAfter: TimeInterval = staleAfter
    ) -> CommunityImpactPresentation {
        guard document.schemaVersion == 1, document.minimumContributors > 0 else {
            return .error("Community impact needs a newer update. Please try again shortly.")
        }

        guard document.visible else { return .threshold(document) }

        guard document.contributorCount != nil,
              document.eligibleActionCount != nil,
              document.estimatedKgCO2e != nil,
              document.methodology.metric.lowercased() == "co2e" else {
            return .error("Community impact needs a newer update. Please try again shortly.")
        }

        let dateIsStale = document.updatedAt.map { now.timeIntervalSince($0) > staleAfter } ?? true
        return .populated(document, isStale: isFromCache || dateIsStale)
    }
}
