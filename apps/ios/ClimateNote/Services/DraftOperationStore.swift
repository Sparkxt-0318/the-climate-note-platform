import Combine
import Foundation

/// The local, protected draft archive.  It deliberately uses the app support
/// directory instead of preferences so note text cannot turn up in backups of
/// ordinary settings or in app diagnostics.
@MainActor
final class DraftOperationStore: ObservableObject {
    enum Owner: Hashable, Sendable {
        case guest
        case account(String)

        var storageKey: String {
            switch self {
            case .guest: "guest"
            case .account(let userID): "account-\(userID)"
            }
        }
    }

    struct Draft: Codable, Equatable, Sendable {
        let articleID: String
        var text: String
        var mode: NoteEntryMode
        var selectionID: String?
        var revision: Int
        var updatedAt: Date
        /// The only pending operation allowed to update or remove this exact
        /// draft snapshot. Editing the draft clears this association.
        var operationID: UUID?
    }

    static let shared = DraftOperationStore()

    private struct Archive: Codable {
        var drafts: [String: Draft] = [:]
        var rejectedLogs: [String: ActionLog] = [:]
        var pendingOperations: [String: ReflectionSaveOperation] = [:]
    }

    private let fileURL: URL
    private var archive: Archive

    init(directory: URL? = nil) {
        let root = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let folder = root.appendingPathComponent("ClimateNote", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        fileURL = folder.appendingPathComponent("private-note-drafts.json")
        archive = (try? Data(contentsOf: fileURL)).flatMap { try? JSONDecoder().decode(Archive.self, from: $0) } ?? Archive()
        protectArchiveIfPossible()
    }

    func draft(articleID: String, owner: Owner) -> Draft? {
        archive.drafts[draftKey(articleID: articleID, owner: owner)]
    }

    @discardableResult
    func save(articleID: String, owner: Owner, text: String, mode: NoteEntryMode, selectionID: String?) -> Draft {
        let key = draftKey(articleID: articleID, owner: owner)
        let revision = (archive.drafts[key]?.revision ?? 0) + 1
        let draft = Draft(articleID: articleID, text: text, mode: mode, selectionID: selectionID, revision: revision, updatedAt: Date(), operationID: nil)
        archive.drafts[key] = draft
        persist()
        return draft
    }

    func discard(articleID: String, owner: Owner) {
        archive.drafts.removeValue(forKey: draftKey(articleID: articleID, owner: owner))
        persist()
    }

    @discardableResult
    func bindCurrentDraft(articleID: String, owner: Owner, to operationID: UUID) -> Bool {
        let key = draftKey(articleID: articleID, owner: owner)
        guard var draft = archive.drafts[key] else { return false }
        draft.operationID = operationID
        archive.drafts[key] = draft
        persist()
        return true
    }

    @discardableResult
    func discardDraft(articleID: String, owner: Owner, onlyIfBoundTo operationID: UUID) -> Bool {
        let key = draftKey(articleID: articleID, owner: owner)
        guard archive.drafts[key]?.operationID == operationID else { return false }
        archive.drafts.removeValue(forKey: key)
        persist()
        return true
    }

    /// Call only from a save CTA whose guest sign-in was explicitly requested.
    /// Account/settings sign-in must never invoke this method.
    @discardableResult
    func claimGuestDraftForExplicitSubmit(articleID: String, accountID: String) -> Draft? {
        let guestKey = draftKey(articleID: articleID, owner: .guest)
        guard var guestDraft = archive.drafts[guestKey] else { return nil }
        let accountKey = draftKey(articleID: articleID, owner: .account(accountID))
        guestDraft.revision = max(guestDraft.revision, archive.drafts[accountKey]?.revision ?? 0) + 1
        guestDraft.updatedAt = Date()
        archive.drafts[accountKey] = guestDraft
        archive.drafts.removeValue(forKey: guestKey)
        persist()
        return guestDraft
    }

    func retainRejected(_ log: ActionLog) {
        archive.rejectedLogs[log.id] = log
        persist()
    }

    func rejectedLog(id: String) -> ActionLog? { archive.rejectedLogs[id] }

    func clearRejectedLog(id: String) {
        archive.rejectedLogs.removeValue(forKey: id)
        persist()
    }

    func persistPendingOperation(_ operation: ReflectionSaveOperation) {
        archive.pendingOperations[operation.documentID] = operation
        persist()
    }

    func pendingOperation(id: UUID) -> ReflectionSaveOperation? {
        archive.pendingOperations[id.uuidString]
    }

    func pendingOperation(articleID: String, owner: Owner) -> ReflectionSaveOperation? {
        guard case .account(let userID) = owner,
              let operationID = draft(articleID: articleID, owner: owner)?.operationID,
              let operation = archive.pendingOperations[operationID.uuidString],
              operation.log.articleID == articleID,
              operation.log.userID == userID else { return nil }
        return operation
    }

    func allPendingOperations(userID: String? = nil) -> [ReflectionSaveOperation] {
        archive.pendingOperations.values.filter { userID == nil || $0.log.userID == userID }
    }

    func clearPendingOperation(id: UUID) {
        archive.pendingOperations.removeValue(forKey: id.uuidString)
        persist()
    }

    private func draftKey(articleID: String, owner: Owner) -> String { "\(owner.storageKey)::\(articleID)" }

    private func persist() {
        guard let data = try? JSONEncoder().encode(archive) else { return }
        do {
            try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            // A draft remains in memory for this session if device protection is
            // temporarily unavailable (for example before first unlock).
        }
    }

    private func protectArchiveIfPossible() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: fileURL.path)
    }
}

enum NoteEntryMode: String, Codable, CaseIterable, Sendable {
    case suggestion
    case reflection
    case action

    var actionLogKind: ActionLog.Kind {
        self == .reflection ? .reflection : .action
    }
}

enum ReflectionSaveState: String, Codable, Equatable, Sendable {
    case queued
    case synced
    case failed
}

enum ReflectionWriteAttempt: Equatable, Sendable {
    case initialDurableWrite
    case retryTransaction
}

enum ReflectionWriteFailurePolicy {
    static func state(after errorCode: Int, attempt: ReflectionWriteAttempt) -> ReflectionSaveState {
        // Initial setData is persisted by Firestore before it waits for the
        // server. A retry transaction has no durable write when it cannot run.
        if attempt == .initialDurableWrite && (errorCode == 4 || errorCode == 14) {
            return .queued
        }
        return .failed
    }
}

struct ReflectionSaveOperation: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let log: ActionLog
    var state: ReflectionSaveState

    var documentID: String { id.uuidString }
}

/// Keeps a save intent immutable across retries. It is intentionally free of
/// Firebase so the safety rules can be tested without a networked emulator.
struct ReflectionOperationLedger: Sendable {
    private(set) var operations: [UUID: ReflectionSaveOperation] = [:]

    init(operations: [ReflectionSaveOperation] = []) {
        self.operations = Dictionary(uniqueKeysWithValues: operations.map { ($0.id, $0) })
    }

    mutating func begin(id: UUID, log: ActionLog) -> ReflectionSaveOperation {
        if let existing = operations[id] { return existing }
        let operation = ReflectionSaveOperation(id: id, log: log, state: .queued)
        operations[id] = operation
        return operation
    }

    func operation(id: UUID) -> ReflectionSaveOperation? { operations[id] }

    mutating func transition(id: UUID, to state: ReflectionSaveState) {
        guard var operation = operations[id] else { return }
        // Once a completed entry has been observed, a late retry/failure must
        // not return the operation to a writable state.
        guard operation.log.status != .completed || state == .synced else { return }
        operation.state = state
        operations[id] = operation
    }

    mutating func observeServerLog(_ log: ActionLog, documentID: String) {
        guard let id = UUID(uuidString: documentID), var operation = operations[id] else { return }
        operation = ReflectionSaveOperation(id: operation.id, log: log, state: operation.state)
        if log.status == .completed { operation.state = .synced }
        operations[id] = operation
    }

    func mayWrite(id: UUID) -> Bool {
        operations[id]?.log.status != .completed
    }

    mutating func removeIfFailed(id: UUID) -> Bool {
        guard operations[id]?.state == .failed else { return false }
        operations.removeValue(forKey: id)
        return true
    }
}

/// Models the one-shot bridge between an explicit guest save CTA and the
/// authentication observer. Merely signing in elsewhere cannot create one.
struct GuestSubmitResumeGuard: Sendable {
    private(set) var pendingOperationID: UUID?
    private(set) var hasResumed = false

    mutating func request(operationID: UUID) {
        pendingOperationID = operationID
        hasResumed = false
    }

    mutating func consumeIfReady(authUserID: String?, observedUserID: String?) -> UUID? {
        guard let pendingOperationID, !hasResumed,
              let authUserID, authUserID == observedUserID else { return nil }
        hasResumed = true
        self.pendingOperationID = nil
        return pendingOperationID
    }

    mutating func cancelIfUnauthenticated(_ authUserID: String?) {
        guard authUserID == nil else { return }
        pendingOperationID = nil
        hasResumed = false
    }
}
