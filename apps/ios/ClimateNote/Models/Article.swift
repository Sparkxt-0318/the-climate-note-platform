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
    var coverAsset: CoverAsset?
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
    /// Editorial provenance is additive so articles published before the
    /// approved-photo pipeline remain readable.
    let provider: String?
    let providerAssetId: String?
    let photographer: String?
    let licenseUrl: URL?
    let crop: CoverCrop?
    let contentHash: String?
    /// ISO-8601 provenance value written by the server. Keeping this as a
    /// string matches the web schema and avoids failing the entire article
    /// decode when Firestore returns a licensed cover.
    let retrievedAt: String?

    init(
        url: URL,
        altText: String,
        caption: String,
        attribution: String,
        license: String,
        sourceUrl: URL?,
        generated: Bool,
        provider: String? = nil,
        providerAssetId: String? = nil,
        photographer: String? = nil,
        licenseUrl: URL? = nil,
        crop: CoverCrop? = nil,
        contentHash: String? = nil,
        retrievedAt: String? = nil
    ) {
        self.url = url
        self.altText = altText
        self.caption = caption
        self.attribution = attribution
        self.license = license
        self.sourceUrl = sourceUrl
        self.generated = generated
        self.provider = provider
        self.providerAssetId = providerAssetId
        self.photographer = photographer
        self.licenseUrl = licenseUrl
        self.crop = crop
        self.contentHash = contentHash
        self.retrievedAt = retrievedAt
    }
}

/// A normalized editorial crop. Published cover URLs already contain the
/// chosen rendition; these values retain review provenance for compatible
/// clients and future image renderers.
struct CoverCrop: Codable, Hashable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
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
