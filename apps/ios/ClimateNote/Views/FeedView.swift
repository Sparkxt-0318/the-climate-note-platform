import Foundation
import SwiftUI
import UIKit
    @EnvironmentObject private var store: ArticleStore
    @EnvironmentObject private var readingSession: ReadingSessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var selectedArticleID: String?
    @State private var leadIsNew = false
    @State private var didEvaluateLeadNovelty = false

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
                    .padding(.horizontal, ClimateTheme.Spacing.large)
                    .padding(.top, ClimateTheme.Spacing.large)
                    .padding(.bottom, ClimateTheme.Spacing.xxLarge)
                    .frame(maxWidth: ClimateTheme.ContentWidth.feed)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.automatic)
            } else if store.isLoading || store.isRefreshing {
                FeedLoadingView()
            } else {
                FeedEmptyView(message: store.errorMessage, retry: { store.retry() })
            }
        }
        .animation(reduceMotion ? nil : ClimateTheme.Motion.standardState, value: store.isLoading)
        .background { ClimateBackdrop() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { ClimateWordmark() } }
        .toolbarBackground(ClimateTheme.pine, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .navigationDestination(for: Article.self) { ArticleDetailView(article: $0) }
        .refreshable { try? await store.refresh() }
        .onAppear { evaluateLeadNoveltyIfNeeded() }
        .onChange(of: store.articles.map(\.id)) { _, _ in evaluateLeadNoveltyIfNeeded() }
    }

    private func evaluateLeadNoveltyIfNeeded() {
        guard let lead = store.articles.first else { return }
        if !didEvaluateLeadNovelty {
            leadIsNew = readingSession.isNewLead(lead)
            didEvaluateLeadNovelty = true
            readingSession.recordFeedVisit()
        }
    }
}

/// The retained-feed state is shared with deterministic screenshot fixtures.
struct FeedRetainedContent: View {
    let articles: [Article]
    let isRefreshing: Bool
    let errorMessage: String?
    var retry: () -> Void = {}
    var leadIsNew: Bool = false
    var showFirstLaunchTip: Bool = false
    var selectedTopic: Binding<String?> = .constant(nil)
    var topics: [String] = []
    var archive: [Article] = []
    var selectedArticleID: Binding<String?> = .constant(nil)
    var usesSplitSelection: Bool = false
    var onDismissTip: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
            if isRefreshing {
                HStack(spacing: ClimateTheme.Spacing.small) {
                    ProgressView().tint(ClimateTheme.accent)
                    Text("Checking for newer notes")
                        .font(ClimateTheme.Typography.subheadline)
                        .foregroundStyle(ClimateTheme.secondaryInk)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Checking for newer notes")
            }
            if let errorMessage {
                VStack(alignment: .leading, spacing: ClimateTheme.Spacing.small) {
                    ClimateInlineStatus(message: errorMessage, kind: .warning)
                    Button("Try again", action: retry)
                        .buttonStyle(ClimateSecondaryButtonStyle())
                        .disabled(isRefreshing)
                }
            }
            FeedContent(
                articles: articles,
                leadIsNew: leadIsNew,
                showFirstLaunchTip: showFirstLaunchTip,
                selectedTopic: selectedTopic,
                topics: topics,
                archive: archive.isEmpty && selectedTopic.wrappedValue == nil
                    ? Array(articles.dropFirst())
                    : archive,
                selectedArticleID: selectedArticleID,
                usesSplitSelection: usesSplitSelection,
                onDismissTip: onDismissTip
            )
        }
    }
}

/// Production feed composition, also used by deterministic screenshot fixtures.
struct FeedContent: View {
    let articles: [Article]
    var leadIsNew: Bool = false
    var showFirstLaunchTip: Bool = false
    var selectedTopic: Binding<String?> = .constant(nil)
    var topics: [String] = []
    var archive: [Article]? = nil
    var selectedArticleID: Binding<String?> = .constant(nil)
    var usesSplitSelection: Bool = false
    var onDismissTip: () -> Void = {}

    private var archiveArticles: [Article] {
        archive ?? Array(articles.dropFirst())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.hero) {
            ClimatePageHeader(
                title: "Read",
                subtitle: "One story. Something you can do.",
                titleFont: ClimateTheme.Typography.leadTitle
            )

            if let lead = articles.first {
                articleLink(lead) {
                    FeaturedStory(article: lead, isNew: leadIsNew)
                }
                .accessibilityLabel(leadIsNew ? "New. Read the latest note: \(lead.title)" : "Read the latest note: \(lead.title)")
                .accessibilityHint("Opens the full article")
            }

            if articles.count > 1 {
                VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
                    Rectangle()
                        .fill(ClimateTheme.divider.opacity(0.35))
                        .frame(height: 1)
                        .padding(.top, ClimateTheme.Spacing.small)

                    Text("Earlier notes")
                        .font(ClimateTheme.Typography.sectionTitle)
                        .tracking(-0.35)
                        .foregroundStyle(ClimateTheme.ink)
                        .accessibilityAddTraits(.isHeader)

                    if !topics.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: ClimateTheme.Spacing.small) {
                                topicChip(title: "All", selected: selectedTopic.wrappedValue == nil) {
                                    selectedTopic.wrappedValue = nil
                                }
                                ForEach(topics, id: \.self) { topic in
                                    topicChip(title: topic, selected: selectedTopic.wrappedValue == topic) {
                                        selectedTopic.wrappedValue = topic
                                    }
                                }
                            }
                        }
                        .accessibilityLabel("Filter earlier notes by topic")
                    }

                    if archiveArticles.isEmpty {
                        Text("No earlier notes in this topic.")
                            .font(ClimateTheme.Typography.subheadline)
                            .foregroundStyle(ClimateTheme.secondaryInk)
                            .padding(.vertical, ClimateTheme.Spacing.medium)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(archiveArticles.enumerated()), id: \.element.id) { index, article in
                                if index > 0 {
                                    Rectangle()
                                        .fill(ClimateTheme.divider.opacity(0.45))
                                        .frame(height: 1)
                                }
                                articleLink(article) { ArchiveRow(article: article) }
                                    .accessibilityLabel("Read \(article.title)")
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if showFirstLaunchTip {
                onDismissTip()
            }
        }
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
                            RoundedRectangle(cornerRadius: 2)
                                .fill(ClimateTheme.accent)
                                .frame(width: 3)
                                .padding(.vertical, ClimateTheme.Spacing.small)
                        }
                    }
            }
            .buttonStyle(ClimateArticleLinkStyle())
        } else {
            NavigationLink(value: article) { label() }
                .buttonStyle(ClimateArticleLinkStyle())
        }
    }

    private func topicChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ClimateTheme.Typography.captionStrong)
                .foregroundStyle(selected ? ClimateTheme.onAccent : ClimateTheme.ink)
                .padding(.horizontal, ClimateTheme.Spacing.medium)
                .padding(.vertical, ClimateTheme.Spacing.small)
                .background(selected ? ClimateTheme.accent : ClimateTheme.elevatedSurface, in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(selected ? Color.clear : ClimateTheme.ink.opacity(0.22), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .frame(minHeight: ClimateTheme.minimumTapTarget)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct FeaturedStory: View {
    let article: Article
    var isNew: Bool = false
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
            if let cover = article.coverAsset {
                BoundedStoryImage(cover: cover, height: 220, topic: article.topic, title: article.title)
            } else {
                SignatureCoverArt(topic: article.topic, title: article.title, height: 220)
            }
            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.medium) {
                HStack(spacing: ClimateTheme.Spacing.small) {
                    topicBadge
                    if isNew {
                        Text("New")
                            .font(ClimateTheme.Typography.captionStrong)
                            .foregroundStyle(ClimateTheme.accent)
                            .accessibilityAddTraits(.isStaticText)
                    }
                }
                Text(article.title)
                    .font(ClimateTheme.Typography.feedHeadline)
                    .tracking(-0.5)
                    .foregroundStyle(ClimateTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(article.excerpt)
                    .font(ClimateTheme.Typography.readingDeck)
                    .foregroundStyle(ClimateTheme.secondaryInk)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    metadataAndCue(horizontal: true)
                    metadataAndCue(horizontal: false)
                }
                .padding(.top, ClimateTheme.Spacing.xSmall)
            }
        }
        .contentShape(Rectangle())
    }

    private var topicBadge: some View {
        Text(article.topic.isEmpty ? "Climate" : article.topic)
            .font(ClimateTheme.Typography.captionStrong)
            .foregroundStyle(ClimateTheme.accent)
            .padding(.horizontal, ClimateTheme.Spacing.small)
            .padding(.vertical, 4)
            .background(ClimateTheme.accent.opacity(0.12), in: Capsule())
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).year().month(.abbreviated).day())
    }

    @ViewBuilder private func metadataAndCue(horizontal: Bool) -> some View {
        if horizontal {
            HStack(alignment: .firstTextBaseline) {
                metadata
                Spacer(minLength: ClimateTheme.Spacing.small)
                readingCue
            }
        } else {
            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.small) {
                metadata
                readingCue
            }
        }
    }

    private var metadata: some View {
        Text([
            article.publishedAt.map(formattedDate),
            "\(article.readingMinutes) min read",
        ]
        .compactMap { $0 }
        .joined(separator: " · "))
            .font(ClimateTheme.Typography.caption)
            .foregroundStyle(ClimateTheme.tertiaryInk)
    }

    private var readingCue: some View {
        HStack(spacing: ClimateTheme.Spacing.xSmall) {
            Text("Read the note")
            Image(systemName: "arrow.right")
                .accessibilityHidden(true)
        }
        .font(ClimateTheme.Typography.subheadlineStrong)
        .foregroundStyle(ClimateTheme.accent)
    }
}

private struct ArchiveRow: View {
    let article: Article
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    var body: some View {
        HStack(alignment: .center, spacing: ClimateTheme.Spacing.medium) {
            if let cover = article.coverAsset {
                BoundedStoryImage(cover: cover, height: 56, topic: article.topic, title: article.title, compact: true)
                    .frame(width: 72)
                    .accessibilityHidden(true)
            } else {
                SignatureCoverArt(topic: article.topic, title: article.title, height: 56, compact: true)
                    .frame(width: 72)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.xSmall) {
                Text(article.topic.isEmpty ? "Climate" : article.topic)
                    .font(ClimateTheme.Typography.captionStrong)
                    .foregroundStyle(ClimateTheme.accent)
                    .lineLimit(1)
                Text(article.title)
                    .font(ClimateTheme.Typography.rowTitle)
                    .foregroundStyle(ClimateTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text([
                    article.publishedAt.map(formattedDate) ?? "Publication date unavailable",
                    "\(article.readingMinutes) min read",
                ].joined(separator: " · "))
                    .font(ClimateTheme.Typography.caption)
                    .foregroundStyle(ClimateTheme.tertiaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: ClimateTheme.Spacing.small)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(ClimateTheme.tertiaryInk)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, ClimateTheme.Spacing.large)
        .contentShape(Rectangle())
    }

    private func formattedDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).year().month(.abbreviated).day())
    }
}

/// Bounds a story-local image before clipping, regardless of intrinsic size.
/// Bundled `climate-note-asset` covers load from the asset catalog; fixtures stay
/// on signature art so QA can force loading/failure states without network.
private struct BoundedStoryImage: View {
    let cover: CoverAsset
    let height: CGFloat
    var topic: String = ""
    var title: String = ""
    var compact: Bool = false

    var body: some View {
        GeometryReader { geometry in
            if cover.url.scheme == "climate-note-fixture"
                || cover.url.scheme == "climate-note-fixture-missing" {
                SignatureCoverArt(topic: topic, title: title, height: height, compact: compact)
            } else if cover.url.scheme == "climate-note-fixture-loading" {
                placeholder { ProgressView("Loading story image") }
            } else if let assetName = BundledCoverCatalog.assetName(from: cover.url),
                      let image = UIImage(named: assetName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: height)
                    .clipped()
                    .accessibilityLabel(cover.altText)
            } else {
                AsyncImage(url: cover.url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                            .frame(width: geometry.size.width, height: height)
                            .clipped()
                            .accessibilityLabel(cover.altText)
                    case .empty:
                        placeholder { ProgressView("Loading story image") }
                    default:
                        SignatureCoverArt(topic: topic, title: title, height: height, compact: compact)
                    }
                }
            }
        }
        .frame(height: height)
        .clipShape(.rect(cornerRadius: ClimateTheme.Radius.image))
    }

    private func placeholder<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .font(ClimateTheme.Typography.caption)
            .foregroundStyle(ClimateTheme.secondaryInk)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ClimateTheme.elevatedSurface)
    }
}

struct FeedLoadingView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.xLarge) {
                ClimatePageHeader(
                title: "Read",
                subtitle: "One story. Something you can do.",
                titleFont: ClimateTheme.Typography.leadTitle
            )
                ProgressView("Loading notes")
                    .font(ClimateTheme.Typography.subheadline)
                    .tint(ClimateTheme.accent)
                RoundedRectangle(cornerRadius: ClimateTheme.Radius.small)
                    .fill(ClimateTheme.elevatedSurface)
                    .frame(height: 210)
                RoundedRectangle(cornerRadius: ClimateTheme.Radius.small)
                    .fill(ClimateTheme.elevatedSurface)
                    .frame(height: 32)
                RoundedRectangle(cornerRadius: ClimateTheme.Radius.small)
                    .fill(ClimateTheme.elevatedSurface)
                    .frame(height: 64)
            }
            .padding(ClimateTheme.Spacing.large)
            .frame(maxWidth: ClimateTheme.ContentWidth.feed)
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading climate notes")
    }
}

struct FeedEmptyView: View {
    let message: String?
    var retry: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.xLarge) {
                ClimatePageHeader(
                    title: "Read",
                    subtitle: message == nil
                        ? "New stories will appear when they’re published."
                        : "Check your connection and try again."
                )
                if let message {
                    ClimateInlineStatus(message: message, kind: .error)
                }
                if let retry {
                    Button(message == nil ? "Check for notes" : "Try again", action: retry)
                        .buttonStyle(ClimateSecondaryButtonStyle())
                }
            }
            .padding(ClimateTheme.Spacing.large)
            .frame(maxWidth: ClimateTheme.ContentWidth.empty, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}
