import XCTest
@testable import ClimateNote

final class PixabayCoverSelectorTests: XCTestCase {
    func testSearchQueryPrefersVisualPlanThenFallsBackToTopicAndTitle() {
        let withPlan = makeArticle(
            title: "Pharmaceutical pollution",
            topic: "Water",
            searchQuery: "pharmaceutical pollution river research"
        )
        XCTAssertEqual(
            PixabayCoverSelector.searchQuery(for: withPlan),
            "pharmaceutical pollution river research"
        )

        let withoutPlan = makeArticle(
            title: "A different future for everyday materials",
            topic: "Materials",
            searchQuery: nil
        )
        let query = PixabayCoverSelector.searchQuery(for: withoutPlan)
        XCTAssertTrue(query.hasPrefix("Materials"))
        XCTAssertTrue(query.contains("different") || query.contains("future") || query.contains("everyday"))
        XCTAssertLessThanOrEqual(query.count, 100)
    }

    func testRankPrefersLandscapeHighEngagementPhotos() {
        let portrait = PixabayHit(
            id: 1,
            largeImageURL: "https://cdn.example/portrait.jpg",
            imageWidth: 900,
            imageHeight: 1400,
            views: 100,
            downloads: 10,
            likes: 5
        )
        let landscape = PixabayHit(
            id: 2,
            largeImageURL: "https://cdn.example/landscape.jpg",
            imageWidth: 1600,
            imageHeight: 900,
            views: 20_000,
            downloads: 2_000,
            likes: 400
        )
        let ranked = PixabayCoverSelector.rank([portrait, landscape])
        XCTAssertEqual(ranked.first?.id, 2)
        XCTAssertGreaterThan(PixabayCoverSelector.score(landscape), PixabayCoverSelector.score(portrait))
    }

    func testCoverAssetMapsPixabayProvenance() throws {
        let article = makeArticle(
            title: "Pharmaceutical pollution",
            topic: "Water",
            searchQuery: "clean river landscape",
            altText: "A protected river landscape"
        )
        let hit = PixabayHit(
            id: 42,
            pageURL: "https://pixabay.com/photos/example-42/",
            largeImageURL: "https://cdn.pixabay.com/photo/example.jpg",
            imageWidth: 1600,
            imageHeight: 900,
            user: "RiverPhotographer"
        )
        let cover = try XCTUnwrap(PixabayCoverSelector.coverAsset(from: hit, article: article))
        XCTAssertEqual(cover.provider, "pixabay")
        XCTAssertEqual(cover.providerAssetId, "42")
        XCTAssertEqual(cover.photographer, "RiverPhotographer")
        XCTAssertEqual(cover.altText, "A protected river landscape")
        XCTAssertEqual(cover.licenseUrl?.host, "pixabay.com")
        XCTAssertFalse(cover.generated)
        XCTAssertTrue(article.needsPixabayCover)
    }

    private func makeArticle(
        title: String,
        topic: String,
        searchQuery: String?,
        altText: String = "Story cover"
    ) -> Article {
        let generation: ArticleGeneration? = {
            guard let searchQuery else { return nil }
            return ArticleGeneration(
                summary: ClimateSummary(
                    problem: "Problem",
                    whyItMatters: "Why",
                    whatWeCanDo: "Action"
                ),
                suggestedActions: [],
                visualPlan: VisualPlan(
                    searchQuery: searchQuery,
                    altText: altText,
                    placement: "cover",
                    generationPrompt: "Editorial photograph"
                )
            )
        }()

        return Article(
            documentID: "test-\(topic.lowercased())",
            slug: "test-\(topic.lowercased())",
            title: title,
            author: "The Climate Note",
            topic: topic,
            excerpt: "Excerpt",
            status: "published",
            contentBlocks: [.paragraph("Body")],
            sourceLinks: [],
            externalLinks: nil,
            readingMinutes: 4,
            publishedAt: Date(timeIntervalSince1970: 1_780_000_000),
            generation: generation,
            coverAsset: nil
        )
    }
}
