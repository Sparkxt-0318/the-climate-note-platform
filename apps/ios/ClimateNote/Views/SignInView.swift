import AuthenticationServices
import GoogleSignIn
import SwiftUI

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthService

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 54)).foregroundStyle(Color.climateSage)
                Text("Keep your climate note").font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text("Sign in without leaving the app. Your reflections stay private to your account.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)

                SignInWithAppleButton(.continue) { request in
                    auth.configureAppleSignIn(request)
                } onCompletion: { result in
                    auth.completeAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(.rect(cornerRadius: 12))
                .disabled(auth.isWorking || !auth.isAuthenticationAvailable)

                GoogleButton {
                    Task { await auth.signInWithGoogle() }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .disabled(auth.isWorking || !auth.isAuthenticationAvailable)
                .accessibilityHint("Signs in securely using your Google account.")

                if !auth.isAuthenticationAvailable {
                    Label("Sign-in is temporarily unavailable. You can keep reading and try again later.", systemImage: "wifi.exclamationmark")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 5) {
                    Text("By continuing, you agree to the privacy practices shown in the app.")
                    Link("Read the Privacy Policy", destination: AppConfig.privacyPolicyURL)
                }
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Spacer()
            }
            .padding(24)
            .overlay { if auth.isWorking { ProgressView().controlSize(.large) } }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Not now") { dismiss() } } }
            .onChange(of: auth.user?.uid) { _, userID in if userID != nil { dismiss() } }
            .alert("Sign-in problem", isPresented: Binding(
                get: { auth.errorMessage != nil },
                set: { if !$0 { auth.errorMessage = nil } }
            )) {
                Button("OK") { auth.errorMessage = nil }
            } message: {
                Text(auth.errorMessage ?? "Please try again.")
            }
        }
    }
}

private struct GoogleButton: UIViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> GIDSignInButton {
        let button = GIDSignInButton()
        button.style = .wide
        button.colorScheme = .light
        button.addTarget(context.coordinator, action: #selector(Coordinator.activate), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: GIDSignInButton, context: Context) {
        context.coordinator.action = action
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) { self.action = action }

        @objc func activate() { action() }
    }
}
