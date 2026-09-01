import XCTest
@testable import ClimateNote

final class ArticleBlockTests: XCTestCase {
    func testDecodesParagraphAndListWithoutChangingText() throws {
        let data = Data(#"[{"type":"paragraph","text":"Exact source sentence."},{"type":"bulletedList","items":["One","Two"]}]"#.utf8)
        let blocks = try JSONDecoder().decode([ArticleBlock].self, from: data)
        XCTAssertEqual(blocks, [.paragraph("Exact source sentence."), .bulletedList(["One", "Two"])])
    }

    func testImpactEstimateUsesCatalogAndNotAIArithmetic() {
        let action = SuggestedAction(
            id: "action-1",
            title: "Walk two miles",
            instruction: "Replace one two-mile car trip with walking.",
            cadence: "Once this week",
            evidence: "Exact source sentence.",
            category: "transport",
            factorId: "passenger-vehicle-mile-avoided-us",
            factorQuantity: 2
        )
        XCTAssertEqual(ImpactFactorCatalog.estimate(for: action)?.value, 0.8)
    }
}
