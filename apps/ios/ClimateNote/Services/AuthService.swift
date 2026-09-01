import AuthenticationServices
import Combine
import CryptoKit
@preconcurrency import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
import GoogleSignIn
import UIKit

@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var isWorking = false
    @Published var errorMessage: String?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    private var appleOperation: AppleOperation = .signIn

    override init() {
        super.init()
    }

    func start() {
        guard authHandle == nil else { return }
        guard FirebaseApp.app() != nil else { return }
        user = Auth.auth().currentUser
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.user = user }
        }
    }

    func signInWithGoogle() async {
        isWorking = true
        defer { isWorking = false }
        do {
            let authorization = try await googleAuthorization()
            try await Auth.auth().signIn(with: authorization.credential)
        } catch {
            show(error)
        }
    }

    func configureAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        appleOperation = .signIn
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
        isWorking = true
    }

    func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task { await handleAppleAuthorization(authorization, operation: .signIn) }
        case .failure(let error):
            isWorking = false
            show(error)
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAccount() async {
        guard let user else { return }
        errorMessage = nil

        if user.providerData.contains(where: { $0.providerID == "apple.com" }) {
            beginAppleAccountDeletion()
            return
        }

        isWorking = true
        defer { isWorking = false }
        do {
            let isGoogleAccount = user.providerData.contains(where: { $0.providerID == "google.com" })
            if isGoogleAccount {
                let authorization = try await googleAuthorization()
                try await user.reauthenticate(with: authorization.credential)
            }
            try await deleteAccountFromServer(user)
            if isGoogleAccount {
                try? await GIDSignIn.sharedInstance.disconnect()
            }
        } catch {
            show(error, fallback: "Your account could not be deleted. Please try again.")
        }
    }

    func exportAccountData() async -> URL? {
        guard let user else { return nil }
        do {
            let token = try await user.getIDToken()
            var request = URLRequest(url: AppConfig.apiBaseURL.appending(path: "/api/account/export"))
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AuthError.exportFailed }
            let url = FileManager.default.temporaryDirectory.appending(path: "the-climate-note-export.json")
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            errorMessage = "Your export could not be prepared. Please try again."
            return nil
        }
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let characters = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            guard SecRandomCopyBytes(kSecRandomDefault, 1, &random) == errSecSuccess else { continue }
            if random < characters.count {
                result.append(characters[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private func googleAuthorization() async throws -> GoogleAuthorization {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingGoogleClientID
        }
        guard let presentingViewController else { throw AuthError.googleAuthorizationCouldNotStart }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController)
        guard let idToken = result.user.idToken?.tokenString else { throw AuthError.missingGoogleIDToken }
        let accessToken = result.user.accessToken.tokenString
        return GoogleAuthorization(
            credential: GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )
        )
    }

    private func beginAppleAccountDeletion() {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        appleOperation = .deleteAccount
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        isWorking = true
        controller.performRequests()
    }

    private func handleAppleAuthorization(
        _ authorization: ASAuthorization,
        operation: AppleOperation
    ) async {
        defer {
            currentNonce = nil
            appleOperation = .signIn
            isWorking = false
        }
        do {
            guard
                let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let tokenData = appleCredential.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else { throw AuthError.missingAppleCredential }

            let credential = OAuthProvider.appleCredential(
                withIDToken: token,
                rawNonce: nonce,
                fullName: appleCredential.fullName
            )

            switch operation {
            case .signIn:
                try await Auth.auth().signIn(with: credential)
            case .deleteAccount:
                guard let user else { return }
                guard
                    let codeData = appleCredential.authorizationCode,
                    let authorizationCode = String(data: codeData, encoding: .utf8)
                else { throw AuthError.missingAppleAuthorizationCode }
                try await user.reauthenticate(with: credential)
                try await Auth.auth().revokeToken(withAuthorizationCode: authorizationCode)
                try await deleteAccountFromServer(user)
            }
        } catch {
            show(error, fallback: "Apple authentication could not be completed.")
        }
    }

    private func deleteAccountFromServer(_ user: User) async throws {
        let token = try await user.getIDToken()
        var request = URLRequest(url: AppConfig.apiBaseURL.appending(path: "/api/account/delete"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw AuthError.accountDeletionFailed
        }
        Messaging.messaging().isAutoInitEnabled = false
        try? await Messaging.messaging().deleteData()
        UserDefaults.standard.set(false, forKey: "climate-note.weekly-notifications")
        try? Auth.auth().signOut()
    }

    private func show(_ error: Error, fallback: String? = nil) {
        if (error as? ASAuthorizationError)?.code == .canceled { return }
        let nsError = error as NSError
        if nsError.domain == kGIDSignInErrorDomain && nsError.code == -5 { return }
        errorMessage = fallback ?? error.localizedDescription
    }

    private enum AuthError: LocalizedError {
        case missingGoogleClientID
        case missingGoogleIDToken
        case googleAuthorizationCouldNotStart
        case missingAppleCredential
        case missingAppleAuthorizationCode
        case accountDeletionFailed
        case exportFailed

        var errorDescription: String? {
            switch self {
            case .missingGoogleClientID: "Google Sign-In is not configured for this app."
            case .missingGoogleIDToken: "Google did not return the secure token needed to sign in."
            case .googleAuthorizationCouldNotStart: "The Google sign-in sheet could not be opened."
            case .missingAppleCredential: "Apple did not return a secure sign-in credential."
            case .missingAppleAuthorizationCode: "Apple did not return the code needed to revoke access."
            case .accountDeletionFailed: "The account deletion service could not complete the request."
            case .exportFailed: "The account export service could not complete the request."
            }
        }
    }

    private enum AppleOperation {
        case signIn
        case deleteAccount
    }

    private struct GoogleAuthorization {
        let credential: AuthCredential
    }

    private var presentingViewController: UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
        var current = root
        while let presented = current?.presentedViewController { current = presented }
        return current
    }
}

extension AuthService: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        let operation = appleOperation
        Task { await handleAppleAuthorization(authorization, operation: operation) }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        isWorking = false
        currentNonce = nil
        appleOperation = .signIn
        show(error)
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }
}
