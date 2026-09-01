import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var store: ArticleStore

    var body: some View {
        Group {
            if store.isLoading {
                ProgressView("Loading this week’s note…")
            } else if store.articles.isEmpty {
                ContentUnavailableView(
                    "Your first note is on its way",
                    systemImage: "book.closed",
                    description: Text(store.errorMessage ?? "New climate stories appear here each week.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(store.articles) { article in
                            NavigationLink(value: article) { ArticleCard(article: article) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 28)
                }
                .navigationDestination(for: Article.self) { ArticleDetailView(article: $0) }
            }
        }
        .navigationTitle("The Climate Note")
    }
}

private struct ArticleCard: View {
    let article: Article

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let cover = article.coverAsset {
                AsyncImage(url: cover.url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color.climateSage.opacity(0.12)).overlay { ProgressView() }
                }
                .frame(height: 210)
                .clipShape(.rect(cornerRadius: 22))
                .accessibilityLabel(cover.altText)
            }
            Text(article.topic.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(Color.climateSage)
            Text(article.title)
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text(article.excerpt)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Label("\(article.readingMinutes) min read", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 28))
        .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
    }
}
