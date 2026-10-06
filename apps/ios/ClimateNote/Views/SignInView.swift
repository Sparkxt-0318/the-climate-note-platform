import AuthenticationServices
import GoogleSignIn
import SwiftUI
import FirebaseCore
import UIKit

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var confirmsAge13 = false

    private var canBeginProviderSignIn: Bool {
        confirmsAge13 && !auth.isWorking && auth.isAuthenticationAvailable && auth.signInConfigurationIssue == nil
    }

    private var canBeginGuestSignIn: Bool {
        confirmsAge13 && !auth.isWorking && auth.isAuthenticationAvailable
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    Spacer(minLength: ClimateTheme.Spacing.xLarge)
                    signInPanel
                    Spacer(minLength: ClimateTheme.Spacing.hero)
                }
                .frame(maxWidth: ClimateTheme.ContentWidth.authentication)
                .frame(maxWidth: .infinity)
                .padding(ClimateTheme.Spacing.medium)
            }
            .scrollIndicators(.hidden)
            .background { ClimateBackdrop() }
            .tint(ClimateTheme.accent)
            .overlay {
                if auth.isWorking {
                    loadingOverlay
                }
            }
            .animation(reduceMotion ? nil : ClimateTheme.Motion.standardState, value: auth.isWorking)
            .toolbar {
                ToolbarItem(placement: .principal) { ClimateWordmark() }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { dismiss() }
                        .font(ClimateTheme.Typography.subheadlineStrong)
                        .foregroundStyle(ClimateTheme.pineInk)
                        .disabled(auth.isWorking)
                        .accessibilityHint("Closes sign-in and returns to reading without creating an account")
                }
            }
            .toolbarBackground(ClimateTheme.pine, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .onAppear { auth.start() }
            .onChange(of: auth.user?.uid) { _, userID in
                if userID != nil { dismiss() }
            }
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
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.compact) {
                ClimateEyebrow(text: "Your private note")
                Text(auth.isGuest ? "Upgrade your guest note." : "Keep your own note.")
                    .font(ClimateTheme.Typography.leadTitle)
                    .tracking(-0.5)
                    .foregroundStyle(ClimateTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(
                    auth.isGuest
                        ? "Add Apple or Google to keep this guest account’s notes across devices."
                        : "Reading never requires an account. Create a guest account to save privately, or use Apple or Google."
                )
                    .font(ClimateTheme.Typography.callout)
                    .foregroundStyle(ClimateTheme.secondaryInk)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(ClimateTheme.divider)
                .frame(height: 1)

            Toggle(isOn: $confirmsAge13) {
                Text("I confirm I am 13 or older.")
                    .font(ClimateTheme.Typography.subheadline)
                    .foregroundStyle(ClimateTheme.ink)
            }
            .tint(ClimateTheme.accent)
            .disabled(auth.isWorking)
            .accessibilityHint("Required before creating a guest account or signing in")

            if !confirmsAge13 {
                Text("Confirm your age to continue.")
                    .font(ClimateTheme.Typography.caption)
                    .foregroundStyle(ClimateTheme.tertiaryInk)
            }

            if !auth.isGuest {
                Button {
                    Task { await auth.signInAsGuest() }
                } label: {
                    Text("Continue as guest")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClimateSecondaryButtonStyle())
                .disabled(!canBeginGuestSignIn)
                .opacity(canBeginGuestSignIn ? 1 : 0.45)
                .accessibilityHint("Creates a private guest account so you can save notes without Apple or Google")
            }

            VStack(spacing: ClimateTheme.Spacing.compact) {
                SignInWithAppleButton(.continue) { request in
                    guard canBeginProviderSignIn else { return }
                    auth.configureAppleSignIn(request)
                } onCompletion: { result in
                    auth.completeAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(minHeight: 50)
                .clipShape(.rect(cornerRadius: ClimateTheme.Radius.medium))
                .disabled(!canBeginProviderSignIn)
                .opacity(canBeginProviderSignIn ? 1 : 0.45)
                .accessibilityHint("Signs in securely using your Apple account")

                GoogleButton {
                    guard canBeginProviderSignIn else { return }
                    Task { await auth.signInWithGoogle() }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .clipShape(.rect(cornerRadius: ClimateTheme.Radius.medium))
                .disabled(!canBeginProviderSignIn)
                .opacity(canBeginProviderSignIn ? 1 : 0.45)
                .allowsHitTesting(canBeginProviderSignIn)
                .accessibilityHint("Signs in securely using your Google account")
            }

            if let issue = auth.signInConfigurationIssue {
                ClimateInlineStatus(message: issue, kind: .warning)
            } else if !auth.isAuthenticationAvailable {
                Label(
                    "Sign-in is temporarily unavailable. You can keep reading as a guest and try again later.",
                    systemImage: "wifi.exclamationmark"
                )
                .font(ClimateTheme.Typography.callout)
                .foregroundStyle(ClimateTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.xSmall) {
                Text("By creating a guest account or continuing with Apple or Google, you agree to the Terms of Service and Privacy Policy.")
                Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)
                    .foregroundStyle(ClimateTheme.accent)
                    .frame(minHeight: ClimateTheme.minimumTapTarget, alignment: .leading)
                Link("Terms of Service", destination: AppConfig.termsOfServiceURL)
                    .foregroundStyle(ClimateTheme.accent)
                    .frame(minHeight: ClimateTheme.minimumTapTarget, alignment: .leading)
            }
            .font(ClimateTheme.Typography.subheadline)
            .foregroundStyle(ClimateTheme.secondaryInk)
        }
        .padding(ClimateTheme.Spacing.large)
        .climateSheet()
    }

    private var loadingOverlay: some View {
        ZStack {
            ClimateTheme.canvas.opacity(0.86)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: ClimateTheme.Spacing.compact) {
                ProgressView()
                    .controlSize(.large)
                    .tint(ClimateTheme.accent)
                Text(auth.isGuest ? "Upgrading account…" : "Signing in")
                    .font(ClimateTheme.Typography.metadata)
                    .foregroundStyle(ClimateTheme.ink)
            }
            .padding(ClimateTheme.Spacing.large)
            .climateSheet(radius: ClimateTheme.Radius.medium)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.97)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Signing in")
        }
    }
}

private struct GoogleButton: UIViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    let action: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(action: action) }

    func makeUIView(context: Context) -> GIDSignInButton {
        let button = GIDSignInButton()
        button.style = .wide
        button.colorScheme = colorScheme == .dark ? .dark : .light
        button.isEnabled = isEnabled
        button.addTarget(context.coordinator, action: #selector(Coordinator.activate), for: .touchUpInside)
        return button
    }

    func updateUIView(_ uiView: GIDSignInButton, context: Context) {
        context.coordinator.action = action
        uiView.isEnabled = isEnabled
        uiView.colorScheme = colorScheme == .dark ? .dark : .light
        uiView.alpha = isEnabled ? 1 : 0.45
        uiView.isUserInteractionEnabled = isEnabled
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func activate() {
            action()
        }
    }
}
