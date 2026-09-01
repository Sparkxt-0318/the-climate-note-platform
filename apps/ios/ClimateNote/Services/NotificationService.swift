import Combine
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import UIKit
import UserNotifications

@MainActor
final class NotificationService: ObservableObject {
    private static let weeklyPreferenceKey = "climate-note.weekly-notifications"
    @Published private(set) var isAuthorized = false
    @Published private(set) var weeklyEnabled: Bool
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
        guard FirebaseApp.app() != nil else {
            errorMessage = "Notifications are not configured yet."
            return
        }
        do {
            if enabled {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
                guard granted else {
                    errorMessage = "Notifications are turned off in iPhone Settings."
                    return
                }
                Messaging.messaging().isAutoInitEnabled = true
                UIApplication.shared.registerForRemoteNotifications()
                try await Messaging.messaging().subscribe(toTopic: "weekly-articles")
                if let userID {
                    try await savePreference(true, userID: userID)
                }
                isAuthorized = true
                weeklyEnabled = true
            } else {
                try? await Messaging.messaging().unsubscribe(fromTopic: "weekly-articles")
                Messaging.messaging().isAutoInitEnabled = false
                try await Messaging.messaging().deleteData()
                if let userID {
                    try await savePreference(false, userID: userID)
                }
                weeklyEnabled = false
            }
            UserDefaults.standard.set(weeklyEnabled, forKey: Self.weeklyPreferenceKey)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func scheduleActionReminder(for log: ActionLog) async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Your climate note"
            content.body = log.title
            content.sound = .default
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date().addingTimeInterval(86_400))
            components.hour = 17
            let request = UNNotificationRequest(
                identifier: "action-\(log.id)",
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )
            try await UNUserNotificationCenter.current().add(request)
            isAuthorized = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func savePreference(_ enabled: Bool, userID: String) async throws {
        try await Firestore.firestore().collection("users").document(userID).setData([
            "notificationPreferences": ["weeklyArticle": enabled],
            "updatedAt": Date(),
        ], merge: true)
    }
}
