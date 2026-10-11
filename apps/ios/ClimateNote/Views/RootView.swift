import SwiftUI
import UIKit

/// A small, view-independent routing surface for notification and deep-link
/// hand-offs. Tabs retain their own navigation state; the router only asks for
/// a destination when an external event needs one.
@MainActor
final class AppRouter: ObservableObject {
    static let shared = AppRouter()

    @Published var selectedTab = ClimateTab.home.rawValue
    @Published private(set) var requestedArticleID: String?
    @Published private(set) var requestedArticleSlug: String?
    @Published private(set) var requestedJournalEntryID: String?
    @Published private(set) var composerArticleID: String?
    @Published private(set) var composerPrefill: String?
    @Published var selectedArticleID: String?

    func showHome() { selectedTab = ClimateTab.home.rawValue }
    func showExplore() { selectedTab = ClimateTab.explore.rawValue }
    func showWrite() { selectedTab = ClimateTab.write.rawValue }
    func showSaved() { selectedTab = ClimateTab.saved.rawValue }

    func showJournal(entryID: String? = nil) {
        selectedTab = ClimateTab.saved.rawValue
        requestedJournalEntryID = entryID
    }

    func showArticle(id: String, openingComposer: Bool = false, prefill: String? = nil) {
        selectedTab = ClimateTab.home.rawValue
        requestedArticleID = id
        requestedArticleSlug = nil
        selectedArticleID = id
        composerArticleID = openingComposer ? id : nil
        composerPrefill = prefill
    }

    func showArticle(slug: String, openingComposer: Bool = false, prefill: String? = nil) {
        selectedTab = ClimateTab.home.rawValue
        requestedArticleSlug = slug
        requestedArticleID = nil
        composerArticleID = openingComposer ? slug : nil
        composerPrefill = prefill
    }

    func consumeRequestedArticleID() -> String? {
        defer { requestedArticleID = nil }
        return requestedArticleID
    }

    func consumeRequestedArticleSlug() -> String? {
        defer { requestedArticleSlug = nil }
        return requestedArticleSlug
    }

    func consumeComposerRequest(for articleID: String) -> (opens: Bool, prefill: String?) {
        guard composerArticleID == articleID else { return (false, nil) }
        composerArticleID = nil
        let prefill = composerPrefill
        composerPrefill = nil
        return (true, prefill)
    }

    func clearJournalEntryRequest(_ entryID: String) {
        guard requestedJournalEntryID == entryID else { return }
        requestedJournalEntryID = nil
    }
}

@MainActor
struct RootView: View {
    @AppStorage("hasSeenClimateNoteWelcome") private var hasSeenWelcome = false
    @EnvironmentObject private var articleStore: ArticleStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var router = AppRouter.shared
    @State private var homePath: [Article] = []

    var body: some View {
        Group {
            if hasSeenWelcome {
                TabView(selection: $router.selectedTab) {
                    homeRoot
                        .tabItem { Label(ClimateTab.home.title, systemImage: ClimateTab.home.systemImage) }
                        .tag(ClimateTab.home.rawValue)
                    NavigationStack { ExploreView() }
                        .tabItem { Label(ClimateTab.explore.title, systemImage: ClimateTab.explore.systemImage) }
                        .tag(ClimateTab.explore.rawValue)
                    NavigationStack { ComposeNoteView() }
                        .tabItem { Label(ClimateTab.write.title, systemImage: ClimateTab.write.systemImage) }
                        .tag(ClimateTab.write.rawValue)
                    NavigationStack {
                        MyNoteView(
                            onRead: router.showHome,
                            requestedEntryID: router.requestedJournalEntryID,
                            articleIsAvailable: { id in articleStore.articles.contains { $0.id == id } },
                            onOpenArticle: { router.showArticle(id: $0) },
                            onWriteReflection: { log in
                                router.showArticle(
                                    id: log.articleID,
                                    openingComposer: true,
                                    prefill: reflectionPrefill(for: log)
                                )
                            },
                            onEntryRevealed: router.clearJournalEntryRequest
                        )
                    }
                        .tabItem { Label(ClimateTab.saved.title, systemImage: ClimateTab.saved.systemImage) }
                        .tag(ClimateTab.saved.rawValue)
                }
                .climateTabBarChrome()
                .onChange(of: router.requestedArticleID) { _, _ in routeRequestedArticle() }
                .onChange(of: router.requestedArticleSlug) { _, _ in routeRequestedArticle() }
                .onChange(of: articleStore.articles) { _, _ in routeRequestedArticle() }
                .onAppear { routeRequestedArticle() }
            } else {
                WelcomeView {
                    hasSeenWelcome = true
                    router.showHome()
                }
            }
        }
        .onOpenURL(perform: route)
    }

    @ViewBuilder private var homeRoot: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                FeedView(selectedArticleID: $router.selectedArticleID)
            } detail: {
                if let article = selectedArticle {
                    ArticleDetailView(article: article)
                } else {
                    ContentUnavailableView(
                        "Choose a story",
                        systemImage: "book.pages",
                        description: Text("Select an article to read it here.")
                    )
                    .background(Color.climatePaper.ignoresSafeArea())
                }
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            NavigationStack(path: $homePath) {
                FeedView()
                    .navigationDestination(for: Article.self) { ArticleDetailView(article: $0) }
            }
        }
    }

    private var selectedArticle: Article? {
        guard let selectedArticleID = router.selectedArticleID else { return nil }
        return articleStore.articles.first { $0.id == selectedArticleID }
    }

    private func routeRequestedArticle() {
        guard hasSeenWelcome else { return }
        let requestedID = router.requestedArticleID
        let requestedSlug = router.requestedArticleSlug
        guard let article = articleStore.articles.first(where: {
            $0.id == requestedID || $0.slug == requestedSlug
        }) else { return }

        router.selectedArticleID = article.id
        if horizontalSizeClass != .regular, homePath.last?.id != article.id {
            homePath.append(article)
        }
        if requestedID != nil { _ = router.consumeRequestedArticleID() }
        if requestedSlug != nil { _ = router.consumeRequestedArticleSlug() }
    }

    private func route(_ url: URL) {
        let parts = url.pathComponents.filter { $0 != "/" }
        let host = url.host?.lowercased()
        if host == "articles", let slug = parts.first {
            router.showArticle(slug: slug)
        } else if host == "saved" || host == "journal" {
            router.showJournal(entryID: parts.first)
        } else if let articleIndex = parts.firstIndex(of: "articles"), parts.indices.contains(articleIndex + 1) {
            router.showArticle(slug: parts[articleIndex + 1])
        } else if let journalIndex = parts.firstIndex(where: { $0 == "saved" || $0 == "journal" }) {
            let entryID = parts.indices.contains(journalIndex + 1) ? parts[journalIndex + 1] : nil
            router.showJournal(entryID: entryID)
        } else if url.host == "write" || parts.first == "write" {
            router.showWrite()
        } else if url.host == "explore" || parts.first == "explore" {
            router.showExplore()
        } else {
            router.showHome()
        }
    }

    private func reflectionPrefill(for log: ActionLog) -> String {
        let existing = log.reflectionText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let context = (existing?.isEmpty == false ? existing : log.detail)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return context.isEmpty ? "" : "“\(context)”\n\n"
    }
}

private struct WelcomeView: View {
    let continueToHome: () -> Void
    @State private var showSignIn = false

    var body: some View {
        ZStack {
            Image("ClimateHeroV2")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
            LinearGradient(
                colors: [Color.climateCanvas.opacity(0.08), Color.climateCanvas.opacity(0.42), Color.climateCanvas.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: max(32, proxy.size.height * 0.16))
                        VStack(spacing: 2) {
                            Text("THE")
                                .climateMetadata(weight: .bold)
                                .tracking(3.4)
                            HStack(alignment: .lastTextBaseline, spacing: 9) {
                                Text("climate note")
                                    .climateDisplay(48, relativeTo: .largeTitle)
                                    .fixedSize(horizontal: false, vertical: true)
                                Image(systemName: "leaf")
                                    .font(.system(size: 27, weight: .light))
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        Text("Real people. Real thoughts.\nA healthier planet.")
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.climateInk)
                            .lineSpacing(3)
                            .padding(.top, 16)
                        Button("Get Started", action: continueToHome)
                            .buttonStyle(ClimatePrimaryButtonStyle())
                            .padding(.top, 40)
                        Button("Log In") { showSignIn = true }
                            .buttonStyle(ClimateTextButtonStyle())
                            .padding(.top, 8)
                    }
                    .foregroundStyle(Color.climateInk)
                    .frame(minHeight: max(0, proxy.size.height - 30), alignment: .bottom)
                    .padding(.horizontal, ClimateLayout.phoneGutter)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
        }
        .sheet(isPresented: $showSignIn) { SignInView() }
    }
}

@MainActor
private struct ComposeNoteView: View {
    @EnvironmentObject private var store: ArticleStore
    @ObservedObject private var router = AppRouter.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: ClimateLayout.section) {
                WriteNotebookHero()

                if store.isLoading && store.articles.isEmpty {
                    ProgressView("Loading stories")
                        .tint(Color.climateSage)
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if store.articles.isEmpty {
                    ClimateStateNotice(
                        symbol: "square.and.pencil",
                        title: "Choose a story first",
                        message: store.errorMessage ?? "Published stories will appear here."
                    )
                } else {
                    VStack(alignment: .leading, spacing: ClimateLayout.element) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Choose a story")
                                    .climateEditorialDisplay(28, relativeTo: .title)
                                    .tracking(-0.35)
                                Text("Your note keeps the story attached for context.")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.climateMuted)
                            }
                            Spacer(minLength: ClimateLayout.compact)
                            Text("\(store.articles.count)")
                                .climateMetadata(weight: .bold)
                                .foregroundStyle(Color.climateSage)
                        }

                        ScrollView(.horizontal) {
                            LazyHStack(spacing: ClimateLayout.element) {
                                ForEach(store.articles) { article in
                                    Button {
                                        router.showArticle(id: article.id, openingComposer: true)
                                    } label: {
                                        ComposeStoryCard(article: article)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Write a private note for \(article.title)")
                                    .accessibilityHint("Opens the article note composer")
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollIndicators(.hidden)
                        .scrollTargetBehavior(.viewAligned)
                    }
                }
            }
            .climateContentWidth()
            .padding(.top, ClimateLayout.element)
            .padding(.bottom, ClimateLayout.majorSection)
        }
        .background(Color.climateCanvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct WriteNotebookHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PRIVATE NOTEBOOK")
                        .climateMetadata(weight: .bold)
                        .tracking(1.35)
                        .foregroundStyle(Color.climatePaperMuted)
                    Text("Write what\nstayed with you.")
                        .climateEditorialDisplay(37, relativeTo: .largeTitle)
                        .tracking(-0.6)
                        .foregroundStyle(Color.climatePaperInk)
                }
                Spacer(minLength: ClimateLayout.element)
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Color.climatePaperInk)
                    .frame(width: 52, height: 52)
                    .background(Color.climateSage.opacity(0.42), in: .circle)
                    .accessibilityHidden(true)
            }

            Text("Begin with a published story, then capture your own response. Notes are private by default.")
                .font(.body)
                .foregroundStyle(Color.climatePaperMuted)
                .lineSpacing(4)

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.caption.weight(.semibold))
                Text("Only you can see your note")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Color.climatePaperInk)
            .frame(minHeight: ClimateLayout.minimumTarget)
        }
        .padding(ClimateLayout.cardPadding)
        .background(Color.climatePaper, in: .rect(cornerRadius: 24))
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(Color.climateSage)
                .frame(width: 4)
                .padding(.vertical, 22)
        }
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.16), lineWidth: 1) }
    }
}

private struct ComposeStoryCard: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ClimateCoverImage(
                url: article.coverAsset?.url,
                altText: article.coverAsset?.altText ?? "Cover for \(article.title)",
                assetName: ClimateLocalArt.assetName(for: article)
            )
            .frame(width: 252, height: 146)
            .clipped()
            .overlay(alignment: .topLeading) {
                Text(article.topic.isEmpty ? "CLIMATE" : article.topic.uppercased())
                    .climateMetadata(weight: .bold)
                    .tracking(0.9)
                    .foregroundStyle(Color.climateInk)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.climateCanvas.opacity(0.82), in: .capsule)
                    .padding(12)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(article.title)
                    .climateEditorialDisplay(22, relativeTo: .title3)
                    .tracking(-0.25)
                    .foregroundStyle(Color.climateInk)
                    .lineLimit(3)
                Spacer(minLength: 0)
                HStack {
                    Text("Open notebook")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.bold))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(Color.climateSage)
            }
            .frame(width: 252, alignment: .leading)
            .frame(minHeight: 142, alignment: .topLeading)
            .padding(ClimateLayout.element)
            .background(Color.climateSurfaceRaised)
        }
        .clipShape(.rect(cornerRadius: ClimateRadius.card))
        .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }
        .contentShape(.rect(cornerRadius: ClimateRadius.card))
    }
}

private struct ExploreView: View {
    @EnvironmentObject private var store: ArticleStore
    @State private var query = ""

    private var results: [Article] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return store.articles }
        return store.articles.filter {
            $0.title.localizedCaseInsensitiveContains(trimmed) ||
            $0.excerpt.localizedCaseInsensitiveContains(trimmed) ||
            $0.topic.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var isFiltering: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var archiveResults: [Article] {
        isFiltering ? results : Array(results.dropFirst())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClimateLayout.section) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("DISCOVER")
                        .climateMetadata(weight: .bold)
                        .tracking(1.5)
                        .foregroundStyle(Color.climateSage)
                    Text("Explore")
                        .climateDiscoveryDisplay(42, relativeTo: .largeTitle, weight: .bold)
                        .tracking(-0.8)
                        .foregroundStyle(Color.climateInk)
                    Text("Search the archive or follow a story that catches your eye.")
                        .font(.body)
                        .foregroundStyle(Color.climateMuted)
                        .lineSpacing(3)
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.climateSage)
                        .accessibilityHidden(true)
                    TextField("Search by title, topic, or idea", text: $query)
                        .font(.body)
                        .foregroundStyle(Color.climateInk)
                        .tint(Color.climateSage)
                        .submitLabel(.search)
                        .accessibilityLabel("Search climate articles")
                    if !query.isEmpty {
                        Button { query = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.climateMuted)
                                .frame(width: ClimateLayout.minimumTarget, height: ClimateLayout.minimumTarget)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.leading, 16)
                .padding(.trailing, query.isEmpty ? 16 : 6)
                .frame(minHeight: 58)
                .background(Color.climateSurfaceRaised, in: .rect(cornerRadius: ClimateRadius.control))
                .overlay { RoundedRectangle(cornerRadius: ClimateRadius.control).stroke(Color.climateRule, lineWidth: 1) }

                if store.isLoading {
                    ProgressView("Loading articles")
                        .tint(Color.climateSage)
                        .foregroundStyle(Color.climateMuted)
                        .frame(maxWidth: .infinity, minHeight: 170)
                } else if let message = store.errorMessage, results.isEmpty {
                    VStack(alignment: .leading, spacing: ClimateLayout.element) {
                        ClimateStateNotice(
                            symbol: "wifi.exclamationmark",
                            title: "Archive unavailable",
                            message: message
                        )
                        Button("Try again", action: store.retry)
                            .buttonStyle(ClimatePrimaryButtonStyle())
                    }
                    .padding(.top, ClimateLayout.section)
                } else if results.isEmpty {
                    ClimateStateNotice(
                        symbol: query.isEmpty ? "book.closed" : "magnifyingglass",
                        title: query.isEmpty ? "No articles yet" : "No matching notes",
                        message: query.isEmpty ? "The first story will appear here soon." : "Try a different title or topic."
                    )
                } else {
                    if !isFiltering, let featured = results.first {
                        VStack(alignment: .leading, spacing: ClimateLayout.element) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("Start here")
                                    .climateDiscoveryDisplay(24, relativeTo: .title2)
                                Spacer()
                                Text("EDITOR'S PICK")
                                    .climateMetadata(weight: .bold)
                                    .tracking(1)
                                    .foregroundStyle(Color.climateSage)
                            }
                            NavigationLink(value: featured) {
                                ExploreFeatureCard(article: featured)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !archiveResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(isFiltering ? "Search results" : "Browse the archive")
                                    .climateDiscoveryDisplay(25, relativeTo: .title2)
                                Spacer()
                                Text("\(archiveResults.count) \(archiveResults.count == 1 ? "NOTE" : "NOTES")")
                                    .climateMetadata(weight: .bold)
                                    .foregroundStyle(Color.climateMuted)
                            }
                            ForEach(archiveResults) { article in
                                NavigationLink(value: article) {
                                    EditorialArticleRow(article: article, thumbnailSize: CGSize(width: 92, height: 92))
                                }
                                .buttonStyle(.plain)
                                ClimateRule()
                            }
                        }
                    }
                }
            }
            .climateContentWidth()
            .padding(.top, ClimateLayout.element)
            .padding(.bottom, ClimateLayout.majorSection)
        }
        .background(Color.climateCanvas.ignoresSafeArea())
        .navigationDestination(for: Article.self) { ArticleDetailView(article: $0) }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct ExploreFeatureCard: View {
    let article: Article

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ClimateCoverImage(
                url: article.coverAsset?.url,
                altText: article.coverAsset?.altText ?? "Cover for \(article.title)",
                assetName: ClimateLocalArt.assetName(for: article)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 248)
            .clipped()

            LinearGradient(
                colors: [.clear, Color.climateCanvas.opacity(0.48), Color.climateCanvas.opacity(0.98)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(article.topic.isEmpty ? "CLIMATE" : article.topic.uppercased())
                    .climateMetadata(weight: .bold)
                    .tracking(1)
                    .foregroundStyle(Color.climateSage)
                Text(article.title)
                    .climateEditorialDisplay(29, relativeTo: .title2)
                    .tracking(-0.35)
                    .foregroundStyle(Color.climateInk)
                    .lineLimit(3)
                HStack {
                    Text("\(article.readingMinutes) min read")
                        .climateMetadata()
                        .foregroundStyle(Color.climateMuted)
                    Spacer()
                    Label("Read story", systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.climateSage)
                }
            }
            .padding(ClimateLayout.cardPadding)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 248)
        .clipShape(.rect(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.18), lineWidth: 1) }
        .contentShape(.rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}
