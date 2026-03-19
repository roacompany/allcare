import SwiftUI
import FirebaseCore

@main
struct BabyCareApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let appState: AppState

    init() {
        // AppState → AuthViewModel → Auth.auth() 호출 전에 Firebase 초기화 필수
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        appState = AppState.shared
    }

    @State private var deepLinkDestination: DeepLinkRouter.Destination?
    private let themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView(deepLinkDestination: $deepLinkDestination)
                .environment(themeManager)
                .environment(appState.auth)
                .environment(appState.baby)
                .environment(appState.activity)
                .environment(appState.calendar)
                .environment(appState.todo)
                .environment(appState.stats)
                .environment(appState.diary)
                .environment(appState.product)
                .environment(appState.health)
                .environment(appState.routine)
                .environment(appState.aiAdvice)
                .environment(appState.announcement)
                .environment(appState.patternReport)
                .environment(appState.purchase)
                .environment(appState.hospitalReport)
                .onOpenURL { url in
                    deepLinkDestination = DeepLinkRouter.destination(from: url)
                }
                .task {
                    themeManager.applyAppearance()
                }
        }
    }
}
