import Foundation
import SwiftUI

/// Keeps the composer policy testable and makes personal writing an equal
/// choice to an assistant suggestion. Suggestions should support reflection,
/// never gate it.
enum ClimateActionPickerPolicy {
    static func defaultMode(actions: [SuggestedAction], initialSelection: SuggestedAction?, initialCustomText: String) -> NoteEntryMode {
        if initialSelection != nil { return .suggestion }
        return .reflection
    }

    static func permitsPersonalWriting(actions: [SuggestedAction]) -> Bool { true }

    static func shouldClearForEmptyOwner(previousOwnerKey: String?, nextOwnerKey: String) -> Bool {
        previousOwnerKey != nil && previousOwnerKey != nextOwnerKey
    }
}

struct ClimateActionPicker: View {
    let article: Article
    let actions: [SuggestedAction]
    let onViewInMyNote: (String) -> Void
    private let seededCustomText: String
    private let capturePresentation: CapturePresentation?

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var reflections: ReflectionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var drafts = DraftOperationStore.shared
    @State private var mode: NoteEntryMode
    @State private var selection: SuggestedAction?
    @State private var customText: String
    @State private var showSignIn = false
    @State private var isSaving = false
    @State private var saveState: ReflectionSaveState?
    @State private var operationID: UUID?
    @State private var guestResumeGuard = GuestSubmitResumeGuard()
    @State private var hasRestoredDraft = false
    @State private var isRestoringDraft = false
    @State private var isDiscardingDraft = false
    @State private var restoredOwnerKey: String?
    @State private var initialWritingFocusRequested: Bool
    @FocusState private var isWriting: Bool

    init(
        article: Article,
        actions: [SuggestedAction],
        initialSelection: SuggestedAction? = nil,
        initialCustomText: String = "",
        initialSaveState: ReflectionSaveState? = nil,
        initialWritingFocus: Bool = false,
        captureAccountID: String? = nil,
        captureOperationID: UUID? = nil,
        onViewInMyNote: @escaping (String) -> Void = { _ in }
    ) {
        self.article = article
        self.actions = actions
        self.onViewInMyNote = onViewInMyNote
        seededCustomText = initialCustomText
        _selection = State(initialValue: initialSelection)
        _customText = State(initialValue: initialCustomText)
        _mode = State(initialValue: ClimateActionPickerPolicy.defaultMode(
            actions: actions,
            initialSelection: initialSelection,
            initialCustomText: initialCustomText
        ))
        _saveState = State(initialValue: initialSaveState)
        _operationID = State(initialValue: captureOperationID)
        _initialWritingFocusRequested = State(initialValue: initialWritingFocus)
#if DEBUG
        if let captureAccountID, let captureOperationID {
            capturePresentation = CapturePresentation(accountID: captureAccountID, operationID: captureOperationID)
        } else {
            capturePresentation = nil
        }
#else
        capturePresentation = nil
#endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.element) {
            ClimatePaperRule()
            Text("YOUR NEXT STEP")
                .climateMetadata(weight: .bold)
                .tracking(1.2)
                .foregroundStyle(Color.climatePaperMuted)
            Text("Make it your note")
                .climateDisplay(34, relativeTo: .title)
                .foregroundStyle(Color.climatePaperInk)
            Text("Write a private reflection, choose an assistant suggestion, or name your own action.")
                .font(.body)
                .foregroundStyle(Color.climatePaperMuted)
                .lineSpacing(4)

            Picker("Note type", selection: $mode) {
                Text("Reflect").tag(NoteEntryMode.reflection)
                Text("My action").tag(NoteEntryMode.action)
                Text("Suggestion").tag(NoteEntryMode.suggestion)
            }
            .pickerStyle(.segmented)
            .tint(Color.climateNotice)
            .disabled(isSaving)
            .accessibilityLabel("Note type")
            .onChange(of: mode) { _, _ in isWriting = false }

            Group {
                switch mode {
                case .suggestion: suggestionContent
                case .reflection, .action: personalWriting
                }
            }

            if !isSaving { saveFeedback }

            if effectiveUserID == nil {
                Text("Sign in to save privately. This draft stays on this device until you submit it.")
                    .font(.footnote)
                    .foregroundStyle(Color.climatePaperMuted)
            }

            Button(action: save) {
                HStack(spacing: ClimateLayout.compact) {
                    if isSaving { ProgressView().tint(Color.climatePaperInk) }
                    Text(saveButtonTitle)
                }
            }
            .buttonStyle(ClimatePrimaryButtonStyle())
            .disabled(isSaving || !hasContent || isCapturePresentation)
            .accessibilityHint(effectiveUserID == nil ? "Opens sign in, then saves this exact draft once." : "Saves your private note")

            if let operationID {
                Button("View in My Note") { onViewInMyNote(operationID.uuidString) }
                    .buttonStyle(ClimatePaperSecondaryButtonStyle())
                    .accessibilityHint("Opens the saved note in My Note")
            }

            if canDiscardUnsubmittedDraft {
                Button("Discard draft", role: .destructive, action: discardDraft)
                    .buttonStyle(ClimatePaperTextButtonStyle())
                    .foregroundStyle(.red)
                    .accessibilityHint("Deletes this local draft from this device")
            }

            if canRemoveFailedDraft {
                Button("Remove local failed draft", role: .destructive, action: removeFailedDraft)
                    .buttonStyle(ClimatePaperTextButtonStyle())
                    .foregroundStyle(.red)
                    .accessibilityHint("Removes only the local failed retry content. It does not cancel saved notes.")
            }
        }
        .padding(ClimateLayout.cardPadding)
        .background(Color.climateNotice.opacity(0.075), in: .rect(cornerRadius: ClimateRadius.card))
        .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climatePaperRule, lineWidth: 1) }
        .animation(reduceMotion ? nil : ClimateMotion.content, value: mode)
        .animation(reduceMotion ? nil : ClimateMotion.content, value: saveState)
        .sensoryFeedback(.selection, trigger: selection?.id)
        .sensoryFeedback(.success, trigger: saveState == .synced)
        .task(id: auth.user?.uid) { restoreDraftIfNeeded() }
        .onAppear {
            guard initialWritingFocusRequested else { return }
            mode = .reflection
            isWriting = true
            initialWritingFocusRequested = false
        }
        .onChange(of: mode) { _, _ in changedDraft() }
        .onChange(of: selection?.id) { _, _ in changedDraft() }
        .onChange(of: customText) { _, _ in changedDraft() }
        .onChange(of: auth.user?.uid) { _, _ in resumeGuestSubmitIfReady() }
        .onChange(of: reflections.observedUserID) { _, _ in resumeGuestSubmitIfReady() }
        .onChange(of: reflections.operationStates) { _, _ in updateOperationState() }
        .sheet(isPresented: $showSignIn, onDismiss: cancelGuestIntentIfNeeded) { SignInView() }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isWriting = false }
            }
        }
    }

    @ViewBuilder private var suggestionContent: some View {
        if actions.isEmpty {
            ComposerStatus(message: "No assistant suggestions are available. You can still write a reflection or your own action.", kind: .information)
        } else {
            VStack(spacing: ClimateLayout.compact) {
                ForEach(actions.indices, id: \.self) { index in
                    suggestionButton(actions[index], number: index + 1)
                }
            }
            .disabled(isSaving)
            Text("AI-generated suggestions are optional ideas, not professional advice. Follow official local guidance for safety and disposal.")
                .font(.footnote)
                .foregroundStyle(Color.climatePaperMuted)
        }
    }

    private var personalWriting: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.compact) {
            Text(mode == .reflection ? "Your reflection" : "Your own action")
                .font(.headline)
                .foregroundStyle(Color.climatePaperInk)
            TextField(
                mode == .reflection ? "What will you notice or carry forward?" : "What will you do differently?",
                text: $customText,
                axis: .vertical
            )
            .lineLimit(4...8)
            .font(.climateBody)
            .foregroundStyle(Color.climatePaperInk)
            .padding(ClimateLayout.element)
            .frame(minHeight: 130, alignment: .topLeading)
            .background(Color.climatePaper, in: .rect(cornerRadius: ClimateRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: ClimateRadius.control)
                    .stroke(isWriting ? Color.climateNotice : Color.climatePaperRule, lineWidth: isWriting ? 2 : 1)
            }
            .focused($isWriting)
            .disabled(isSaving)
            .accessibilityLabel(mode == .reflection ? "Your private reflection" : "Your private action")
            Text("Your draft is stored only on this device until it is submitted.")
                .font(.footnote)
                .foregroundStyle(Color.climatePaperMuted)
        }
    }

    @ViewBuilder private var saveFeedback: some View {
        if isSaving {
            ComposerStatus(message: "Saving your note", kind: .information)
        } else if let saveState {
            switch saveState {
            case .queued:
                ComposerStatus(message: "Saved on this device — waiting to sync", kind: .information)
            case .synced:
                ComposerStatus(message: "Saved to My Note", kind: .success)
            case .failed:
                ComposerStatus(message: "Couldn’t sync — retry when you’re ready", kind: .error)
            }
        }
    }

    private var hasContent: Bool {
        mode == .suggestion
            ? selection != nil
            : !customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canDiscardUnsubmittedDraft: Bool {
        hasContent && operationID == nil && saveState == nil && !isCapturePresentation
    }

    private var canRemoveFailedDraft: Bool {
        hasContent && saveState == .failed && !isCapturePresentation
    }

    private var saveButtonTitle: String {
        if isSaving { return "Saving…" }
        if saveState == .failed { return "Retry save" }
        if saveState == .synced { return "Saved to My Note" }
        return effectiveUserID == nil ? "Sign in to save" : "Save to My Note"
    }

    private var effectiveUserID: String? { capturePresentation?.accountID ?? auth.user?.uid }
    private var isCapturePresentation: Bool { capturePresentation != nil }
    private var draftOwner: DraftOperationStore.Owner { auth.user.map { .account($0.uid) } ?? .guest }

    private func changedDraft() {
        guard hasRestoredDraft, !isRestoringDraft, !isDiscardingDraft, !isCapturePresentation else { return }
        saveState = nil
        operationID = nil
        _ = drafts.save(articleID: article.id, owner: draftOwner, text: customText, mode: mode, selectionID: selection?.id)
    }

    private func restoreDraftIfNeeded() {
        guard !isCapturePresentation else {
            hasRestoredDraft = true
            return
        }
        let owner = draftOwner
        let ownerKey = owner.storageKey
        isRestoringDraft = true
        if !seededCustomText.isEmpty {
            mode = .reflection
            customText = seededCustomText
            selection = nil
            operationID = nil
            saveState = nil
        } else if let draft = drafts.draft(articleID: article.id, owner: owner) {
            mode = draft.mode
            customText = draft.text
            selection = actions.first(where: { $0.id == draft.selectionID })
            if let operation = drafts.pendingOperation(articleID: article.id, owner: owner) {
                operationID = operation.id
                saveState = operation.state
            } else {
                operationID = nil
                saveState = nil
            }
        } else if ClimateActionPickerPolicy.shouldClearForEmptyOwner(previousOwnerKey: restoredOwnerKey, nextOwnerKey: ownerKey) {
            mode = .reflection
            customText = ""
            selection = nil
            saveState = nil
            operationID = nil
        }
        restoredOwnerKey = ownerKey
        hasRestoredDraft = true
        Task { @MainActor in
            await Task.yield()
            isRestoringDraft = false
        }
    }

    private func discardDraft() {
        guard !isCapturePresentation else { return }
        isDiscardingDraft = true
        drafts.discard(articleID: article.id, owner: draftOwner)
        customText = ""
        selection = nil
        saveState = nil
        operationID = nil
        Task { @MainActor in
            await Task.yield()
            isDiscardingDraft = false
        }
    }

    private func removeFailedDraft() {
        guard saveState == .failed else { return }
        isDiscardingDraft = true
        if let operationID { _ = reflections.discardFailedOperation(operationID) }
        drafts.discard(articleID: article.id, owner: draftOwner)
        customText = ""
        selection = nil
        saveState = nil
        operationID = nil
        Task { @MainActor in
            await Task.yield()
            isDiscardingDraft = false
        }
    }

    private func save() {
        guard !isSaving, hasContent, !isCapturePresentation else { return }
        isWriting = false
        guard let userID = auth.user?.uid else {
            guestResumeGuard.request(operationID: operationID ?? UUID())
            _ = drafts.save(articleID: article.id, owner: .guest, text: customText, mode: mode, selectionID: selection?.id)
            showSignIn = true
            return
        }
        performSave(userID: userID, operationID: operationID ?? UUID())
    }

    private func performSave(userID: String, operationID: UUID) {
        guard !isSaving else { return }
        isSaving = true
        self.operationID = operationID
        if drafts.draft(articleID: article.id, owner: draftOwner) == nil {
            _ = drafts.save(articleID: article.id, owner: draftOwner, text: customText, mode: mode, selectionID: selection?.id)
        }
        _ = drafts.bindCurrentDraft(articleID: article.id, owner: draftOwner, to: operationID)
        let actionToSave = mode == .suggestion ? selection : nil
        let textToSave = mode == .suggestion ? "" : customText.trimmingCharacters(in: .whitespacesAndNewlines)
        let kind = mode.actionLogKind
        Task { @MainActor in
            defer { isSaving = false }
            do {
                let operation = try await reflections.plan(
                    article: article,
                    action: actionToSave,
                    customText: textToSave,
                    userID: userID,
                    kind: kind,
                    operationID: operationID
                )
                self.operationID = operation.id
                saveState = operation.state
            } catch {
                saveState = .failed
            }
        }
    }

    private func resumeGuestSubmitIfReady() {
        guard let userID = auth.user?.uid,
              let intentID = guestResumeGuard.consumeIfReady(authUserID: userID, observedUserID: reflections.observedUserID) else { return }
        if let draft = drafts.claimGuestDraftForExplicitSubmit(articleID: article.id, accountID: userID) {
            mode = draft.mode
            customText = draft.text
            selection = actions.first(where: { $0.id == draft.selectionID })
        }
        performSave(userID: userID, operationID: intentID)
    }

    private func cancelGuestIntentIfNeeded() {
        guestResumeGuard.cancelIfUnauthenticated(auth.user?.uid)
    }

    private func updateOperationState() {
        guard !isCapturePresentation,
              let operationID,
              let state = reflections.operationState(for: operationID) else { return }
        saveState = state
        if state == .synced {
            _ = drafts.discardDraft(articleID: article.id, owner: draftOwner, onlyIfBoundTo: operationID)
        }
    }

    private func suggestionButton(_ action: SuggestedAction, number: Int) -> some View {
        let isSelected = selection?.id == action.id
        return Button {
            selection = action
            isWriting = false
        } label: {
            HStack(alignment: .top, spacing: ClimateLayout.element) {
                Text(String(format: "%02d", number))
                    .climateMetadata(weight: .bold)
                    .foregroundStyle(Color.climatePaperMuted)
                VStack(alignment: .leading, spacing: 5) {
                    Text("AI-GENERATED SUGGESTION")
                        .climateMetadata(weight: .bold)
                        .tracking(0.7)
                    Text(action.title)
                        .climateDisplay(22, relativeTo: .title3)
                    Text(action.instruction)
                        .font(.climateBody)
                        .lineSpacing(3)
                    Text(action.cadence)
                        .font(.footnote.weight(.semibold))
                    if !action.evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(action.evidence)
                            .font(.footnote)
                            .lineSpacing(2)
                    }
                }
                .foregroundStyle(Color.climatePaperInk)
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.climatePaperInk : Color.climatePaperMuted)
                    .accessibilityHidden(true)
            }
            .padding(ClimateLayout.cardPadding)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .background(isSelected ? Color.climateSage.opacity(0.5) : Color.climatePaper, in: .rect(cornerRadius: ClimateRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: ClimateRadius.card)
                    .stroke(isSelected ? Color.climatePaperInk.opacity(0.5) : Color.climatePaperRule, lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint("Selects this AI-generated suggestion for your private climate note")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private struct CapturePresentation {
        let accountID: String
        let operationID: UUID
    }
}

private struct ComposerStatus: View {
    enum Kind { case information, success, error }
    let message: String
    let kind: Kind

    var body: some View {
        Label(message, systemImage: symbol)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: ClimateLayout.minimumTarget, alignment: .leading)
            .padding(.horizontal, ClimateLayout.element)
            .background(background, in: .rect(cornerRadius: ClimateRadius.control))
            .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch kind {
        case .information: "arrow.triangle.2.circlepath"
        case .success: "checkmark.circle.fill"
        case .error: "exclamationmark.triangle.fill"
        }
    }

    private var foreground: Color {
        switch kind {
        case .information: Color.climatePaperInk
        case .success: Color.climateNotice
        case .error: .red
        }
    }

    private var background: Color {
        switch kind {
        case .information: Color.climateSage.opacity(0.22)
        case .success: Color.climateSage.opacity(0.32)
        case .error: Color.red.opacity(0.10)
        }
    }
}

private struct ClimatePaperSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.climatePaperInk)
            .frame(maxWidth: .infinity, minHeight: ClimateLayout.controlHeight)
            .background(Color.climatePaper, in: .rect(cornerRadius: ClimateRadius.control))
            .overlay { RoundedRectangle(cornerRadius: ClimateRadius.control).stroke(Color.climatePaperRule, lineWidth: 1) }
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.5)
    }
}

private struct ClimatePaperTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(minWidth: ClimateLayout.minimumTarget, minHeight: ClimateLayout.minimumTarget, alignment: .leading)
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}
