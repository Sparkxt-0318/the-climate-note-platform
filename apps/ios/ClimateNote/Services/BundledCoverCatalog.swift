import Foundation
import UIKit

/// Ships curated cover photos for known Climate Note articles so Read never
/// opens as a wall of identical gradient placeholders.
enum BundledCoverCatalog {
    /// Long published slugs that exceed asset-catalog name comfort on Windows
    /// are stored under shorter Cover-* names and remapped here.
    private static let slugAliases: [String: String] = [
        "seeking-shade-killing-the-coral-reef-sunscreen-chemicals-and-the-crisis-of-coral-bleaching":
            "seeking-shade-coral-sunscreen",
    ]

    /// Asset catalog name for a published slug, if we bundled a cover.
    static func assetName(forSlug slug: String) -> String? {
        let key = slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        let assetKey = slugAliases[key] ?? key
        guard UIImage(named: "Cover-\(assetKey)") != nil else { return nil }
        return "Cover-\(assetKey)"
    }

    /// Prefer slug match, then topic signature art assets.
    static func assetName(for article: Article) -> String? {
        if let named = assetName(forSlug: article.slug) { return named }
        let topic = article.topic
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        if !topic.isEmpty, UIImage(named: "Signature/\(topic)") != nil {
            return "Signature/\(topic)"
        }
        return nil
    }

    /// Path segment inside a `climate-note-asset://cover/...` URL.
    static func assetName(from url: URL) -> String? {
        guard url.scheme?.lowercased() == "climate-note-asset" else { return nil }
        let name = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return name.isEmpty ? nil : name
    }

    static func coverAsset(for article: Article) -> CoverAsset? {
        guard let name = assetName(for: article) else { return nil }
        var components = URLComponents()
        components.scheme = "climate-note-asset"
        components.host = "cover"
        components.path = "/" + name
        guard let url = components.url else { return nil }
        return CoverAsset(
            url: url,
            altText: "\(article.topic.isEmpty ? "Climate" : article.topic) cover for \(article.title)",
            caption: article.topic.isEmpty ? "Story cover" : "\(article.topic) · story cover",
            attribution: "Bundled editorial cover",
            license: "App asset",
            sourceUrl: nil,
            generated: false,
            provider: "bundled",
            providerAssetId: name,
            photographer: nil,
            licenseUrl: nil,
            crop: nil,
            contentHash: nil,
            retrievedAt: nil
        )
    }
}
