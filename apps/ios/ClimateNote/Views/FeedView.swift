import SwiftUI
import UIKit

@MainActor
struct FeedView: View {
    @EnvironmentObject private var store: ArticleStore
    @EnvironmentObject private var readingSession: ReadingSessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding private var selectedArticleID: String?
    @State private var leadIsNew = false
    @State private var didRecordFeedVisit = false

    init(selectedArticleID: Binding<String?> = .constant(nil)) {
        _selectedArticleID = selectedArticleID
    }

    private var usesSplitSelection: Bool { horizontalSizeClass == .regular }

    var body: some View {
        Group {
            if !store.articles.isEmpty {
                ScrollView {
                    FeedRetainedContent(
                        articles: store.articles,
                        isRefreshing: store.isRefreshing,
                        errorMessage: store.errorMessage,
                        retry: store.retry,
                        leadIsNew: leadIsNew,
                        showFirstLaunchTip: readingSession.showFirstLaunchTip,
                        selectedTopic: $readingSession.selectedTopic,
                        topics: readingSession.topics(from: store.articles),
                        archive: readingSession.filteredArchive(from: store.articles),
                        selectedArticleID: $selectedArticleID,
                        usesSplitSelection: usesSplitSelection,
                        onDismissTip: readingSession.dismissFirstLaunchTip
                    )
                    .climateContentWidth()
                    .padding(.top, 12)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.automatic)
                .refreshable { try? await store.refresh() }
            } else if store.isLoading || store.isRefreshing {
                FeedLoadingView()
            } else {
                FeedEmptyView(message: store.errorMessage, retry: store.retry)
            }
        }
        .background(Color.climateCanvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: Article.self) { ArticleDetailView(article: $0) }
        .animation(reduceMotion ? nil : ClimateMotion.content, value: store.isLoading)
        .onAppear(perform: recordFeedVisitIfNeeded)
        .onChange(of: store.articles.map(\.id)) { _, _ in recordFeedVisitIfNeeded() }
    }

    private func recordFeedVisitIfNeeded() {
        guard !didRecordFeedVisit, let lead = store.articles.first else { return }
        leadIsNew = readingSession.isNewLead(lead)
        didRecordFeedVisit = true
        readingSession.recordFeedVisit()
    }
}

/// Keeps good cached content visible while the next refresh is pending or fails.
struct FeedRetainedContent: View {
    let articles: [Article]
    let isRefreshing: Bool
    let errorMessage: String?
    var retry: () -> Void = {}
    var leadIsNew = false
    var showFirstLaunchTip = false
    var selectedTopic: Binding<String?> = .constant(nil)
    var topics: [String] = []
    var archive: [Article] = []
    var selectedArticleID: Binding<String?> = .constant(nil)
    var usesSplitSelection = false
    var onDismissTip: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.element) {
            if isRefreshing {
                Label("Updating notes", systemImage: "arrow.clockwise")
                    .climateMetadata(weight: .semibold)
                    .foregroundStyle(Color.climateMuted)
                    .frame(minHeight: ClimateLayout.minimumTarget)
                    .accessibilityLabel("Updating notes")
            }

            if let errorMessage {
                FeedStatusNotice(message: errorMessage, retry: retry, isRefreshing: isRefreshing)
            }

            FeedContent(
                articles: articles,
                leadIsNew: leadIsNew,
                showFirstLaunchTip: showFirstLaunchTip,
                selectedTopic: selectedTopic,
                topics: topics,
                archive: archive.isEmpty && selectedTopic.wrappedValue == nil ? Array(articles.dropFirst()) : archive,
                selectedArticleID: selectedArticleID,
                usesSplitSelection: usesSplitSelection,
                onDismissTip: onDismissTip
            )
        }
    }
}

/// The production feed composition also drives deterministic preview fixtures.
struct FeedContent: View {
    let articles: [Article]
    var leadIsNew = false
    var showFirstLaunchTip = false
    var selectedTopic: Binding<String?> = .constant(nil)
    var topics: [String] = []
    var archive: [Article]? = nil
    var selectedArticleID: Binding<String?> = .constant(nil)
    var usesSplitSelection = false
    var onDismissTip: () -> Void = {}

    private var archiveArticles: [Article] { archive ?? Array(articles.dropFirst()) }

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            FeedMasthead()
                .padding(.bottom, ClimateLayout.section)

            if showFirstLaunchTip {
                FeedTip(onDismiss: onDismissTip)
                    .padding(.bottom, ClimateLayout.section)
            }

            if let lead = articles.first {
                articleLink(lead) {
                    FeaturedArticleCard(article: lead, isNew: leadIsNew)
                }
                .accessibilityLabel(leadIsNew ? "New article. \(lead.title)" : "Read \(lead.title)")
                .accessibilityHint("Opens the article")
            }

            if articles.count > 1 {
                VStack(alignment: .leading, spacing: ClimateLayout.element) {
                    ClimateSectionHeader("Earlier notes", eyebrow: "Archive")

                    if !topics.isEmpty {
                        topicFilters
                    }

                    if archiveArticles.isEmpty {
                        Text("No notes in this topic.")
                            .font(.body)
                            .foregroundStyle(Color.climateMuted)
                            .padding(.vertical, ClimateLayout.element)
                    } else {
                        ForEach(archiveArticles) { article in
                            articleLink(article) {
                                EditorialArticleRow(article: article)
                            }
                            .accessibilityLabel("Read \(article.title)")
                            ClimateRule()
                        }
                    }
                }
                .padding(.top, ClimateLayout.majorSection)
            }
        }
    }

    private var topicFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ClimateLayout.compact) {
                topicChip("All", isSelected: selectedTopic.wrappedValue == nil) {
                    selectedTopic.wrappedValue = nil
                }
                ForEach(topics, id: \.self) { topic in
                    topicChip(topic, isSelected: selectedTopic.wrappedValue == topic) {
                        selectedTopic.wrappedValue = topic
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityLabel("Filter by topic")
    }

    @ViewBuilder
    private func articleLink<Label: View>(_ article: Article, @ViewBuilder label: () -> Label) -> some View {
        if usesSplitSelection {
            Button {
                selectedArticleID.wrappedValue = article.id
            } label: {
                label()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .leading) {
                        if selectedArticleID.wrappedValue == article.id {
                            Capsule()
                                .fill(Color.climateSage)
                                .frame(width: 4)
                                .padding(.vertical, ClimateLayout.compact)
                        }
                    }
            }
            .buttonStyle(ClimateArticleButtonStyle())
        } else {
            NavigationLink(value: article) { label() }
                .buttonStyle(ClimateArticleButtonStyle())
        }
    }

    private func topicChip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.climatePaperInk : Color.climateInk)
                .padding(.horizontal, 14)
                .frame(minHeight: ClimateLayout.minimumTarget)
                .background(isSelected ? Color.climateSage : Color.climateSurfaceRaised, in: .capsule)
                .overlay {
                    Capsule().stroke(isSelected ? Color.clear : Color.climateRule, lineWidth: 1)
                }
        }
        .buttonStyle(ClimateArticleButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct FeedMasthead: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                NavigationLink { EditorialIntroductionView() } label: {
                    HStack(spacing: 7) {
                        Text("The Climate Note")
                            .climateDisplay(22, relativeTo: .headline)
                        Image(systemName: "feather")
                            .font(.system(size: 17, weight: .light))
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(Color.climateInk)
                    .frame(minHeight: ClimateLayout.minimumTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("About The Climate Note")

                Spacer()

                NavigationLink { AccountView() } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(Color.climateMuted)
                        .frame(width: ClimateLayout.minimumTarget, height: ClimateLayout.minimumTarget)
                }
                .accessibilityLabel("Profile and settings")
            }

            Text("Read")
                .climateDisplay(40, relativeTo: .largeTitle)
                .foregroundStyle(Color.climateInk)
            Text("Clear climate stories, one note at a time.")
                .font(.body)
                .foregroundStyle(Color.climateMuted)
        }
    }
}

private struct FeedTip: View {
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Color.climateSage)
                .frame(width: ClimateLayout.minimumTarget, height: ClimateLayout.minimumTarget)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("A place to begin")
                    .font(.subheadline.weight(.semibold))
                Text("Open a story, then save a private note when you are ready.")
                    .font(.subheadline)
                    .foregroundStyle(Color.climateMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button("Got it", action: onDismiss)
                .buttonStyle(ClimateTextButtonStyle())
                .accessibilityLabel("Dismiss reading tip")
        }
        .padding(ClimateLayout.element)
        .background(Color.climateSurfaceRaised, in: .rect(cornerRadius: ClimateRadius.card))
        .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }
    }
}

private struct FeedStatusNotice: View {
    let message: String
    let retry: () -> Void
    let isRefreshing: Bool

    var body: some View {
        HStack(alignment: .center, spacing: ClimateLayout.element) {
            Image(systemName: "wifi.exclamationmark")
                .foregroundStyle(Color.climateSage)
                .frame(width: ClimateLayout.minimumTarget, height: ClimateLayout.minimumTarget)
                .accessibilityHidden(true)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.climateInk)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button("Retry", action: retry)
                .buttonStyle(ClimateTextButtonStyle())
                .disabled(isRefreshing)
        }
        .padding(.horizontal, ClimateLayout.element)
        .padding(.vertical, 10)
        .background(Color.climateSurfaceRaised, in: .rect(cornerRadius: ClimateRadius.control))
        .overlay { RoundedRectangle(cornerRadius: ClimateRadius.control).stroke(Color.climateRule, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}

private struct EditorialIntroductionView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("A note for a\nchanging world.")
                    .climateDisplay(44, relativeTo: .largeTitle)
                    .foregroundStyle(Color.climatePaperInk)
                    .padding(.top, 28)
                Text("Context for what is changing and what we can do next.")
                    .font(.body)
                    .foregroundStyle(Color.climatePaperMuted)
                    .lineSpacing(4)
                    .padding(.top, 14)
                ClimatePaperRule().padding(.vertical, 24)
                Text("The Climate Note is a space for clear information, open conversation, and practical action. Progress starts with paying attention.")
                    .font(.climateBody)
                    .foregroundStyle(Color.climatePaperInk)
                    .lineSpacing(7)
                Button("Browse stories") { dismiss() }
                    .buttonStyle(ClimatePaperButtonStyle())
                    .padding(.top, 28)
            }
            .frame(maxWidth: ClimateLayout.readerMaxWidth, alignment: .leading)
            .padding(.horizontal, ClimateLayout.phoneGutter)
            .padding(.bottom, 54)
            .frame(maxWidth: .infinity)
        }
        .background(Color.climatePaper.ignoresSafeArea())
        .navigationTitle("The Climate Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.climateCanvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }
}

private struct ClimatePaperButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.climateInk.opacity(isEnabled ? 1 : 0.55))
            .frame(maxWidth: .infinity, minHeight: ClimateLayout.controlHeight)
            .background(Color.climatePaperInk.opacity(isEnabled ? (configuration.isPressed ? 0.82 : 1) : 0.42), in: .rect(cornerRadius: ClimateRadius.control))
            .scaleEffect(isEnabled && configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .animation(reduceMotion ? nil : ClimateMotion.press, value: configuration.isPressed)
    }
}

private struct FeaturedArticleCard: View {
    let article: Article
    var isNew = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                EditorialCoverImage(article: article, height: dynamicTypeSize.isAccessibilitySize ? 188 : 232)
                LinearGradient(
                    colors: [.clear, Color.climateCanvas.opacity(0.60)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                HStack(spacing: 7) {
                    Text(article.topic.isEmpty ? "Climate" : article.topic)
                    if isNew { Text("New") }
                }
                .climateMetadata(weight: .bold)
                .tracking(0.8)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(Color.climateInk)
                .background(Color.climateCanvas.opacity(0.78), in: .capsule)
                .padding(ClimateLayout.element)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(article.title)
                    .climateDisplay(29, relativeTo: .title2)
                    .foregroundStyle(Color.climateInk)
                    .multilineTextAlignment(.leading)
                Text(article.excerpt)
                    .font(.subheadline)
                    .foregroundStyle(Color.climateInk.opacity(0.88))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 3)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 7) {
                        Text("By \(article.displayAuthor) · \(article.readingMinutes) min read")
                        Spacer()
                        readCue
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("By \(article.displayAuthor) · \(article.readingMinutes) min read")
                        readCue
                    }
                }
                .climateMetadata()
                .foregroundStyle(Color.climateMuted)
            }
            .padding(ClimateLayout.cardPadding)
            .background(Color.climateSurfaceRaised)
        }
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: ClimateRadius.card))
        .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.white.opacity(0.14), lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }

    private var readCue: some View {
        Label("Read", systemImage: "arrow.right")
            .fontWeight(.semibold)
            .foregroundStyle(Color.climateSage)
            .accessibilityHidden(true)
    }
}

struct EditorialArticleRow: View {
    let article: Article
    var thumbnailSize = CGSize(width: 88, height: 88)

    var body: some View {
        HStack(spacing: 16) {
            EditorialCoverImage(article: article, height: thumbnailSize.height)
                .frame(width: thumbnailSize.width, height: thumbnailSize.height)
                .clipShape(.rect(cornerRadius: ClimateRadius.image))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(article.topic.isEmpty ? "Climate" : article.topic)
                    .climateMetadata(weight: .semibold)
                    .foregroundStyle(Color.climateSage)
                    .lineLimit(1)
                Text(article.title)
                    .climateDisplay(22, relativeTo: .headline)
                    .foregroundStyle(Color.climateInk)
                    .lineLimit(2)
                Text("\(article.publishedAt?.formatted(.dateTime.month(.abbreviated).day().year()) ?? "This week") · \(article.readingMinutes) min read")
                    .climateMetadata()
                    .foregroundStyle(Color.climateMuted.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.climateSage)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 14)
        .contentShape(.rect)
    }
}

/// Covers always have a bounded local rendering: bundled assets win, a verified
/// remote cover is used next, then topic-specific signature art fills the slot.
struct EditorialCoverImage: View {
    let article: Article
    let height: CGFloat
    var compact = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            if let assetName = localAssetName, let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: height)
                    .clipped()
                    .accessibilityLabel(altText)
            } else if let url = remoteURL {
                AsyncImage(url: url, transaction: Transaction(animation: reduceMotion ? nil : ClimateMotion.content)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: height)
                            .clipped()
                            .accessibilityLabel(altText)
                    case .empty:
                        EditorialImagePlaceholder()
                    default:
                        SignatureCoverArt(topic: article.topic, title: article.title, height: height, compact: compact)
                    }
                }
            } else {
                SignatureCoverArt(topic: article.topic, title: article.title, height: height, compact: compact)
            }
        }
        .frame(height: height)
        .clipped()
    }

    private var localAssetName: String? {
        if let cover = article.coverAsset, let bundled = BundledCoverCatalog.assetName(from: cover.url) {
            return bundled
        }
        return article.coverAsset == nil ? ClimateLocalArt.assetName(for: article) : nil
    }

    private var remoteURL: URL? {
        guard let url = article.coverAsset?.url, url.scheme != "climate-note-asset" else { return nil }
        return url
    }

    private var altText: String {
        article.coverAsset?.altText ?? "Cover image for \(article.title)"
    }
}

private struct EditorialImagePlaceholder: View {
    var body: some View {
        ProgressView()
            .tint(Color.climateSage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.climateSurfaceRaised)
            .accessibilityLabel("Loading cover image")
    }
}

/// Deterministic topic art, used only when a supplied image cannot be shown.
struct SignatureCoverArt: View {
    let topic: String
    let title: String
    let height: CGFloat
    var compact = false

    private var seed: UInt {
        (topic + title).unicodeScalars.reduce(17) { ($0 &* 31) &+ UInt($1.value) }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: palette,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Color.climateSage.opacity(0.24))
                    .frame(width: max(72, geometry.size.width * 0.62))
                    .offset(x: geometry.size.width * 0.26, y: -height * 0.23)
                Circle()
                    .stroke(Color.climateInk.opacity(0.18), lineWidth: compact ? 1 : 2)
                    .frame(width: max(62, geometry.size.width * 0.52))
                    .offset(x: -geometry.size.width * 0.24, y: height * 0.24)
                Image(systemName: symbol)
                    .font(.system(size: compact ? 21 : 46, weight: .light))
                    .foregroundStyle(Color.climateInk.opacity(0.7))
            }
            .frame(width: geometry.size.width, height: height)
        }
        .frame(height: height)
        .accessibilityLabel("Illustrated cover for \(title)")
    }

    private var symbol: String {
        ["leaf", "drop", "sun.max", "wind", "tree", "mountain.2"][Int(seed % 6)]
    }

    private var palette: [Color] {
        switch seed % 4 {
        case 0: [Color(red: 0.10, green: 0.29, blue: 0.25), Color(red: 0.03, green: 0.10, blue: 0.09)]
        case 1: [Color(red: 0.17, green: 0.34, blue: 0.30), Color(red: 0.08, green: 0.18, blue: 0.17)]
        case 2: [Color(red: 0.16, green: 0.25, blue: 0.31), Color(red: 0.05, green: 0.12, blue: 0.15)]
        default: [Color(red: 0.26, green: 0.31, blue: 0.22), Color(red: 0.08, green: 0.16, blue: 0.13)]
        }
    }
}

private struct ClimateArticleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.995 : 1)
            .animation(reduceMotion ? nil : ClimateMotion.press, value: configuration.isPressed)
    }
}

private struct FeedLoadingView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClimateLayout.element) {
                FeedMasthead()
                RoundedRectangle(cornerRadius: ClimateRadius.card)
                    .fill(Color.climateSurfaceRaised)
                    .frame(height: 232)
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: 16) {
                        RoundedRectangle(cornerRadius: ClimateRadius.image)
                            .fill(Color.climateSurfaceRaised)
                            .frame(width: 88, height: 88)
                        VStack(alignment: .leading, spacing: 8) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.climateSurfaceRaised).frame(height: 14)
                            RoundedRectangle(cornerRadius: 4).fill(Color.climateSurfaceRaised.opacity(0.7)).frame(width: 160, height: 12)
                        }
                    }
                    ClimateRule()
                }
            }
            .redacted(reason: .placeholder)
            .climateContentWidth()
            .padding(.top, 12)
        }
        .accessibilityLabel("Loading notes")
    }
}

private struct FeedEmptyView: View {
    let message: String?
    let retry: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClimateLayout.section) {
                FeedMasthead()
                ClimateStateNotice(
                    symbol: message == nil ? "book.closed" : "wifi.exclamationmark",
                    title: message == nil ? "No notes yet" : "Could not load notes",
                    message: message ?? "New stories will appear here."
                )
                Button(message == nil ? "Check again" : "Try again", action: retry)
                    .buttonStyle(ClimatePrimaryButtonStyle())
            }
            .climateContentWidth()
            .padding(.top, 12)
        }
    }
}
