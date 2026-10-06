import Foundation
import SwiftUI

enum ClimateActionPickerPolicy {
    static func defaultMode(actions: [SuggestedAction], initialSelection: SuggestedAction?, initialCustomText: String) -> NoteEntryMode {
        if initialSelection != nil { return .suggestion }
        // Personal writing is the calm, always-available default. Generated
        // suggestions can enhance it but never gate it.
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
    /// Prefill from “Start a reflection” or an external composer request.
    private let seededCustomText: String
    /// Used only by isolated DEBUG capture fixtures. It never participates in
    /// production authentication or a Firestore write.
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
        self.seededCustomText = initialCustomText
        _selection = State(initialValue: initialSelection)
        _customText = State(initialValue: initialCustomText)
        _mode = State(initialValue: ClimateActionPickerPolicy.defaultMode(
            actions: actions, initialSelection: initialSelection, initialCustomText: initialCustomText
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
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
            Divider().overlay(ClimateTheme.divider)
            ClimatePageHeader(
                title: "Make it your note.",
                subtitle: "Write a private reflection, choose an assistant suggestion, or name your own action.",
                titleFont: ClimateTheme.Typography.sectionTitle
            )

            Picker("Note type", selection: $mode) {
                Text("Reflection").tag(NoteEntryMode.reflection)
                Text("My own action").tag(NoteEntryMode.action)
                Text("Suggestion").tag(NoteEntryMode.suggestion)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Note type")
            .disabled(isSaving)
            .onChange(of: mode) { _, _ in isWriting = false }

            switch mode {
            case .suggestion: suggestions
            case .reflection, .action: personalWriting
            }

            if !isSaving {
                saveFeedback
            }

            if effectiveUserID == nil {
                Text("Sign in to save privately. Your draft stays on this device until you choose to submit it.")
                    .font(ClimateTheme.Typography.subheadline)
                    .foregroundStyle(ClimateTheme.secondaryInk)
            }

            Button(action: save) {
                HStack(spacing: ClimateTheme.Spacing.small) {
                    if isSaving { ProgressView().tint(ClimateTheme.onPrimaryAction) }
                    Text(saveButtonTitle)
                }
            }
            .buttonStyle(ClimatePrimaryButtonStyle())
            .disabled(isSaving || !hasContent || isCapturePresentation)
            .accessibilityHint(effectiveUserID == nil ? "Opens sign in, then saves this exact draft once." : "Saves your private note")

            if let operationID {
                Button("View in My Note") { onViewInMyNote(operationID.uuidString) }
                    .buttonStyle(ClimateSecondaryButtonStyle())
                    .accessibilityHint("Opens the saved note in My Note")
            }

            if canDiscardUnsubmittedDraft {
                Button("Discard draft", role: .destructive, action: discardDraft)
                    .font(ClimateTheme.Typography.subheadline)
                    .foregroundStyle(ClimateTheme.error)
                    .frame(minHeight: ClimateTheme.minimumTapTarget, alignment: .leading)
                    .accessibilityHint("Deletes this local draft from this device")
            }

            if canRemoveFailedDraft {
                Button("Remove local failed draft", role: .destructive, action: removeFailedDraft)
                    .font(ClimateTheme.Typography.subheadline)
                    .foregroundStyle(ClimateTheme.error)
                    .frame(minHeight: ClimateTheme.minimumTapTarget, alignment: .leading)
                    .accessibilityHint("Removes only the local failed retry content. It does not cancel saved notes.")
            }
        }
        .animation(reduceMotion ? nil : ClimateTheme.Motion.standardState, value: mode)
        .animation(reduceMotion ? nil : ClimateTheme.Motion.standardState, value: saveState)
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

    @ViewBuilder
    private var suggestions: some View {
        if actions.isEmpty {
            ClimateInlineStatus(message: "No assistant suggestions are available. You can still write a reflection or your own action.", kind: .information)
        } else {
            VStack(spacing: ClimateTheme.Spacing.compact) {
                ForEach(actions.indices, id: \.self) { index in actionButton(actions[index], number: index + 1) }
            }
            .disabled(isSaving)
            Text("AI-generated suggestions are optional ideas, not medical, legal, or professional advice. Follow official local guidance for disposal, safety, and health topics.")
                .font(ClimateTheme.Typography.caption)
                .foregroundStyle(ClimateTheme.secondaryInk)
        }
    }

    private var personalWriting: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.small) {
            Text(mode == .reflection ? "Your reflection" : "Your own action")
                .font(ClimateTheme.Typography.headline)
                .foregroundStyle(ClimateTheme.ink)
            TextField(mode == .reflection ? "What will you notice or carry forward?" : "What will you do differently?", text: $customText, axis: .vertical)
                .lineLimit(4...8)
                .font(ClimateTheme.Typography.body)
                .foregroundStyle(ClimateTheme.ink)
                .padding(ClimateTheme.Spacing.medium)
                .background(ClimateTheme.surface, in: .rect(cornerRadius: ClimateTheme.Radius.medium))
                .overlay {
                    RoundedRectangle(cornerRadius: ClimateTheme.Radius.medium)
                        .stroke(isWriting ? ClimateTheme.accent : ClimateTheme.divider, lineWidth: isWriting ? 2 : 1)
                }
                .focused($isWriting)
                .disabled(isSaving)
                .accessibilityLabel(mode == .reflection ? "Your private reflection" : "Your private action")
            Text("Your draft is stored only on this device until it is submitted.")
                .font(ClimateTheme.Typography.caption)
                .foregroundStyle(ClimateTheme.secondaryInk)
        }
    }

    @ViewBuilder
    private var saveFeedback: some View {
        if isSaving {
            ClimateInlineStatus(message: "Saving", kind: .information)
        } else if let saveState {
            switch saveState {
            case .queued:
                ClimateInlineStatus(message: "Saved on this device—waiting to sync", kind: .information)
            case .synced:
                ClimateInlineStatus(message: "Saved to My Note", kind: .success)
            case .failed:
                ClimateInlineStatus(message: "Couldn’t sync—retry", kind: .error)
            }
        }
    }

    private var hasContent: Bool {
        mode == .suggestion ? selection != nil : !customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canDiscardUnsubmittedDraft: Bool {
        hasContent && operationID == nil && saveState == nil && !isCapturePresentation
    }

    private var canRemoveFailedDraft: Bool {
        hasContent && saveState == .failed && !isCapturePresentation
    }

    private var saveButtonTitle: String {
        if isSaving { return "Saving" }
        if saveState == .failed { return "Retry" }
        if saveState == .synced { return "Saved to My Note" }
        return effectiveUserID == nil ? "Sign in to save" : "Save to My Note"
    }

    private var effectiveUserID: String? {
        capturePresentation?.accountID ?? auth.user?.uid
    }

    private var isCapturePresentation: Bool { capturePresentation != nil }

    private var draftOwner: DraftOperationStore.Owner {
        auth.user.map { .account($0.uid) } ?? .guest
    }

    private func changedDraft() {
        guard hasRestoredDraft, !isRestoringDraft, !isDiscardingDraft, !isCapturePresentation else { return }
        saveState = nil
        operationID = nil
        drafts.save(articleID: article.id, owner: draftOwner, text: customText, mode: mode, selectionID: selection?.id)
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
            // A deliberate prefill (selection → reflection) wins over a stored draft.
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
        } else if ClimateActionPickerPolicy.shouldClearForEmptyOwner(
            previousOwnerKey: restoredOwnerKey,
            nextOwnerKey: ownerKey
        ) {
            // A retained article screen may outlive an account switch. Do not
            // show or submit the previous owner's in-memory draft.
            mode = .reflection
            customText = ""
            selection = nil
            saveState = nil
            operationID = nil
        }
        restoredOwnerKey = ownerKey
        hasRestoredDraft = true
        Task { @MainActor in
            // onChange handlers run with the next render. Keep the restore
            // guard through that turn so they cannot clear the restored
            // operation UUID or save state.
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
            drafts.save(articleID: article.id, owner: .guest, text: customText, mode: mode, selectionID: selection?.id)
            showSignIn = true
            return
        }
        performSave(userID: userID, operationID: operationID ?? UUID())
    }

    private func performSave(userID: String, operationID: UUID) {
        guard !isSaving else { return }
        isSaving = true
        self.operationID = operationID
        // Bind before issuing the write so a relaunch can recover the exact
        // operation. A later edit creates a new revision and clears this link.
        if drafts.draft(articleID: article.id, owner: draftOwner) == nil {
            _ = drafts.save(
                articleID: article.id,
                owner: draftOwner,
                text: customText,
                mode: mode,
                selectionID: selection?.id
            )
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
        guard !isCapturePresentation else { return }
        guard let operationID, let state = reflections.operationState(for: operationID) else { return }
        saveState = state
        if state == .synced {
            _ = drafts.discardDraft(articleID: article.id, owner: draftOwner, onlyIfBoundTo: operationID)
        }
    }

    private func actionButton(_ action: SuggestedAction, number: Int) -> some View {
        let isSelected = selection?.id == action.id
        return Button {
            selection = action
            isWriting = false
        } label: {
            HStack(alignment: .top, spacing: ClimateTheme.Spacing.compact) {
                Text(String(format: "%02d", number))
                    .font(ClimateTheme.Typography.metadata)
                    .foregroundStyle(ClimateTheme.accent)
                VStack(alignment: .leading, spacing: ClimateTheme.Spacing.small) {
                    Text("AI-generated suggestion")
                        .font(ClimateTheme.Typography.metadata)
                        .foregroundStyle(ClimateTheme.accent)
                    Text(action.category).font(ClimateTheme.Typography.metadata).foregroundStyle(ClimateTheme.secondaryInk)
                    Text(action.title).font(ClimateTheme.Typography.headline).foregroundStyle(ClimateTheme.ink)
                    Text(action.instruction).font(ClimateTheme.Typography.readingBody).foregroundStyle(ClimateTheme.secondaryInk).lineSpacing(3)
                    Text(action.cadence).font(ClimateTheme.Typography.metadata).foregroundStyle(ClimateTheme.secondaryInk)
                    if !action.evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(action.evidence)
                            .font(ClimateTheme.Typography.caption)
                            .foregroundStyle(ClimateTheme.tertiaryInk)
                            .lineSpacing(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? ClimateTheme.accent : ClimateTheme.tertiaryInk)
                    .accessibilityHidden(true)
            }
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
            .padding(ClimateTheme.Spacing.medium)
            .frame(minHeight: ClimateTheme.minimumTapTarget)
            .climateSheet(radius: ClimateTheme.Radius.medium, isSelected: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(ClimateArticleLinkStyle())
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
