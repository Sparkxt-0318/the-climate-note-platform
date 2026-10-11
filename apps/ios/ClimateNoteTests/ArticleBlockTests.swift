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

    func testLegacyActionLogDecodesWithoutReflectionFields() throws {
        let data = Data(#"{
          "userID":"user-1","articleID":"article-1","articleTitle":"A story",
          "actionID":"action-1","title":"Walk","detail":"Walk one trip",
          "category":"transport","status":"planned","createdAt":0,
          "completedAt":null,"impactEstimate":null
        }"#.utf8)
        let log = try JSONDecoder().decode(ActionLog.self, from: data)
        XCTAssertNil(log.reflectionText)
        XCTAssertNil(log.reflectionUpdatedAt)
    }

    func testActionLogReflectionRoundTrips() throws {
        let log = ActionLog(
            documentID: nil,
            userID: "user-1",
            articleID: "article-1",
            articleTitle: "A story",
            actionID: "action-1",
            title: "Walk",
            detail: "Walk one trip",
            category: "transport",
            status: .planned,
            createdAt: Date(timeIntervalSince1970: 1),
            completedAt: nil,
            impactEstimate: nil,
            reflectionText: "The quieter route felt better.",
            reflectionUpdatedAt: Date(timeIntervalSince1970: 2)
        )
        let decoded = try JSONDecoder().decode(ActionLog.self, from: JSONEncoder().encode(log))
        XCTAssertEqual(decoded.reflectionText, "The quieter route felt better.")
        XCTAssertEqual(decoded.reflectionUpdatedAt, Date(timeIntervalSince1970: 2))
    }
}
