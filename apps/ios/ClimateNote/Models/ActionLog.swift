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
    /// Older documents did not record a kind. They are actions by definition so
    /// the existing journal continues to behave as it did before this field
    /// was introduced.
    let kind: Kind
    let createdAt: Date
    let completedAt: Date?
    let impactEstimate: ImpactEstimate?

    enum Status: String, Codable, Sendable { case planned, completed }

    enum Kind: Hashable, Sendable, Codable {
        case action
        case reflection
        /// Keep future server values readable instead of dropping the complete
        /// journal entry when a newer client introduces another kind.
        case unknown(String)

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            switch rawValue {
            case "action": self = .action
            case "reflection": self = .reflection
            default: self = .unknown(rawValue)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .action: try container.encode("action")
            case .reflection: try container.encode("reflection")
            case .unknown(let value): try container.encode(value)
            }
        }

        var supportsCompletion: Bool { self == .action }
        var supportsReminder: Bool { self == .action }
    }

    private enum CodingKeys: String, CodingKey {
        case documentID, userID, articleID, articleTitle, actionID, title, detail
        case category, status, kind, createdAt, completedAt, impactEstimate
    }

    init(
        documentID: String? = nil,
        userID: String,
        articleID: String,
        articleTitle: String,
        actionID: String,
        title: String,
        detail: String,
        category: String,
        status: Status,
        kind: Kind = .action,
        createdAt: Date,
        completedAt: Date?,
        impactEstimate: ImpactEstimate?
    ) {
        self.documentID = documentID
        self.userID = userID
        self.articleID = articleID
        self.articleTitle = articleTitle
        self.actionID = actionID
        self.title = title
        self.detail = detail
        self.category = category
        self.status = status
        self.kind = kind
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.impactEstimate = impactEstimate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        documentID = try container.decodeIfPresent(String.self, forKey: .documentID)
        userID = try container.decode(String.self, forKey: .userID)
        articleID = try container.decode(String.self, forKey: .articleID)
        articleTitle = try container.decode(String.self, forKey: .articleTitle)
        actionID = try container.decode(String.self, forKey: .actionID)
        title = try container.decode(String.self, forKey: .title)
        detail = try container.decode(String.self, forKey: .detail)
        category = try container.decode(String.self, forKey: .category)
        status = try container.decode(Status.self, forKey: .status)
        kind = try container.decodeIfPresent(Kind.self, forKey: .kind) ?? .action
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        impactEstimate = try container.decodeIfPresent(ImpactEstimate.self, forKey: .impactEstimate)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Firestore document IDs belong in the reference path. Excluding this
        // transient wrapper also lets protected local archives encode logs.
        try container.encode(userID, forKey: .userID)
        try container.encode(articleID, forKey: .articleID)
        try container.encode(articleTitle, forKey: .articleTitle)
        try container.encode(actionID, forKey: .actionID)
        try container.encode(title, forKey: .title)
        try container.encode(detail, forKey: .detail)
        try container.encode(category, forKey: .category)
        try container.encode(status, forKey: .status)
        try container.encode(kind, forKey: .kind)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encodeIfPresent(impactEstimate, forKey: .impactEstimate)
    }

    func replacingDocumentID(_ documentID: String) -> ActionLog {
        ActionLog(
            documentID: documentID,
            userID: userID,
            articleID: articleID,
            articleTitle: articleTitle,
            actionID: actionID,
            title: title,
            detail: detail,
            category: category,
            status: status,
            kind: kind,
            createdAt: createdAt,
            completedAt: completedAt,
            impactEstimate: impactEstimate
        )
    }
}

struct ImpactEstimate: Codable, Hashable, Sendable {
    let value: Double
    let unit: String
    let label: String
    let methodology: String
    let factorID: String
    /// Optional fields make the new multi-metric contract safe for existing
    /// action logs. The server always recalculates public aggregation values.
    let metric: String?
    let factorVersion: String?
    let input: ImpactInput?

    init(
        value: Double,
        unit: String,
        label: String,
        methodology: String,
        factorID: String,
        metric: String? = nil,
        factorVersion: String? = nil,
        input: ImpactInput? = nil
    ) {
        self.value = value
        self.unit = unit
        self.label = label
        self.methodology = methodology
        self.factorID = factorID
        self.metric = metric
        self.factorVersion = factorVersion
        self.input = input
    }

    var isCarbonDioxideEquivalent: Bool {
        metric?.lowercased() == "co2e" || (metric == nil && unit == "kg CO₂e")
    }
}

struct ImpactInput: Codable, Hashable, Sendable {
    let quantity: Double
    let unit: String
}
