import XCTest
@testable import ClimateNote

final class ClimateTabTests: XCTestCase {
    func testSharedTabConfigurationHasTheFourProductTabsInOrder() {
        XCTAssertEqual(ClimateTab.allCases.map(\.title), ["Home", "Explore", "Write", "Saved"])
        XCTAssertEqual(ClimateTab.allCases.map(\.systemImage), ["house", "magnifyingglass", "plus.circle", "bookmark"])
        XCTAssertEqual(ClimateTab.allCases.map(\.rawValue), [0, 1, 2, 3])
    }

    func testVerifiedPublishedInventoryIsCompleteOrderedAndUnique() {
        let expectedSlugs = [
            "benjamin-jance-iv-cities-the-savior-of-energy-chaeho",
            "the-colorful-reefs-in-finding-nemo-we-grew-up-with-are-a-lie",
            "disappearance-of-bees",
            "biotic-homogenization",
            "mangrove-and-coastal-habitat-degradation-amrii",
            "soil-salinization-seoha",
            "seeking-shade-killing-the-coral-reef-sunscreen-chemicals-and-the-crisis-of-coral-bleaching",
            "the-rise-of-microtrends-clothing-waste-edition-yeseo",
            "addressing-the-overflow-of-food-delivery-packaging-chaeho-song",
            "pharmaceutical-pollution",
            "lignin-based-materials-in-tires-and-coatings",
        ]

        XCTAssertEqual(ScreenshotFixtures.articles.count, 11)
        XCTAssertEqual(ScreenshotFixtures.articles.map(\.slug), expectedSlugs)
        XCTAssertEqual(Set(ScreenshotFixtures.articles.compactMap(\.documentID)).count, 11)
        XCTAssertEqual(Set(ScreenshotFixtures.articles.map(\.slug)).count, 11)
        XCTAssertEqual(
            ScreenshotFixtures.articles.compactMap(\.publishedAt),
            ScreenshotFixtures.articles.compactMap(\.publishedAt).sorted(by: >)
        )
    }

    func testEveryVerifiedArticleHasDistinctTopicMatchedLocalArt() {
        let assets = ScreenshotFixtures.articles.map { ClimateLocalArt.assetName(for: $0) }
        XCTAssertEqual(Set(assets).count, 11)
        XCTAssertEqual(assets.last, "PixabayTire")
        XCTAssertEqual(ClimateLocalArt.assetName(for: ScreenshotFixtures.article), "PixabayLaboratory")
    }

    func testCanonicalPharmaceuticalFixtureMatchesPublishedArticle() {
        let article = ScreenshotFixtures.article

        XCTAssertEqual(article.documentID, "drive-1WHdIl4RMFNr6FN5hIdoQoGh3CcNeV5rz")
        XCTAssertEqual(article.slug, "pharmaceutical-pollution")
        XCTAssertEqual(article.title, "Pharmaceutical pollution")
        XCTAssertNil(article.author)
        XCTAssertEqual(article.displayAuthor, "The Climate Note")
        XCTAssertEqual(article.topic, "Climate")
        XCTAssertEqual(article.readingMinutes, 3)
        XCTAssertEqual(article.contentBlocks.count, 13)
        XCTAssertEqual(article.generation?.suggestedActions.count, 3)
        XCTAssertEqual(article.generation?.visualPlan.searchQuery, "pharmaceutical pollution water testing river")
    }

    func testCanonicalShareURLHasNoDoubleSlashAfterHost() {
        let url = AppConfig.articleURL(slug: "pharmaceutical-pollution")
        XCTAssertEqual(url.absoluteString, "https://the-climate-note.vercel.app/articles/pharmaceutical-pollution")
        XCTAssertFalse(url.absoluteString.contains(".app//"))
    }
}
