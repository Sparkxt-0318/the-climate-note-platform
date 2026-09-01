import SwiftUI

struct ArticleDetailView: View {
    let article: Article

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if article.generation?.visualPlan.placement == "cover" { visual }
                articleBody
                sources
                externalLinks
                if let generation = article.generation {
                    SummaryView(summary: generation.summary)
                    ClimateActionPicker(article: article, actions: generation.suggestedActions)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 56)
        }
        .background(Color.climateBackground)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(article.topic.uppercased())
                .font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Color.climateSage)
            Text(article.title).font(.largeTitle.bold())
            Text(article.excerpt).font(.title3).foregroundStyle(.secondary)
            HStack {
                if let author = article.author { Text("By \(author)") }
                Spacer()
                Text("\(article.readingMinutes) min read")
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.top, 12)
    }

    @ViewBuilder private var visual: some View {
        if let cover = article.coverAsset {
            VStack(alignment: .leading, spacing: 8) {
                AsyncImage(url: cover.url) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }
                    .clipShape(.rect(cornerRadius: 22))
                    .accessibilityLabel(cover.altText)
                Text("\(cover.caption) \(cover.attribution)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var articleBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(article.contentBlocks.enumerated()), id: \.offset) { index, block in
                blockView(block)
                if index == firstParagraphIndex, article.generation?.visualPlan.placement == "after-introduction" {
                    visual
                }
            }
        }
    }

    private var firstParagraphIndex: Int {
        article.contentBlocks.firstIndex { if case .paragraph = $0 { true } else { false } } ?? 0
    }

    @ViewBuilder private func blockView(_ block: ArticleBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(text).font(.body).lineSpacing(6)
        case .heading(let level, let text):
            Text(text).font(level == 2 ? .title2.bold() : .title3.bold()).padding(.top, 12)
        case .bulletedList(let items):
            list(items, numbered: false)
        case .numberedList(let items):
            list(items, numbered: true)
        }
    }

    private func list(_ items: [String], numbered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(numbered ? "\(index + 1)." : "•").foregroundStyle(Color.climateSage).bold()
                    Text(item).lineSpacing(4)
                }
            }
        }
    }

    @ViewBuilder private var sources: some View {
        if !article.sourceLinks.isEmpty {
            DisclosureGroup("Sources") {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(article.sourceLinks, id: \.url) { source in
                        Link(source.label, destination: source.url).foregroundStyle(Color.climateSage)
                    }
                }
                .padding(.top, 12)
            }
            .font(.headline)
        }
    }

    @ViewBuilder private var externalLinks: some View {
        if let links = article.externalLinks, !links.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Also published on").font(.headline)
                HStack(spacing: 10) {
                    if let url = links.instagram { Link("Instagram", destination: url) }
                    if let url = links.substack { Link("Substack", destination: url) }
                    if let url = links.medium { Link("Medium", destination: url) }
                }
                .buttonStyle(.bordered)
                .tint(.climateSage)
            }
        }
    }
}

private struct SummaryView: View {
    let summary: ClimateSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("The note in a nutshell", systemImage: "sparkles").font(.title2.bold())
            item("What’s happening", summary.problem)
            item("Why it matters", summary.whyItMatters)
            item("What we can do", summary.whatWeCanDo)
            Text("AI-generated summary · The original article above is unchanged.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(22)
        .background(Color.climateSage.opacity(0.11), in: .rect(cornerRadius: 26))
    }

    private func item(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.headline)
            Text(body).foregroundStyle(.secondary)
        }
    }
}
