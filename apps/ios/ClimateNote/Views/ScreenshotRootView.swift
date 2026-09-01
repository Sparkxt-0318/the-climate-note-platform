#if DEBUG
import SwiftUI

enum ScreenshotConfiguration {
    static var scene: String? {
        guard let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--climate-screenshot") else {
            return nil
        }
        let valueIndex = ProcessInfo.processInfo.arguments.index(after: index)
        guard valueIndex < ProcessInfo.processInfo.arguments.endIndex else { return nil }
        return ProcessInfo.processInfo.arguments[valueIndex]
    }
}

struct ScreenshotRootView: View {
    let scene: String

    var body: some View {
        switch scene {
        case "story":
            NavigationStack { ArticleDetailView(article: ScreenshotFixtures.article) }
        case "summary":
            NavigationStack { ScreenshotSummaryView() }
        case "actions":
            NavigationStack { ScreenshotActionsView() }
        case "progress":
            ScreenshotTabShell(selectedTab: 1) { ScreenshotProgressView() }
        default:
            ScreenshotTabShell(selectedTab: 0) { ScreenshotFeedView() }
        }
    }
}

private struct ScreenshotTabShell<Content: View>: View {
    let selectedTab: Int
    @ViewBuilder let content: () -> Content

    var body: some View {
        TabView(selection: .constant(selectedTab)) {
            NavigationStack { selectedTab == 0 ? AnyView(content()) : AnyView(Color.climateBackground) }
                .tabItem { Label("Read", systemImage: "book.pages") }
                .tag(0)
            NavigationStack { selectedTab == 1 ? AnyView(content()) : AnyView(Color.climateBackground) }
                .tabItem { Label("My Note", systemImage: "leaf") }
                .tag(1)
            NavigationStack { Color.climateBackground }
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
                .tag(2)
        }
    }
}

private struct ScreenshotFeedView: View {
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                ScreenshotArticleCard(
                    title: "Pharmaceutical pollution",
                    excerpt: "Medicine protects our health—but traces that reach rivers can affect wildlife and water systems."
                )
                ScreenshotArticleCard(
                    title: "Lignin-based materials in tires and coatings",
                    excerpt: "A material found in plant cell walls could help replace fossil-based ingredients in everyday products."
                )
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 28)
        }
        .background(Color.climateBackground)
        .navigationTitle("The Climate Note")
    }
}

private struct ScreenshotArticleCard: View {
    let title: String
    let excerpt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CLIMATE").font(.caption.weight(.bold)).tracking(1.2).foregroundStyle(Color.climateSage)
            Text(title).font(.title2.bold())
            Text(excerpt).foregroundStyle(.secondary).lineLimit(3)
            Label("5 min read", systemImage: "clock").font(.caption).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: .rect(cornerRadius: 28))
        .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
    }
}

private struct ScreenshotSummaryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("PHARMACEUTICAL POLLUTION").font(.caption.bold()).tracking(1.1).foregroundStyle(Color.climateSage)
                Label("The note in a nutshell", systemImage: "sparkles").font(.largeTitle.bold())
                SummaryItem(title: "What’s happening", copy: ScreenshotFixtures.summary.problem)
                SummaryItem(title: "Why it matters", copy: ScreenshotFixtures.summary.whyItMatters)
                SummaryItem(title: "What we can do", copy: ScreenshotFixtures.summary.whatWeCanDo)
                Text("AI-generated summary · The original article is unchanged.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(24)
            .background(Color.climateSage.opacity(0.11), in: .rect(cornerRadius: 28))
            .padding(18)
        }
        .background(Color.climateBackground)
        .navigationTitle("Simple and clear")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SummaryItem: View {
    let title: String
    let copy: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.title3.bold())
            Text(copy).font(.body).foregroundStyle(.secondary).lineSpacing(5)
        }
    }
}

private struct ScreenshotActionsView: View {
    var body: some View {
        ScrollView {
            ClimateActionPicker(article: ScreenshotFixtures.article, actions: ScreenshotFixtures.actions)
                .padding(18)
        }
        .background(Color.climateBackground)
        .navigationTitle("Take one step")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ScreenshotProgressView: View {
    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("This week").font(.headline)
                    HStack {
                        ForEach(0..<7) { offset in
                            let completed = [0, 2, 3, 5].contains(offset)
                            VStack(spacing: 8) {
                                Text(day(offset).formatted(.dateTime.weekday(.narrow))).font(.caption)
                                Text(day(offset).formatted(.dateTime.day()))
                                    .font(.subheadline.bold())
                                    .frame(width: 38, height: 38)
                                    .background(completed ? Color.climateSage : Color.secondary.opacity(0.1), in: .circle)
                                    .foregroundStyle(completed ? .white : .primary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(22)
                .background(.background, in: .rect(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your impact").font(.headline)
                    Text("4").font(.system(size: 54, weight: .bold, design: .rounded)).foregroundStyle(Color.climateSage)
                    Text("climate actions completed").foregroundStyle(.secondary)
                    Text("1.6 kg CO₂e").font(.title2.bold())
                    Text("estimated only from supported, measurable actions")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
                .background(.background, in: .rect(cornerRadius: 24))

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Return unused medicine safely").font(.headline)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.climateSage)
                    }
                    Text("Used a local medicine take-back location instead of throwing medicine away.")
                        .foregroundStyle(.secondary)
                    Text("Pharmaceutical pollution").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(.background, in: .rect(cornerRadius: 20))
            }
            .padding(18)
        }
        .background(Color.climateBackground)
        .navigationTitle("My Note")
    }

    private func day(_ offset: Int) -> Date {
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let start = calendar.date(byAdding: .day, value: -(weekday - calendar.firstWeekday + 7) % 7, to: today) ?? today
        return calendar.date(byAdding: .day, value: offset, to: start) ?? today
    }
}

private enum ScreenshotFixtures {
    static let summary = ClimateSummary(
        problem: "Medicines can pass through people, drains, and waste systems, leaving small traces in rivers and other waterways.",
        whyItMatters: "Even tiny amounts can affect fish and other wildlife over time, while many disposal systems were not designed to remove every compound.",
        whatWeCanDo: "Use an official medicine take-back location, follow local disposal guidance, and share safe options with your household."
    )

    static let actions = [
        SuggestedAction(
            id: "action-1",
            title: "Return unused medicine safely",
            instruction: "Find a pharmacy or community medicine take-back location and bring one unused medication there this week.",
            cadence: "One trip this week",
            evidence: "Use a medicine take-back location.",
            category: "water",
            factorId: nil,
            factorQuantity: nil
        ),
        SuggestedAction(
            id: "action-2",
            title: "Check your local guidance",
            instruction: "Look up your city’s official medicine-disposal instructions and save the approved location in your phone.",
            cadence: "Ten minutes today",
            evidence: "Follow local disposal guidance.",
            category: "learning",
            factorId: nil,
            factorQuantity: nil
        ),
        SuggestedAction(
            id: "action-3",
            title: "Share one safe option",
            instruction: "Send your household the address of a verified medicine take-back location near you.",
            cadence: "Share once this week",
            evidence: "Share safe disposal options.",
            category: "civic",
            factorId: nil,
            factorQuantity: nil
        ),
    ]

    static let article = Article(
        documentID: "screenshot-pharmaceutical-pollution",
        slug: "pharmaceutical-pollution",
        title: "Pharmaceutical pollution",
        author: "The Climate Note",
        topic: "Climate",
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
        publishedAt: Date(),
        generation: ArticleGeneration(
            summary: summary,
            suggestedActions: actions,
            visualPlan: VisualPlan(
                searchQuery: "pharmaceutical pollution river research",
                altText: "A river flowing through a green landscape near a community",
                placement: "after-introduction",
                generationPrompt: "Clean editorial illustration of medicine disposal and a protected river"
            )
        ),
        coverAsset: nil
    )
}
#endif
