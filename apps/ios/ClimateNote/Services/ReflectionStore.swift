import Combine
import Foundation
import FirebaseCore
import FirebaseFirestore

@MainActor
final class ReflectionStore: ObservableObject {
    @Published private(set) var logs: [ActionLog] = []
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    /// The picker waits for this to match AuthService before resuming an
    /// explicitly requested guest submission.
    @Published private(set) var observedUserID: String?
    @Published private(set) var operationStates: [String: ReflectionSaveState] = [:]

    private var listener: ListenerRegistration?
    private var userID: String?
    private var observationID = UUID()
    private var ledger = ReflectionOperationLedger()
    private let protectedDrafts: DraftOperationStore

    init(protectedDrafts: DraftOperationStore = .shared) {
        self.protectedDrafts = protectedDrafts
    }

    func observe(userID: String?) {
        guard self.userID != userID else { return }
        self.userID = userID
        ledger = ReflectionOperationLedger(operations: protectedDrafts.allPendingOperations(userID: userID))
        observedUserID = userID
        logs = []
        restartObservation()
    }

    func retry() { restartObservation() }

    func operationState(for operationID: UUID) -> ReflectionSaveState? {
        operationStates[operationID.uuidString]
    }

    /// A failed operation has received a terminal local rejection. This only
    /// removes protected retry content; queued or server-synced writes are
    /// deliberately not cancellable from the device.
    @discardableResult
    func discardFailedOperation(_ operationID: UUID) -> Bool {
        guard ledger.removeIfFailed(id: operationID) else { return false }
        protectedDrafts.clearPendingOperation(id: operationID)
        protectedDrafts.clearRejectedLog(id: operationID.uuidString)
        publishOperationStates()
        return true
    }

    private func restartObservation() {
        observationID = UUID()
        listener?.remove()
        listener = nil
        errorMessage = nil
        isLoading = false
        guard let userID else { return }
        guard FirebaseApp.app() != nil else {
            errorMessage = "Your notes are unavailable right now. Please try again later."
            return
        }
        isLoading = true
        let currentObservation = observationID
        listener = Firestore.firestore()
            .collection("users").document(userID).collection("actionLogs")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.observationID == currentObservation, self.userID == userID else { return }
                    self.isLoading = false
                    if error != nil {
                        self.errorMessage = "We couldn’t refresh your notes. Check your connection and try again."
                        return
                    }
                    guard let snapshot else { return }
                    self.logs = snapshot.documents.compactMap { document in
                        (try? document.data(as: ActionLog.self))?.replacingDocumentID(document.documentID)
                    }
                    self.applyMetadata(from: snapshot)
                    self.errorMessage = nil
                }
            }
    }

    private func applyMetadata(from snapshot: QuerySnapshot) {
        for document in snapshot.documents {
            let documentID = document.documentID
            guard let operationID = UUID(uuidString: documentID) else { continue }
            if let decoded = try? document.data(as: ActionLog.self) {
                let log = decoded.replacingDocumentID(documentID)
                // A relaunch or a second device may surface a UUID document
                // before this process has a ledger entry. Adopt it so metadata
                // transitions are still tracked without issuing another write.
                if ledger.operation(id: operationID) == nil {
                    _ = ledger.begin(id: operationID, log: log)
                }
                ledger.observeServerLog(log, documentID: documentID)
            }
            if document.metadata.hasPendingWrites {
                ledger.transition(id: operationID, to: .queued)
            } else if !snapshot.metadata.isFromCache {
                // A cached no-pending snapshot is not proof that the server has
                // accepted the write, so only a non-cache snapshot becomes synced.
                ledger.transition(id: operationID, to: .synced)
                protectedDrafts.clearRejectedLog(id: documentID)
            }
            persistOperation(operationID)
        }
        publishOperationStates()
    }

    /// Starts or retries one immutable save intent. Supplying the same
    /// operation ID always returns and writes the original frozen payload.
    @discardableResult
    func plan(
        article: Article,
        action: SuggestedAction?,
        customText: String,
        userID: String,
        kind: ActionLog.Kind = .action,
        operationID: UUID? = nil
    ) async throws -> ReflectionSaveOperation {
        guard FirebaseApp.app() != nil, !userID.isEmpty, self.userID == userID else {
            throw JournalError.unavailable
        }
        let intentID = operationID ?? UUID()
        let operation: ReflectionSaveOperation
        let isRetry: Bool
        if let existing = ledger.operation(id: intentID) {
            guard existing.log.userID == userID else { throw JournalError.unavailable }
            operation = existing
            isRetry = true
        } else {
            let title = action?.title ?? (kind == .reflection ? "My reflection" : "My own climate action")
            let detail = action?.instruction ?? customText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !detail.isEmpty else { throw JournalError.emptyNote }
            let log = ActionLog(
                documentID: intentID.uuidString,
                userID: userID,
                articleID: article.id,
                articleTitle: article.title,
                actionID: action?.id ?? (kind == .reflection ? "reflection" : "custom"),
                title: title,
                detail: detail,
                category: action?.category ?? (kind == .reflection ? "reflection" : "custom"),
                status: .planned,
                kind: kind,
                createdAt: Date(),
                completedAt: nil,
                impactEstimate: kind == .action ? ImpactFactorCatalog.estimate(for: action) : nil
            )
            operation = ledger.begin(id: intentID, log: log)
            isRetry = false
        }

        guard ledger.mayWrite(id: intentID) else { return operation }
        ledger.transition(id: intentID, to: .queued)
        persistOperation(intentID)
        publishOperationStates()
        enqueue(operation, isRetry: isRetry)
        return ledger.operation(id: intentID) ?? operation
    }

    /// A retry uses a transaction: an existing completed document is observed
    /// and left untouched, so stale planned data can never overwrite it.
    private func enqueue(_ operation: ReflectionSaveOperation, isRetry: Bool) {
        let reference = Firestore.firestore()
            .collection("users").document(operation.log.userID).collection("actionLogs")
            .document(operation.documentID)
        if isRetry {
            Firestore.firestore().runTransaction({ transaction, errorPointer in
                let existing: DocumentSnapshot
                do {
                    existing = try transaction.getDocument(reference)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                if existing.exists, existing.data()?["status"] as? String == ActionLog.Status.completed.rawValue {
                    return false
                }
                do {
                    try transaction.setData(from: operation.log, forDocument: reference)
                    return true
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }) { [weak self] _, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let error { self.handleWriteFailure(error, operation: operation, attempt: .retryTransaction) }
                    else {
                        self.ledger.transition(id: operation.id, to: .synced)
                        self.protectedDrafts.clearRejectedLog(id: operation.documentID)
                        self.persistOperation(operation.id)
                        self.publishOperationStates()
                    }
                }
            }
        } else {
            do {
                try reference.setData(from: operation.log) { [weak self] error in
                    Task { @MainActor in
                        guard let self else { return }
                        if let error { self.handleWriteFailure(error, operation: operation, attempt: .initialDurableWrite) }
                        else {
                            // The write callback is a server acknowledgement;
                            // cache-only listeners never produce this state.
                            self.ledger.transition(id: operation.id, to: .synced)
                            self.protectedDrafts.clearRejectedLog(id: operation.documentID)
                            self.persistOperation(operation.id)
                            self.publishOperationStates()
                        }
                    }
                }
            } catch {
                handleWriteFailure(error, operation: operation, attempt: .initialDurableWrite)
            }
        }
    }

    private func handleWriteFailure(_ error: Error, operation: ReflectionSaveOperation, attempt: ReflectionWriteAttempt) {
        let code = (error as NSError).code
        if ReflectionWriteFailurePolicy.state(after: code, attempt: attempt) == .queued {
            ledger.transition(id: operation.id, to: .queued)
        } else {
            ledger.transition(id: operation.id, to: .failed)
            protectedDrafts.retainRejected(operation.log)
        }
        persistOperation(operation.id)
        publishOperationStates()
    }

    func complete(_ log: ActionLog) async throws {
        guard let userID, userID == log.userID, let documentID = log.documentID,
              FirebaseApp.app() != nil else { throw JournalError.unavailable }
        guard log.status == .planned, log.kind.supportsCompletion else { return }
        try await Firestore.firestore()
            .collection("users").document(userID).collection("actionLogs").document(documentID)
            .updateData(["status": ActionLog.Status.completed.rawValue, "completedAt": Date()])
    }

    func reopen(_ log: ActionLog) async throws {
        guard let userID, userID == log.userID, let documentID = log.documentID,
              FirebaseApp.app() != nil else { throw JournalError.unavailable }
        guard log.status == .completed, log.kind.supportsCompletion else { return }
        try await Firestore.firestore()
            .collection("users").document(userID).collection("actionLogs").document(documentID)
            .updateData(["status": ActionLog.Status.planned.rawValue, "completedAt": NSNull()])
    }

    private func publishOperationStates() {
        operationStates = Dictionary(uniqueKeysWithValues: ledger.operations.map { ($0.key.uuidString, $0.value.state) })
    }

    private func persistOperation(_ id: UUID) {
        guard let operation = ledger.operation(id: id) else { return }
        if operation.state == .synced {
            _ = protectedDrafts.discardDraft(
                articleID: operation.log.articleID,
                owner: .account(operation.log.userID),
                onlyIfBoundTo: id
            )
            protectedDrafts.clearPendingOperation(id: id)
        } else {
            protectedDrafts.persistPendingOperation(operation)
        }
    }

    private enum JournalError: LocalizedError {
        case unavailable, emptyNote
        var errorDescription: String? {
            switch self {
            case .unavailable: "We couldn’t update this note. Sign in and try again."
            case .emptyNote: "Choose an action or write a reflection before saving."
            }
        }
    }
}
