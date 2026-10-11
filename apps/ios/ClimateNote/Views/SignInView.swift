import AuthenticationServices
@preconcurrency import GoogleSignIn
import SwiftUI

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var confirmsAge13 = false

    private var canBeginSignIn: Bool {
        confirmsAge13 && !auth.isWorking && auth.isAuthenticationAvailable
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Spacer(minLength: ClimateLayout.section)
                    signInPanel
                    Spacer(minLength: ClimateLayout.majorSection)
                }
                .climateContentWidth(520)
            }
            .scrollIndicators(.hidden)
            .background(Color.climateCanvas.ignoresSafeArea())
            .foregroundStyle(Color.climateInk)
            .tint(Color.climateSage)
            .overlay { if auth.isWorking { loadingOverlay } }
            .animation(reduceMotion ? nil : ClimateMotion.content, value: auth.isWorking)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now", action: dismiss.callAsFunction)
                        .disabled(auth.isWorking)
                        .accessibilityHint("Closes sign-in and returns to reading without creating an account")
                }
            }
            .onAppear { auth.start() }
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
        .interactiveDismissDisabled(auth.isWorking)
    }

    private var signInPanel: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.section) {
            HStack(spacing: 12) {
                Image(systemName: "leaf")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(Color.climateSage)
                    .frame(width: 52, height: 52)
                    .overlay { Circle().stroke(Color.climateSage.opacity(0.52), lineWidth: 1) }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("THE CLIMATE NOTE")
                        .climateMetadata(weight: .bold)
                        .tracking(1.2)
                        .foregroundStyle(Color.climateSage)
                    Text("your private notebook")
                        .climateEditorialDisplay(22, relativeTo: .title3)
                }
            }

            VStack(alignment: .leading, spacing: 9) {
                Text(auth.isGuest ? "Keep your guest note." : "Keep your own note.")
                    .climateDisplay(42, relativeTo: .largeTitle)
                    .tracking(-0.6)
                Text(
                    auth.isGuest
                        ? "Add Apple or Google to keep this guest account’s notes across devices."
                        : "Reading never requires an account. Continue as a guest to save privately, or use Apple or Google."
                )
                .font(.body)
                .foregroundStyle(Color.climateMuted)
                .lineSpacing(4)
            }

            ClimateRule()

            Toggle(isOn: $confirmsAge13) {
                Text("I confirm I am 13 or older.")
                    .font(.body.weight(.medium))
            }
            .tint(Color.climateSage)
            .frame(minHeight: ClimateLayout.minimumTarget)
            .disabled(auth.isWorking)
            .accessibilityHint("Required before creating a guest account or signing in")

            if !confirmsAge13 {
                Text("Confirm your age to continue.")
                    .font(.footnote)
                    .foregroundStyle(Color.climateMuted)
            }

            if !auth.isGuest {
                Button("Continue as guest") {
                    Task { await auth.signInAsGuest() }
                }
                .buttonStyle(ClimatePrimaryButtonStyle())
                .disabled(!canBeginSignIn)
                .opacity(canBeginSignIn ? 1 : 0.48)
                .accessibilityHint("Creates a private guest account so you can save notes without Apple or Google")
            }

            VStack(spacing: ClimateLayout.element) {
                SignInWithAppleButton(.continue) { request in
                    guard canBeginSignIn else { return }
                    auth.configureAppleSignIn(request)
                } onCompletion: { result in
                    auth.completeAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(minHeight: ClimateLayout.controlHeight)
                .clipShape(.rect(cornerRadius: ClimateRadius.control))
                .disabled(!canBeginSignIn)
                .opacity(canBeginSignIn ? 1 : 0.48)
                .accessibilityHint("Signs in securely using your Apple account")

                GoogleButton(isEnabled: canBeginSignIn) {
                    Task { await auth.signInWithGoogle() }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: ClimateLayout.controlHeight)
                .disabled(!canBeginSignIn)
                .accessibilityLabel("Continue with Google")
                .accessibilityHint("Signs in securely using your Google account")
            }

            if !auth.isAuthenticationAvailable {
                Label("Sign-in is temporarily unavailable. You can keep reading and try again later.", systemImage: "wifi.exclamationmark")
                    .font(.footnote)
                    .foregroundStyle(Color.climateMuted)
                    .frame(maxWidth: .infinity, minHeight: ClimateLayout.minimumTarget, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: ClimateLayout.compact) {
                Text("By creating a guest account or continuing with Apple or Google, you agree to the Terms of Service and Privacy Policy.")
                HStack(spacing: ClimateLayout.element) {
                    Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)
                    Link("Terms of Service", destination: AppConfig.termsOfServiceURL)
                }
            }
            .font(.footnote)
            .foregroundStyle(Color.climateMuted)
            .lineSpacing(3)
        }
        .padding(ClimateLayout.cardPadding)
        .background(
            LinearGradient(
                colors: [Color.climateSurfaceRaised.opacity(0.86), Color.climateSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: ClimateRadius.card)
        )
        .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateSage.opacity(0.20), lineWidth: 1) }
        .shadow(color: Color.black.opacity(0.24), radius: 24, y: 16)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.climateCanvas.opacity(0.84).ignoresSafeArea()
            VStack(spacing: ClimateLayout.element) {
                ProgressView().controlSize(.large).tint(Color.climateSage)
                Text(auth.isGuest ? "Upgrading account…" : "Signing in…")
                    .font(.body.weight(.semibold))
            }
            .padding(ClimateLayout.cardPadding)
            .background(Color.climateSurfaceRaised, in: .rect(cornerRadius: ClimateRadius.card))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Signing in")
        }
    }
}

private struct GoogleButton: UIViewRepresentable {
    let isEnabled: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    func makeCoordinator() -> Coordinator { Coordinator(action: action, isEnabled: isEnabled) }

    func makeUIView(context: Context) -> GIDSignInButton {
        let button = GIDSignInButton()
        button.style = .wide
        button.colorScheme = colorScheme == .dark ? .dark : .light
        button.isEnabled = context.coordinator.isEnabled
        button.addTarget(context.coordinator, action: #selector(Coordinator.activate), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: GIDSignInButton, context: Context) {
        context.coordinator.action = action
        context.coordinator.isEnabled = isEnabled
        uiView.isEnabled = isEnabled
        uiView.isUserInteractionEnabled = isEnabled
        uiView.alpha = isEnabled ? 1 : 0.48
        uiView.colorScheme = colorScheme == .dark ? .dark : .light
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        var isEnabled: Bool
        init(action: @escaping () -> Void, isEnabled: Bool) { self.action = action; self.isEnabled = isEnabled }
        @objc func activate() { guard isEnabled else { return }; action() }
    }
}
