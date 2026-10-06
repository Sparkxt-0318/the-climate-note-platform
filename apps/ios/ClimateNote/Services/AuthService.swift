import AuthenticationServices
import Combine
import CryptoKit
@preconcurrency import FirebaseAuth
import FirebaseCore
import FirebaseMessaging
@preconcurrency import GoogleSignIn
import UIKit

@MainActor
final class AuthService: NSObject, ObservableObject {
    @Published private(set) var user: User?
    @Published private(set) var isWorking = false
    @Published private(set) var isAuthenticationAvailable = false
    @Published var errorMessage: String?
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?
    private var appleOperation: AppleOperation = .signIn

    override init() {
        super.init()
    }

    func start() {
        guard authHandle == nil else { return }
        guard FirebaseApp.app() != nil else {
            isAuthenticationAvailable = false
            errorMessage = "Sign-in is temporarily unavailable. You can continue reading and try again later."
            return
        }
        isAuthenticationAvailable = true
        user = Auth.auth().currentUser
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in self?.user = user }
        }
    }

    /// True when the signed-in Firebase user is an anonymous guest account.
    var isGuest: Bool { user?.isAnonymous == true }

    /// Surfaces misconfiguration that would make Apple/Google sign-in fail at runtime.
    /// Guest (anonymous) sign-in only needs Firebase itself.
    var signInConfigurationIssue: String? {
        guard FirebaseApp.app() != nil else {
            return "Firebase is not configured in this build. Guest and provider sign-in are unavailable."
        }
        guard let clientID = FirebaseApp.app()?.options.clientID, !clientID.isEmpty else {
            return "Google Sign-In is missing a client ID. Check GoogleService-Info.plist."
        }
        let expectedScheme = Bundle.main.object(forInfoDictionaryKey: "REVERSED_CLIENT_ID") as? String
            ?? reversedClientID(from: clientID)
        let schemes = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        let registered = schemes
            .compactMap { $0["CFBundleURLSchemes"] as? [String] }
            .flatMap { $0 }
        if let expectedScheme, !expectedScheme.isEmpty, !registered.contains(expectedScheme) {
            return "Google Sign-In URL scheme is not registered. Add \(expectedScheme) to Info.plist URL types."
        }
        return nil
    }

    private func reversedClientID(from clientID: String) -> String? {
        guard clientID.hasSuffix(".apps.googleusercontent.com") else { return nil }
        let prefix = clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(prefix)"
    }

    /// Creates a Firebase anonymous guest account so notes can sync under a private UID.
    func signInAsGuest() async {
        guard beginAuthentication() else { return }
        if user?.isAnonymous == true { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await Auth.auth().signInAnonymously()
        } catch {
            show(error, fallback: "A guest account could not be created. Check your connection and try again.")
        }
    }

    func signInWithGoogle() async {
        guard beginAuthentication() else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let authorization = try await googleAuthorization()
            try await applyCredential(authorization.credential)
        } catch {
            show(error, fallback: "Google Sign-In could not be completed. Please check your connection and try again.")
        }
    }

    /// Links Apple/Google to an existing guest, or signs in when starting fresh.
    private func applyCredential(_ credential: AuthCredential) async throws {
        if let user, user.isAnonymous {
            do {
                try await user.link(with: credential)
                return
            } catch {
                // Prefer linking so guest notes keep the same UID; fall back if the
                // provider is already tied to another account.
                let nsError = error as NSError
                let linkConflictCodes: Set<Int> = [
                    17025, // credentialAlreadyInUse
                    17007, // emailAlreadyInUse
                    17015, // providerAlreadyLinked
                ]
                if nsError.domain == AuthErrorDomain, linkConflictCodes.contains(nsError.code) {
                    try await Auth.auth().signIn(with: credential)
                    return
                }
                throw error
            }
        }
        try await Auth.auth().signIn(with: credential)
    }

    func configureAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        guard beginAuthentication() else { return }
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
            Self.removeStaleExportFiles()
            let url = FileManager.default.temporaryDirectory
                .appending(path: "climate-note-export-\(UUID().uuidString).json")
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            var writableURL = url
            try? writableURL.setResourceValues(resourceValues)
            return writableURL
        } catch {
            errorMessage = "Your export could not be prepared. Please try again."
            return nil
        }
    }

    static func removeExportFile(_ url: URL?) {
        guard let url else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func removeStaleExportFiles() {
        let directory = FileManager.default.temporaryDirectory
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else { return }
        for file in files where file.lastPathComponent.hasPrefix("climate-note-export-")
            || file.lastPathComponent == "the-climate-note-export.json" {
            try? FileManager.default.removeItem(at: file)
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
        await Task.yield()
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
                try await applyCredential(credential)
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

    private func beginAuthentication() -> Bool {
        guard !isWorking else { return false }
        errorMessage = nil
        guard FirebaseApp.app() != nil else {
            isAuthenticationAvailable = false
            errorMessage = "Sign-in is temporarily unavailable. You can continue reading and try again later."
            return false
        }
        isAuthenticationAvailable = true
        return true
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
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        let windows = scenes.flatMap(\.windows)
        let window = windows.first(where: \.isKeyWindow)
            ?? windows.first(where: { !$0.isHidden && $0.alpha > 0 })
        var current = window?.rootViewController
        while true {
            if let presented = current?.presentedViewController {
                current = presented
            } else if let navigation = current as? UINavigationController {
                current = navigation.visibleViewController
            } else if let tabs = current as? UITabBarController {
                current = tabs.selectedViewController
            } else {
                return current
            }
        }
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
        show(error, fallback: "Sign in with Apple could not be completed. Please try again.")
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let activeWindows = scenes
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows)

        if let keyWindow = activeWindows.first(where: \.isKeyWindow) {
            return keyWindow
        }

        let visibleWindow = scenes
            .flatMap(\.windows)
            .first(where: { !$0.isHidden && $0.alpha > 0 })
        return visibleWindow ?? ASPresentationAnchor()
    }
}
