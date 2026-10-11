import SwiftUI
import UIKit

struct MyNoteView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var reflections: ReflectionStore
    @EnvironmentObject private var notifications: NotificationService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showSignIn = false
    @State private var highlightedEntryID: String?
    @AccessibilityFocusState private var focusedEntryID: String?

    var onRead: () -> Void = {}
    var requestedEntryID: String?
    var articleIsAvailable: (String) -> Bool = { _ in true }
    var onOpenArticle: (String) -> Void = { _ in }
    var onWriteReflection: (ActionLog) -> Void = { _ in }
    var onEntryRevealed: (String) -> Void = { _ in }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: ClimateLayout.majorSection) {
                    content
                }
                .climateContentWidth()
                .padding(.top, ClimateLayout.element)
                .padding(.bottom, ClimateLayout.majorSection)
            }
            .scrollBounceBehavior(.basedOnSize)
            .onChange(of: requestedEntryID) { _, entryID in reveal(entryID, proxy: proxy) }
            .onAppear {
                reveal(requestedEntryID, proxy: proxy)
                Task { await notifications.refreshActionReminderStatus(for: reflections.logs) }
            }
            .onChange(of: reflections.logs) { _, logs in
                Task { await notifications.refreshActionReminderStatus(for: logs) }
                reveal(requestedEntryID, proxy: proxy)
            }
        }
        .background(Color.climateCanvas.ignoresSafeArea())
        .foregroundStyle(Color.climateInk)
        .tint(Color.climateSage)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSignIn) { SignInView() }
    }

    @ViewBuilder private var content: some View {
        if auth.user == nil {
            JournalGuestContent(onSignIn: { showSignIn = true }, onRead: onRead)
        } else if reflections.logs.isEmpty && reflections.isLoading {
            JournalLoadingView()
        } else if reflections.logs.isEmpty, let error = reflections.errorMessage {
            journalHeader
            JournalErrorContent(message: error, onRetry: reflections.retry)
        } else {
            journalHeader
            if let error = reflections.errorMessage {
                JournalErrorContent(message: error, onRetry: reflections.retry)
            }
            if reflections.isLoading {
                ProgressView("Refreshing your notes…")
                    .tint(Color.climateSage)
                    .font(.subheadline)
            }
            JournalContent(
                logs: reflections.logs,
                onRead: onRead,
                articleIsAvailable: articleIsAvailable,
                onOpenArticle: onOpenArticle,
                onWriteReflection: onWriteReflection,
                highlightedEntryID: highlightedEntryID,
                accessibilityFocus: $focusedEntryID
            )
        }
    }

    private var journalHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(reflections.logs.isEmpty ? "PRIVATE BY DEFAULT" : "MY NOTE")
                    .climateMetadata(weight: .bold)
                    .tracking(1.2)
                    .foregroundStyle(Color.climateSage)
                Text("My Note")
                    .climateDisplay(38, relativeTo: .largeTitle)
                Text(reflections.logs.isEmpty
                    ? "Save one action. Return later. Notice what changed."
                    : "Small actions, held close. Capture what you’re doing and how it feels.")
                    .font(.body)
                    .foregroundStyle(Color.climateMuted)
                    .lineSpacing(4)
            }
            Spacer(minLength: ClimateLayout.compact)
            NavigationLink { AccountView() } label: {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Color.climateMuted)
                    .frame(width: ClimateLayout.minimumTarget, height: ClimateLayout.minimumTarget)
            }
            .accessibilityLabel("Profile and settings")
        }
    }

    private func reveal(_ entryID: String?, proxy: ScrollViewProxy) {
        guard let entryID, reflections.logs.contains(where: { $0.id == entryID }) else { return }
        DispatchQueue.main.async {
            withAnimation(reduceMotion ? nil : ClimateMotion.content) {
                proxy.scrollTo(entryID, anchor: .center)
            }
            highlightedEntryID = entryID
            focusedEntryID = entryID
            onEntryRevealed(entryID)
        }
    }
}

struct JournalGuestContent: View {
    var onSignIn: () -> Void = {}
    var onRead: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.section) {
            Text("MY NOTE")
                .climateMetadata(weight: .bold)
                .tracking(1.2)
                .foregroundStyle(Color.climateSage)
            Image(systemName: "book.closed")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(Color.climateSage)
                .accessibilityHidden(true)
            Text("A private place for small actions.")
                .climateDisplay(40, relativeTo: .largeTitle)
            Text("Save an action from any story, set a reminder, and write down what stayed with you. Your notes are visible only to you.")
                .font(.body)
                .foregroundStyle(Color.climateMuted)
                .lineSpacing(5)
            Button("Continue as guest or sign in", action: onSignIn)
                .buttonStyle(ClimatePrimaryButtonStyle())
                .accessibilityHint("Creates a private guest account or opens secure sign in")
            Button("Browse stories", action: onRead)
                .buttonStyle(ClimateTextButtonStyle())
                .accessibilityHint("Opens stories you can save into My Note")
            CommunityImpactLink()
        }
    }
}

struct JournalLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.section) {
            Text("MY NOTE")
                .climateMetadata(weight: .bold)
                .tracking(1.2)
                .foregroundStyle(Color.climateSage)
            Text("Small actions, held close.")
                .climateDisplay(38, relativeTo: .largeTitle)
            ProgressView("Loading your notes…")
                .tint(Color.climateSage)
                .font(.body)
        }
    }
}

struct JournalErrorContent: View {
    let message: String
    var onRetry: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.element) {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.climateInk)
                .frame(maxWidth: .infinity, minHeight: ClimateLayout.minimumTarget, alignment: .leading)
                .padding(ClimateLayout.element)
                .background(Color.climateSurfaceRaised, in: .rect(cornerRadius: ClimateRadius.card))
                .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateSage.opacity(0.42), lineWidth: 1) }
            Button("Try again", action: onRetry)
                .buttonStyle(ClimateTextButtonStyle())
        }
    }
}

/// Production journal composition. Persisted entry kinds keep a reflection
/// distinct from an action even after relaunching or updating the app.
struct JournalContent: View {
    let logs: [ActionLog]
    var onRead: () -> Void = {}
    var allowsActions = true
    var referenceDate = Date()
    var articleIsAvailable: (String) -> Bool = { _ in true }
    var onOpenArticle: (String) -> Void = { _ in }
    var onWriteReflection: (ActionLog) -> Void = { _ in }
    var highlightedEntryID: String?
    var accessibilityFocus: AccessibilityFocusState<String?>.Binding?

    private var actions: [ActionLog] { logs.filter { $0.kind == .action } }
    private var planned: [ActionLog] { actions.filter { $0.status == .planned } }
    private var completed: [ActionLog] { actions.filter { $0.status == .completed } }
    private var writtenReflections: [ActionLog] { logs.filter { $0.kind == .reflection } }
    private var unknown: [ActionLog] {
        logs.filter { if case .unknown = $0.kind { return true }; return false }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.majorSection) {
            if logs.isEmpty {
                emptyContent
            } else {
                if !actions.isEmpty {
                    JournalCalendarStrip(completedDates: completed.compactMap(\.completedAt), referenceDate: referenceDate)
                }
                if let next = planned.first { plannedActionSection(next) }
                reflectionSection
                if planned.count > 1 { journalSection(title: "Also planned", entries: Array(planned.dropFirst())) }
                if !completed.isEmpty { journalSection(title: "Completed", entries: completed) }
                if !unknown.isEmpty { journalSection(title: "Saved notes", entries: unknown) }
                if !completed.isEmpty { JournalProgress(logs: completed) }
            }
            CommunityImpactLink()
        }
    }

    private var emptyContent: some View {
        let steps = [
            ("Read what catches you", "Explore verified climate stories."),
            ("Choose one small step", "Keep the action realistic and specific."),
            ("Return and reflect", "Record what changed when you tried it."),
        ]
        return VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Image("ClimateHeroV2")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 248)
                    .clipped()
                    .accessibilityHidden(true)
                LinearGradient(
                    colors: [.clear, Color.climateCanvas.opacity(0.60), Color.climateCanvas.opacity(0.96)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                VStack(alignment: .leading, spacing: 7) {
                    Text("YOUR FIRST NOTE")
                        .climateMetadata(weight: .bold)
                        .tracking(1.1)
                        .foregroundStyle(Color.climateSage)
                    Text("Start with a story worth keeping.")
                        .climateEditorialDisplay(32, relativeTo: .title)
                        .tracking(-0.4)
                    Text("Choose one useful step from a published article. Your source stays attached for context.")
                        .font(.subheadline)
                        .foregroundStyle(Color.climateInk.opacity(0.82))
                        .lineSpacing(3)
                }
                .padding(ClimateLayout.cardPadding)
            }
            .clipShape(.rect(cornerRadius: ClimateRadius.card))
            .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }
            .shadow(color: Color.black.opacity(0.24), radius: 24, y: 14)

            VStack(spacing: 0) {
                ForEach(steps.indices, id: \.self) { index in
                    HStack(spacing: 13) {
                        Text(String(format: "%02d", index + 1))
                            .climateEditorialDisplay(17, relativeTo: .body)
                            .foregroundStyle(Color.climateSage)
                            .frame(width: 38, height: 38)
                            .overlay { Circle().stroke(Color.climateSage.opacity(0.42), lineWidth: 1) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(steps[index].0).font(.body.weight(.semibold))
                            Text(steps[index].1).font(.footnote).foregroundStyle(Color.climateMuted)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 66)
                    if index < steps.count - 1 { ClimateRule() }
                }
            }
            .padding(.top, ClimateLayout.element)

            Button("Browse stories", action: onRead)
                .buttonStyle(ClimatePrimaryButtonStyle())
                .allowsHitTesting(allowsActions)
                .padding(.top, ClimateLayout.element)

            Label("Your note stays private unless you choose to contribute an anonymous supported-action estimate.", systemImage: "lock")
                .font(.footnote)
                .foregroundStyle(Color.climateMuted)
                .lineSpacing(3)
                .padding(.top, 14)
        }
    }

    private func plannedActionSection(_ log: ActionLog) -> some View {
        VStack(alignment: .leading, spacing: ClimateLayout.element) {
            JournalHeading("Planned action")
            entry(log)
                .id(log.id)
                .padding(ClimateLayout.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(highlightedEntryID == log.id ? Color.climateSage.opacity(0.15) : Color.climateSurfaceRaised, in: .rect(cornerRadius: ClimateRadius.card))
                .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }
                .modifier(JournalEntryAccessibilityFocus(focus: accessibilityFocus, entryID: log.id))
        }
    }

    @ViewBuilder private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.element) {
            JournalHeading("Reflection")
            if writtenReflections.isEmpty {
                if allowsActions, let seed = planned.first ?? completed.first {
                    Button {
                        onWriteReflection(seed)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Write a reflection")
                                .font(.headline)
                            Text("What stayed with you from this note?")
                                .font(.body)
                                .foregroundStyle(Color.climateMuted)
                        }
                        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                        .padding(ClimateLayout.cardPadding)
                        .background(Color.climateSurface, in: .rect(cornerRadius: ClimateRadius.card))
                        .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens a private reflection on this note")
                } else {
                    Text("Reflections from your reading will appear here.")
                        .font(.body)
                        .foregroundStyle(Color.climateMuted)
                        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
                        .padding(ClimateLayout.cardPadding)
                        .background(Color.climateSurface, in: .rect(cornerRadius: ClimateRadius.card))
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(writtenReflections.enumerated()), id: \.element.id) { index, log in
                        if index > 0 { ClimateRule().padding(.vertical, ClimateLayout.element) }
                        entry(log)
                            .id(log.id)
                            .modifier(JournalEntryAccessibilityFocus(focus: accessibilityFocus, entryID: log.id))
                    }
                }
            }
        }
    }

    private func journalSection(title: String, entries: [ActionLog]) -> some View {
        VStack(alignment: .leading, spacing: ClimateLayout.element) {
            JournalHeading(title)
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, log in
                    if index > 0 { ClimateRule().padding(.vertical, ClimateLayout.element) }
                    entry(log)
                        .id(log.id)
                        .padding(highlightedEntryID == log.id ? ClimateLayout.compact : 0)
                        .background(highlightedEntryID == log.id ? Color.climateSage.opacity(0.11) : .clear, in: .rect(cornerRadius: ClimateRadius.control))
                        .modifier(JournalEntryAccessibilityFocus(focus: accessibilityFocus, entryID: log.id))
                }
            }
        }
    }

    @ViewBuilder private func entry(_ log: ActionLog) -> some View {
        switch log.kind {
        case .action:
            if allowsActions, log.status == .planned {
                ActionLogRow(log: log, articleIsAvailable: articleIsAvailable, onOpenArticle: onOpenArticle)
            } else if allowsActions {
                CompletedActionRow(log: log, articleIsAvailable: articleIsAvailable, onOpenArticle: onOpenArticle)
            } else {
                JournalEntry(log: log, articleIsAvailable: articleIsAvailable, onOpenArticle: onOpenArticle) { EmptyView() }
            }
        case .reflection, .unknown:
            JournalEntry(log: log, articleIsAvailable: articleIsAvailable, onOpenArticle: onOpenArticle) { EmptyView() }
        }
    }
}

private struct JournalHeading: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title.uppercased())
            .climateMetadata(weight: .bold)
            .tracking(1.1)
            .foregroundStyle(Color.climateSage)
    }
}

private struct JournalCalendarStrip: View {
    let completedDates: [Date]
    let referenceDate: Date
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.element) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week").climateDisplay(27, relativeTo: .title2)
                Spacer(minLength: ClimateLayout.compact)
                Text(dateRange).font(.footnote).foregroundStyle(Color.climateMuted)
            }
            WeekCalendar(completedDates: completedDates, referenceDate: referenceDate)
        }
        .padding(ClimateLayout.cardPadding)
        .background(Color.climateSurface, in: .rect(cornerRadius: ClimateRadius.card))
        .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateRule, lineWidth: 1) }
    }

    private var dateRange: String {
        let start = WeekCalendar.days(for: referenceDate, calendar: calendar).first ?? referenceDate
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let formatter = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone)
        return "\(start.formatted(formatter.month(.abbreviated).day())) – \(end.formatted(formatter.month(.abbreviated).day()))"
    }
}

private struct WeekCalendar: View {
    let completedDates: [Date]
    let referenceDate: Date
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.calendar) private var calendar

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: ClimateLayout.compact), count: 4), spacing: ClimateLayout.compact) {
                    cells
                }
            } else {
                HStack(spacing: 5) { cells }
            }
        }
    }

    @ViewBuilder private var cells: some View {
        ForEach(days, id: \.self) { day in
            let isCompleted = completedDates.contains { calendar.isDate($0, inSameDayAs: day) }
            let isToday = calendar.isDate(day, inSameDayAs: referenceDate)
            VStack(spacing: 7) {
                Text(day.formatted(.dateTime.weekday(.narrow))).font(.caption.weight(.semibold))
                Text(day.formatted(.dateTime.day())).font(.body.weight(.semibold)).monospacedDigit()
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(isCompleted || isToday ? Color.climatePaperInk : Color.climateMuted)
            .frame(maxWidth: .infinity, minHeight: 82)
            .background(isCompleted || isToday ? Color.climateSage : Color.climateSurfaceRaised, in: .rect(cornerRadius: ClimateRadius.control))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(day.formatted(.dateTime.weekday(.wide).month().day())), \(isCompleted ? "action completed" : "no completed action")")
        }
    }

    private var days: [Date] { Self.days(for: referenceDate, calendar: calendar) }

    static func days(for date: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: date)
        let offset = -((calendar.component(.weekday, from: today) - calendar.firstWeekday + 7) % 7)
        let start = calendar.date(byAdding: .day, value: offset, to: today) ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

private struct JournalProgress: View {
    let logs: [ActionLog]
    private var summary: PersonalImpactSummary { PersonalImpactSummary(logs: logs) }

    var body: some View {
        if summary.hasContent {
            VStack(alignment: .leading, spacing: ClimateLayout.element) {
                JournalHeading("Your impact")
                PersonalImpactSummaryView(summary: summary, showsTitle: false, compact: true)
            }
            .padding(ClimateLayout.cardPadding)
            .background(
                LinearGradient(
                    colors: [Color.climateSurfaceRaised.opacity(0.88), Color.climateSurface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: .rect(cornerRadius: ClimateRadius.card)
            )
            .overlay { RoundedRectangle(cornerRadius: ClimateRadius.card).stroke(Color.climateSage.opacity(0.20), lineWidth: 1) }
            .shadow(color: Color.black.opacity(0.20), radius: 22, y: 12)
        }
    }
}

private struct JournalEntry<Actions: View>: View {
    let log: ActionLog
    let articleIsAvailable: (String) -> Bool
    let onOpenArticle: (String) -> Void
    let actions: Actions

    init(log: ActionLog, articleIsAvailable: @escaping (String) -> Bool, onOpenArticle: @escaping (String) -> Void, @ViewBuilder actions: () -> Actions) {
        self.log = log
        self.articleIsAvailable = articleIsAvailable
        self.onOpenArticle = onOpenArticle
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.element) {
            if showsStatus { Label(statusLabel, systemImage: statusSymbol).font(.footnote.weight(.semibold)).foregroundStyle(statusColor) }
            Text(log.title).climateDisplay(25, relativeTo: .title2)
            Text(log.detail).font(.climateBody).foregroundStyle(Color.climateMuted).lineSpacing(3)
            if articleIsAvailable(log.articleID) {
                Button {
                    onOpenArticle(log.articleID)
                } label: {
                    Label("From \(log.articleTitle)", systemImage: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: ClimateLayout.minimumTarget, alignment: .leading)
                }
                .buttonStyle(ClimateTextButtonStyle())
                .accessibilityHint("Opens the source story")
            } else {
                Text("The source story is no longer available. This note is still yours.")
                    .font(.footnote)
                    .foregroundStyle(Color.climateMuted)
            }
            if log.status == .completed, let completedAt = log.completedAt {
                Text(completedAt.formatted(.dateTime.year().month(.abbreviated).day()))
                    .font(.footnote)
                    .foregroundStyle(Color.climateMuted)
            }
            actions
        }
    }

    private var showsStatus: Bool { !(log.kind == .action && log.status == .planned) }
    private var statusLabel: String {
        switch log.kind {
        case .reflection: "Reflection"
        case .unknown: "Saved note"
        case .action: log.status == .completed ? "Completed" : "Planned"
        }
    }
    private var statusSymbol: String {
        switch log.kind {
        case .reflection: "text.quote"
        case .unknown: "doc.text"
        case .action: log.status == .completed ? "checkmark.circle.fill" : "circle.dashed"
        }
    }
    private var statusColor: Color { log.status == .completed ? Color.climateSage : Color.climateMuted }
}

private struct ActionLogRow: View {
    let log: ActionLog
    let articleIsAvailable: (String) -> Bool
    let onOpenArticle: (String) -> Void
    @EnvironmentObject private var reflections: ReflectionStore
    @EnvironmentObject private var notifications: NotificationService
    @State private var errorMessage: String?
    @State private var isCompleting = false
    @State private var completionSubmitted = false
    @State private var showReminderEditor = false

    var body: some View {
        JournalEntry(log: log, articleIsAvailable: articleIsAvailable, onOpenArticle: onOpenArticle) {
            if let errorMessage { JournalInlineError(message: errorMessage) }
            if completionSubmitted { JournalInlineSuccess(message: "Marked complete. You can undo this if needed.") }
            JournalActionButtons(
                isCompleting: isCompleting,
                completionSubmitted: completionSubmitted,
                reminder: notifications.reminder(for: log),
                onComplete: complete,
                onUndo: reopen,
                onRemind: { showReminderEditor = true },
                onRemoveReminder: { notifications.cancelActionReminder(for: log) }
            )
        }
        .sheet(isPresented: $showReminderEditor) { ReminderEditor(log: log, existingReminder: notifications.reminder(for: log)) }
    }

    private func complete() {
        guard !isCompleting, !completionSubmitted, log.kind.supportsCompletion else { return }
        isCompleting = true
        errorMessage = nil
        Task { @MainActor in
            defer { isCompleting = false }
            do {
                try await reflections.complete(log)
                notifications.cancelActionReminder(for: log)
                completionSubmitted = true
                UIAccessibility.post(notification: .announcement, argument: "Action completed. Reminder cancelled.")
            } catch {
                errorMessage = "We couldn’t mark this action complete. Please try again."
            }
        }
    }

    private func reopen() {
        guard !isCompleting, completionSubmitted || log.status == .completed else { return }
        isCompleting = true
        errorMessage = nil
        Task { @MainActor in
            defer { isCompleting = false }
            do {
                try await reflections.reopen(log)
                completionSubmitted = false
                UIAccessibility.post(notification: .announcement, argument: "Action marked incomplete")
            } catch {
                errorMessage = "We couldn’t reopen this action. Please try again."
            }
        }
    }
}

private struct CompletedActionRow: View {
    let log: ActionLog
    let articleIsAvailable: (String) -> Bool
    let onOpenArticle: (String) -> Void
    @EnvironmentObject private var reflections: ReflectionStore
    @State private var isReopening = false
    @State private var errorMessage: String?

    var body: some View {
        JournalEntry(log: log, articleIsAvailable: articleIsAvailable, onOpenArticle: onOpenArticle) {
            if let errorMessage { JournalInlineError(message: errorMessage) }
            Button(isReopening ? "Reopening…" : "Mark incomplete", action: reopen)
                .buttonStyle(ClimateTextButtonStyle())
                .disabled(isReopening)
        }
    }

    private func reopen() {
        guard !isReopening else { return }
        isReopening = true
        Task { @MainActor in
            defer { isReopening = false }
            do {
                try await reflections.reopen(log)
                UIAccessibility.post(notification: .announcement, argument: "Action marked incomplete")
            } catch {
                errorMessage = "We couldn’t reopen this action. Please try again."
            }
        }
    }
}

private struct JournalActionButtons: View {
    let isCompleting: Bool
    let completionSubmitted: Bool
    let reminder: NotificationService.ActionReminder?
    let onComplete: () -> Void
    let onUndo: () -> Void
    let onRemind: () -> Void
    let onRemoveReminder: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateLayout.compact) {
            Button(completionSubmitted ? "Completed" : isCompleting ? "Completing…" : "Mark complete", action: onComplete)
                .buttonStyle(ClimatePrimaryButtonStyle())
                .disabled(isCompleting || completionSubmitted)
            if completionSubmitted {
                Button("Undo", action: onUndo).buttonStyle(ClimateTextButtonStyle())
            } else if let reminder {
                HStack(spacing: ClimateLayout.element) {
                    Button(action: onRemind) {
                        Label(reminder.fireDate.formatted(date: .abbreviated, time: .shortened), systemImage: "bell.fill")
                    }
                    .buttonStyle(ClimateTextButtonStyle())
                    .accessibilityHint("Changes this reminder")
                    Button("Remove", action: onRemoveReminder).buttonStyle(ClimateTextButtonStyle())
                }
            } else {
                Button(action: onRemind) { Label("Remind me", systemImage: "bell") }
                    .buttonStyle(ClimateTextButtonStyle())
            }
        }
    }
}

private struct ReminderEditor: View {
    let log: ActionLog
    let existingReminder: NotificationService.ActionReminder?
    @EnvironmentObject private var notifications: NotificationService
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(log: ActionLog, existingReminder: NotificationService.ActionReminder?) {
        self.log = log
        self.existingReminder = existingReminder
        _date = State(initialValue: existingReminder?.fireDate ?? NotificationService().proposedActionReminderDate())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ClimateLayout.section) {
                    Text(existingReminder == nil ? "Reminder" : "Edit reminder")
                        .climateDisplay(34, relativeTo: .title)
                    Text("We’ll remind you on this device about \(log.title).")
                        .font(.body).foregroundStyle(Color.climateMuted).lineSpacing(4)
                    DatePicker("Remind me", selection: $date, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                        .tint(Color.climateSage)
                        .padding(ClimateLayout.cardPadding)
                        .background(Color.climateSurface, in: .rect(cornerRadius: ClimateRadius.card))
                    if let errorMessage { JournalInlineError(message: errorMessage) }
                    Button(isSaving ? "Saving…" : "Save reminder", action: save)
                        .buttonStyle(ClimatePrimaryButtonStyle())
                        .disabled(isSaving)
                    if existingReminder != nil {
                        Button("Remove reminder", role: .destructive) {
                            notifications.cancelActionReminder(for: log)
                            dismiss()
                        }
                        .buttonStyle(ClimateTextButtonStyle())
                        .foregroundStyle(.red)
                    }
                }
                .climateContentWidth()
                .padding(.top, ClimateLayout.section)
                .padding(.bottom, ClimateLayout.majorSection)
            }
            .background(Color.climateCanvas.ignoresSafeArea())
            .foregroundStyle(Color.climateInk)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: dismiss.callAsFunction) } }
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            if await notifications.scheduleActionReminder(for: log, at: date) {
                UIAccessibility.post(notification: .announcement, argument: "Reminder saved")
                dismiss()
            } else {
                errorMessage = notifications.errorMessage ?? "We couldn’t set the reminder. Please try again."
            }
        }
    }
}

private struct JournalInlineError: View {
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

private struct JournalInlineSuccess: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "checkmark.circle.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.climateInk)
            .frame(maxWidth: .infinity, minHeight: ClimateLayout.minimumTarget, alignment: .leading)
            .padding(.horizontal, ClimateLayout.element)
            .background(Color.climateSage.opacity(0.32), in: .rect(cornerRadius: ClimateRadius.control))
    }
}

private struct JournalEntryAccessibilityFocus: ViewModifier {
    var focus: AccessibilityFocusState<String?>.Binding?
    let entryID: String

    @ViewBuilder func body(content: Content) -> some View {
        if let focus { content.accessibilityFocused(focus, equals: entryID) }
        else { content }
    }
}
