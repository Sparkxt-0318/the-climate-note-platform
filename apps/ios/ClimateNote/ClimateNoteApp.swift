import SwiftUI
import FirebaseCore

@main
struct ClimateNoteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var articleStore = ArticleStore()
    @StateObject private var authService = AuthService()
    @StateObject private var reflectionStore = ReflectionStore()
    @StateObject private var notificationService = NotificationService()

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
                .tint(.climateSage)
                .task {
#if DEBUG
                    if ScreenshotConfiguration.scene != nil { return }
#endif
                    authService.start()
                    articleStore.start()
                    reflectionStore.observe(userID: authService.user?.uid)
                    await notificationService.refreshStatus()
                }
                .onChange(of: authService.user?.uid) { _, userID in
                    reflectionStore.observe(userID: userID)
                }
        }
    }
}
