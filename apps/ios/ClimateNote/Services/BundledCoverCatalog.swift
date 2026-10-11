import Foundation
import UIKit

/// Selects an explicitly bundled editorial cover before any optional runtime
/// lookup. The current Pixabay catalogue stays untouched; this supports cover
/// bundles introduced by future published collections.
enum BundledCoverCatalog {
    private static let slugAliases: [String: String] = [
        "seeking-shade-killing-the-coral-reef-sunscreen-chemicals-and-the-crisis-of-coral-bleaching":
            "seeking-shade-coral-sunscreen",
    ]

    static func assetName(forSlug slug: String) -> String? {
        let key = slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return nil }
        let assetKey = slugAliases[key] ?? key
        guard UIImage(named: "Cover-\(assetKey)") != nil else { return nil }
        return "Cover-\(assetKey)"
    }

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

    /// The path segment inside a climate-note-asset URL.
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
            providerAssetId: name
        )
    }
}
