import Foundation
import SwiftUI
import UIKit

@MainActor
struct ArticleDetailView: View {
    /// Debug captures can verify content that normally sits below the introductory reading.
    /// The production route leaves this nil and opens at the article heading.
    enum InitialScrollTarget: Equatable {
        case articleVisual
    }

    let article: Article
    let initialScrollTarget: InitialScrollTarget?
    /// The picker only invokes this after a deliberate "View in My Note" tap.
    let onViewInMyNote: (String) -> Void
    @EnvironmentObject private var readingSession: ReadingSessionStore
    @ObservedObject private var router = AppRouter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsBackToArticle = false
    @State private var opensComposer = false
    @State private var composerPrefill = ""
    @State private var didRestoreScroll = false
    @State private var shouldJumpToComposer = false

    init(
        article: Article,
        initialScrollTarget: InitialScrollTarget? = nil,
        onViewInMyNote: @escaping (String) -> Void = { AppRouter.shared.showJournal(entryID: $0) }
    ) {
        self.article = article
        self.initialScrollTarget = initialScrollTarget
        self.onViewInMyNote = onViewInMyNote
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: ClimateTheme.Spacing.xLarge) {
                    articleHeader
                        .id("article-top")
                    // Signature art fills the cover slot when a licensed photo is
                    // missing; otherwise the story-local cover stays in place.
                    if article.generation?.visualPlan.placement == "cover"
                        || article.coverAsset != nil
                        || article.generation == nil {
                        articleVisual
                            .id("article-visual")
                    }
                    openingReading
                    if hasGeneratedContent {
                        // Quiet shortcuts only — a full primary CTA mid-article
                        // kills the reading loop before the story earns the ask.
                        quietJumpLinks(proxy)
                    }
                    remainingReading
                    sources
                    externalLinks
                    if let generation = article.generation {
                        SummaryView(summary: generation.summary)
                            .id("article-summary")
                    }
                    ClimateActionPicker(
                        article: article,
                        actions: article.generation?.suggestedActions ?? [],
                        initialCustomText: composerPrefill,
                        initialWritingFocus: opensComposer,
                        onViewInMyNote: onViewInMyNote
                    )
                    .id("\(article.id)-composer-\(opensComposer)-\(composerPrefill)")
                    .id("article-actions")
                    if showsBackToArticle {
                        Button("Back to the article") {
                            showsBackToArticle = false
                            jump(to: "article-top", proxy: proxy)
                        }
                        .buttonStyle(ClimateSecondaryButtonStyle())
                    }
                }
                .padding(.horizontal, ClimateTheme.Spacing.large)
                .padding(.top, ClimateTheme.Spacing.large)
                .padding(.bottom, ClimateTheme.Spacing.xxLarge)
                .frame(maxWidth: ClimateTheme.ContentWidth.reading, alignment: .leading)
                .frame(maxWidth: .infinity)
                .background {
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ArticleScrollOffsetKey.self,
                            value: Double(-geometry.frame(in: .named("article-scroll")).minY)
                        )
                    }
                }
            }
            .coordinateSpace(name: "article-scroll")
            .scrollDismissesKeyboard(.interactively)
            .onPreferenceChange(ArticleScrollOffsetKey.self) { offset in
                readingSession.updateScrollOffset(offset, for: article.id)
            }
            .background {
                ArticleScrollOffsetRestorer(
                    articleID: article.id,
                    offset: readingSession.scrollOffset(for: article.id),
                    shouldRestore: !didRestoreScroll && readingSession.scrollOffset(for: article.id) > 24
                ) {
                    didRestoreScroll = true
                }
            }
            .onAppear {
                readingSession.markArticleOpened(article)
                if initialScrollTarget == .articleVisual {
                    DispatchQueue.main.async {
                        jump(to: "article-visual", proxy: proxy)
                    }
                }
                openComposerIfRequested(proxy: proxy)
            }
            .onChange(of: router.composerArticleID) { _, _ in
                openComposerIfRequested(proxy: proxy)
            }
            .onChange(of: shouldJumpToComposer) { _, needsJump in
                guard needsJump else { return }
                shouldJumpToComposer = false
                DispatchQueue.main.async {
                    jump(to: "article-actions", proxy: proxy, presentsBack: hasGeneratedContent)
                }
            }
        }
        .background { ClimateBackdrop() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { ClimateWordmark() }
        }
        .toolbarBackground(ClimateTheme.pine, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: article.id) { _, _ in
            showsBackToArticle = false
            opensComposer = false
            composerPrefill = ""
            didRestoreScroll = false
            readingSession.markArticleOpened(article)
        }
    }

    private func startReflection(with passage: String) {
        let trimmed = passage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        composerPrefill = "“\(trimmed)”\n\n"
        opensComposer = true
        shouldJumpToComposer = true
    }

    private func openComposerIfRequested(proxy: ScrollViewProxy) {
        let request = router.consumeComposerRequest(for: article.id)
        guard request.opens else { return }
        opensComposer = true
        if let prefill = request.prefill, !prefill.isEmpty {
            composerPrefill = prefill
        }
        DispatchQueue.main.async {
            jump(to: "article-actions", proxy: proxy, presentsBack: hasGeneratedContent)
        }
    }

    @ViewBuilder private func quietJumpLinks(_ proxy: ScrollViewProxy) -> some View {
        HStack(spacing: ClimateTheme.Spacing.large) {
            Button("Skip to action") { jump(to: "article-actions", proxy: proxy, presentsBack: true) }
            if article.generation != nil {
                Button("Jump to summary") { jump(to: "article-summary", proxy: proxy, presentsBack: true) }
            }
        }
        .buttonStyle(.plain)
        .font(ClimateTheme.Typography.subheadlineStrong)
        .foregroundStyle(ClimateTheme.accent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: ClimateTheme.minimumTapTarget, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Article shortcuts")
    }

    private func jump(to destination: String, proxy: ScrollViewProxy, presentsBack: Bool = false) {
        if presentsBack && hasGeneratedContent { showsBackToArticle = true }
        withAnimation(reduceMotion ? nil : ClimateTheme.Motion.standardState) {
            proxy.scrollTo(destination, anchor: .top)
        }
    }

    private var hasGeneratedContent: Bool { article.generation != nil }

    private var articleHeader: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
            Text(article.topic.isEmpty ? "Climate" : article.topic)
                .font(ClimateTheme.Typography.captionStrong)
                .foregroundStyle(ClimateTheme.accent)
                .padding(.horizontal, ClimateTheme.Spacing.small)
                .padding(.vertical, 4)
                .background(ClimateTheme.accent.opacity(0.12), in: Capsule())

            Text(article.title)
                .font(ClimateTheme.Typography.articleTitle)
                .tracking(-0.45)
                .foregroundStyle(ClimateTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(article.excerpt)
                .font(ClimateTheme.Typography.readingDeck)
                .foregroundStyle(ClimateTheme.secondaryInk)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            bylineRow
        }
    }

    private var bylineRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: ClimateTheme.Spacing.compact) {
                byline
                    .frame(maxWidth: .infinity, alignment: .leading)
                shareLink
            }
            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.medium) {
                byline
                shareLink
            }
        }
    }

    private var byline: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: ClimateTheme.Spacing.small) {
                bylineItems
            }
            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.xSmall) {
                bylineItems
            }
        }
        .font(ClimateTheme.Typography.readingSubheadline)
        .foregroundStyle(ClimateTheme.secondaryInk)
    }

    @ViewBuilder private var bylineItems: some View {
        if let author = article.author {
            Text("By \(author)")
                .fontWeight(.semibold)
        }
        if let publishedAt = article.publishedAt {
            if article.author != nil {
                Text("·")
                    .accessibilityHidden(true)
            }
            Text(publishedAt.formatted(date: .abbreviated, time: .omitted))
        }
        if article.author != nil || article.publishedAt != nil {
            Text("·")
                .accessibilityHidden(true)
        }
        Text("\(article.readingMinutes) min read")
    }

    private var shareLink: some View {
        ShareLink(
            item: AppConfig.apiBaseURL.appending(path: "articles/\(article.slug)"),
            subject: Text(article.title),
            message: Text(article.excerpt)
        ) {
            HStack(spacing: ClimateTheme.Spacing.xSmall) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .medium))
                    .accessibilityHidden(true)
                Text("Share")
                    .font(ClimateTheme.Typography.shareLabel)
            }
            .foregroundStyle(ClimateTheme.ink)
            .padding(.horizontal, ClimateTheme.Spacing.compact)
            .frame(minHeight: 34)
            .background(ClimateTheme.elevatedSurface, in: .capsule)
            .overlay {
                Capsule()
                    .stroke(ClimateTheme.ink.opacity(0.38), lineWidth: 1.25)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens the share sheet for this article")
        .accessibilityLabel("Share \(article.title)")
    }

    private var openingReading: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
            ForEach(openingBlockIndexes, id: \.self) { index in
                let block = article.contentBlocks[index]
                blockView(block)
                if let firstParagraphIndex,
                   index == firstParagraphIndex,
                   article.generation?.visualPlan.placement == "after-introduction" {
                    articleVisual
                        .id("article-visual")
                        .padding(.vertical, ClimateTheme.Spacing.small)
                }
            }
        }
    }

    private var remainingReading: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
            ForEach(remainingBlockIndexes, id: \.self) { index in
                blockView(article.contentBlocks[index])
            }
        }
    }

    private var firstParagraphIndex: Int? {
        article.contentBlocks.firstIndex {
            if case .paragraph = $0 { return true }
            return false
        }
    }

    private var openingBlockIndexes: [Int] {
        guard !article.contentBlocks.isEmpty else { return [] }
        let end = (firstParagraphIndex ?? 0) + 1
        return Array(article.contentBlocks.indices.prefix(end))
    }

    private var remainingBlockIndexes: [Int] {
        Array(article.contentBlocks.indices.dropFirst(openingBlockIndexes.count))
    }

    @ViewBuilder private func blockView(_ block: ArticleBlock) -> some View {
        switch block {
        case .paragraph(let text):
            SelectableReadingText(
                text: text,
                style: .body,
                onStartReflection: startReflection
            )

        case .heading(let level, let text):
            Text(text)
                .font(level == 2 ? ClimateTheme.Typography.readingHeading : ClimateTheme.Typography.rowTitle)
                .tracking(level == 2 ? -0.25 : 0)
                .foregroundStyle(ClimateTheme.ink)
                .padding(.top, ClimateTheme.Spacing.medium)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .accessibilityAddTraits(.isHeader)

        case .bulletedList(let items):
            articleList(items, numbered: false)

        case .numberedList(let items):
            articleList(items, numbered: true)
        }
    }

    private func articleList(_ items: [String], numbered: Bool) -> some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.medium) {
            ForEach(items.indices, id: \.self) { index in
                let item = items[index]

                HStack(alignment: .firstTextBaseline, spacing: ClimateTheme.Spacing.compact) {
                    Text(numbered ? String(format: "%02d", index + 1) : "—")
                        .font(ClimateTheme.Typography.metadata)
                        .foregroundStyle(ClimateTheme.accent)
                        .frame(width: 30, alignment: .leading)

                    SelectableReadingText(
                        text: item,
                        style: .listItem,
                        onStartReflection: startReflection
                    )
                }
            }
        }
    }

    @ViewBuilder private var articleVisual: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.small) {
            Group {
                if let cover = article.coverAsset,
                   cover.url.scheme != "climate-note-fixture",
                   cover.url.scheme != "climate-note-fixture-missing" {
                    GeometryReader { geometry in
                        if cover.url.scheme == "climate-note-fixture-loading" {
                            visualPlaceholder(showProgress: true)
                        } else if let assetName = BundledCoverCatalog.assetName(from: cover.url),
                                  let image = UIImage(named: assetName) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: 220)
                                .clipped()
                                .accessibilityLabel(cover.altText)
                        } else {
                            AsyncImage(url: cover.url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().scaledToFill()
                                        .frame(width: geometry.size.width, height: 220)
                                        .clipped()
                                        .accessibilityLabel(cover.altText)
                                case .empty:
                                    visualPlaceholder(showProgress: true)
                                default:
                                    SignatureCoverArt(topic: article.topic, title: article.title, height: 220)
                                }
                            }
                        }
                    }
                    .frame(height: 220)
                    .clipShape(.rect(cornerRadius: ClimateTheme.Radius.small))
                } else {
                    SignatureCoverArt(topic: article.topic, title: article.title, height: 220)
                }
            }

            if let cover = article.coverAsset {
                MediaCredit(cover: cover)
            } else {
                let topic = article.topic.isEmpty ? "Climate" : article.topic
                Text("Signature cover · \(topic)")
                    .font(ClimateTheme.Typography.metadata)
                    .foregroundStyle(ClimateTheme.secondaryInk)
            }
        }
    }

    @ViewBuilder private var sources: some View {
        if !article.sourceLinks.isEmpty {
            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.medium) {
                Rectangle()
                    .fill(ClimateTheme.divider.opacity(0.7))
                    .frame(height: 1)

                DisclosureGroup {
                    VStack(alignment: .leading, spacing: ClimateTheme.Spacing.compact) {
                        Text("Published sources used for this note.")
                            .font(ClimateTheme.Typography.caption)
                            .foregroundStyle(ClimateTheme.secondaryInk)

                        ForEach(article.sourceLinks.indices, id: \.self) { index in
                            let source = article.sourceLinks[index]

                            Link(destination: source.url) {
                                HStack(alignment: .firstTextBaseline, spacing: ClimateTheme.Spacing.small) {
                                    Text(String(format: "%02d", index + 1))
                                        .font(ClimateTheme.Typography.metadata)
                                    Text(source.label)
                                        .font(ClimateTheme.Typography.subheadlineStrong)
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .accessibilityHidden(true)
                                }
                                .multilineTextAlignment(.leading)
                                .frame(minHeight: ClimateTheme.minimumTapTarget, alignment: .leading)
                            }
                            .foregroundStyle(ClimateTheme.accent)
                        }
                    }
                    .padding(.top, ClimateTheme.Spacing.small)
                } label: {
                    ClimateEyebrow(text: "Sources and context")
                }
            }
        }
    }

    @ViewBuilder private var externalLinks: some View {
        if let links = article.externalLinks, !links.isEmpty {
            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.medium) {
                Rectangle()
                    .fill(ClimateTheme.divider.opacity(0.7))
                    .frame(height: 1)
                ClimateEyebrow(text: "Also published on")
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: ClimateTheme.Spacing.small) { externalLinkButtons(links) }
                    VStack(alignment: .leading, spacing: ClimateTheme.Spacing.small) { externalLinkButtons(links) }
                }
            }
        }
    }

    @ViewBuilder private func externalLinkButtons(_ links: ExternalLinks) -> some View {
        if let url = links.instagram {
            Link("Instagram", destination: url)
                .buttonStyle(ClimateSecondaryButtonStyle())
        }
        if let url = links.substack {
            Link("Substack", destination: url)
                .buttonStyle(ClimateSecondaryButtonStyle())
        }
        if let url = links.medium {
            Link("Medium", destination: url)
                .buttonStyle(ClimateSecondaryButtonStyle())
        }
    }

    @ViewBuilder private func visualPlaceholder(showProgress: Bool, message: String = "Story image unavailable") -> some View {
        VStack(spacing: ClimateTheme.Spacing.small) {
            if showProgress {
                ProgressView("Loading story image")
            } else {
                Label(message, systemImage: "photo")
            }
        }
        .font(ClimateTheme.Typography.caption)
        .foregroundStyle(ClimateTheme.secondaryInk)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ClimateTheme.elevatedSurface)
    }
}

private struct MediaCredit: View {
    let cover: CoverAsset

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.xSmall) {
            if cover.generated {
                Text("AI-generated image")
                    .font(ClimateTheme.Typography.metadata)
                    .foregroundStyle(ClimateTheme.accent)
            }
            if !creditText.isEmpty {
                Text(creditText)
                    .font(ClimateTheme.Typography.metadata)
                    .foregroundStyle(ClimateTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if cover.sourceUrl != nil || cover.licenseUrl != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: ClimateTheme.Spacing.small) { creditLinks }
                    VStack(alignment: .leading, spacing: ClimateTheme.Spacing.xSmall) { creditLinks }
                }
            }
        }
    }

    private var creditText: String {
        let attribution: String
        if !cover.attribution.isEmpty {
            attribution = cover.attribution
        } else {
            attribution = [
                cover.photographer.map { "Photo by \($0)" },
                cover.provider.map { $0.capitalized },
            ]
            .compactMap { $0 }
            .joined(separator: " · ")
        }
        return [cover.caption, attribution, cover.license]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    @ViewBuilder private var creditLinks: some View {
        if let sourceURL = cover.sourceUrl {
            Link(destination: sourceURL) {
                Label("Photo source", systemImage: "arrow.up.right")
            }
            .font(ClimateTheme.Typography.captionStrong)
            .foregroundStyle(ClimateTheme.accent)
            .frame(minHeight: ClimateTheme.minimumTapTarget)
            .accessibilityHint("Opens the story photo source")
        }
        if let licenseURL = cover.licenseUrl {
            Link(destination: licenseURL) {
                Label("Photo license", systemImage: "arrow.up.right")
            }
            .font(ClimateTheme.Typography.captionStrong)
            .foregroundStyle(ClimateTheme.accent)
            .frame(minHeight: ClimateTheme.minimumTapTarget)
            .accessibilityHint("Opens the story photo license")
        }
    }
}

private struct ArticleScrollOffsetKey: PreferenceKey {
    static var defaultValue: Double = 0
    static func reduce(value: inout Double, nextValue: () -> Double) {
        value = nextValue()
    }
}

/// Restores a remembered reading offset once the hosting UIScrollView is available.
private struct ArticleScrollOffsetRestorer: UIViewRepresentable {
    let articleID: String
    let offset: Double
    let shouldRestore: Bool
    let onRestored: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if context.coordinator.articleID != articleID {
            context.coordinator.articleID = articleID
            context.coordinator.didRestore = false
        }
        guard shouldRestore, offset > 24, !context.coordinator.didRestore else { return }
        DispatchQueue.main.async {
            guard let scrollView = uiView.enclosingScrollView() else { return }
            let maxOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            scrollView.setContentOffset(CGPoint(x: 0, y: min(offset, maxOffset)), animated: false)
            context.coordinator.didRestore = true
            onRestored()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var articleID: String?
        var didRestore = false
    }
}

private extension UIView {
    func enclosingScrollView() -> UIScrollView? {
        var current: UIView? = self
        while let view = current {
            if let scrollView = view as? UIScrollView { return scrollView }
            current = view.superview
        }
        return nil
    }
}

/// Selectable article copy with a custom “Start a reflection” edit-menu action.
private struct SelectableReadingText: UIViewRepresentable {
    enum Style {
        case body
        case listItem
    }

    let text: String
    let style: Style
    let onStartReflection: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStartReflection: onStartReflection)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        apply(text, to: textView)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        context.coordinator.onStartReflection = onStartReflection
        if textView.text != text {
            apply(text, to: textView)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width.isFinite, width > 0 else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }

    private func apply(_ text: String, to textView: UITextView) {
        let metrics = UIFontMetrics(forTextStyle: .body)
        let base = UIFont(name: "Newsreader16pt-Regular", size: 19)
            ?? UIFont.preferredFont(forTextStyle: .body)
        let font = metrics.scaledFont(for: base)
        let lineSpacing: CGFloat = style == .body ? 7 : 6
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        textView.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: UIColor(ClimateTheme.ink),
                .paragraphStyle: paragraph,
            ]
        )
        textView.adjustsFontForContentSizeCategory = true
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var onStartReflection: (String) -> Void

        init(onStartReflection: @escaping (String) -> Void) {
            self.onStartReflection = onStartReflection
        }

        func textView(
            _ textView: UITextView,
            editMenuForTextIn range: NSRange,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            let action = UIAction(title: "Start a reflection") { [weak textView] _ in
                guard let textView else { return }
                let selected: String
                if let selectedRange = textView.selectedTextRange,
                   let value = textView.text(in: selectedRange),
                   !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    selected = value
                } else if let full = textView.text {
                    selected = full
                } else {
                    return
                }
                onStartReflection(selected)
            }
            return UIMenu(children: suggestedActions + [action])
        }
    }
}

struct SummaryView: View {
    let summary: ClimateSummary

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
            Rectangle()
                .fill(ClimateTheme.divider)
                .frame(height: 1)
            ClimateEyebrow(text: "The short version")
            Text("The story in three parts")
                .font(ClimateTheme.Typography.leadTitle)
                .foregroundStyle(ClimateTheme.ink)

            summaryItem(number: "01", title: "What’s happening", body: summary.problem)
            summaryItem(number: "02", title: "Why it matters", body: summary.whyItMatters)
            summaryItem(number: "03", title: "What we can do", body: summary.whatWeCanDo)

            Text("AI-generated summary · Check the original article and sources for context.")
                .font(ClimateTheme.Typography.metadata)
                .foregroundStyle(ClimateTheme.tertiaryInk)
        }
        .padding(.vertical, ClimateTheme.Spacing.large)
    }

    private func summaryItem(number: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: ClimateTheme.Spacing.medium) {
            Text(number)
                .font(ClimateTheme.Typography.metadata)
                .foregroundStyle(ClimateTheme.accent)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.xSmall) {
                Text(title)
                    .font(ClimateTheme.Typography.headline)
                    .foregroundStyle(ClimateTheme.ink)
                Text(body)
                    .font(ClimateTheme.Typography.readingBody)
                    .foregroundStyle(ClimateTheme.secondaryInk)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

