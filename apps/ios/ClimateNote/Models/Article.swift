import Foundation
@preconcurrency import FirebaseFirestore

struct Article: Codable, Identifiable, Hashable, Sendable {
    @DocumentID var documentID: String?
    var id: String { documentID ?? slug }
    let slug: String
    let title: String
    let author: String?
    let topic: String
    let excerpt: String
    let status: String
    let contentBlocks: [ArticleBlock]
    let sourceLinks: [SourceLink]
    let externalLinks: ExternalLinks?
    let readingMinutes: Int
    let publishedAt: Date?
    let generation: ArticleGeneration?
    let coverAsset: CoverAsset?
}

struct ExternalLinks: Codable, Hashable, Sendable {
    let instagram: URL?
    let substack: URL?
    let medium: URL?

    var isEmpty: Bool { instagram == nil && substack == nil && medium == nil }
}

enum ArticleBlock: Codable, Hashable, Sendable {
    case paragraph(String)
    case heading(level: Int, text: String)
    case bulletedList([String])
    case numberedList([String])

    private enum CodingKeys: String, CodingKey { case type, text, level, items }
    private enum Kind: String, Codable { case paragraph, heading, bulletedList, numberedList }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .type) {
        case .paragraph:
            self = .paragraph(try container.decode(String.self, forKey: .text))
        case .heading:
            self = .heading(
                level: try container.decode(Int.self, forKey: .level),
                text: try container.decode(String.self, forKey: .text)
            )
        case .bulletedList:
            self = .bulletedList(try container.decode([String].self, forKey: .items))
        case .numberedList:
            self = .numberedList(try container.decode([String].self, forKey: .items))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .paragraph(let text):
            try container.encode(Kind.paragraph, forKey: .type)
            try container.encode(text, forKey: .text)
        case .heading(let level, let text):
            try container.encode(Kind.heading, forKey: .type)
            try container.encode(level, forKey: .level)
            try container.encode(text, forKey: .text)
        case .bulletedList(let items):
            try container.encode(Kind.bulletedList, forKey: .type)
            try container.encode(items, forKey: .items)
        case .numberedList(let items):
            try container.encode(Kind.numberedList, forKey: .type)
            try container.encode(items, forKey: .items)
        }
    }
}

struct SourceLink: Codable, Hashable, Sendable {
    let label: String
    let url: URL
}

struct CoverAsset: Codable, Hashable, Sendable {
    let url: URL
    let altText: String
    let caption: String
    let attribution: String
    let license: String
    let sourceUrl: URL?
    let generated: Bool
}

struct ArticleGeneration: Codable, Hashable, Sendable {
    let summary: ClimateSummary
    let suggestedActions: [SuggestedAction]
    let visualPlan: VisualPlan
}

struct ClimateSummary: Codable, Hashable, Sendable {
    let problem: String
    let whyItMatters: String
    let whatWeCanDo: String
}

struct SuggestedAction: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let instruction: String
    let cadence: String
    let evidence: String
    let category: String
    let factorId: String?
    let factorQuantity: Double?
}

struct VisualPlan: Codable, Hashable, Sendable {
    let searchQuery: String
    let altText: String
    let placement: String
    let generationPrompt: String
}
