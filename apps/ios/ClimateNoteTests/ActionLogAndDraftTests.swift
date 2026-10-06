import Foundation
import XCTest
@testable import ClimateNote

@MainActor
final class ActionLogAndDraftTests: XCTestCase {
    func testLegacyLogWithoutKindDefaultsToAction() throws {
        let log = try JSONDecoder().decode(ActionLog.self, from: legacyLogData(kind: nil))
        XCTAssertEqual(log.kind, .action)
        XCTAssertTrue(log.kind.supportsCompletion)
        XCTAssertTrue(log.kind.supportsReminder)
    }

    func testReflectionAndUnknownKindsDecodeWithoutDroppingEntry() throws {
        let reflection = try JSONDecoder().decode(ActionLog.self, from: legacyLogData(kind: "reflection"))
        XCTAssertEqual(reflection.kind, .reflection)
        XCTAssertFalse(reflection.kind.supportsCompletion)

        let future = try JSONDecoder().decode(ActionLog.self, from: legacyLogData(kind: "pledge"))
        XCTAssertEqual(future.kind, .unknown("pledge"))
        XCTAssertFalse(future.kind.supportsCompletion)
        XCTAssertFalse(future.kind.supportsReminder)
        XCTAssertEqual(try JSONDecoder().decode(ActionLog.Kind.self, from: JSONEncoder().encode(future.kind)), .unknown("pledge"))
    }

    func testOperationLedgerFreezesIDAndPayloadAcrossRetry() {
        let id = UUID()
        var ledger = ReflectionOperationLedger()
        let first = ledger.begin(id: id, log: makeLog(detail: "Frozen first text"))
        let retry = ledger.begin(id: id, log: makeLog(detail: "Changed text"))
        XCTAssertEqual(first.id, retry.id)
        XCTAssertEqual(retry.documentID, id.uuidString)
        XCTAssertEqual(retry.log.detail, "Frozen first text")
    }

    func testCompletedServerLogCannotBeReturnedToQueuedByLateRetry() {
        let id = UUID()
        var ledger = ReflectionOperationLedger()
        _ = ledger.begin(id: id, log: makeLog(detail: "Keep complete"))
        let completed = ActionLog(
            documentID: id.uuidString, userID: "user", articleID: "article", articleTitle: "Article",
            actionID: "action", title: "Title", detail: "Keep complete", category: "custom",
            status: .completed, createdAt: Date(timeIntervalSince1970: 1), completedAt: Date(timeIntervalSince1970: 2), impactEstimate: nil
        )
        ledger.observeServerLog(completed, documentID: id.uuidString)
        ledger.transition(id: id, to: .queued)
        XCTAssertFalse(ledger.mayWrite(id: id))
        XCTAssertEqual(ledger.operation(id: id)?.state, .synced)
    }

    func testOnlyFailedOperationsMayBeRemovedFromLocalRetryLedger() {
        let queuedID = UUID()
        let failedID = UUID()
        var ledger = ReflectionOperationLedger()
        _ = ledger.begin(id: queuedID, log: makeLog(detail: "Queued"))
        _ = ledger.begin(id: failedID, log: makeLog(detail: "Rejected"))
        ledger.transition(id: failedID, to: .failed)

        XCTAssertFalse(ledger.removeIfFailed(id: queuedID))
        XCTAssertNotNil(ledger.operation(id: queuedID))
        XCTAssertTrue(ledger.removeIfFailed(id: failedID))
        XCTAssertNil(ledger.operation(id: failedID))
    }

    func testDraftsStaySeparatedAndGuestClaimRequiresExplicitMethod() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DraftOperationStore(directory: directory)
        _ = store.save(articleID: "article", owner: .guest, text: "Guest text", mode: .reflection, selectionID: nil)
        _ = store.save(articleID: "article", owner: .account("user"), text: "Account text", mode: .action, selectionID: nil)
        XCTAssertEqual(store.draft(articleID: "article", owner: .guest)?.text, "Guest text")
        XCTAssertEqual(store.draft(articleID: "article", owner: .account("user"))?.text, "Account text")

        let claimed = store.claimGuestDraftForExplicitSubmit(articleID: "article", accountID: "user")
        XCTAssertEqual(claimed?.text, "Guest text")
        XCTAssertNil(store.draft(articleID: "article", owner: .guest))
        XCTAssertEqual(store.draft(articleID: "article", owner: .account("user"))?.text, "Guest text")
    }

    func testPendingOperationSurvivesStoreRecreationWithFrozenIdentifier() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID()
        let initial = DraftOperationStore(directory: directory)
        initial.persistPendingOperation(ReflectionSaveOperation(id: id, log: makeLog(detail: "Offline text"), state: .queued))
        let restored = DraftOperationStore(directory: directory)
        XCTAssertEqual(restored.pendingOperation(id: id)?.id, id)
        XCTAssertEqual(restored.pendingOperation(id: id)?.log.detail, "Offline text")
        XCTAssertEqual(restored.pendingOperation(id: id)?.state, .queued)
    }

    func testNewDraftRevisionDoesNotReattachOrDeleteOlderPendingOperation() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DraftOperationStore(directory: directory)
        let operationID = UUID()
        let first = store.save(articleID: "article", owner: .account("user"), text: "A", mode: .reflection, selectionID: nil)
        XCTAssertTrue(store.bindCurrentDraft(articleID: "article", owner: .account("user"), to: operationID))
        store.persistPendingOperation(ReflectionSaveOperation(id: operationID, log: makeLog(detail: first.text), state: .queued))

        let second = store.save(articleID: "article", owner: .account("user"), text: "B", mode: .reflection, selectionID: nil)
        XCTAssertGreaterThan(second.revision, first.revision)
        XCTAssertNil(store.pendingOperation(articleID: "article", owner: .account("user")))
        XCTAssertFalse(store.discardDraft(articleID: "article", owner: .account("user"), onlyIfBoundTo: operationID))
        XCTAssertEqual(store.draft(articleID: "article", owner: .account("user"))?.text, "B")
    }

    func testOnlyInitialDurableWriteMayRemainQueuedWhenOffline() {
        XCTAssertEqual(ReflectionWriteFailurePolicy.state(after: 14, attempt: .initialDurableWrite), .queued)
        XCTAssertEqual(ReflectionWriteFailurePolicy.state(after: 14, attempt: .retryTransaction), .failed)
        XCTAssertEqual(ReflectionWriteFailurePolicy.state(after: 4, attempt: .retryTransaction), .failed)
    }

    func testGuestSubmitResumesOnceOnlyAfterBothUserSourcesAgree() {
        let id = UUID()
        var guardState = GuestSubmitResumeGuard()
        guardState.request(operationID: id)
        XCTAssertNil(guardState.consumeIfReady(authUserID: "user", observedUserID: nil))
        XCTAssertNil(guardState.consumeIfReady(authUserID: "user", observedUserID: "other"))
        XCTAssertEqual(guardState.consumeIfReady(authUserID: "user", observedUserID: "user"), id)
        XCTAssertNil(guardState.consumeIfReady(authUserID: "user", observedUserID: "user"))
        guardState.request(operationID: UUID())
        guardState.cancelIfUnauthenticated(nil)
        XCTAssertNil(guardState.consumeIfReady(authUserID: "user", observedUserID: "user"))
    }

    func testPersonalWritingRemainsAvailableWithoutSuggestions() {
        XCTAssertTrue(ClimateActionPickerPolicy.permitsPersonalWriting(actions: []))
        XCTAssertEqual(ClimateActionPickerPolicy.defaultMode(actions: [], initialSelection: nil, initialCustomText: ""), .reflection)
    }

    func testEmptyDraftForNewOwnerClearsRetainedAccountPresentation() {
        XCTAssertTrue(ClimateActionPickerPolicy.shouldClearForEmptyOwner(
            previousOwnerKey: "account-first", nextOwnerKey: "account-second"
        ))
        XCTAssertTrue(ClimateActionPickerPolicy.shouldClearForEmptyOwner(
            previousOwnerKey: "account-first", nextOwnerKey: "guest"
        ))
        XCTAssertFalse(ClimateActionPickerPolicy.shouldClearForEmptyOwner(
            previousOwnerKey: nil, nextOwnerKey: "guest"
        ))
        XCTAssertFalse(ClimateActionPickerPolicy.shouldClearForEmptyOwner(
            previousOwnerKey: "account-first", nextOwnerKey: "account-first"
        ))
    }

    func testPersonalImpactCountsOnlyCompletedActionsWithSupportedCarbonEstimates() {
        let supported = ImpactEstimate(
            value: 3.2,
            unit: "kg CO₂e",
            label: "Estimated avoided emissions",
            methodology: "EPA passenger vehicle factor",
            factorID: "passenger_vehicle_miles_avoided",
            metric: "co2e",
            factorVersion: "epa-2025.1"
        )
        let logs = [
            makeImpactLog(kind: .action, status: .completed, impact: supported),
            makeImpactLog(kind: .action, status: .completed, impact: nil),
            makeImpactLog(kind: .action, status: .planned, impact: supported),
            makeImpactLog(kind: .reflection, status: .completed, impact: supported),
        ]

        let summary = PersonalImpactSummary(logs: logs)
        XCTAssertEqual(summary.completedActionCount, 2)
        XCTAssertEqual(summary.supportedActionCount, 1)
        XCTAssertEqual(summary.estimatedKgCO2e, 3.2)
        XCTAssertEqual(summary.factorVersions, ["epa-2025.1"])
    }

    func testLegacyImpactEstimateDecodesWithoutNewMetadata() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "value": 1.5,
            "unit": "kg CO₂e",
            "label": "Estimated avoided emissions",
            "methodology": "Legacy method",
            "factorID": "legacy-factor",
        ])
        let estimate = try JSONDecoder().decode(ImpactEstimate.self, from: data)
        XCTAssertNil(estimate.metric)
        XCTAssertNil(estimate.factorVersion)
        XCTAssertNil(estimate.input)
        XCTAssertTrue(estimate.isCarbonDioxideEquivalent)
    }

    func testLicensedCoverDecodesServerISOProvenanceWithoutDroppingArticleMedia() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "url": "https://cdn.example/cover.jpg",
            "altText": "River water moving around a smooth stone",
            "caption": "River water",
            "attribution": "Photo by Example via Pexels",
            "license": "Pexels License",
            "licenseUrl": "https://www.pexels.com/license/",
            "sourceUrl": "https://www.pexels.com/photo/example/",
            "generated": false,
            "provider": "pexels",
            "providerAssetId": "123",
            "photographer": "Example",
            "contentHash": String(repeating: "a", count: 64),
            "retrievedAt": "2026-10-02T16:00:00.000Z",
        ])
        let cover = try JSONDecoder().decode(CoverAsset.self, from: data)
        XCTAssertEqual(cover.provider, "pexels")
        XCTAssertEqual(cover.retrievedAt, "2026-10-02T16:00:00.000Z")
        XCTAssertEqual(cover.licenseUrl?.host, "www.pexels.com")
    }

    func testCommunityImpactPresentationProtectsThresholdAndMarksStaleData() {
        let methodology = CommunityImpactMethodology(
            metric: "co2e",
            factorVersions: ["epa-2025.1"],
            description: "Versioned server factors"
        )
        let hidden = CommunityImpactDocument(
            schemaVersion: 1,
            visible: false,
            minimumContributors: 10,
            contributorCount: nil,
            eligibleActionCount: nil,
            estimatedKgCO2e: nil,
            updatedAt: nil,
            methodology: methodology
        )
        XCTAssertEqual(
            CommunityImpactPresentationResolver.presentation(for: hidden, isFromCache: false),
            .threshold(hidden)
        )

        let oldDate = Date(timeIntervalSince1970: 1)
        let visible = CommunityImpactDocument(
            schemaVersion: 1,
            visible: true,
            minimumContributors: 10,
            contributorCount: 12,
            eligibleActionCount: 38,
            estimatedKgCO2e: 94.6,
            updatedAt: oldDate,
            methodology: methodology
        )
        XCTAssertEqual(
            CommunityImpactPresentationResolver.presentation(
                for: visible,
                isFromCache: false,
                now: oldDate.addingTimeInterval(100),
                staleAfter: 50
            ),
            .populated(visible, isStale: true)
        )
    }

    private func legacyLogData(kind: String?) -> Data {
        var value: [String: Any] = [
            "userID": "user", "articleID": "article", "articleTitle": "Article", "actionID": "action",
            "title": "Title", "detail": "Detail", "category": "custom", "status": "planned",
            "createdAt": 0
        ]
        if let kind { value["kind"] = kind }
        return try! JSONSerialization.data(withJSONObject: value)
    }

    private func makeLog(detail: String) -> ActionLog {
        ActionLog(
            documentID: nil, userID: "user", articleID: "article", articleTitle: "Article", actionID: "action",
            title: "Title", detail: detail, category: "custom", status: .planned,
            createdAt: Date(timeIntervalSince1970: 1), completedAt: nil, impactEstimate: nil
        )
    }

    private func makeImpactLog(
        kind: ActionLog.Kind,
        status: ActionLog.Status,
        impact: ImpactEstimate?
    ) -> ActionLog {
        ActionLog(
            documentID: UUID().uuidString,
            userID: "user",
            articleID: "article",
            articleTitle: "Article",
            actionID: UUID().uuidString,
            title: "Title",
            detail: "Detail",
            category: "transport",
            status: status,
            kind: kind,
            createdAt: Date(timeIntervalSince1970: 1),
            completedAt: status == .completed ? Date(timeIntervalSince1970: 2) : nil,
            impactEstimate: impact
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
