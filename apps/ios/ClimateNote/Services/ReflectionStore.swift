import Combine
import Foundation
import FirebaseCore
import FirebaseFirestore

@MainActor
final class ReflectionStore: ObservableObject {
    @Published private(set) var logs: [ActionLog] = []
    @Published private(set) var errorMessage: String?
    private var listener: ListenerRegistration?
    private var userID: String?

    func observe(userID: String?) {
        guard self.userID != userID else { return }
        self.userID = userID
        listener?.remove()
        listener = nil
        logs = []
        guard FirebaseApp.app() != nil, let userID else { return }

        listener = Firestore.firestore()
            .collection("users").document(userID).collection("actionLogs")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    if let error {
                        self?.errorMessage = error.localizedDescription
                    } else {
                        self?.logs = snapshot?.documents.compactMap { try? $0.data(as: ActionLog.self) } ?? []
                        self?.errorMessage = nil
                    }
                }
            }
    }

    func plan(article: Article, action: SuggestedAction?, customText: String, userID: String) async throws {
        let title = action?.title ?? "My own climate note"
        let detail = action?.instruction ?? customText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !detail.isEmpty else { return }
        let reference = Firestore.firestore()
            .collection("users").document(userID).collection("actionLogs").document()
        let log = ActionLog(
            documentID: reference.documentID,
            userID: userID,
            articleID: article.id,
            articleTitle: article.title,
            actionID: action?.id ?? "custom",
            title: title,
            detail: detail,
            category: action?.category ?? "custom",
            status: .planned,
            createdAt: Date(),
            completedAt: nil,
            impactEstimate: ImpactFactorCatalog.estimate(for: action)
        )
        try reference.setData(from: log)
    }

    func complete(_ log: ActionLog) async throws {
        guard let userID, let documentID = log.documentID else { return }
        try await Firestore.firestore()
            .collection("users").document(userID).collection("actionLogs").document(documentID)
            .updateData(["status": ActionLog.Status.completed.rawValue, "completedAt": Date()])
    }
}
