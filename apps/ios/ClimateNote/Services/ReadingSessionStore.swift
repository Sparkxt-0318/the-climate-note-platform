import Foundation

/// Local reading memory for quiet “New” markers, topic filters, scroll restore, and the first tip.
@MainActor
final class ReadingSessionStore: ObservableObject {
    static let shared = ReadingSessionStore()

    @Published private(set) var lastOpenedArticleID: String?
    @Published private(set) var lastScrollOffset: Double
    @Published var selectedTopic: String? {
        didSet { defaults.set(selectedTopic, forKey: Keys.selectedTopic) }
    }
    @Published private(set) var showFirstLaunchTip: Bool

    private let defaults: UserDefaults

    private enum Keys {
        static let lastOpenedArticleID = "climate.reading.lastOpenedArticleID"
        static let lastScrollOffset = "climate.reading.lastScrollOffset"
        static let lastReadVisit = "climate.reading.lastReadVisit"
        static let selectedTopic = "climate.reading.selectedTopic"
        static let firstLaunchTipDismissed = "climate.reading.firstLaunchTipDismissed"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lastOpenedArticleID = defaults.string(forKey: Keys.lastOpenedArticleID)
        lastScrollOffset = defaults.double(forKey: Keys.lastScrollOffset)
        selectedTopic = defaults.string(forKey: Keys.selectedTopic)
        showFirstLaunchTip = !defaults.bool(forKey: Keys.firstLaunchTipDismissed)
        defaults.removeObject(forKey: "climate.reading.lastOpenedArticleTitle")
    }

    private var lastReadVisit: Date? {
        get { defaults.object(forKey: Keys.lastReadVisit) as? Date }
        set { defaults.set(newValue, forKey: Keys.lastReadVisit) }
    }

    func markArticleOpened(_ article: Article) {
        lastOpenedArticleID = article.id
        defaults.set(article.id, forKey: Keys.lastOpenedArticleID)
    }

    func updateScrollOffset(_ offset: Double, for articleID: String) {
        guard articleID == lastOpenedArticleID || lastOpenedArticleID == nil else { return }
        lastScrollOffset = max(0, offset)
        defaults.set(lastScrollOffset, forKey: Keys.lastScrollOffset)
    }

    func scrollOffset(for articleID: String) -> Double {
        guard articleID == lastOpenedArticleID else { return 0 }
        return lastScrollOffset
    }

    func recordFeedVisit() {
        lastReadVisit = Date()
    }

    func dismissFirstLaunchTip() {
        showFirstLaunchTip = false
        defaults.set(true, forKey: Keys.firstLaunchTipDismissed)
    }

    func isNewLead(_ article: Article) -> Bool {
        guard let published = article.publishedAt else { return false }
        guard let visit = lastReadVisit else { return true }
        return published > visit
    }

    func topics(from articles: [Article]) -> [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for article in articles.dropFirst() {
            let topic = article.topic.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !topic.isEmpty, seen.insert(topic).inserted else { continue }
            ordered.append(topic)
        }
        return ordered
    }

    func filteredArchive(from articles: [Article]) -> [Article] {
        let archive = Array(articles.dropFirst())
        guard let selectedTopic, !selectedTopic.isEmpty else { return archive }
        return archive.filter { $0.topic.caseInsensitiveCompare(selectedTopic) == .orderedSame }
    }
}
