import SwiftUI
import FirebaseCore

@main
struct ClimateNoteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var articleStore = ArticleStore()
    @StateObject private var authService = AuthService()
    @StateObject private var reflectionStore = ReflectionStore()
    @StateObject private var notificationService = NotificationService()
    @StateObject private var impactStore = ImpactStore()

    init() {
        ClimateTheme.configureChromeAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Group {
#if DEBUG
                if let scene = ScreenshotConfiguration.scene {
                    ScreenshotRootView(scene: scene)
                } else {
                    RootView()
                }
#else
                RootView()
#endif
            }
                .environmentObject(articleStore)
                .environmentObject(authService)
                .environmentObject(reflectionStore)
                .environmentObject(notificationService)
                .environmentObject(impactStore)
                .environmentObject(ReadingSessionStore.shared)
                .tint(.climateSage)
                .task {
#if DEBUG
                    if ScreenshotConfiguration.isIsolated { return }
#endif
                    AuthService.removeStaleExportFiles()
                    authService.start()
                    articleStore.start()
                    reflectionStore.observe(userID: authService.user?.uid)
                    impactStore.start()
                    impactStore.observePreference(userID: authService.user?.uid)
                    await notificationService.refreshStatus()
                }
                .onChange(of: authService.user?.uid) { previousUserID, userID in
#if DEBUG
                    if ScreenshotConfiguration.isIsolated { return }
#endif
                    if userID == nil {
                        Task {
                            await notificationService.clearSessionPrivacyState(for: previousUserID)
                        }
                    }
                    reflectionStore.observe(userID: userID)
                    impactStore.observePreference(userID: userID)
                }
        }
    }
}
