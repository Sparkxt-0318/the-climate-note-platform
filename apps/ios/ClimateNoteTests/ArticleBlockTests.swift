import XCTest
@testable import ClimateNote

final class ArticleBlockTests: XCTestCase {
    func testCommunityImpactDecodesServerSnapshot() throws {
        let data = Data(#"{"schemaVersion":1,"completedActions":12,"estimatedKgCO2e":1.6,"estimatedActions":2,"updatedAt":"2026-09-12T12:00:00.000Z"}"#.utf8)
        let snapshot = try JSONDecoder().decode(CommunityImpact.self, from: data)
        XCTAssertTrue(snapshot.isValid)
        XCTAssertNotNil(snapshot.date)
        XCTAssertEqual(snapshot.completedActions, 12)
    }

    func testCommunityImpactRejectsCorruptTotals() {
        XCTAssertFalse(CommunityImpact(schemaVersion: 1, completedActions: 1, estimatedKgCO2e: 2, estimatedActions: 2, updatedAt: "2026-09-12T12:00:00Z").isValid)
        XCTAssertFalse(CommunityImpact(schemaVersion: 2, completedActions: 0, estimatedKgCO2e: 0, estimatedActions: 0, updatedAt: "invalid").isValid)
    }

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
