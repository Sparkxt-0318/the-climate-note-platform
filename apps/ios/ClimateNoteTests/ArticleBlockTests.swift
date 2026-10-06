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

    func testRefreshWaitsForServerAfterCachedSnapshot() {
        var state = ArticleRefreshRequestState()
        let request = state.begin()
        XCTAssertNil(state.resolve(.cachedSnapshot, for: request))
        XCTAssertEqual(state.resolve(.serverSnapshot, for: request), .success)
    }

    func testRefreshAllowsAnEmptyServerSnapshotToFinish() {
        var state = ArticleRefreshRequestState()
        let request = state.begin()
        XCTAssertEqual(state.resolve(.serverSnapshot, for: request), .success)
    }

    func testRefreshPresentationKeepsInitialCachedEmptyLoadingAndRetainsVisibleContent() {
        let initialCache = ArticleRefreshPresentationPolicy.snapshotDecision(
            isFromCache: true, hadRetainedArticles: false, incomingIsEmpty: true
        )
        XCTAssertFalse(initialCache.stopsLoading)
        XCTAssertEqual(ArticleRefreshPresentationPolicy.displayedArticles(
            current: ["retained"], incoming: [], decision: ArticleRefreshPresentationPolicy.snapshotDecision(
                isFromCache: true, hadRetainedArticles: true, incomingIsEmpty: true
            )
        ), ["retained"])
    }

    func testRefreshPresentationAppliesServerEmptyAndRetainsFailureOrTimeoutContent() {
        let serverEmpty = ArticleRefreshPresentationPolicy.snapshotDecision(
            isFromCache: false, hadRetainedArticles: true, incomingIsEmpty: true
        )
        XCTAssertTrue(serverEmpty.stopsLoading)
        XCTAssertEqual(ArticleRefreshPresentationPolicy.displayedArticles(
            current: ["retained"], incoming: [], decision: serverEmpty
        ), [])
        XCTAssertEqual(ArticleRefreshPresentationPolicy.articlesAfterTerminal(
            resolution: .failure, current: ["retained"], server: []
        ), ["retained"])
        XCTAssertEqual(ArticleRefreshPresentationPolicy.articlesAfterTerminal(
            resolution: .timedOut, current: ["retained"], server: []
        ), ["retained"])
    }

    func testRefreshFailureAndTimeoutLeaveTheCallerToRetainExistingArticles() {
        var state = ArticleRefreshRequestState()
        let failureRequest = state.begin()
        XCTAssertEqual(state.resolve(.failure, for: failureRequest), .failure)
        XCTAssertNil(state.resolve(.timeout, for: failureRequest))

        let timeoutRequest = state.begin()
        XCTAssertEqual(state.resolve(.timeout, for: timeoutRequest), .timedOut)
    }

    func testRefreshIgnoresDuplicateServerSnapshots() {
        var state = ArticleRefreshRequestState()
        let request = state.begin()
        XCTAssertEqual(state.resolve(.serverSnapshot, for: request), .success)
        XCTAssertNil(state.resolve(.serverSnapshot, for: request))
    }

    func testRefreshCancellationAndObsoleteCallbacksCannotCompleteNewRequest() {
        var state = ArticleRefreshRequestState()
        let obsolete = state.begin()
        let current = state.begin()
        XCTAssertNil(state.resolve(.serverSnapshot, for: obsolete))
        XCTAssertEqual(state.resolve(.cancelled, for: current), .cancelled)
        XCTAssertNil(state.resolve(.serverSnapshot, for: current))
    }
}
