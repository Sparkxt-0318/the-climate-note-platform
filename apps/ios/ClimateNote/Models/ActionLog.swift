import Foundation
@preconcurrency import FirebaseFirestore

struct ActionLog: Codable, Identifiable, Hashable, Sendable {
    @DocumentID var documentID: String?
    var id: String { documentID ?? actionID }
    let userID: String
    let articleID: String
    let articleTitle: String
    let actionID: String
    let title: String
    let detail: String
    let category: String
    let status: Status
    let createdAt: Date
    let completedAt: Date?
    let impactEstimate: ImpactEstimate?

    enum Status: String, Codable, Sendable { case planned, completed }
}

struct ImpactEstimate: Codable, Hashable, Sendable {
    let value: Double
    let unit: String
    let label: String
    let methodology: String
    let factorID: String
}
