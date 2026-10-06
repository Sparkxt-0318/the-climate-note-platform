import SwiftUI

/// Keeps a saved note and its source story connected while each tab retains its own stack.
/// Notification responses route through the same object instead of depending on SwiftUI views.
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var selectedTab = 0
    @Published private(set) var requestedJournalEntryID: String?
    @Published private(set) var requestedArticleID: String?
    @Published private(set) var composerArticleID: String?
    @Published private(set) var composerPrefill: String?
    @Published var selectedArticleID: String?

    func showRead() { selectedTab = 0 }

    func showJournal(entryID: String? = nil) {
        selectedTab = 1
        requestedJournalEntryID = entryID
    }

    func showArticle(id: String, openingComposer: Bool = false, prefill: String? = nil) {
        selectedTab = 0
        requestedArticleID = id
        selectedArticleID = id
        composerArticleID = openingComposer ? id : nil
        composerPrefill = prefill
    }

    func consumeRequestedArticleID() -> String? {
        defer { requestedArticleID = nil }
        return requestedArticleID
    }

    func consumeComposerRequest(for articleID: String) -> (opens: Bool, prefill: String?) {
        guard composerArticleID == articleID else { return (false, nil) }
        composerArticleID = nil
        let text = composerPrefill
        composerPrefill = nil
        return (true, text)
    }

    func clearJournalEntryRequest(_ entryID: String) {
        guard requestedJournalEntryID == entryID else { return }
        requestedJournalEntryID = nil
    }
}

@MainActor
struct RootView: View {
    @EnvironmentObject private var articleStore: ArticleStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var router = AppRouter.shared
    @State private var readPath: [Article] = []

    var body: some View {
        TabView(selection: $router.selectedTab) {
            readRoot
                .tabItem { Label("Read", systemImage: "book.pages") }
                .tag(0)

            NavigationStack {
                MyNoteView(
                    onRead: router.showRead,
                    requestedEntryID: router.requestedJournalEntryID,
                    articleIsAvailable: { id in articleStore.articles.contains { $0.id == id } },
                    onOpenArticle: { router.showArticle(id: $0) },
                    onWriteReflection: { router.showArticle(id: $0.articleID, openingComposer: true) },
                    onEntryRevealed: router.clearJournalEntryRequest
                )
            }
            .tabItem { Label("My Note", systemImage: "book.closed") }
            .tag(1)

            NavigationStack { AccountView() }
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
                .tag(2)
        }
        .tint(ClimateTheme.mintBright)
        .toolbarBackground(ClimateTheme.pine, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .background(ClimateTheme.canvas)
        .sensoryFeedback(.selection, trigger: router.selectedTab)
        .onChange(of: router.requestedArticleID) { _, _ in routeRequestedArticle() }
        .onChange(of: articleStore.articles) { _, _ in routeRequestedArticle() }
    }

    @ViewBuilder private var readRoot: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                FeedView(selectedArticleID: $router.selectedArticleID)
            } detail: {
                NavigationStack {
                    if let article = articleStore.articles.first(where: { $0.id == router.selectedArticleID }) {
                        ArticleDetailView(article: article)
                    } else {
                        ContentUnavailableView(
                            "Choose a note",
                            systemImage: "book.pages",
                            description: Text("Select a story from the list to read it here.")
                        )
                        .background { ClimateBackdrop() }
                    }
                }
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationStack(path: $readPath) {
                FeedView()
            }
        }
    }

    private func routeRequestedArticle() {
        guard let articleID = router.requestedArticleID,
              let article = articleStore.articles.first(where: { $0.id == articleID }) else { return }
        router.selectedArticleID = article.id
        if horizontalSizeClass != .regular, readPath.last?.id != article.id {
            readPath.append(article)
        }
        _ = router.consumeRequestedArticleID()
    }
}
