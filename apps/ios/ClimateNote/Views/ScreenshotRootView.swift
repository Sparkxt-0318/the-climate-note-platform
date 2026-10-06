#if DEBUG
import Foundation
import SwiftUI

enum ScreenshotConfiguration {
    static let fixtureLocale = Locale(identifier: "en_US_POSIX")
    static let fixtureTimeZone = TimeZone(secondsFromGMT: 0)!
    static let fixtureCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = fixtureLocale
        calendar.timeZone = fixtureTimeZone
        calendar.firstWeekday = 1
        return calendar
    }()

    static var scene: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--climate-screenshot"), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    static var isIsolated: Bool {
        scene != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}

/// Native QA uses production content components. Fixtures are never inserted into live stores.
/// Interaction is disabled so a screenshot session cannot invoke authentication or mutate data.
struct ScreenshotRootView: View {
    let scene: String

    var body: some View {
        Group {
            switch scene {
            case "story":
                ScreenshotTabs(selectedTab: 0) { PushedStoryCapture(article: ScreenshotFixtures.article) }
            case "story-visual":
                ScreenshotTabs(selectedTab: 0) { PushedStoryVisualCapture(article: ScreenshotFixtures.article) }
            case "story-no-generation":
                ScreenshotTabs(selectedTab: 0) { PushedStoryCapture(article: ScreenshotFixtures.earlierArticle) }
            case "summary":
                ScreenshotPage(width: ClimateTheme.ContentWidth.reading) { SummaryView(summary: ScreenshotFixtures.summary) }
            case "actions", "action-selected", "reflection", "reflection-keyboard", "save-queued", "save-error", "save-synced":
                ScreenshotPage(width: ClimateTheme.ContentWidth.reading) {
                    ClimateActionPicker(
                        article: ScreenshotFixtures.article,
                        actions: ScreenshotFixtures.actions,
                        initialSelection: scene == "action-selected" ? ScreenshotFixtures.actions.first : nil,
                        initialCustomText: ["reflection", "reflection-keyboard", "save-queued", "save-error", "save-synced"].contains(scene)
                            ? "I’ll check our medicine cabinet and find a local take-back point." : "",
                        initialSaveState: saveState,
                        initialWritingFocus: scene == "reflection-keyboard",
                        captureAccountID: isSaveStateCapture ? "screenshot-user" : nil,
                        captureOperationID: isSaveStateCapture ? ScreenshotFixtures.captureOperationID : nil
                    )
                }
            case "progress", "journal-empty":
                ScreenshotTabs(selectedTab: 1) {
                    ScreenshotJournalPage {
                        JournalContent(logs: scene == "progress" ? ScreenshotFixtures.logs : [],
                                       allowsActions: false, referenceDate: ScreenshotFixtures.referenceDate)
                    }
                }
            case "impact-loading", "impact-threshold", "impact-populated", "impact-stale", "impact-error":
                ScreenshotPage(width: ClimateTheme.ContentWidth.reading) {
                    CommunityImpactScreenContent(presentation: impactPresentation)
                }
            case "journal-guest":
                ScreenshotTabs(selectedTab: 1) { NavigationStack { MyNoteView() } }
            case "account":
                ScreenshotTabs(selectedTab: 2) { NavigationStack { AccountView() } }
            case "privacy":
                NavigationStack { PrivacyView() }
            case "signin-unavailable", "signin":
                SignInView()
            case "feed-loading":
                ScreenshotTabs(selectedTab: 0) { ScreenshotChrome { FeedLoadingView() } }
            case "feed-refreshing":
                ScreenshotTabs(selectedTab: 0) {
                    ScreenshotPage {
                        FeedRetainedContent(articles: ScreenshotFixtures.articles, isRefreshing: true, errorMessage: nil)
                    }
                }
            case "feed-stale":
                ScreenshotTabs(selectedTab: 0) {
                    ScreenshotPage {
                        FeedRetainedContent(articles: ScreenshotFixtures.articles, isRefreshing: false, errorMessage: "Fixture refresh timeout")
                    }
                }
            case "feed-image-loading":
                ScreenshotTabs(selectedTab: 0) {
                    ScreenshotPage { FeedContent(articles: ScreenshotFixtures.imageLoadingArticles) }
                }
            case "feed-image-error":
                ScreenshotTabs(selectedTab: 0) {
                    ScreenshotPage { FeedContent(articles: ScreenshotFixtures.imageFailureArticles) }
                }
            case "feed-empty", "feed-error":
                ScreenshotTabs(selectedTab: 0) {
                    ScreenshotChrome {
                        FeedEmptyView(message: scene == "feed-error" ? "Fixture connection failure" : nil, retry: {})
                    }
                }
            default:
                ScreenshotTabs(selectedTab: 0) {
                    ScreenshotPage {
                        FeedContent(articles: ScreenshotFixtures.articles)
                    }
                }
            }
        }
        .environment(\.climateMotionEnabled, false)
        .environment(\.locale, ScreenshotConfiguration.fixtureLocale)
        .environment(\.calendar, ScreenshotConfiguration.fixtureCalendar)
        .environment(\.timeZone, ScreenshotConfiguration.fixtureTimeZone)
        .dynamicTypeSize(ProcessInfo.processInfo.arguments.contains("--climate-large-text") ? .accessibility3 : .large)
        .transaction { $0.disablesAnimations = true }
        .allowsHitTesting(false)
    }

    private var isSaveStateCapture: Bool {
        ["save-queued", "save-error", "save-synced"].contains(scene)
    }

    private var saveState: ReflectionSaveState? {
        switch scene {
        case "save-queued": .queued
        case "save-error": .failed
        case "save-synced": .synced
        default: nil
        }
    }

    private var impactPresentation: CommunityImpactPresentation {
        switch scene {
        case "impact-threshold": .threshold(ScreenshotFixtures.communityImpact(visible: false))
        case "impact-populated": .populated(ScreenshotFixtures.communityImpact(visible: true), isStale: false)
        case "impact-stale": .populated(ScreenshotFixtures.communityImpact(visible: true), isStale: true)
        case "impact-error": .error("Fixture community-impact connection failure")
        default: .loading
        }
    }
}

/// Reaches ArticleDetailView through the same value-based NavigationStack routing as FeedView.
/// This preserves the back affordance and the reader's actual entry context in native captures.
private struct PushedStoryCapture: View {
    let article: Article
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                FeedContent(articles: [article])
                    .padding(.horizontal, ClimateTheme.Spacing.large)
                    .padding(.top, ClimateTheme.Spacing.large)
                    .padding(.bottom, ClimateTheme.Spacing.xxLarge)
                    .frame(maxWidth: ClimateTheme.ContentWidth.feed)
                    .frame(maxWidth: .infinity)
            }
            .background { ClimateBackdrop() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { ClimateWordmark() } }
            .toolbarBackground(ClimateTheme.pine, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: Article.self) { ArticleDetailView(article: $0) }
        }
        .onAppear {
            guard path.isEmpty else { return }
            path.append(article)
        }
    }
}

/// Uses ArticleDetailView's production ScrollViewReader anchor to expose the story-local
/// image and caption below the introduction on a phone capture.
private struct PushedStoryVisualCapture: View {
    let article: Article
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                FeedContent(articles: [article])
                    .padding(.horizontal, ClimateTheme.Spacing.large)
                    .padding(.top, ClimateTheme.Spacing.large)
                    .padding(.bottom, ClimateTheme.Spacing.xxLarge)
                    .frame(maxWidth: ClimateTheme.ContentWidth.feed)
                    .frame(maxWidth: .infinity)
            }
            .background { ClimateBackdrop() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .principal) { ClimateWordmark() } }
            .toolbarBackground(ClimateTheme.pine, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: Article.self) {
                ArticleDetailView(article: $0, initialScrollTarget: .articleVisual)
            }
        }
        .onAppear {
            guard path.isEmpty else { return }
            path.append(article)
        }
    }
}

/// Mirrors MyNoteView's production width, horizontal padding, and bottom spacing.
private struct ScreenshotJournalPage<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScreenshotChrome {
            ScrollView {
                content()
                    .padding(ClimateTheme.Spacing.large)
                    .padding(.bottom, ClimateTheme.Spacing.large)
                    .frame(maxWidth: ClimateTheme.ContentWidth.reading, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct ScreenshotPage<Content: View>: View {
    let width: CGFloat
    let content: () -> Content

    init(
        width: CGFloat = ClimateTheme.ContentWidth.feed,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.width = width
        self.content = content
    }

    var body: some View {
        ScreenshotChrome {
            ScrollView {
                content()
                    .padding(.horizontal, ClimateTheme.Spacing.large)
                    .padding(.top, ClimateTheme.Spacing.large)
                    .padding(.bottom, ClimateTheme.Spacing.xxLarge)
                    .frame(maxWidth: width, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private struct ScreenshotChrome<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        NavigationStack {
            content()
                .background { ClimateBackdrop() }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .principal) { ClimateWordmark() } }
                .toolbarBackground(ClimateTheme.pine, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

private struct ScreenshotTabs<Content: View>: View {
    let selectedTab: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        TabView(selection: .constant(selectedTab)) {
            tab(0).tabItem { Label("Read", systemImage: "book.pages") }.tag(0)
            tab(1).tabItem { Label("My Note", systemImage: "book.closed") }.tag(1)
            tab(2).tabItem { Label("Account", systemImage: "person.crop.circle") }.tag(2)
        }
        .tint(ClimateTheme.mintBright)
        .toolbarBackground(ClimateTheme.pine, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .background(ClimateTheme.canvas)
    }

    @ViewBuilder private func tab(_ index: Int) -> some View {
        if selectedTab == index { content() } else { ClimateBackdrop() }
    }
}

private enum ScreenshotFixtures {
    static let referenceDate = ScreenshotConfiguration.fixtureCalendar.date(from: DateComponents(year: 2026, month: 9, day: 9, hour: 12))!
    static let captureOperationID = UUID(uuidString: "99B57C1A-327B-4A8A-9D3A-BDDF5EBB0E91")!
    static var articles: [Article] { [article, earlierArticle] }
    static let earlierArticle = Article(
        documentID: "fixture-materials", slug: "lignin-based-materials", title: "A different future for everyday materials",
        author: "The Climate Note", topic: "Materials",
        excerpt: "What plant cell walls can teach us about making the things we use every day.",
        status: "published", contentBlocks: [.paragraph("This is deterministic sample content for native visual QA.")],
        sourceLinks: [], externalLinks: nil, readingMinutes: 4,
        publishedAt: ScreenshotConfiguration.fixtureCalendar.date(from: DateComponents(year: 2026, month: 8, day: 30)),
        generation: nil, coverAsset: fixtureCover
    )
    static var imageLoadingArticles: [Article] { [articleWithCover(imageLoadingCover), earlierArticle] }
    static var imageFailureArticles: [Article] { [articleWithCover(imageFailureCover), earlierArticle] }
    static var logs: [ActionLog] {
        [
            ActionLog(documentID: "fixture-planned", userID: "fixture", articleID: article.id,
                      articleTitle: article.title, actionID: actions[0].id, title: actions[0].title,
                      detail: actions[0].instruction, category: "water", status: .planned,
                      createdAt: referenceDate, completedAt: nil, impactEstimate: nil),
            ActionLog(documentID: "fixture-completed", userID: "fixture", articleID: article.id,
                      articleTitle: article.title, actionID: actions[1].id, title: actions[1].title,
                      detail: actions[1].instruction, category: "learning", status: .completed,
                      createdAt: referenceDate.addingTimeInterval(-172800),
                      completedAt: referenceDate.addingTimeInterval(-86400),
                      impactEstimate: ImpactEstimate(
                        value: 3.2,
                        unit: "kg CO₂e",
                        label: "estimated CO₂e avoided",
                        methodology: "Fixture estimate for native visual QA.",
                        factorID: "passenger-vehicle-mile-avoided-us",
                        metric: "co2e",
                        factorVersion: "EPA-2023",
                        input: ImpactInput(quantity: 8, unit: "mile")
                      )),
            ActionLog(documentID: "fixture-reflection", userID: "fixture", articleID: article.id,
                      articleTitle: article.title, actionID: "custom", title: "A private reflection",
                      detail: "I’ll check our medicine cabinet and find a local take-back point.", category: "custom", status: .planned,
                      kind: .reflection, createdAt: referenceDate.addingTimeInterval(-3600), completedAt: nil, impactEstimate: nil)
        ]
    }

    static let summary = ClimateSummary(
        problem: "Medicines can pass through people, drains, and waste systems, leaving small traces in rivers and other waterways.",
        whyItMatters: "Even tiny amounts can affect fish and other wildlife over time, while many disposal systems were not designed to remove every compound.",
        whatWeCanDo: "Use an official medicine take-back location, follow local disposal guidance, and share safe options with your household."
    )

    static func communityImpact(visible: Bool) -> CommunityImpactDocument {
        CommunityImpactDocument(
            schemaVersion: 1,
            visible: visible,
            minimumContributors: 10,
            contributorCount: visible ? 42 : nil,
            eligibleActionCount: visible ? 187 : nil,
            estimatedKgCO2e: visible ? 1_260 : nil,
            updatedAt: visible ? referenceDate : nil,
            methodology: CommunityImpactMethodology(
                metric: "co2e",
                factorVersions: visible ? ["EPA-2023"] : [],
                description: "Estimates use supported completed actions and versioned factors."
            )
        )
    }

    static let actions = [
        SuggestedAction(
            id: "action-1",
            title: "Return unused medicine safely",
            instruction: "Bring one unused medication to a pharmacy or community take-back location this week.",
            cadence: "One trip this week",
            evidence: "Use a medicine take-back location.",
            category: "water",
            factorId: nil,
            factorQuantity: nil
        ),
        SuggestedAction(
            id: "action-2",
            title: "Check your local guidance",
            instruction: "Look up your city’s official medicine-disposal instructions and save the approved location.",
            cadence: "Ten minutes today",
            evidence: "Follow local disposal guidance.",
            category: "learning",
            factorId: nil,
            factorQuantity: nil
        ),
        SuggestedAction(
            id: "action-3",
            title: "Share one safe option",
            instruction: "Send your household the address of a verified medicine take-back location nearby.",
            cadence: "Share once this week",
            evidence: "Share safe disposal options.",
            category: "community",
            factorId: nil,
            factorQuantity: nil
        ),
    ]

    static let article = Article(
        documentID: "screenshot-pharmaceutical-pollution",
        slug: "pharmaceutical-pollution",
        title: "Pharmaceutical pollution",
        author: "The Climate Note",
        topic: "Water",
        excerpt: "Medicine protects our health—but traces that reach rivers can affect wildlife and water systems.",
        status: "published",
        contentBlocks: [
            .paragraph("Many people rely on medicine every day. After medication is used—or when unused medicine is discarded—some of its ingredients can enter wastewater and the wider environment."),
            .paragraph("Treatment systems remove many pollutants, but they were not built to catch every pharmaceutical compound. Researchers have detected traces in waterways around the world."),
            .heading(level: 2, text: "Small traces, real effects"),
            .paragraph("The amount may be small, yet long-term exposure can still affect aquatic life. Safe collection and careful disposal help keep unnecessary medicine out of drains and household waste."),
        ],
        sourceLinks: [],
        externalLinks: nil,
        readingMinutes: 5,
        publishedAt: ScreenshotConfiguration.fixtureCalendar.date(from: DateComponents(year: 2026, month: 9, day: 6)),
        generation: ArticleGeneration(
            summary: summary,
            suggestedActions: actions,
            visualPlan: VisualPlan(
                searchQuery: "pharmaceutical pollution river research",
                altText: "A river flowing through a green landscape near a community",
                placement: "after-introduction",
                generationPrompt: "Editorial photograph of a protected river landscape"
            )
        ),
        coverAsset: fixtureCover
    )

    static let fixtureCover = CoverAsset(
        url: URL(string: "climate-note-fixture://river")!,
        altText: "A calm river through a wooded landscape",
        caption: "Fixture image used only for deterministic native QA",
        attribution: "Bundled Climate Note asset",
        license: "Fixture-only bundled asset",
        sourceUrl: nil,
        generated: false
    )

    static let imageLoadingCover = CoverAsset(
        url: URL(string: "climate-note-fixture-loading://river")!,
        altText: "Story image loading",
        caption: "Fixture loading state",
        attribution: "",
        license: "Fixture-only",
        sourceUrl: nil,
        generated: false
    )

    static let imageFailureCover = CoverAsset(
        url: URL(string: "climate-note-fixture-missing://river")!,
        altText: "Story image unavailable",
        caption: "Fixture failure state",
        attribution: "",
        license: "Fixture-only",
        sourceUrl: nil,
        generated: false
    )

    static func articleWithCover(_ cover: CoverAsset) -> Article {
        Article(
            documentID: article.documentID, slug: article.slug, title: article.title, author: article.author,
            topic: article.topic, excerpt: article.excerpt, status: article.status,
            contentBlocks: article.contentBlocks, sourceLinks: article.sourceLinks,
            externalLinks: article.externalLinks, readingMinutes: article.readingMinutes,
            publishedAt: article.publishedAt, generation: article.generation, coverAsset: cover
        )
    }
}
#endif
