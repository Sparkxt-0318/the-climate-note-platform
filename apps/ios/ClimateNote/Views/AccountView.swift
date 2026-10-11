import SwiftUI
import UIKit

struct AccountView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var reflections: ReflectionStore
    @EnvironmentObject private var impact: ImpactStore
    @State private var showSignIn = false
    @State private var confirmDeletion = false
    @State private var exportURL: URL?
    @State private var isPreparingExport = false
    @State private var isUpdatingNotifications = false
    @State private var isDeletingAccount = false

    private var accountOperationPending: Bool {
        isPreparingExport || isDeletingAccount || isUpdatingNotifications || impact.isSavingPreference || auth.isWorking
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClimateLayout.majorSection) {
                accountLead
                identityActions
                if auth.user != nil {
                    dataSection
                    impactPanel
                }
                notificationsPanel
                helpPanel
                aboutPanel
                if auth.user != nil { destructivePanel }
            }
            .climateContentWidth()
            .padding(.top, ClimateLayout.section)
            .padding(.bottom, ClimateLayout.majorSection)
        }
        .background(Color.climateCanvas.ignoresSafeArea())
        .foregroundStyle(Color.climateInk)
        .tint(Color.climateSage)
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: auth.user?.uid) { impact.observePreference(userID: auth.user?.uid) }
        .sheet(isPresented: $showSignIn) { SignInView() }
        .sheet(isPresented: Binding(
            get: { exportURL != nil },
            set: { presenting in
                if !presenting {
                    AuthService.removeExportFile(exportURL)
                    exportURL = nil
                }
            }
        )) {
            if let exportURL { ShareSheet(items: [exportURL]) }
        }
        .alert("Delete your account?", isPresented: $confirmDeletion) {
            Button("Delete", role: .destructive) {
                guard !accountOperationPending else { return }
                isDeletingAccount = true
                Task {
                    defer { isDeletingAccount = false }
                    await auth.deleteAccount()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This permanently removes your account, private notes, and completion history. Apple or Google may ask you to confirm your identity.")
        }
        .alert("Account problem", isPresented: Binding(
            get: { auth.errorMessage != nil || notifications.errorMessage != nil },
            set: { if !$0 { auth.errorMessage = nil; notifications.errorMessage = nil } }
        )) {
            Button("OK") { auth.errorMessage = nil; notifications.errorMessage = nil }
        } message: {
            Text(auth.errorMessage ?? notifications.errorMessage ?? "Please try again.")
        }
    }

    private var accountLead: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ACCOUNT")
                .climateMetadata(weight: .bold)
                .tracking(1.2)
                .foregroundStyle(Color.climateSage)
            Text("Your climate profile")
                .climateDisplay(38, relativeTo: .largeTitle)
            if let user = auth.user {
                Text(profileHeader(for: user.email))
                    .font(.headline)
                    .textSelection(.enabled)
                Text(auth.isGuest ? "Notes stay on this device for now. Link Apple or Google to keep them across devices." : "Notes stay private to your account.")
                    .font(.body)
                    .foregroundStyle(Color.climateMuted)
                    .lineSpacing(4)
            } else {
                Text("Reading never requires an account. Sign in only if you want a private note.")
                    .font(.body)
                    .foregroundStyle(Color.climateMuted)
                    .lineSpacing(4)
            }
        }
    }

    @ViewBuilder private var identityActions: some View {
        if auth.user != nil {
            if auth.isGuest {
                Button("Keep notes with Apple or Google") { showSignIn = true }
                    .buttonStyle(ClimatePrimaryButtonStyle())
                    .disabled(accountOperationPending)
                    .accessibilityHint("Opens sign-in to link Apple or Google to this guest account")
            }
        } else {
            Button("Sign in or continue as guest") { showSignIn = true }
                .buttonStyle(ClimatePrimaryButtonStyle())
                .accessibilityHint("Opens guest continue and secure sign in")
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.element) {
            AccountHeading("Your data")
            VStack(spacing: 0) {
                Button(action: prepareExport) {
                    AccountRow(title: isPreparingExport ? "Preparing export…" : "Export synced account data", trailingProgress: isPreparingExport, showsChevron: false)
                }
                .buttonStyle(.plain)
                .disabled(accountOperationPending)
                .accessibilityHint("Prepares a synced account data export to share or save; unfinished drafts remain on this device")
                AccountDivider()
                Button {
                    guard !accountOperationPending else { return }
                    auth.signOut()
                } label: {
                    AccountRow(title: auth.isGuest ? "End guest session" : "Sign out", showsChevron: false)
                }
                .buttonStyle(.plain)
                .disabled(accountOperationPending)
                .accessibilityHint(auth.isGuest ? "Ends the guest session on this device" : "Signs out of this device")
            }
            .accountSurface()
        }
    }

    private var impactPanel: some View {
        let summary = PersonalImpactSummary(logs: reflections.logs)
        return VStack(alignment: .leading, spacing: ClimateLayout.element) {
            AccountHeading("Impact")
            VStack(alignment: .leading, spacing: ClimateLayout.element) {
                if summary.hasContent {
                    PersonalImpactSummaryView(summary: summary, showsTitle: false, compact: true)
                } else {
                    Text("Personal estimates appear after you complete a supported action.")
                        .font(.footnote).foregroundStyle(Color.climateMuted)
                }
                AccountDivider()
                CommunityImpactLink()
                AccountDivider()
                Toggle("Include my completed supported actions in anonymous community totals", isOn: Binding(
                    get: { impact.includeInCommunityImpact },
                    set: { value in Task { await impact.setCommunityContribution(value, userID: auth.user?.uid) } }
                ))
                .font(.body)
                .tint(Color.climateSage)
                .frame(minHeight: ClimateLayout.minimumTarget)
                .disabled(impact.isLoadingPreference || impact.isSavingPreference)

                Text("This is optional. You can withdraw at any time; private notes and identity are never included.")
                    .font(.footnote)
                    .foregroundStyle(Color.climateMuted)
                    .lineSpacing(2)

                if impact.isLoadingPreference || impact.isSavingPreference {
                    HStack(spacing: ClimateLayout.compact) {
                        ProgressView().tint(Color.climateSage)
                        Text(impact.isSavingPreference ? "Saving preference…" : "Loading preference…")
                            .font(.footnote).foregroundStyle(Color.climateMuted)
                    }
                    .accessibilityElement(children: .combine)
                }
                if let message = impact.preferenceErrorMessage {
                    AccountError(message: message)
                    Button("Try again") { Task { await impact.retryPreference(userID: auth.user?.uid) } }
                        .buttonStyle(ClimateTextButtonStyle())
                        .disabled(impact.isSavingPreference)
                }
            }
            .padding(ClimateLayout.cardPadding)
            .accountSurface()
        }
    }

    private var notificationsPanel: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.element) {
            AccountHeading("Notifications")
            VStack(alignment: .leading, spacing: ClimateLayout.element) {
                Toggle("Weekly new article", isOn: Binding(
                    get: { notifications.weeklyEnabled },
                    set: { value in
                        guard !accountOperationPending else { return }
                        isUpdatingNotifications = true
                        Task {
                            defer { isUpdatingNotifications = false }
                            await notifications.setWeeklyEnabled(value, userID: auth.user?.uid)
                        }
                    }
                ))
                .font(.body)
                .tint(Color.climateSage)
                .frame(minHeight: ClimateLayout.minimumTarget)
                .disabled(accountOperationPending)
                Text("Off by default. Action reminders are scheduled only when you choose a date for a planned action.")
                    .font(.footnote)
                    .foregroundStyle(Color.climateMuted)
                    .lineSpacing(3)
                if isUpdatingNotifications {
                    HStack(spacing: ClimateLayout.compact) {
                        ProgressView().tint(Color.climateSage)
                        Text("Updating…").font(.footnote).foregroundStyle(Color.climateMuted)
                    }
                    .accessibilityElement(children: .combine)
                }
                if notifications.hasPendingPreferenceSync {
                    Button("Try saving preference") {
                        guard !accountOperationPending else { return }
                        isUpdatingNotifications = true
                        Task {
                            defer { isUpdatingNotifications = false }
                            await notifications.retryPreferenceSync(userID: auth.user?.uid)
                        }
                    }
                    .buttonStyle(ClimateTextButtonStyle())
                    .disabled(accountOperationPending)
                }
            }
            .padding(ClimateLayout.cardPadding)
            .accountSurface()
        }
    }

    private var helpPanel: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.element) {
            AccountHeading("Help & privacy")
            VStack(spacing: 0) {
                Link(destination: URL(string: "mailto:theclimatenote@gmail.com")!) { AccountRow(title: "Email support") }
                AccountDivider()
                Link(destination: AppConfig.supportURL) { AccountRow(title: "Support website") }
                AccountDivider()
                Link(destination: AppConfig.privacyPolicyURL) { AccountRow(title: "Privacy policy") }
                AccountDivider()
                Link(destination: AppConfig.termsOfServiceURL) { AccountRow(title: "Terms") }
                AccountDivider()
                NavigationLink { PrivacyView() } label: { AccountRow(title: "Privacy in plain language") }
            }
            .accountSurface()
        }
    }

    private var aboutPanel: some View {
        Text("For readers 13+. AI summaries are labeled. Impact figures are estimates.")
            .font(.footnote)
            .foregroundStyle(Color.climateMuted)
            .lineSpacing(3)
    }

    private var destructivePanel: some View {
        Button(isDeletingAccount || auth.isWorking ? "Deleting account…" : "Delete account") {
            guard !accountOperationPending else { return }
            confirmDeletion = true
        }
        .buttonStyle(ClimateTextButtonStyle())
        .foregroundStyle(.red)
        .disabled(accountOperationPending)
        .accessibilityHint("Opens a confirmation before permanently deleting your account")
    }

    private func prepareExport() {
        guard !accountOperationPending else { return }
        isPreparingExport = true
        Task {
            defer { isPreparingExport = false }
            exportURL = await auth.exportAccountData()
        }
    }

    private func profileHeader(for email: String?) -> String {
        guard let email = normalizedEmail(email), !email.lowercased().hasSuffix("privaterelay.appleid.com") else { return "Your climate profile" }
        return email
    }

    private func accountDetail(for email: String?) -> String {
        guard let email = normalizedEmail(email) else { return "Apple private relay" }
        return email.lowercased().hasSuffix("privaterelay.appleid.com") ? "Apple private relay" : email
    }

    private func normalizedEmail(_ email: String?) -> String? {
        let value = email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }
}

private struct AccountHeading: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased()).climateMetadata(weight: .bold).tracking(1.1).foregroundStyle(Color.climateSage)
    }
}

private struct AccountRow: View {
    let title: String
    var trailingProgress = false
    var showsChevron = true
    var body: some View {
        HStack(spacing: ClimateLayout.element) {
            Text(title).font(.body.weight(.medium))
            Spacer(minLength: ClimateLayout.compact)
            if trailingProgress { ProgressView().tint(Color.climateSage) }
            else if showsChevron { Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Color.climateMuted).accessibilityHidden(true) }
        }
        .foregroundStyle(Color.climateInk)
        .frame(maxWidth: .infinity, minHeight: ClimateLayout.controlHeight, alignment: .leading)
        .padding(.horizontal, ClimateLayout.cardPadding)
        .contentShape(.rect)
    }
}

private struct AccountDivider: View {
    var body: some View { ClimateRule().padding(.leading, ClimateLayout.cardPadding) }
}

private struct AccountError: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, minHeight: ClimateLayout.minimumTarget, alignment: .leading)
            .padding(.horizontal, ClimateLayout.element)
            .background(Color.red.opacity(0.12), in: .rect(cornerRadius: ClimateRadius.control))
    }
}

private extension View {
    func accountSurface() -> some View {
        background(
            LinearGradient(
                colors: [Color.climateSurfaceRaised.opacity(0.72), Color.climateSurface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: .rect(cornerRadius: ClimateRadius.card)
        )
            .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateSage.opacity(0.18), lineWidth: 1) }
            .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

struct PrivacyView: View {
    private let sections = [
        ("01", "PUBLIC", "Stories are meant to travel.", "Published stories, cited sources, photo credits, and clearly labeled AI summaries."),
        ("02", "PRIVATE", "Your notebook stays yours.", "Your identity, reflections, actions, reminders, and completion history."),
        ("03", "NEVER", "No hidden second use.", "No behavioral ads, data sales, or public-model training with private notes."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClimateLayout.majorSection) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PRIVACY, IN PLAIN LANGUAGE")
                        .climateMetadata(weight: .bold).tracking(1.2).foregroundStyle(Color.climateSage)
                    Text("Public stories.\nPrivate notes.")
                        .climateDisplay(40, relativeTo: .largeTitle)
                        .tracking(-0.6)
                    Text("A clear boundary between what the publication shares and what remains yours.")
                        .font(.body).foregroundStyle(Color.climateMuted).lineSpacing(4)
                }

                VStack(alignment: .leading, spacing: 9) {
                    Text("The promise is simple.")
                        .climateEditorialDisplay(27, relativeTo: .title2)
                    Text("Read openly. Write privately. Decide for yourself whether an anonymous action estimate contributes to the community total.")
                        .font(.subheadline)
                        .foregroundStyle(Color.climateMuted)
                        .lineSpacing(3)
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 21)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [Color.climateSurfaceRaised, Color.climateSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: .rect(cornerRadius: ClimateRadius.card)
                )
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color.climateSage).frame(width: 3).clipShape(.capsule)
                }

                VStack(spacing: 0) {
                    ForEach(sections.indices, id: \.self) { index in
                        let item = sections[index]
                        HStack(alignment: .top, spacing: ClimateLayout.element) {
                            Text(item.0)
                                .climateEditorialDisplay(29, relativeTo: .title2)
                                .foregroundStyle(Color.climateSage.opacity(0.45))
                                .frame(width: 42, alignment: .leading)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.1)
                                    .climateMetadata(weight: .bold)
                                    .tracking(1.1)
                                    .foregroundStyle(Color.climateSage)
                                Text(item.2)
                                    .climateEditorialDisplay(23, relativeTo: .title3)
                                Text(item.3)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.climateMuted)
                                    .lineSpacing(3)
                            }
                        }
                        .padding(.vertical, 17)
                        if index < sections.count - 1 {
                            ClimateRule()
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Questions about privacy?").font(.headline)
                    Link("Email us", destination: URL(string: "mailto:theclimatenote@gmail.com")!)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.climateSage)
                        .frame(minHeight: ClimateLayout.minimumTarget, alignment: .leading)
                }
            }
            .climateContentWidth()
            .padding(.top, ClimateLayout.section)
            .padding(.bottom, ClimateLayout.majorSection)
        }
        .background(Color.climateCanvas.ignoresSafeArea())
        .foregroundStyle(Color.climateInk)
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
