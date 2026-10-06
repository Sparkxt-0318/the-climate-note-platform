import Combine
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import UIKit
@preconcurrency import UserNotifications

@MainActor
final class NotificationService: ObservableObject {
    private static let weeklyPreferenceKey = "climate-note.weekly-notifications"
    private static let actionReminderPrefix = "climate-note.action-reminders."

    struct ActionReminder: Codable, Equatable, Sendable {
        let entryID: String
        let fireDate: Date

        var requestIdentifier: String { "action-\(entryID)" }
    }

    @Published private(set) var isAuthorized = false
    @Published private(set) var weeklyEnabled: Bool
    @Published private(set) var hasPendingPreferenceSync = false
    @Published private(set) var actionReminders: [String: ActionReminder] = [:]
    @Published var errorMessage: String?

    init() {
        weeklyEnabled = UserDefaults.standard.bool(forKey: Self.weeklyPreferenceKey)
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        if !weeklyEnabled, FirebaseApp.app() != nil {
            Messaging.messaging().isAutoInitEnabled = false
        }
    }

    func setWeeklyEnabled(_ enabled: Bool, userID: String?) async {
        errorMessage = nil
        guard FirebaseApp.app() != nil else {
            errorMessage = "Notifications are not configured yet."
            return
        }
        if enabled {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                isAuthorized = granted
                guard granted else {
                    errorMessage = "Notifications are turned off in iPhone Settings."
                    return
                }
                Messaging.messaging().isAutoInitEnabled = true
                UIApplication.shared.registerForRemoteNotifications()
                try await Messaging.messaging().subscribe(toTopic: "weekly-articles")
                isAuthorized = true
                commitDevicePreference(true)
            } catch {
                errorMessage = "We couldn’t update notifications on this device. Please try again."
                return
            }
        } else {
            do {
                try await Messaging.messaging().unsubscribe(fromTopic: "weekly-articles")
                // Topic delivery has stopped. Keep the UI and persisted local preference truthful
                // even if the optional local messaging-data cleanup below later fails.
                commitDevicePreference(false)
                Messaging.messaging().isAutoInitEnabled = false
            } catch {
                errorMessage = "We couldn’t update notifications on this device. Please try again."
                return
            }
            do {
                try await Messaging.messaging().deleteData()
            } catch {
                errorMessage = "Weekly notifications are off on this device, but we couldn’t finish local cleanup. Please try again later."
            }
        }
        await syncPreference(enabled, userID: userID)
    }

    func retryPreferenceSync(userID: String?) async {
        guard hasPendingPreferenceSync else { return }
        errorMessage = nil
        await syncPreference(weeklyEnabled, userID: userID)
    }

    private func commitDevicePreference(_ enabled: Bool) {
        weeklyEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: Self.weeklyPreferenceKey)
    }

    private func syncPreference(_ enabled: Bool, userID: String?) async {
        guard let userID else {
            hasPendingPreferenceSync = false
            return
        }
        do {
            try await savePreference(enabled, userID: userID)
            hasPendingPreferenceSync = false
        } catch {
            hasPendingPreferenceSync = true
            errorMessage = "Notifications changed on this device, but we couldn’t save that preference to your account. Try again when you’re connected."
        }
    }

    func proposedActionReminderDate(from now: Date = Date(), calendar: Calendar = .current) -> Date {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.date(bySettingHour: 17, minute: 0, second: 0, of: tomorrow) ?? tomorrow
    }

    func reminder(for log: ActionLog) -> ActionReminder? {
        loadActionReminders(for: log.userID)[log.id]
    }

    /// Reconciles local presentation with the device's notification center after a relaunch.
    /// Reminder records are scoped to the account and never synced to Firestore.
    func refreshActionReminderStatus(for logs: [ActionLog]) async {
        let grouped = Dictionary(grouping: logs, by: \.userID)
        for (userID, entries) in grouped {
            var stored = loadActionReminders(for: userID)
            let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
            let pendingIDs = Set(pending.map(\.identifier))
            let knownIDs = Set(entries.map(\.id))
            stored = stored.filter { entryID, reminder in
                knownIDs.contains(entryID) && pendingIDs.contains(reminder.requestIdentifier)
            }
            saveActionReminders(stored, for: userID)
            if userID == logs.first?.userID { actionReminders = stored }
        }
    }

    @discardableResult
    func scheduleActionReminder(for log: ActionLog, at fireDate: Date) async -> Bool {
        errorMessage = nil
        guard log.kind.supportsReminder, log.status == .planned else {
            errorMessage = "Only planned actions can have reminders."
            return false
        }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            isAuthorized = granted
            guard granted else {
                errorMessage = "To set a reminder, allow notifications for Climate Note in iPhone Settings."
                return false
            }
            let content = UNMutableNotificationContent()
            content.title = "Your climate note"
            // Keep lock-screen copy generic so private note titles are not exposed.
            content.body = "A planned action is ready when you are."
            content.sound = .default
            content.userInfo = [
                "actionLogID": log.id,
                "articleID": log.articleID,
                "userID": log.userID,
            ]
            let calendar = Calendar.current
            guard fireDate > Date() else {
                errorMessage = "Choose a time in the future."
                return false
            }
            var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate)
            components.calendar = calendar
            components.timeZone = calendar.timeZone
            // Replacing a request with the same identifier edits it atomically on this device.
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["action-\(log.id)"])
            let request = UNNotificationRequest(
                identifier: "action-\(log.id)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try await UNUserNotificationCenter.current().add(request)
            var stored = loadActionReminders(for: log.userID)
            stored[log.id] = ActionReminder(entryID: log.id, fireDate: fireDate)
            saveActionReminders(stored, for: log.userID)
            actionReminders = stored
            return true
        } catch {
            errorMessage = "We couldn’t set the reminder. Please try again."
            return false
        }
    }

    @discardableResult
    func scheduleActionReminder(for log: ActionLog) async -> Bool {
        await scheduleActionReminder(for: log, at: proposedActionReminderDate())
    }

    func cancelActionReminder(for log: ActionLog) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["action-\(log.id)"])
        var stored = loadActionReminders(for: log.userID)
        stored.removeValue(forKey: log.id)
        saveActionReminders(stored, for: log.userID)
        actionReminders = stored
    }

    /// Clears lock-screen reminders and push state when the account session ends on this device.
    func clearSessionPrivacyState(for userID: String?) async {
        if let userID, !userID.isEmpty {
            let stored = loadActionReminders(for: userID)
            let identifiers = stored.values.map(\.requestIdentifier)
            if !identifiers.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
            }
            UserDefaults.standard.removeObject(forKey: Self.actionReminderPrefix + userID)
            actionReminders = [:]
        }

        if weeklyEnabled {
            do {
                try await Messaging.messaging().unsubscribe(fromTopic: "weekly-articles")
            } catch {
                // Best-effort privacy cleanup; local preference still flips off below.
            }
            commitDevicePreference(false)
        }
        Messaging.messaging().isAutoInitEnabled = false
        try? await Messaging.messaging().deleteData()
    }

    private func loadActionReminders(for userID: String) -> [String: ActionReminder] {
        guard !userID.isEmpty,
              let data = UserDefaults.standard.data(forKey: Self.actionReminderPrefix + userID),
              let reminders = try? JSONDecoder().decode([String: ActionReminder].self, from: data) else { return [:] }
        return reminders
    }

    private func saveActionReminders(_ reminders: [String: ActionReminder], for userID: String) {
        guard !userID.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(reminders) else { return }
        UserDefaults.standard.set(data, forKey: Self.actionReminderPrefix + userID)
    }

    private func savePreference(_ enabled: Bool, userID: String) async throws {
        try await Firestore.firestore().collection("users").document(userID).setData([
            "notificationPreferences": ["weeklyArticle": enabled],
            "updatedAt": Date(),
        ], merge: true)
    }
}
