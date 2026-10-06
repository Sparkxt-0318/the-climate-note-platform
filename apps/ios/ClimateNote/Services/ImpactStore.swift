import Combine
import Foundation
import FirebaseCore
@preconcurrency import FirebaseFirestore

/// Reads the server-owned, privacy-safe community summary and owns the one
/// private preference a signed-in reader may change. It never calculates or
/// writes aggregate values on-device.
@MainActor
final class ImpactStore: ObservableObject {
    @Published private(set) var communityPresentation: CommunityImpactPresentation = .loading
    @Published private(set) var includeInCommunityImpact = false
    @Published private(set) var isLoadingPreference = false
    @Published private(set) var isSavingPreference = false
    @Published private(set) var preferenceErrorMessage: String?

    private var communityListener: ListenerRegistration?
    private var preferenceListener: ListenerRegistration?
    private var communityObservationID = UUID()
    private var preferenceObservationID = UUID()
    private var activePreferenceWriteID: UUID?
    private var observedUserID: String?
    private var confirmedPreference = false
    private var retryPreferenceValue: Bool?
    private var lastCommunityDocument: CommunityImpactDocument?

    func start() {
        guard communityListener == nil else { return }
        guard FirebaseApp.app() != nil else {
            communityPresentation = .error("Community impact is temporarily unavailable. Please try again later.")
            return
        }

        if lastCommunityDocument == nil { communityPresentation = .loading }
        let observationID = UUID()
        communityObservationID = observationID
        communityListener = Firestore.firestore()
            .collection("communityImpact")
            .document("current")
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self, self.communityObservationID == observationID else { return }
                    if error != nil {
                        if let retained = self.lastCommunityDocument {
                            self.communityPresentation = CommunityImpactPresentationResolver.presentation(
                                for: retained,
                                isFromCache: true
                            )
                        } else {
                            self.communityPresentation = .error("We couldn’t load community impact. Check your connection and try again.")
                        }
                        return
                    }
                    guard let snapshot, snapshot.exists,
                          let document = try? snapshot.data(as: CommunityImpactDocument.self) else {
                        self.communityPresentation = .error("Community impact is temporarily unavailable. Please try again later.")
                        return
                    }
                    self.lastCommunityDocument = document
                    self.communityPresentation = CommunityImpactPresentationResolver.presentation(
                        for: document,
                        isFromCache: snapshot.metadata.isFromCache
                    )
                }
            }
    }

    func retryCommunity() {
        communityListener?.remove()
        communityListener = nil
        start()
    }

    func observePreference(userID: String?) {
        guard observedUserID != userID || preferenceListener == nil else { return }

        preferenceObservationID = UUID()
        activePreferenceWriteID = nil
        preferenceListener?.remove()
        preferenceListener = nil
        observedUserID = userID
        confirmedPreference = false
        retryPreferenceValue = nil
        includeInCommunityImpact = false
        preferenceErrorMessage = nil
        isSavingPreference = false

        guard let userID else {
            isLoadingPreference = false
            return
        }
        guard FirebaseApp.app() != nil else {
            isLoadingPreference = false
            preferenceErrorMessage = "Community participation is temporarily unavailable. Please try again later."
            return
        }

        isLoadingPreference = true
        let observationID = preferenceObservationID
        preferenceListener = Firestore.firestore()
            .collection("users").document(userID).collection("preferences").document("impact")
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self,
                          self.preferenceObservationID == observationID,
                          self.observedUserID == userID else { return }
                    self.isLoadingPreference = false
                    if error != nil {
                        self.preferenceErrorMessage = "We couldn’t load your community participation preference."
                        return
                    }
                    guard let snapshot else { return }
                    let preference = (try? snapshot.data(as: CommunityImpactPreference.self))
                        ?? CommunityImpactPreference()
                    self.includeInCommunityImpact = preference.includeInCommunityImpact
                    if !snapshot.metadata.hasPendingWrites {
                        self.confirmedPreference = preference.includeInCommunityImpact
                    }
                    self.preferenceErrorMessage = nil
                }
            }
    }

    func setCommunityContribution(_ value: Bool, userID: String?) async {
        guard let userID, userID == observedUserID else {
            preferenceErrorMessage = "Sign in to choose whether to include your completed supported actions."
            return
        }
        guard FirebaseApp.app() != nil else {
            preferenceErrorMessage = "Community participation is temporarily unavailable. Please try again later."
            return
        }
        guard !isSavingPreference else { return }

        let writeID = UUID()
        activePreferenceWriteID = writeID
        retryPreferenceValue = value
        includeInCommunityImpact = value
        preferenceErrorMessage = nil
        isSavingPreference = true

        do {
            try await writePreference(value, userID: userID)
            guard activePreferenceWriteID == writeID, observedUserID == userID else { return }
            confirmedPreference = value
            retryPreferenceValue = nil
            isSavingPreference = false
        } catch {
            guard activePreferenceWriteID == writeID, observedUserID == userID else { return }
            includeInCommunityImpact = confirmedPreference
            isSavingPreference = false
            preferenceErrorMessage = "We couldn’t save your community participation preference. Please try again."
        }
    }

    func retryPreference(userID: String?) async {
        if let retryPreferenceValue {
            await setCommunityContribution(retryPreferenceValue, userID: userID)
            return
        }

        guard userID == observedUserID else {
            observePreference(userID: userID)
            return
        }

        preferenceListener?.remove()
        preferenceListener = nil
        observedUserID = nil
        observePreference(userID: userID)
    }

    private func writePreference(_ value: Bool, userID: String) async throws {
        let reference = Firestore.firestore()
            .collection("users").document(userID).collection("preferences").document("impact")
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.setData(["includeInCommunityImpact": value], merge: true) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}
