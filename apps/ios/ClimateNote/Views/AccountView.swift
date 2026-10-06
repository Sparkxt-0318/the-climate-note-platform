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
            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.hero) {
                accountLead
                identityActions

                if auth.user != nil {
                    dataSection
                    impactPanel
                }

                notificationsPanel
                supportPanel

                VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
                    aboutPanel
                    if auth.user != nil {
                        destructivePanel
                    }
                }
            }
            .padding(.horizontal, ClimateTheme.Spacing.large)
            .padding(.top, ClimateTheme.Spacing.large)
            .padding(.bottom, ClimateTheme.Spacing.xxLarge)
            .frame(maxWidth: ClimateTheme.ContentWidth.reading, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background { ClimateBackdrop() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { ClimateWordmark() }
        }
        .toolbarBackground(ClimateTheme.pine, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(ClimateTheme.accent)
        .task(id: auth.user?.uid) {
            impact.observePreference(userID: auth.user?.uid)
        }
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
            if let exportURL {
                ShareSheet(items: [exportURL])
            }
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
            set: {
                if !$0 {
                    auth.errorMessage = nil
                    notifications.errorMessage = nil
                }
            }
        )) {
            Button("OK") {
                auth.errorMessage = nil
                notifications.errorMessage = nil
            }
        } message: {
            Text(auth.errorMessage ?? notifications.errorMessage ?? "Please try again.")
        }
    }

    private var accountLead: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.compact) {
            Text("Account")
                .font(ClimateTheme.Typography.leadTitle)
                .tracking(-0.5)
                .foregroundStyle(ClimateTheme.ink)
                .accessibilityAddTraits(.isHeader)

            if let user = auth.user {
                Text(auth.isGuest ? "Guest" : (user.email ?? "Signed in with Apple"))
                    .font(ClimateTheme.Typography.headline)
                    .foregroundStyle(ClimateTheme.ink)
                    .textSelection(.enabled)

                Text(
                    auth.isGuest
                        ? "Notes stay on this device for now. Link Apple or Google to keep them across devices."
                        : "Notes stay private to your account."
                )
                .font(ClimateTheme.Typography.pageSubtitle)
                .foregroundStyle(ClimateTheme.secondaryInk)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Reading never requires an account. Sign in only if you want a private note.")
                    .font(ClimateTheme.Typography.pageSubtitle)
                    .foregroundStyle(ClimateTheme.secondaryInk)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, ClimateTheme.Spacing.small)
    }

    @ViewBuilder private var identityActions: some View {
        if auth.user != nil {
            if auth.isGuest {
                Button {
                    showSignIn = true
                } label: {
                    Text("Keep notes with Apple or Google")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClimatePrimaryButtonStyle())
                .disabled(accountOperationPending)
                .accessibilityHint("Opens sign-in to link Apple or Google to this guest account")
            }
        } else {
            Button {
                showSignIn = true
            } label: {
                Text("Sign in or continue as guest")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ClimatePrimaryButtonStyle())
            .accessibilityHint("Opens guest continue and secure sign-in")
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.medium) {
            ClimateQuietLabel(text: "Your data")

            VStack(spacing: 0) {
                Button {
                    prepareExport()
                } label: {
                    HStack(spacing: ClimateTheme.Spacing.small) {
                        AccountListRow(
                            title: isPreparingExport ? "Preparing export…" : "Export my private data",
                            showsChevron: false
                        )
                        if isPreparingExport {
                            ProgressView()
                                .tint(ClimateTheme.accent)
                        }
                    }
                }
                .buttonStyle(ClimateArticleLinkStyle())
                .disabled(accountOperationPending)
                .accessibilityHint("Prepares a private data export to share or save")

                AccountHairline()

                Button {
                    guard !accountOperationPending else { return }
                    auth.signOut()
                } label: {
                    AccountListRow(
                        title: auth.isGuest ? "End guest session" : "Sign out",
                        showsChevron: false
                    )
                }
                .buttonStyle(ClimateArticleLinkStyle())
                .disabled(accountOperationPending)
                .accessibilityHint(auth.isGuest ? "Ends the guest session on this device" : "Signs out of this device")
            }
            .padding(.horizontal, ClimateTheme.Spacing.medium)
            .background(ClimateTheme.elevatedSurface, in: .rect(cornerRadius: ClimateTheme.Radius.medium))
        }
    }

    private var impactPanel: some View {
        let summary = PersonalImpactSummary(logs: reflections.logs)
        return VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
            ClimateQuietLabel(text: "Impact")

            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
                if summary.hasContent {
                    PersonalImpactSummaryView(summary: summary, showsTitle: false, compact: true)
                }

                CommunityImpactLink()

                Toggle(
                    "Include my actions in community totals",
                    isOn: Binding(
                        get: { impact.includeInCommunityImpact },
                        set: { value in
                            Task { await impact.setCommunityContribution(value, userID: auth.user?.uid) }
                        }
                    )
                )
                .font(ClimateTheme.Typography.body)
                .foregroundStyle(ClimateTheme.ink)
                .tint(ClimateTheme.accent)
                .frame(minHeight: ClimateTheme.minimumTapTarget)
                .disabled(impact.isLoadingPreference || impact.isSavingPreference)

                if impact.isLoadingPreference || impact.isSavingPreference {
                    ProgressView(impact.isSavingPreference ? "Saving…" : "Loading…")
                        .font(ClimateTheme.Typography.subheadline)
                        .tint(ClimateTheme.accent)
                }

                if let message = impact.preferenceErrorMessage {
                    ClimateInlineStatus(message: message, kind: .error)
                    Button("Try again") {
                        Task { await impact.retryPreference(userID: auth.user?.uid) }
                    }
                    .buttonStyle(ClimateSecondaryButtonStyle())
                    .disabled(impact.isSavingPreference)
                }
            }
            .padding(ClimateTheme.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ClimateTheme.elevatedSurface, in: .rect(cornerRadius: ClimateTheme.Radius.medium))
        }
    }

    private var notificationsPanel: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.medium) {
            ClimateQuietLabel(text: "Notifications")

            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.medium) {
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
                .font(ClimateTheme.Typography.body)
                .foregroundStyle(ClimateTheme.ink)
                .tint(ClimateTheme.accent)
                .frame(minHeight: ClimateTheme.minimumTapTarget)
                .disabled(accountOperationPending)

                if isUpdatingNotifications {
                    HStack(spacing: ClimateTheme.Spacing.small) {
                        ProgressView()
                        Text("Updating…")
                            .font(ClimateTheme.Typography.subheadline)
                            .foregroundStyle(ClimateTheme.secondaryInk)
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
                    .buttonStyle(ClimateSecondaryButtonStyle())
                    .disabled(accountOperationPending)
                }
            }
            .padding(ClimateTheme.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ClimateTheme.elevatedSurface, in: .rect(cornerRadius: ClimateTheme.Radius.medium))
        }
    }

    private var supportPanel: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.medium) {
            ClimateQuietLabel(text: "Help")

            VStack(spacing: 0) {
                Link(destination: URL(string: "mailto:theclimatenote@gmail.com")!) {
                    AccountListRow(title: "Email support")
                }
                AccountHairline()
                Link(destination: AppConfig.supportURL) {
                    AccountListRow(title: "Support website")
                }
                AccountHairline()
                Link(destination: AppConfig.privacyPolicyURL) {
                    AccountListRow(title: "Privacy policy")
                }
                AccountHairline()
                Link(destination: AppConfig.termsOfServiceURL) {
                    AccountListRow(title: "Terms")
                }
                AccountHairline()
                NavigationLink {
                    PrivacyView()
                } label: {
                    AccountListRow(title: "Privacy in plain language")
                }
            }
            .padding(.horizontal, ClimateTheme.Spacing.medium)
            .background(ClimateTheme.elevatedSurface, in: .rect(cornerRadius: ClimateTheme.Radius.medium))
        }
    }

    private var aboutPanel: some View {
        Text("For readers 13+. AI summaries are labeled. Impact figures are estimates.")
            .font(ClimateTheme.Typography.caption)
            .foregroundStyle(ClimateTheme.tertiaryInk)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var destructivePanel: some View {
        Button(isDeletingAccount || auth.isWorking ? "Deleting account…" : "Delete account") {
            guard !accountOperationPending else { return }
            confirmDeletion = true
        }
        .font(ClimateTheme.Typography.subheadline)
        .foregroundStyle(ClimateTheme.error)
        .frame(minHeight: ClimateTheme.minimumTapTarget, alignment: .leading)
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
}

private struct AccountListRow: View {
    let title: String
    var showsChevron = true

    var body: some View {
        HStack(spacing: ClimateTheme.Spacing.small) {
            Text(title)
                .font(ClimateTheme.Typography.body)
                .foregroundStyle(ClimateTheme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ClimateTheme.tertiaryInk)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

private struct AccountHairline: View {
    var body: some View {
        Rectangle()
            .fill(ClimateTheme.divider.opacity(0.45))
            .frame(height: 1)
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

struct PrivacyView: View {
    private let sections = [
        ("01", "What is public", "Published articles, their cited sources, licensed photo credits, and a rounded community impact total after the privacy threshold is met."),
        ("02", "What is private", "Your identity, reflections, chosen actions, completion history, and personal impact estimates."),
        ("03", "What we do not do", "We do not sell data, show behavioral ads, or use private notes to train public AI models."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.hero) {
                ClimatePageHeader(title: "Privacy", subtitle: "The reading is public. Your notes stay yours.")

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(sections.indices, id: \.self) { index in
                        let section = sections[index]

                        HStack(alignment: .top, spacing: ClimateTheme.Spacing.medium) {
                            Text(section.0)
                                .font(ClimateTheme.Typography.caption)
                                .foregroundStyle(ClimateTheme.accent)
                                .frame(width: 28, alignment: .leading)
                            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.small) {
                                Text(section.1)
                                    .font(ClimateTheme.Typography.headline)
                                    .foregroundStyle(ClimateTheme.ink)
                                    .accessibilityAddTraits(.isHeader)
                                Text(section.2)
                                    .font(ClimateTheme.Typography.body)
                                    .foregroundStyle(ClimateTheme.secondaryInk)
                                    .lineSpacing(4)
                            }
                        }
                        .padding(.vertical, ClimateTheme.Spacing.large)

                        if index < sections.count - 1 {
                            AccountHairline()
                        }
                    }
                }

                Link(destination: URL(string: "mailto:theclimatenote@gmail.com")!) {
                    VStack(alignment: .leading, spacing: ClimateTheme.Spacing.small) {
                        Text("Questions about privacy?")
                        Label("Email us", systemImage: "arrow.up.right")
                            .foregroundStyle(ClimateTheme.accent)
                    }
                    .font(ClimateTheme.Typography.subheadlineStrong)
                    .foregroundStyle(ClimateTheme.ink)
                    .padding(.vertical, ClimateTheme.Spacing.medium)
                    .frame(minHeight: ClimateTheme.minimumTapTarget)
                }
                .buttonStyle(ClimateArticleLinkStyle())
            }
            .padding(.horizontal, ClimateTheme.Spacing.large)
            .padding(.top, ClimateTheme.Spacing.large)
            .padding(.bottom, ClimateTheme.Spacing.hero)
            .frame(maxWidth: ClimateTheme.ContentWidth.reading, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background { ClimateBackdrop() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) { ClimateWordmark() }
        }
        .toolbarBackground(ClimateTheme.pine, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(ClimateTheme.accent)
    }
}
