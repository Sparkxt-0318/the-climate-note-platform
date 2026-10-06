import Foundation

/// Builds a Pixabay search query and ranks hits for Climate Note covers.
/// Prefer `visualPlan.searchQuery` from the article pipeline; fall back to topic + title.
enum PixabayCoverSelector {
    static func searchQuery(for article: Article) -> String {
        if let planned = article.generation?.visualPlan.searchQuery
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !planned.isEmpty {
            return clip(planned)
        }

        var parts: [String] = []
        let topic = article.topic.trimmingCharacters(in: .whitespacesAndNewlines)
        if !topic.isEmpty { parts.append(topic) }

        let titleWords = article.title
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { $0.count > 3 }
            .prefix(5)
        parts.append(contentsOf: titleWords)

        if parts.isEmpty { parts.append("climate nature") }
        return clip(parts.joined(separator: " "))
    }

    static func rank(_ hits: [PixabayHit]) -> [PixabayHit] {
        hits.sorted { lhs, rhs in
            let left = score(lhs)
            let right = score(rhs)
            if left != right { return left > right }
            return lhs.id > rhs.id
        }
    }

    static func score(_ hit: PixabayHit) -> Int {
        var value = 0
        value += min(hit.likes ?? 0, 5_000)
        value += min((hit.downloads ?? 0) / 10, 5_000)
        value += min((hit.views ?? 0) / 100, 2_000)
        let width = hit.imageWidth ?? hit.webformatWidth ?? 0
        let height = hit.imageHeight ?? hit.webformatHeight ?? 0
        if width >= 1280 { value += 800 }
        if width >= height { value += 600 } // prefer landscape covers
        if height > 0, Double(width) / Double(height) >= 1.3 { value += 400 }
        if hit.type == "photo" { value += 300 }
        return value
    }

    static func coverAsset(from hit: PixabayHit, article: Article) -> CoverAsset? {
        guard let urlString = hit.largeImageURL ?? hit.webformatURL ?? hit.previewURL,
              let url = URL(string: urlString) else { return nil }

        let photographer = hit.user?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pageURL = hit.pageURL.flatMap(URL.init(string:))
        let alt = article.generation?.visualPlan.altText
            ?? "\(article.topic.isEmpty ? "Climate" : article.topic) story cover for \(article.title)"
        let attribution: String = {
            if let photographer, !photographer.isEmpty {
                return "Photo by \(photographer) via Pixabay"
            }
            return "Photo via Pixabay"
        }()

        return CoverAsset(
            url: url,
            altText: alt,
            caption: article.topic.isEmpty ? "Story cover" : "\(article.topic) · story cover",
            attribution: attribution,
            license: "Pixabay Content License",
            sourceUrl: pageURL,
            generated: false,
            provider: "pixabay",
            providerAssetId: String(hit.id),
            photographer: photographer,
            licenseUrl: URL(string: "https://pixabay.com/service/license-summary/"),
            crop: nil,
            contentHash: nil,
            retrievedAt: ISO8601DateFormatter().string(from: Date())
        )
    }

    private static func clip(_ query: String) -> String {
        let cleaned = query
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count <= 100 { return cleaned }
        return String(cleaned.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct PixabayHit: Decodable, Hashable, Sendable {
    let id: Int
    let pageURL: String?
    let type: String?
    let tags: String?
    let previewURL: String?
    let webformatURL: String?
    let largeImageURL: String?
    let imageWidth: Int?
    let imageHeight: Int?
    let webformatWidth: Int?
    let webformatHeight: Int?
    let views: Int?
    let downloads: Int?
    let likes: Int?
    let user: String?

    init(
        id: Int,
        pageURL: String? = nil,
        type: String? = "photo",
        tags: String? = nil,
        previewURL: String? = nil,
        webformatURL: String? = nil,
        largeImageURL: String? = nil,
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        webformatWidth: Int? = nil,
        webformatHeight: Int? = nil,
        views: Int? = nil,
        downloads: Int? = nil,
        likes: Int? = nil,
        user: String? = nil
    ) {
        self.id = id
        self.pageURL = pageURL
        self.type = type
        self.tags = tags
        self.previewURL = previewURL
        self.webformatURL = webformatURL
        self.largeImageURL = largeImageURL
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.webformatWidth = webformatWidth
        self.webformatHeight = webformatHeight
        self.views = views
        self.downloads = downloads
        self.likes = likes
        self.user = user
    }
}

struct PixabaySearchResponse: Decodable, Sendable {
    let hits: [PixabayHit]
}

/// Resolves a licensed Pixabay cover for articles that publish without one.
@MainActor
final class PixabayCoverService {
    static let shared = PixabayCoverService()

    private var memoryCache: [String: CoverAsset] = [:]
    private var inFlight: Set<String> = []
    private let session: URLSession
    private let defaultsKey = "climate-note.pixabay-cover-cache"

    init(session: URLSession = .shared) {
        self.session = session
        loadDiskCache()
    }

    var isConfigured: Bool { AppConfig.pixabayAPIKey != nil }

    func cachedCover(for articleID: String) -> CoverAsset? {
        memoryCache[articleID]
    }

    func resolveCover(for article: Article) async -> CoverAsset? {
        if let cached = memoryCache[article.id] { return cached }
        guard isConfigured else { return nil }
        guard !inFlight.contains(article.id) else { return nil }
        inFlight.insert(article.id)
        defer { inFlight.remove(article.id) }

        do {
            let hits = try await search(query: PixabayCoverSelector.searchQuery(for: article))
            guard let best = PixabayCoverSelector.rank(hits).first,
                  let cover = PixabayCoverSelector.coverAsset(from: best, article: article) else {
                return nil
            }
            memoryCache[article.id] = cover
            persistDiskCache()
            return cover
        } catch {
            return nil
        }
    }

    private func search(query: String) async throws -> [PixabayHit] {
        guard let apiKey = AppConfig.pixabayAPIKey else { return [] }
        var components = URLComponents(string: "https://pixabay.com/api/")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "image_type", value: "photo"),
            URLQueryItem(name: "orientation", value: "horizontal"),
            URLQueryItem(name: "safesearch", value: "true"),
            URLQueryItem(name: "editors_choice", value: "true"),
            URLQueryItem(name: "order", value: "popular"),
            URLQueryItem(name: "per_page", value: "20"),
            URLQueryItem(name: "min_width", value: "1200"),
        ]
        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue("ClimateNote-iOS", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            // Retry without editors_choice if the curated set is empty/unavailable.
            return try await searchRelaxed(query: query, apiKey: apiKey)
        }
        let decoded = try JSONDecoder().decode(PixabaySearchResponse.self, from: data)
        if decoded.hits.isEmpty {
            return try await searchRelaxed(query: query, apiKey: apiKey)
        }
        return decoded.hits
    }

    private func searchRelaxed(query: String, apiKey: String) async throws -> [PixabayHit] {
        var components = URLComponents(string: "https://pixabay.com/api/")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "image_type", value: "photo"),
            URLQueryItem(name: "orientation", value: "horizontal"),
            URLQueryItem(name: "safesearch", value: "true"),
            URLQueryItem(name: "order", value: "popular"),
            URLQueryItem(name: "per_page", value: "20"),
            URLQueryItem(name: "min_width", value: "1000"),
        ]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return []
        }
        return try JSONDecoder().decode(PixabaySearchResponse.self, from: data).hits
    }

    private func loadDiskCache() {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode([String: CoverAsset].self, from: data)
        else { return }
        memoryCache = decoded
    }

    private func persistDiskCache() {
        // Keep cache bounded to recent stories.
        if memoryCache.count > 40 {
            let trimmed = Array(memoryCache.keys.sorted().suffix(40))
            memoryCache = memoryCache.filter { trimmed.contains($0.key) }
        }
        if let data = try? JSONEncoder().encode(memoryCache) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
}

extension Article {
    var needsPixabayCover: Bool {
        if BundledCoverCatalog.assetName(for: self) != nil { return false }
        guard let cover = coverAsset else { return true }
        guard let scheme = cover.url.scheme?.lowercased() else { return true }
        if scheme == "climate-note-asset" { return false }
        if cover.provider == "bundled" { return false }
        return scheme == "climate-note-fixture"
            || scheme == "climate-note-fixture-missing"
            || scheme == "climate-note-fixture-loading"
    }
}
