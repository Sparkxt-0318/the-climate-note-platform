import Foundation
import SwiftUI
import UIKit

@MainActor
struct ArticleDetailView: View {
    enum InitialScrollTarget: Equatable {
        case articleVisual
    }

    let article: Article
    let initialScrollTarget: InitialScrollTarget?
    let onViewInMyNote: (String) -> Void
    @EnvironmentObject private var readingSession: ReadingSessionStore
    @ObservedObject private var router = AppRouter.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsBackToArticle = false
    @State private var opensComposer = false
    @State private var composerPrefill = ""
    @State private var didRestoreScroll = false
    @State private var shouldJumpToComposer = false
    @State private var readingProgress = 0.0

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
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        articleVisual
                            .id("article-visual")

                        VStack(alignment: .leading, spacing: 0) {
                            articleHeader
                                .id("article-top")

                            openingReading
                                .padding(.top, 26)

                            if hasGeneratedContent {
                                quietJumpLinks(proxy)
                                    .padding(.top, ClimateLayout.section)
                            }

                            remainingReading
                                .padding(.top, openingBlockIndexes.isEmpty ? 0 : 22)

                            sources
                            externalLinks

                            if let generation = article.generation {
                                SummaryView(summary: generation.summary)
                                    .id("article-summary")
                                    .padding(.top, ClimateLayout.majorSection)
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
                            .padding(.top, ClimateLayout.majorSection)

                            if showsBackToArticle {
                                Button("Back to the article") {
                                    showsBackToArticle = false
                                    jump(to: "article-top", proxy: proxy)
                                }
                                .buttonStyle(ClimatePaperOutlineButtonStyle())
                                .padding(.top, ClimateLayout.section)
                            }
                        }
                        .frame(maxWidth: ClimateLayout.readerMaxWidth, alignment: .leading)
                        .padding(.horizontal, ClimateLayout.phoneGutter)
                        .padding(.top, ClimateLayout.section)
                        .padding(.bottom, 58)
                        .frame(maxWidth: .infinity)
                    }
                    .background {
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ArticleScrollStateKey.self,
                                value: ArticleScrollState(
                                    offset: Double(-geometry.frame(in: .named("article-scroll")).minY),
                                    contentHeight: Double(geometry.size.height)
                                )
                            )
                        }
                    }
                }
                .coordinateSpace(name: "article-scroll")
                .scrollDismissesKeyboard(.interactively)
                .onPreferenceChange(ArticleScrollStateKey.self) { state in
                    let offset = max(0, state.offset)
                    readingSession.updateScrollOffset(offset, for: article.id)
                    let available = max(1, state.contentHeight - Double(viewport.size.height))
                    readingProgress = min(1, max(0, offset / available))
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
                        DispatchQueue.main.async { jump(to: "article-visual", proxy: proxy) }
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
        }
        .background(Color.climatePaper.ignoresSafeArea())
        .foregroundStyle(Color.climatePaperInk)
        .tint(Color.climateInk)
        .safeAreaInset(edge: .top, spacing: 0) {
            ReadingProgressBar(progress: readingProgress)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.climateCanvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: AppConfig.articleURL(slug: article.slug),
                    subject: Text(article.title),
                    message: Text(article.excerpt)
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: ClimateLayout.minimumTarget, height: ClimateLayout.minimumTarget)
                }
                .accessibilityLabel("Share \(article.title)")
            }
        }
        .onChange(of: article.id) { _, _ in
            showsBackToArticle = false
            opensComposer = false
            composerPrefill = ""
            didRestoreScroll = false
            readingProgress = 0
            readingSession.markArticleOpened(article)
        }
    }

    private var hasGeneratedContent: Bool { article.generation != nil }

    private var articleHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(article.topic.isEmpty ? "Climate" : article.topic.uppercased())
                .climateMetadata(weight: .bold)
                .tracking(1.4)
                .foregroundStyle(Color.climatePaperMuted)

            Text(article.title)
                .climateDisplay(44, relativeTo: .largeTitle)
                .foregroundStyle(Color.climatePaperInk)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text(article.excerpt)
                .font(.system(.body, design: .serif))
                .foregroundStyle(Color.climatePaperMuted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { bylineItems }
                VStack(alignment: .leading, spacing: 5) { bylineItems }
            }
            .climateMetadata()
            .foregroundStyle(Color.climatePaperMuted)
        }
    }

    @ViewBuilder private var bylineItems: some View {
        Text("By \(article.displayAuthor)")
        Text("·").accessibilityHidden(true)
        Text(article.publishedAt?.formatted(.dateTime.month(.abbreviated).day().year()) ?? "This week")
        Text("·").accessibilityHidden(true)
        Text("\(article.readingMinutes) min read")
    }

    private var openingReading: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(openingBlockIndexes, id: \.self) { index in
                blockView(article.contentBlocks[index])
            }
        }
    }

    private var remainingReading: some View {
        VStack(alignment: .leading, spacing: 22) {
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
        return Array(article.contentBlocks.indices.prefix((firstParagraphIndex ?? 0) + 1))
    }

    private var remainingBlockIndexes: [Int] {
        Array(article.contentBlocks.indices.dropFirst(openingBlockIndexes.count))
    }

    @ViewBuilder private func blockView(_ block: ArticleBlock) -> some View {
        switch block {
        case .paragraph(let text):
            SelectableReadingText(text: text, style: .body, onStartReflection: startReflection)

        case .heading(let level, let text):
            Text(text)
                .climateDisplay(level == 2 ? 28 : 24, relativeTo: level == 2 ? .title : .title2)
                .foregroundStyle(Color.climatePaperInk)
                .padding(.top, 18)
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
        VStack(alignment: .leading, spacing: 14) {
            ForEach(items.indices, id: \.self) { index in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(numbered ? "\(index + 1)." : "•")
                        .font(.headline)
                        .foregroundStyle(Color.climateSage)
                        .frame(width: 26, alignment: .leading)
                    SelectableReadingText(text: items[index], style: .listItem, onStartReflection: startReflection)
                }
            }
        }
    }

    private var articleVisual: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if article.coverAsset == nil {
                    ClimateCoverImage(
                        url: nil,
                        altText: "Cover image for \(article.title)",
                        assetName: article.coverAsset == nil ? ClimateLocalArt.assetName(for: article) : nil
                    )
                } else {
                    EditorialCoverImage(article: article, height: 272)
                }
            }
            .frame(height: 272)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, Color.climateCanvas.opacity(0.52)], startPoint: .top, endPoint: .bottom)
            }

            if let cover = article.coverAsset {
                MediaCredit(cover: cover)
                    .padding(.horizontal, ClimateLayout.phoneGutter)
            }
        }
    }

    @ViewBuilder private func quietJumpLinks(_ proxy: ScrollViewProxy) -> some View {
        HStack(spacing: ClimateLayout.element) {
            Button("Summary") { jump(to: "article-summary", proxy: proxy, presentsBack: true) }
            Button("Add a note") { jump(to: "article-actions", proxy: proxy, presentsBack: true) }
        }
        .buttonStyle(.plain)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Color.climateSage)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: ClimateLayout.minimumTarget, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Article shortcuts")
    }

    @ViewBuilder private var sources: some View {
        if !article.sourceLinks.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                ClimatePaperRule().padding(.top, ClimateLayout.majorSection)
                Text("Sources")
                    .climateDisplay(28, relativeTo: .title2)

                ForEach(Array(article.sourceLinks.enumerated()), id: \.element.url) { index, source in
                    Link(destination: source.url) {
                        HStack(alignment: .firstTextBaseline, spacing: 9) {
                            Text("\(index + 1).")
                                .climateMetadata(weight: .semibold)
                                .foregroundStyle(Color.climatePaperMuted)
                            Text(source.label)
                                .font(.body.weight(.semibold))
                                .underline()
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.up.right")
                                .climateMetadata(weight: .semibold)
                                .accessibilityHidden(true)
                        }
                        .foregroundStyle(Color.climatePaperInk)
                        .frame(minHeight: ClimateLayout.minimumTarget)
                    }
                }
            }
        }
    }

    @ViewBuilder private var externalLinks: some View {
        if let links = article.externalLinks, !links.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Also published on")
                    .climateMetadata(weight: .semibold)
                    .foregroundStyle(Color.climatePaperMuted)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { externalLinks(links) }
                    VStack(alignment: .leading, spacing: 6) { externalLinks(links) }
                }
            }
            .padding(.top, 28)
        }
    }

    @ViewBuilder private func externalLinks(_ links: ExternalLinks) -> some View {
        if let url = links.instagram {
            Link("Instagram", destination: url)
                .frame(minWidth: ClimateLayout.minimumTarget, minHeight: ClimateLayout.minimumTarget)
        }
        if let url = links.substack {
            Link("Substack", destination: url)
                .frame(minWidth: ClimateLayout.minimumTarget, minHeight: ClimateLayout.minimumTarget)
        }
        if let url = links.medium {
            Link("Medium", destination: url)
                .frame(minWidth: ClimateLayout.minimumTarget, minHeight: ClimateLayout.minimumTarget)
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
        if let prefill = request.prefill, !prefill.isEmpty { composerPrefill = prefill }
        DispatchQueue.main.async {
            jump(to: "article-actions", proxy: proxy, presentsBack: hasGeneratedContent)
        }
    }

    private func jump(to destination: String, proxy: ScrollViewProxy, presentsBack: Bool = false) {
        if presentsBack && hasGeneratedContent { showsBackToArticle = true }
        withAnimation(reduceMotion ? nil : ClimateMotion.content) {
            proxy.scrollTo(destination, anchor: .top)
        }
    }
}

private struct ReadingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Color.climatePaperRule
                Color.climateSage.frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reading progress")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }
}

private struct ClimatePaperOutlineButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.climatePaperInk)
            .frame(maxWidth: .infinity, minHeight: ClimateLayout.controlHeight)
            .overlay { RoundedRectangle(cornerRadius: ClimateRadius.control).stroke(Color.climatePaperRule, lineWidth: 1) }
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.99 : 1)
            .animation(reduceMotion ? nil : ClimateMotion.press, value: configuration.isPressed)
    }
}

private struct MediaCredit: View {
    let cover: CoverAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !creditText.isEmpty {
                Text(creditText)
                    .climateMetadata()
                    .foregroundStyle(Color.climatePaperMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let sourceURL = cover.sourceUrl {
                Link("Photo source", destination: sourceURL)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.climatePaperInk)
                    .frame(minHeight: ClimateLayout.minimumTarget)
            }
        }
    }

    private var creditText: String {
        let attribution = !cover.attribution.isEmpty
            ? cover.attribution
            : [cover.photographer.map { "Photo by \($0)" }, cover.provider].compactMap { $0 }.joined(separator: " · ")
        return [cover.caption, attribution, cover.license].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

private struct ArticleScrollState: Equatable {
    let offset: Double
    let contentHeight: Double
}

private struct ArticleScrollStateKey: PreferenceKey {
    static var defaultValue = ArticleScrollState(offset: 0, contentHeight: 1)
    static func reduce(value: inout ArticleScrollState, nextValue: () -> ArticleScrollState) {
        value = nextValue()
    }
}

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
            let maximum = max(0, scrollView.contentSize.height - scrollView.bounds.height)
            scrollView.setContentOffset(CGPoint(x: 0, y: min(offset, maximum)), animated: false)
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

/// Supports native selection and keeps a reflection entry point in the iOS edit menu.
private struct SelectableReadingText: UIViewRepresentable {
    enum Style { case body, listItem }

    let text: String
    let style: Style
    let onStartReflection: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onStartReflection: onStartReflection) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = false
        textView.isSelectable = true
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
        if textView.text != text { apply(text, to: textView) }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width.isFinite, width > 0 else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitted.height))
    }

    private func apply(_ text: String, to textView: UITextView) {
        let system = UIFont.systemFont(ofSize: 19, weight: .regular)
        let serifDescriptor = system.fontDescriptor.withDesign(.serif) ?? system.fontDescriptor
        let nativeSerif = UIFont(descriptor: serifDescriptor, size: 19)
        let font = UIFontMetrics(forTextStyle: .body).scaledFont(for: nativeSerif)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = style == .body ? 9 : 8
        textView.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: UIColor(Color.climatePaperInk),
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
                let selected = textView.selectedTextRange.flatMap { textView.text(in: $0) } ?? textView.text ?? ""
                guard !selected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                self.onStartReflection(selected)
            }
            return UIMenu(children: suggestedActions + [action])
        }
    }
}

private struct SummaryView: View {
    let summary: ClimateSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("THE SHORT VERSION")
                .climateMetadata(weight: .bold)
                .tracking(1.2)
                .foregroundStyle(Color.climatePaperMuted)
            Text("The story in three parts")
                .climateDisplay(30, relativeTo: .title)
            item("What is happening", summary.problem)
            item("Why it matters", summary.whyItMatters)
            item("What we can do", summary.whatWeCanDo)
            Text("AI summary. Read the article and sources for context.")
                .climateMetadata()
                .foregroundStyle(Color.climatePaperMuted)
        }
        .padding(ClimateLayout.cardPadding)
        .background(Color.climateNotice.opacity(0.08), in: .rect(cornerRadius: ClimateRadius.card))
        .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climatePaperRule, lineWidth: 1) }
        .overlay(alignment: .leading) { Rectangle().fill(Color.climateSage).frame(width: 3) }
    }

    private func item(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.body.weight(.bold))
            Text(body).font(.body).foregroundStyle(Color.climatePaperMuted).lineSpacing(4)
        }
        .padding(.leading, 14)
    }
}
