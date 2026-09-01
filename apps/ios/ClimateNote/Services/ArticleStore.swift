import Combine
import Foundation
import FirebaseCore
import FirebaseFirestore

@MainActor
final class ArticleStore: ObservableObject {
    @Published private(set) var articles: [Article] = []
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    private var listener: ListenerRegistration?

    func start() {
        guard listener == nil else { return }
        guard FirebaseApp.app() != nil else {
            isLoading = false
            errorMessage = "The app still needs its Firebase configuration file."
            return
        }

        listener = Firestore.firestore()
            .collection("articles")
            .whereField("status", isEqualTo: "published")
            .order(by: "publishedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.isLoading = false
                    if let error {
                        self.errorMessage = error.localizedDescription
                        return
                    }
                    self.articles = snapshot?.documents.compactMap { try? $0.data(as: Article.self) } ?? []
                    self.errorMessage = nil
                }
            }
    }
}
