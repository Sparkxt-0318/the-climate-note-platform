import XCTest
@testable import ClimateNote

final class PixabayCoverSelectorTests: XCTestCase {
    func testSearchQueryUsesVisualPlanThenTopicAndTitleFallback() {
        XCTAssertEqual(PixabayCoverSelector.searchQuery(for: article(query: "clean river research")), "clean river research")
        let fallback = PixabayCoverSelector.searchQuery(for: article(query: nil))
        XCTAssertTrue(fallback.hasPrefix("Water"))
        XCTAssertLessThanOrEqual(fallback.count, 100)
    }

    func testRankingPrefersLandscapeEngagementAndMapsProvenance() throws {
        let portrait = PixabayHit(id: 1, largeImageURL: "https://example.com/p.jpg", imageWidth: 900, imageHeight: 1400, views: 100)
        let landscape = PixabayHit(id: 2, largeImageURL: "https://example.com/l.jpg", imageWidth: 1600, imageHeight: 900, views: 20_000, downloads: 2_000, likes: 400, user: "River")
        XCTAssertEqual(PixabayCoverSelector.rank([portrait, landscape]).first?.id, 2)
        XCTAssertGreaterThan(PixabayCoverSelector.score(landscape), PixabayCoverSelector.score(portrait))
        let cover = try XCTUnwrap(PixabayCoverSelector.coverAsset(from: landscape, article: article(query: "river")))
        XCTAssertEqual(cover.provider, "pixabay")
        XCTAssertEqual(cover.providerAssetId, "2")
        XCTAssertEqual(cover.photographer, "River")
        XCTAssertEqual(cover.altText, "River")
        XCTAssertEqual(cover.licenseUrl?.host, "pixabay.com")
        XCTAssertFalse(cover.generated)
        XCTAssertTrue(article(query: "river").needsPixabayCover)
    }

    private func article(query: String?) -> Article {
        Article(documentID: "test", slug: "test-water", title: "A different future for water", author: nil, topic: "Water", excerpt: "Excerpt", status: "published", contentBlocks: [.paragraph("Body")], sourceLinks: [], externalLinks: nil, readingMinutes: 4, publishedAt: Date(), generation: query.map { ArticleGeneration(summary: ClimateSummary(problem: "P", whyItMatters: "W", whatWeCanDo: "A"), suggestedActions: [], visualPlan: VisualPlan(searchQuery: $0, altText: "River", placement: "cover", generationPrompt: "photo")) }, coverAsset: nil)
    }
}
