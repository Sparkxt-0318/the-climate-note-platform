import SwiftUI
import UIKit

struct AccountView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var notifications: NotificationService
    @State private var showSignIn = false
    @State private var confirmDeletion = false
    @State private var exportURL: URL?

    var body: some View {
        List {
            Section {
                if let user = auth.user {
                    LabeledContent("Signed in as", value: user.email ?? "Apple private relay")
                    Button("Sign out") { auth.signOut() }
                    Button("Export my private data") {
                        Task { exportURL = await auth.exportAccountData() }
                    }
                    Button("Delete account", role: .destructive) { confirmDeletion = true }
                        .disabled(auth.isWorking)
                } else {
                    Button("Sign in or create an account") { showSignIn = true }
                }
            }
            Section("Help") {
                Link("Email support", destination: URL(string: "mailto:theclimatenote@gmail.com")!)
                Link("Support website", destination: AppConfig.supportURL)
                Link("Privacy Policy", destination: AppConfig.privacyPolicyURL)
                NavigationLink("Privacy") { PrivacyView() }
            }
            Section("Notifications") {
                Toggle("Weekly new article", isOn: Binding(
                    get: { notifications.weeklyEnabled },
                    set: { value in Task { await notifications.setWeeklyEnabled(value, userID: auth.user?.uid) } }
                ))
                Text("Off by default. Action reminders are scheduled only when you tap Remind me.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section {
                Text("The Climate Note is designed for readers age 13 and older.")
                Text("AI summaries and actions are labeled. Original articles are never rewritten by AI.")
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Account")
        .sheet(isPresented: $showSignIn) { SignInView() }
        .sheet(isPresented: Binding(
            get: { exportURL != nil },
            set: { if !$0 { exportURL = nil } }
        )) {
            if let exportURL { ShareSheet(items: [exportURL]) }
        }
        .alert("Delete your account?", isPresented: $confirmDeletion) {
            Button("Delete", role: .destructive) { Task { await auth.deleteAccount() } }
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
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

private struct PrivacyView: View {
    var body: some View {
        List {
            Section("What is public") { Text("Published articles, their cited sources, and labeled AI additions.") }
            Section("What is private") { Text("Your reflections, chosen actions, completion history, and impact estimates.") }
            Section("What we do not do") { Text("We do not sell data, show behavioral ads, or use your private notes to train public AI models.") }
            Section("Questions") { Link("theclimatenote@gmail.com", destination: URL(string: "mailto:theclimatenote@gmail.com")!) }
        }
        .navigationTitle("Privacy")
    }
}
