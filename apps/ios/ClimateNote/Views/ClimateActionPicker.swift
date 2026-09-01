import SwiftUI

struct ClimateActionPicker: View {
    let article: Article
    let actions: [SuggestedAction]
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var reflections: ReflectionStore
    @State private var selection: SuggestedAction?
    @State private var customText = ""
    @State private var showSignIn = false
    @State private var saved = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Write your climate note!").font(.title2.bold())
            Text("Choose one small, article-specific action—or write your own.")
                .foregroundStyle(.secondary)

            ForEach(actions) { action in
                Button {
                    selection = action
                    customText = ""
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: selection?.id == action.id ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(Color.climateSage)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(action.title).font(.headline)
                            Text(action.instruction).font(.subheadline).foregroundStyle(.secondary)
                            Text(action.cadence).font(.caption.weight(.semibold)).foregroundStyle(Color.climateSage)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(.background, in: .rect(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Select this action for your private climate note")
            }

            TextField("My own reflection and action", text: $customText, axis: .vertical)
                .lineLimit(3...6)
                .padding(16)
                .background(.background, in: .rect(cornerRadius: 18))
                .onChange(of: customText) { _, newValue in if !newValue.isEmpty { selection = nil } }

            Button(saved ? "Saved to My Note" : "Save my climate note") { save() }
                .buttonStyle(ClimatePrimaryButtonStyle())
                .disabled(saved || (selection == nil && customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                .accessibilityHint(saved ? "This action is saved" : "Save the selected action or your custom reflection")
        }
        .padding(22)
        .background(Color.climateSage.opacity(0.08), in: .rect(cornerRadius: 26))
        .sheet(isPresented: $showSignIn) { SignInView() }
        .alert("Couldn’t save your note", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private func save() {
        guard let userID = auth.user?.uid else {
            showSignIn = true
            return
        }
        Task {
            do {
                try await reflections.plan(article: article, action: selection, customText: customText, userID: userID)
                saved = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
