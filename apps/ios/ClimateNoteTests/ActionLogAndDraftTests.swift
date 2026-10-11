import XCTest
@testable import ClimateNote

@MainActor
final class ActionLogAndDraftTests: XCTestCase {
    func testLegacyAndUnknownKindsRemainReadable() throws {
        let legacy = try JSONDecoder().decode(ActionLog.self, from: data(kind: nil))
        XCTAssertEqual(legacy.kind, .action)
        XCTAssertTrue(legacy.kind.supportsCompletion)
        XCTAssertTrue(legacy.kind.supportsReminder)
        let reflection = try JSONDecoder().decode(ActionLog.self, from: data(kind: "reflection"))
        XCTAssertEqual(reflection.kind, .reflection)
        XCTAssertFalse(reflection.kind.supportsCompletion)
        let future = try JSONDecoder().decode(ActionLog.self, from: data(kind: "pledge"))
        XCTAssertEqual(future.kind, .unknown("pledge"))
        XCTAssertFalse(future.kind.supportsCompletion)
        XCTAssertFalse(future.kind.supportsReminder)
        XCTAssertEqual(try JSONDecoder().decode(ActionLog.Kind.self, from: JSONEncoder().encode(future.kind)), .unknown("pledge"))
    }

    func testLedgerFreezesPayloadAndCompletedEntryCannotReturnToQueue() {
        let id = UUID(); var ledger = ReflectionOperationLedger()
        let first = ledger.begin(id: id, log: log(detail: "first"))
        XCTAssertEqual(ledger.begin(id: id, log: log(detail: "second")).log.detail, "first")
        ledger.observeServerLog(ActionLog(documentID: id.uuidString, userID: "u", articleID: "a", articleTitle: "A", actionID: "x", title: "T", detail: first.log.detail, category: "c", status: .completed, createdAt: Date(), completedAt: Date(), impactEstimate: nil), documentID: id.uuidString)
        ledger.transition(id: id, to: .queued)
        XCTAssertFalse(ledger.mayWrite(id: id))
        XCTAssertEqual(ledger.operation(id: id)?.state, .synced)
    }

    func testProtectedDraftsSeparateGuestFromAccount() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DraftOperationStore(directory: directory)
        _ = store.save(articleID: "a", owner: .guest, text: "guest", mode: .reflection, selectionID: nil)
        _ = store.save(articleID: "a", owner: .account("u"), text: "account", mode: .action, selectionID: nil)
        XCTAssertEqual(store.claimGuestDraftForExplicitSubmit(articleID: "a", accountID: "u")?.text, "guest")
        XCTAssertNil(store.draft(articleID: "a", owner: .guest))
        XCTAssertEqual(store.draft(articleID: "a", owner: .account("u"))?.text, "guest")
    }

    func testImpactPresentationProtectsThresholdAndLegacyImpactStillDecodes() throws {
        let estimate = try JSONDecoder().decode(ImpactEstimate.self, from: Data(#"{"value":1,"unit":"kg CO₂e","label":"L","methodology":"M","factorID":"F"}"#.utf8))
        XCTAssertTrue(estimate.isCarbonDioxideEquivalent)
        XCTAssertNil(estimate.metric)
        XCTAssertNil(estimate.factorVersion)
        XCTAssertNil(estimate.input)
        let doc = CommunityImpactDocument(schemaVersion: 1, visible: false, minimumContributors: 10, contributorCount: nil, eligibleActionCount: nil, estimatedKgCO2e: nil, updatedAt: nil, methodology: CommunityImpactMethodology(metric: "co2e", factorVersions: [], description: "M"))
        XCTAssertEqual(CommunityImpactPresentationResolver.presentation(for: doc, isFromCache: false), .threshold(doc))
    }

    func testOnlyFailedOperationsMayBeRemovedFromLocalRetryLedger() {
        let queuedID = UUID(); let failedID = UUID(); var ledger = ReflectionOperationLedger()
        _ = ledger.begin(id: queuedID, log: log(detail: "Queued"))
        _ = ledger.begin(id: failedID, log: log(detail: "Rejected"))
        ledger.transition(id: failedID, to: .failed)
        XCTAssertFalse(ledger.removeIfFailed(id: queuedID))
        XCTAssertNotNil(ledger.operation(id: queuedID))
        XCTAssertTrue(ledger.removeIfFailed(id: failedID))
        XCTAssertNil(ledger.operation(id: failedID))
    }

    func testPendingOperationSurvivesStoreRecreationWithFrozenIdentifier() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID()
        DraftOperationStore(directory: directory).persistPendingOperation(ReflectionSaveOperation(id: id, log: log(detail: "Offline text"), state: .queued))
        let restored = DraftOperationStore(directory: directory)
        XCTAssertEqual(restored.pendingOperation(id: id)?.id, id)
        XCTAssertEqual(restored.pendingOperation(id: id)?.log.detail, "Offline text")
        XCTAssertEqual(restored.pendingOperation(id: id)?.state, .queued)
    }

    func testNewDraftRevisionDoesNotReattachOrDeleteOlderPendingOperation() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = DraftOperationStore(directory: directory); let operationID = UUID()
        let first = store.save(articleID: "article", owner: .account("user"), text: "A", mode: .reflection, selectionID: nil)
        XCTAssertTrue(store.bindCurrentDraft(articleID: "article", owner: .account("user"), to: operationID))
        store.persistPendingOperation(ReflectionSaveOperation(id: operationID, log: log(detail: first.text), state: .queued))
        let second = store.save(articleID: "article", owner: .account("user"), text: "B", mode: .reflection, selectionID: nil)
        XCTAssertGreaterThan(second.revision, first.revision)
        XCTAssertNil(store.pendingOperation(articleID: "article", owner: .account("user")))
        XCTAssertFalse(store.discardDraft(articleID: "article", owner: .account("user"), onlyIfBoundTo: operationID))
        XCTAssertEqual(store.draft(articleID: "article", owner: .account("user"))?.text, "B")
    }

    func testAccountPurgeRemovesOnlyDeletedAccountsLocalData() throws {
        let directory = try temporaryDirectory(); defer { try? FileManager.default.removeItem(at: directory) }
        let store = DraftOperationStore(directory: directory)
        let deletedOperationID = UUID(); let retainedOperationID = UUID()
        _ = store.save(articleID: "deleted", owner: .account("deleted-user"), text: "remove", mode: .reflection, selectionID: nil)
        _ = store.save(articleID: "retained", owner: .account("other-user"), text: "keep", mode: .reflection, selectionID: nil)
        _ = store.save(articleID: "guest", owner: .guest, text: "keep guest", mode: .reflection, selectionID: nil)
        store.persistPendingOperation(ReflectionSaveOperation(id: deletedOperationID, log: log(userID: "deleted-user", detail: "remove"), state: .queued))
        store.persistPendingOperation(ReflectionSaveOperation(id: retainedOperationID, log: log(userID: "other-user", detail: "keep"), state: .queued))

        store.purgeAccount(userID: "deleted-user")

        XCTAssertNil(store.draft(articleID: "deleted", owner: .account("deleted-user")))
        XCTAssertNil(store.pendingOperation(id: deletedOperationID))
        XCTAssertEqual(store.draft(articleID: "retained", owner: .account("other-user"))?.text, "keep")
        XCTAssertEqual(store.draft(articleID: "guest", owner: .guest)?.text, "keep guest")
        XCTAssertNotNil(store.pendingOperation(id: retainedOperationID))
    }

    func testOnlyInitialDurableWriteMayRemainQueuedWhenOffline() {
        XCTAssertEqual(ReflectionWriteFailurePolicy.state(after: 14, attempt: .initialDurableWrite), .queued)
        XCTAssertEqual(ReflectionWriteFailurePolicy.state(after: 14, attempt: .retryTransaction), .failed)
        XCTAssertEqual(ReflectionWriteFailurePolicy.state(after: 4, attempt: .retryTransaction), .failed)
    }

    func testGuestSubmitResumesOnceOnlyAfterBothUserSourcesAgree() {
        let id = UUID(); var state = GuestSubmitResumeGuard()
        state.request(operationID: id)
        XCTAssertNil(state.consumeIfReady(authUserID: "user", observedUserID: nil))
        XCTAssertNil(state.consumeIfReady(authUserID: "user", observedUserID: "other"))
        XCTAssertEqual(state.consumeIfReady(authUserID: "user", observedUserID: "user"), id)
        XCTAssertNil(state.consumeIfReady(authUserID: "user", observedUserID: "user"))
        state.request(operationID: UUID()); state.cancelIfUnauthenticated(nil)
        XCTAssertNil(state.consumeIfReady(authUserID: "user", observedUserID: "user"))
    }

    func testPersonalWritingAndOwnerTransitionsFollowPickerPolicy() {
        XCTAssertTrue(ClimateActionPickerPolicy.permitsPersonalWriting(actions: []))
        XCTAssertEqual(ClimateActionPickerPolicy.defaultMode(actions: [], initialSelection: nil, initialCustomText: ""), .reflection)
        XCTAssertTrue(ClimateActionPickerPolicy.shouldClearForEmptyOwner(previousOwnerKey: "account-first", nextOwnerKey: "account-second"))
        XCTAssertTrue(ClimateActionPickerPolicy.shouldClearForEmptyOwner(previousOwnerKey: "account-first", nextOwnerKey: "guest"))
        XCTAssertFalse(ClimateActionPickerPolicy.shouldClearForEmptyOwner(previousOwnerKey: nil, nextOwnerKey: "guest"))
        XCTAssertFalse(ClimateActionPickerPolicy.shouldClearForEmptyOwner(previousOwnerKey: "account-first", nextOwnerKey: "account-first"))
    }

    func testPersonalImpactCountsOnlyCompletedActionsWithSupportedCarbonEstimates() {
        let supported = ImpactEstimate(value: 3.2, unit: "kg CO₂e", label: "Estimated", methodology: "EPA", factorID: "passenger_vehicle_miles_avoided", metric: "co2e", factorVersion: "epa-2025.1")
        let logs = [
            impactLog(kind: .action, status: .completed, impact: supported),
            impactLog(kind: .action, status: .completed, impact: nil),
            impactLog(kind: .action, status: .planned, impact: supported),
            impactLog(kind: .reflection, status: .completed, impact: supported),
        ]
        let summary = PersonalImpactSummary(logs: logs)
        XCTAssertEqual(summary.completedActionCount, 2)
        XCTAssertEqual(summary.supportedActionCount, 1)
        XCTAssertEqual(summary.estimatedKgCO2e, 3.2)
        XCTAssertEqual(summary.factorVersions, ["epa-2025.1"])
    }

    func testCommunityPresentationMarksStaleVisibleAggregate() {
        let oldDate = Date(timeIntervalSince1970: 1)
        let document = CommunityImpactDocument(schemaVersion: 1, visible: true, minimumContributors: 10, contributorCount: 12, eligibleActionCount: 38, estimatedKgCO2e: 94.6, updatedAt: oldDate, methodology: CommunityImpactMethodology(metric: "co2e", factorVersions: ["epa-2025.1"], description: "Versioned"))
        XCTAssertEqual(CommunityImpactPresentationResolver.presentation(for: document, isFromCache: false, now: oldDate.addingTimeInterval(100), staleAfter: 50), .populated(document, isStale: true))
    }

    func testLicensedCoverDecodesServerProvenanceWithoutDroppingMedia() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "url": "https://cdn.example/cover.jpg",
            "altText": "River water around a stone",
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

    func testRefreshPresentationRetainsUsefulContentUntilServerResolution() {
        let cachedEmpty = ArticleRefreshPresentationPolicy.snapshotDecision(isFromCache: true, hadRetainedArticles: false, incomingIsEmpty: true)
        XCTAssertFalse(cachedEmpty.stopsLoading)
        let cachedWithRetained = ArticleRefreshPresentationPolicy.snapshotDecision(isFromCache: true, hadRetainedArticles: true, incomingIsEmpty: false)
        XCTAssertFalse(cachedWithRetained.replacesArticles)
        XCTAssertEqual(ArticleRefreshPresentationPolicy.displayedArticles(current: ["retained"], incoming: ["cached"], decision: cachedWithRetained), ["retained"])
        XCTAssertEqual(ArticleRefreshPresentationPolicy.articlesAfterTerminal(resolution: .failure, current: ["retained"], server: ["server"]), ["retained"])
        XCTAssertEqual(ArticleRefreshPresentationPolicy.articlesAfterTerminal(resolution: .success, current: ["retained"], server: ["server"]), ["server"])
    }

    private func data(kind: String?) -> Data {
        var object: [String: Any] = ["userID":"u", "articleID":"a", "articleTitle":"A", "actionID":"x", "title":"T", "detail":"D", "category":"c", "status":"planned", "createdAt":0]
        object["kind"] = kind
        return try! JSONSerialization.data(withJSONObject: object)
    }
    private func log(userID: String = "u", detail: String) -> ActionLog { ActionLog(userID: userID, articleID: "a", articleTitle: "A", actionID: "x", title: "T", detail: detail, category: "c", status: .planned, createdAt: Date(), completedAt: nil, impactEstimate: nil) }
    private func impactLog(kind: ActionLog.Kind, status: ActionLog.Status, impact: ImpactEstimate?) -> ActionLog { ActionLog(documentID: UUID().uuidString, userID: "u", articleID: "a", articleTitle: "A", actionID: UUID().uuidString, title: "T", detail: "D", category: "transport", status: status, kind: kind, createdAt: Date(), completedAt: status == .completed ? Date() : nil, impactEstimate: impact) }
    private func temporaryDirectory() throws -> URL { let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true); try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url }
}
