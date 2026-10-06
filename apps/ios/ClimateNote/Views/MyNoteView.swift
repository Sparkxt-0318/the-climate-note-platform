import Foundation
import SwiftUI

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
                VStack(alignment: .leading, spacing: ClimateTheme.Spacing.hero) {
                    content
                }
                .padding(.horizontal, ClimateTheme.Spacing.large)
                .padding(.top, ClimateTheme.Spacing.large)
                .padding(.bottom, ClimateTheme.Spacing.xxLarge)
                .frame(maxWidth: ClimateTheme.ContentWidth.reading, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .onChange(of: requestedEntryID) { _, entryID in
                reveal(entryID, proxy: proxy)
            }
            .onAppear {
                reveal(requestedEntryID, proxy: proxy)
                Task { await notifications.refreshActionReminderStatus(for: reflections.logs) }
            }
            .onChange(of: reflections.logs) { _, logs in
                Task { await notifications.refreshActionReminderStatus(for: logs) }
                reveal(requestedEntryID, proxy: proxy)
            }
        }
        .background { ClimateBackdrop() }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .principal) { ClimateWordmark() } }
        .toolbarBackground(ClimateTheme.pine, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .tint(ClimateTheme.accent)
        .sheet(isPresented: $showSignIn) { SignInView() }
    }

    @ViewBuilder private var content: some View {
        if auth.user == nil {
            JournalGuestContent(onSignIn: { showSignIn = true }, onRead: onRead)
        } else if reflections.logs.isEmpty && reflections.isLoading {
            JournalLoadingView()
        } else if reflections.logs.isEmpty, let error = reflections.errorMessage {
            ClimatePageHeader(
                title: "My Note",
                subtitle: "Small actions add up. Capture what you’re doing and how it feels.",
                titleFont: ClimateTheme.Typography.leadTitle
            )
            JournalErrorContent(message: error, onRetry: reflections.retry)
        } else {
            if let error = reflections.errorMessage {
                JournalErrorContent(message: error, onRetry: reflections.retry)
            }
            if reflections.isLoading {
                ProgressView("Refreshing your notes…")
                    .font(ClimateTheme.Typography.callout)
                    .tint(ClimateTheme.accent)
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

    private func reveal(_ entryID: String?, proxy: ScrollViewProxy) {
        guard let entryID, reflections.logs.contains(where: { $0.id == entryID }) else { return }
        DispatchQueue.main.async {
            withAnimation(reduceMotion ? nil : ClimateTheme.Motion.standardState) {
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
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.hero) {
            ClimatePageHeader(
                title: "My Note",
                subtitle: "Small actions add up. Capture what you’re doing and how it feels.",
                titleFont: ClimateTheme.Typography.leadTitle
            )

            Button("Continue as guest or sign in", action: onSignIn)
                .buttonStyle(ClimatePrimaryButtonStyle())
            Button("Browse notes", action: onRead)
                .buttonStyle(ClimateSecondaryButtonStyle())
                .frame(maxWidth: .infinity)
                .accessibilityHint("Opens Read. Reading is available without signing in.")

            CommunityImpactLink()
        }
    }
}

struct JournalLoadingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.hero) {
            ClimatePageHeader(
                title: "My Note",
                subtitle: "Small actions add up. Capture what you’re doing and how it feels.",
                titleFont: ClimateTheme.Typography.leadTitle
            )
            ProgressView("Loading your notes…")
                .font(ClimateTheme.Typography.callout)
                .tint(ClimateTheme.accent)
        }
    }
}

struct JournalErrorContent: View {
    let message: String
    var onRetry: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.small) {
            ClimateInlineStatus(message: message, kind: .error)
            Button("Try again", action: onRetry)
                .buttonStyle(ClimateSecondaryButtonStyle())
        }
    }
}

/// Production journal composition. Reflection and action semantics come from the persisted
/// kind field, so an older custom action remains an action instead of being guessed as writing.
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
        logs.filter {
            if case .unknown = $0.kind { return true }
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.hero) {
            ClimatePageHeader(
                title: "My Note",
                subtitle: "Small actions add up. Capture what you’re doing and how it feels.",
                titleFont: ClimateTheme.Typography.leadTitle
            )

            if logs.isEmpty {
                emptyContent
            } else {
                if !actions.isEmpty {
                    JournalCalendarStrip(
                        completedDates: completed.compactMap(\.completedAt),
                        referenceDate: referenceDate
                    )
                }

                if let next = planned.first {
                    plannedActionSection(next)
                }

                reflectionSection

                if planned.count > 1 {
                    journalSection(title: "Also planned", entries: Array(planned.dropFirst()))
                }
                if !completed.isEmpty {
                    journalSection(title: "Completed", entries: completed)
                }
                if !unknown.isEmpty {
                    journalSection(title: "Saved notes", entries: unknown)
                }
                if !completed.isEmpty {
                    JournalProgress(logs: completed)
                }
            }

            CommunityImpactLink()
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
            ClimateQuietLabel(text: "Nothing here yet")
            Text("Pick an action from a note—it’ll show up here.")
                .font(ClimateTheme.Typography.pageSubtitle)
                .foregroundStyle(ClimateTheme.secondaryInk)
            Button("Browse notes", action: onRead)
                .buttonStyle(ClimatePrimaryButtonStyle())
                .allowsHitTesting(allowsActions)
                .accessibilityHint("Opens the Read tab")
        }
    }

    @ViewBuilder private func plannedActionSection(_ log: ActionLog) -> some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
            ClimateQuietLabel(text: "Planned action")
            entry(log)
                .id(log.id)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(ClimateTheme.Spacing.medium)
                .background(
                    highlightedEntryID == log.id
                        ? ClimateTheme.accent.opacity(0.10)
                        : ClimateTheme.elevatedSurface,
                    in: .rect(cornerRadius: ClimateTheme.Radius.medium)
                )
                .modifier(JournalEntryAccessibilityFocus(focus: accessibilityFocus, entryID: log.id))
        }
    }

    @ViewBuilder private var reflectionSection: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.medium) {
            ClimateQuietLabel(text: "Reflection")
            if writtenReflections.isEmpty {
                if allowsActions, let seed = planned.first ?? completed.first {
                    Button {
                        onWriteReflection(seed)
                    } label: {
                        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.small) {
                            Text("Write a reflection")
                                .font(ClimateTheme.Typography.subheadlineStrong)
                                .foregroundStyle(ClimateTheme.ink)
                            Text("What stayed with you from this note?")
                                .font(ClimateTheme.Typography.callout)
                                .foregroundStyle(ClimateTheme.tertiaryInk)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(ClimateTheme.Spacing.medium)
                        .frame(minHeight: 96, alignment: .topLeading)
                        .background(ClimateTheme.elevatedSurface, in: .rect(cornerRadius: ClimateTheme.Radius.medium))
                        .overlay {
                            RoundedRectangle(cornerRadius: ClimateTheme.Radius.medium)
                                .stroke(ClimateTheme.ink.opacity(0.12), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens a private reflection on this note")
                } else {
                    Text("Reflections from your reading will appear here.")
                        .font(ClimateTheme.Typography.callout)
                        .foregroundStyle(ClimateTheme.tertiaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(ClimateTheme.Spacing.medium)
                        .frame(minHeight: 88, alignment: .topLeading)
                        .background(ClimateTheme.elevatedSurface, in: .rect(cornerRadius: ClimateTheme.Radius.medium))
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(writtenReflections.enumerated()), id: \.element.id) { index, log in
                        if index > 0 {
                            Rectangle()
                                .fill(ClimateTheme.divider.opacity(0.55))
                                .frame(height: 1)
                                .padding(.vertical, ClimateTheme.Spacing.large)
                        }
                        entry(log)
                            .id(log.id)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .modifier(JournalEntryAccessibilityFocus(focus: accessibilityFocus, entryID: log.id))
                    }
                }
            }
        }
    }

    private func journalSection(title: String, entries: [ActionLog]) -> some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
            ClimateQuietLabel(text: title)
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, log in
                    if index > 0 {
                        Rectangle()
                            .fill(ClimateTheme.divider.opacity(0.55))
                            .frame(height: 1)
                            .padding(.vertical, ClimateTheme.Spacing.large)
                    }
                    entry(log)
                        .id(log.id)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(highlightedEntryID == log.id ? ClimateTheme.Spacing.small : 0)
                        .background(
                            highlightedEntryID == log.id ? ClimateTheme.accent.opacity(0.08) : Color.clear,
                            in: .rect(cornerRadius: ClimateTheme.Radius.small)
                        )
                        .modifier(JournalEntryAccessibilityFocus(focus: accessibilityFocus, entryID: log.id))
                }
            }
        }
    }

    @ViewBuilder private func entry(_ log: ActionLog) -> some View {
        switch log.kind {
        case .action:
            if allowsActions && log.status == .planned {
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

private struct JournalCalendarStrip: View {
    let completedDates: [Date]
    let referenceDate: Date
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    private var completedCount: Int {
        let days = WeekCalendar.days(for: referenceDate, calendar: calendar)
        return days.filter { day in
            completedDates.contains { calendar.isDate($0, inSameDayAs: day) }
        }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week")
                    .font(ClimateTheme.Typography.sectionTitle)
                    .foregroundStyle(ClimateTheme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: ClimateTheme.Spacing.small)
                Text(dateRange)
                    .font(ClimateTheme.Typography.caption)
                    .foregroundStyle(ClimateTheme.tertiaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            WeekCalendar(completedDates: completedDates, referenceDate: referenceDate)
                .accessibilityLabel(
                    completedCount == 0
                        ? "This week, no actions completed yet"
                        : "This week, \(completedCount) completed"
                )
        }
        .padding(ClimateTheme.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ClimateTheme.elevatedSurface, in: .rect(cornerRadius: ClimateTheme.Radius.medium))
    }

    private var dateRange: String {
        let start = calendar.date(
            byAdding: .day,
            value: -((calendar.component(.weekday, from: referenceDate) - calendar.firstWeekday + 7) % 7),
            to: calendar.startOfDay(for: referenceDate)
        ) ?? referenceDate
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let sameMonth = calendar.isDate(start, equalTo: end, toGranularity: .month)
        let startText = start.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).month(.abbreviated).day())
        let endText = sameMonth
            ? end.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).day())
            : end.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).month(.abbreviated).day())
        return "\(startText) — \(endText)"
    }
}

private struct JournalProgress: View {
    let logs: [ActionLog]
    private var summary: PersonalImpactSummary { PersonalImpactSummary(logs: logs) }

    var body: some View {
        if summary.hasContent {
            VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
                ClimateQuietLabel(text: "Your impact")
                PersonalImpactSummaryView(summary: summary, showsTitle: false, compact: true)
            }
            .padding(ClimateTheme.Spacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ClimateTheme.elevatedSurface, in: .rect(cornerRadius: ClimateTheme.Radius.medium))
        }
    }
}

private struct WeekCalendar: View {
    let completedDates: [Date]
    let referenceDate: Date
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: ClimateTheme.Spacing.small), count: 4),
                spacing: ClimateTheme.Spacing.small
            ) {
                ForEach(days, id: \.self) { day in
                    let completed = completedDates.contains { calendar.isDate($0, inSameDayAs: day) }
                    let today = calendar.isDate(day, inSameDayAs: referenceDate)
                    dayCell(day: day, completed: completed, today: today)
                }
            }
        } else {
            HStack(alignment: .top, spacing: ClimateTheme.Spacing.xSmall) {
                ForEach(days, id: \.self) { day in
                    let completed = completedDates.contains { calendar.isDate($0, inSameDayAs: day) }
                    let today = calendar.isDate(day, inSameDayAs: referenceDate)
                    dayCell(day: day, completed: completed, today: today)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func dayCell(day: Date, completed: Bool, today: Bool) -> some View {
        let weekday = day.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).weekday(.abbreviated))
        let dayNum = day.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).day())

        if completed {
            VStack(spacing: ClimateTheme.Spacing.xSmall) {
                Text(weekday)
                    .font(ClimateTheme.Typography.calendarWeekday)
                Text(dayNum)
                    .font(ClimateTheme.Typography.calendarDay)
                    .monospacedDigit()
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.top, 2)
            }
            .foregroundStyle(ClimateTheme.onPrimaryAction)
            .frame(maxWidth: .infinity)
            .padding(.vertical, ClimateTheme.Spacing.compact)
            .background(ClimateTheme.primaryAction, in: .rect(cornerRadius: ClimateTheme.Radius.medium))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(day.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).weekday(.wide).month().day())), \(today ? "today, " : "")action completed")
        } else {
            VStack(spacing: ClimateTheme.Spacing.xSmall) {
                Text(weekday)
                    .font(ClimateTheme.Typography.calendarWeekday)
                    .foregroundStyle(today ? ClimateTheme.ink : ClimateTheme.tertiaryInk)
                Text(dayNum)
                    .font(ClimateTheme.Typography.calendarDay)
                    .monospacedDigit()
                    .foregroundStyle(today ? ClimateTheme.ink : ClimateTheme.tertiaryInk)
                Circle()
                    .stroke(today ? ClimateTheme.ink.opacity(0.35) : ClimateTheme.divider, lineWidth: 1.25)
                    .frame(width: 18, height: 18)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ClimateTheme.Spacing.compact)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(day.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).weekday(.wide).month().day())), \(today ? "today, " : "")no completed action")
        }
    }

    private var days: [Date] {
        Self.days(for: referenceDate, calendar: calendar)
    }

    static func days(for referenceDate: Date, calendar: Calendar) -> [Date] {
        let today = calendar.startOfDay(for: referenceDate)
        let weekday = calendar.component(.weekday, from: today)
        let offset = -(weekday - calendar.firstWeekday + 7) % 7
        let start = calendar.date(byAdding: .day, value: offset, to: today) ?? today
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

private struct JournalEntry<Actions: View>: View {
    let log: ActionLog
    let articleIsAvailable: (String) -> Bool
    let onOpenArticle: (String) -> Void
    let actions: Actions
    @Environment(\.calendar) private var calendar
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone

    init(
        log: ActionLog,
        articleIsAvailable: @escaping (String) -> Bool,
        onOpenArticle: @escaping (String) -> Void,
        @ViewBuilder actions: () -> Actions
    ) {
        self.log = log
        self.articleIsAvailable = articleIsAvailable
        self.onOpenArticle = onOpenArticle
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.medium) {
            if showsStatusBadge {
                HStack(spacing: ClimateTheme.Spacing.xSmall) {
                    Image(systemName: statusSymbol)
                        .font(.caption.weight(.semibold))
                        .accessibilityHidden(true)
                    Text(statusLabel)
                        .font(ClimateTheme.Typography.captionStrong)
                }
                .foregroundStyle(statusColor)
            }

            Text(log.title)
                .font(ClimateTheme.Typography.leadDeck)
                .foregroundStyle(ClimateTheme.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(log.detail)
                .font(ClimateTheme.Typography.panelBody)
                .foregroundStyle(ClimateTheme.secondaryInk)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if articleIsAvailable(log.articleID) {
                Button {
                    onOpenArticle(log.articleID)
                } label: {
                    HStack(spacing: ClimateTheme.Spacing.xSmall) {
                        Text("From \(log.articleTitle)")
                            .font(ClimateTheme.Typography.captionStrong)
                            .multilineTextAlignment(.leading)
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: ClimateTheme.minimumTapTarget, alignment: .leading)
                }
                .buttonStyle(.plain)
                .foregroundStyle(ClimateTheme.accent)
                .accessibilityHint("Opens the source article")
            } else {
                Text("The source article is no longer available. This note is still yours.")
                    .font(ClimateTheme.Typography.subheadline)
                    .foregroundStyle(ClimateTheme.secondaryInk)
            }

            if log.status == .completed, let date = log.completedAt {
                Text(date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: timeZone).year().month(.abbreviated).day()))
                    .font(ClimateTheme.Typography.caption)
                    .foregroundStyle(ClimateTheme.tertiaryInk)
            }

            actions
        }
    }

    /// Planned actions already sit under a “Planned action” label — skip the redundant badge.
    private var showsStatusBadge: Bool {
        !(log.kind == .action && log.status == .planned)
    }

    private var statusLabel: String {
        switch log.kind {
        case .reflection: return "Reflection"
        case .unknown: return "Saved note"
        case .action: return log.status == .completed ? "Completed" : "Planned"
        }
    }

    private var statusSymbol: String {
        switch log.kind {
        case .reflection: return "text.quote"
        case .unknown: return "doc.text"
        case .action: return log.status == .completed ? "checkmark.circle.fill" : "circle.dashed"
        }
    }

    private var statusColor: Color {
        switch log.kind {
        case .reflection: return ClimateTheme.secondaryInk
        case .unknown: return ClimateTheme.tertiaryInk
        case .action: return log.status == .completed ? ClimateTheme.accent : ClimateTheme.secondaryInk
        }
    }
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
            if let errorMessage { ClimateInlineStatus(message: errorMessage, kind: .error) }
            if completionSubmitted {
                ClimateInlineStatus(message: "Marked complete.", kind: .success)
            }
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
        .sheet(isPresented: $showReminderEditor) {
            ReminderEditor(log: log, existingReminder: notifications.reminder(for: log))
        }
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
                AccessibilityNotification.Announcement("Action completed. Reminder cancelled.").post()
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
                AccessibilityNotification.Announcement("Action marked incomplete").post()
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
            if let errorMessage { ClimateInlineStatus(message: errorMessage, kind: .error) }
            Button(isReopening ? "Reopening…" : "Mark incomplete", action: reopen)
                .buttonStyle(.plain)
                .font(ClimateTheme.Typography.subheadlineStrong)
                .foregroundStyle(ClimateTheme.accent)
                .frame(minHeight: ClimateTheme.minimumTapTarget, alignment: .leading)
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
                AccessibilityNotification.Announcement("Action marked incomplete").post()
            } catch {
                errorMessage = "We couldn’t reopen this action. Please try again."
            }
        }
    }
}

private struct JournalEntryAccessibilityFocus: ViewModifier {
    var focus: AccessibilityFocusState<String?>.Binding?
    let entryID: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if let focus {
            content.accessibilityFocused(focus, equals: entryID)
        } else {
            content
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
        VStack(alignment: .leading, spacing: ClimateTheme.Spacing.xSmall) {
            Button(completionSubmitted ? "Completed" : isCompleting ? "Completing…" : "Mark complete", action: onComplete)
                .buttonStyle(ClimatePrimaryButtonStyle())
                .disabled(isCompleting || completionSubmitted)

            if completionSubmitted {
                Button("Undo", action: onUndo)
                    .buttonStyle(.plain)
                    .font(ClimateTheme.Typography.subheadlineStrong)
                    .foregroundStyle(ClimateTheme.accent)
                    .frame(minHeight: ClimateTheme.minimumTapTarget, alignment: .leading)
            } else if let reminder {
                HStack(spacing: ClimateTheme.Spacing.medium) {
                    Button(action: onRemind) {
                        Label(
                            reminder.fireDate.formatted(date: .abbreviated, time: .shortened),
                            systemImage: "bell.fill"
                        )
                        .font(ClimateTheme.Typography.subheadlineStrong)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ClimateTheme.accent)
                    .accessibilityHint("Changes this reminder")

                    Button("Remove", action: onRemoveReminder)
                        .buttonStyle(.plain)
                        .font(ClimateTheme.Typography.subheadline)
                        .foregroundStyle(ClimateTheme.secondaryInk)
                }
                .frame(minHeight: ClimateTheme.minimumTapTarget, alignment: .leading)
            } else {
                Button(action: onRemind) {
                    Label("Remind me", systemImage: "bell")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClimateSecondaryButtonStyle())
            }
        }
        .padding(.top, ClimateTheme.Spacing.xSmall)
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
                VStack(alignment: .leading, spacing: ClimateTheme.Spacing.large) {
                    ClimatePageHeader(
                        title: existingReminder == nil ? "Reminder" : "Edit reminder",
                        subtitle: "We’ll remind you on this device about \(log.title).",
                        titleFont: ClimateTheme.Typography.pageTitle
                    )
                    DatePicker(
                        "Remind me",
                        selection: $date,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .font(ClimateTheme.Typography.headline)
                    .foregroundStyle(ClimateTheme.ink)
                    .tint(ClimateTheme.accent)
                    .padding(ClimateTheme.Spacing.medium)
                    .climateSheet(radius: ClimateTheme.Radius.medium)

                    if let errorMessage {
                        ClimateInlineStatus(message: errorMessage, kind: .error)
                    }

                    Button(isSaving ? "Saving…" : "Save reminder") { save() }
                        .buttonStyle(ClimatePrimaryButtonStyle())
                        .disabled(isSaving)

                    if existingReminder != nil {
                        Button("Remove reminder", role: .destructive) {
                            notifications.cancelActionReminder(for: log)
                            dismiss()
                        }
                        .font(ClimateTheme.Typography.headline)
                        .foregroundStyle(ClimateTheme.error)
                        .frame(minHeight: ClimateTheme.minimumTapTarget, alignment: .leading)
                    }
                }
                .padding(ClimateTheme.Spacing.large)
                .padding(.bottom, ClimateTheme.Spacing.hero)
                .frame(maxWidth: ClimateTheme.ContentWidth.reading, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .background { ClimateBackdrop() }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { ClimateWordmark() }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                        .font(ClimateTheme.Typography.subheadlineStrong)
                        .foregroundStyle(ClimateTheme.pineInk)
                }
            }
            .toolbarBackground(ClimateTheme.pine, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .tint(ClimateTheme.accent)
        }
    }

    private func save() {
        guard !isSaving else { return }
        isSaving = true
        Task { @MainActor in
            defer { isSaving = false }
            if await notifications.scheduleActionReminder(for: log, at: date) {
                AccessibilityNotification.Announcement("Reminder set for \(date.formatted(date: .abbreviated, time: .shortened))").post()
                dismiss()
            } else {
                errorMessage = notifications.errorMessage ?? "We couldn’t set the reminder. Please try again."
            }
        }
    }
}
