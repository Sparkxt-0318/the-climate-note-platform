import Combine
import Foundation
import FirebaseCore
import FirebaseFirestore

/// An SDK-independent gate for a single refresh request. A cached Firestore snapshot is useful
/// presentation data but must not end a pull-to-refresh before the server answers.
struct ArticleRefreshRequestState {
    enum Event { case cachedSnapshot, serverSnapshot, failure, timeout, cancelled }
    enum Resolution: Equatable { case success, failure, timedOut, cancelled }

    private(set) var activeID: UUID?

    mutating func begin() -> UUID {
        let id = UUID()
        activeID = id
        return id
    }

    mutating func resolve(_ event: Event, for id: UUID) -> Resolution? {
        guard activeID == id else { return nil }
        switch event {
        case .cachedSnapshot: return nil
        case .serverSnapshot: activeID = nil; return .success
        case .failure: activeID = nil; return .failure
        case .timeout: activeID = nil; return .timedOut
        case .cancelled: activeID = nil; return .cancelled
        }
    }

}

/// Presentation policy kept independent from Firestore so cache/server outcomes can be tested
/// without an SDK listener. It preserves a visible feed on failure and timeout.
struct ArticleRefreshPresentationPolicy {
    struct SnapshotDecision: Equatable {
        let replacesArticles: Bool
        let stopsLoading: Bool
    }

    /// A cached empty first response is not a usable empty-state answer. Retained content and
    /// cached nonempty content may stop the skeleton while the server-backed refresh continues.
    static func snapshotDecision(
        isFromCache: Bool,
        hadRetainedArticles: Bool,
        incomingIsEmpty: Bool
    ) -> SnapshotDecision {
        let keepsInitialLoading = isFromCache && !hadRetainedArticles && incomingIsEmpty
        return SnapshotDecision(
            replacesArticles: !isFromCache || !hadRetainedArticles,
            stopsLoading: !keepsInitialLoading
        )
    }

    static func displayedArticles<Item>(
        current: [Item], incoming: [Item], decision: SnapshotDecision
    ) -> [Item] {
        decision.replacesArticles ? incoming : current
    }

    static func articlesAfterTerminal<Item>(
        resolution: ArticleRefreshRequestState.Resolution,
        current: [Item], server: [Item]
    ) -> [Item] {
        resolution == .success ? server : current
    }
}

@MainActor
final class ArticleStore: ObservableObject {
    @Published private(set) var articles: [Article] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?

    private var listener: ListenerRegistration?
    private var observationID = UUID()
    private var refreshState = ArticleRefreshRequestState()
    private var refreshContinuation: CheckedContinuation<Void, Error>?
    private var refreshTimeout: Task<Void, Never>?

    func start() {
        guard listener == nil, !isRefreshing else { return }
        Task { try? await refresh() }
    }

    func retry() {
        guard !isRefreshing else { return }
        Task { try? await refresh() }
    }

    /// Replaces the Firestore listener and awaits a server snapshot, failure, cancellation, or timeout.
    /// The listener itself stays alive after a terminal refresh result so later live updates still arrive.
    func refresh() async throws {
        guard !isRefreshing else { return }

        let requestID = refreshState.begin()
        isRefreshing = true
        isLoading = articles.isEmpty
        errorMessage = nil

        guard FirebaseApp.app() != nil else {
            errorMessage = "Notes are unavailable right now. Please try again later."
            finishRefresh(for: requestID, event: .failure)
            return
        }

        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                refreshContinuation = continuation
                guard refreshState.activeID == requestID else {
                    refreshContinuation = nil
                    continuation.resume(throwing: CancellationError())
                    return
                }
                replaceListener(for: requestID)
                refreshTimeout = Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .seconds(15))
                    guard !Task.isCancelled else { return }
                    self?.timeoutRefresh(for: requestID)
                }
            }
        }, onCancel: { [weak self] in
            Task { @MainActor in self?.cancelRefresh(for: requestID) }
        })
    }

    private func replaceListener(for requestID: UUID) {
        observationID = UUID()
        let currentObservation = observationID
        listener?.remove()
        listener = Firestore.firestore()
            .collection("articles")
            .whereField("status", isEqualTo: "published")
            .order(by: "publishedAt", descending: true)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.observationID == currentObservation else { return }
                    if error != nil {
                        self.errorMessage = "We couldn’t refresh the notes. Check your connection and try again."
                        self.articles = ArticleRefreshPresentationPolicy.articlesAfterTerminal(
                            resolution: .failure, current: self.articles, server: []
                        )
                        self.isLoading = false
                        self.finishRefresh(for: requestID, event: .failure)
                        return
                    }

                    let incoming = snapshot?.documents.compactMap { try? $0.data(as: Article.self) } ?? []
                    let isFromCache = snapshot?.metadata.isFromCache ?? true
                    let hadRetainedArticles = !self.articles.isEmpty
                    let presentation = ArticleRefreshPresentationPolicy.snapshotDecision(
                        isFromCache: isFromCache,
                        hadRetainedArticles: hadRetainedArticles,
                        incomingIsEmpty: incoming.isEmpty
                    )
                    self.articles = ArticleRefreshPresentationPolicy.displayedArticles(
                        current: self.articles, incoming: incoming, decision: presentation
                    )
                    self.applyCachedPixabayCovers()
                    if presentation.stopsLoading {
                        self.isLoading = false
                    }
                    if !isFromCache {
                        self.errorMessage = nil
                        Task { await self.enrichMissingCoversFromPixabay() }
                    }
                    if isFromCache {
                        _ = self.refreshState.resolve(.cachedSnapshot, for: requestID)
                    } else {
                        self.finishRefresh(for: requestID, event: .serverSnapshot)
                    }
                }
            }
    }

    private func timeoutRefresh(for requestID: UUID) {
        errorMessage = "We couldn’t confirm newer notes. Showing the last available articles."
        articles = ArticleRefreshPresentationPolicy.articlesAfterTerminal(
            resolution: .timedOut, current: articles, server: []
        )
        finishRefresh(for: requestID, event: .timeout)
    }

    private func cancelRefresh(for requestID: UUID) {
        finishRefresh(for: requestID, event: .cancelled)
    }

    private func finishRefresh(for requestID: UUID, event: ArticleRefreshRequestState.Event) {
        guard let resolution = refreshState.resolve(event, for: requestID) else { return }
        isRefreshing = false
        isLoading = false
        refreshTimeout?.cancel()
        refreshTimeout = nil
        let continuation = refreshContinuation
        refreshContinuation = nil
        if resolution == .cancelled {
            continuation?.resume(throwing: CancellationError())
        } else {
            continuation?.resume()
        }
    }

    private func applyBundledCovers() {
        for index in articles.indices {
            guard articles[index].coverAsset == nil
                || articles[index].coverAsset?.url.scheme?.hasPrefix("climate-note-fixture") == true
            else { continue }
            if let bundled = BundledCoverCatalog.coverAsset(for: articles[index]) {
                articles[index].coverAsset = bundled
            }
        }
    }

    private func applyCachedPixabayCovers() {
        applyBundledCovers()
        for index in articles.indices where articles[index].needsPixabayCover {
            if let cached = PixabayCoverService.shared.cachedCover(for: articles[index].id) {
                articles[index].coverAsset = cached
            }
        }
    }

    private func enrichMissingCoversFromPixabay() async {
        applyBundledCovers()
        guard PixabayCoverService.shared.isConfigured else { return }
        let candidates = articles.filter(\.needsPixabayCover)
        guard !candidates.isEmpty else { return }

        for article in candidates {
            guard let cover = await PixabayCoverService.shared.resolveCover(for: article) else { continue }
            if let index = articles.firstIndex(where: { $0.id == article.id }), articles[index].needsPixabayCover {
                articles[index].coverAsset = cover
            }
        }
    }
}
