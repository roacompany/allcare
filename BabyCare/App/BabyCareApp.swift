import SwiftUI
import FirebaseCore
import FirebaseFirestore

@main
struct BabyCareApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let appState: AppState

    init() {
        // URLCache 설정 (이미지 캐싱 지원)
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,   // 50MB memory
            diskCapacity: 200 * 1024 * 1024      // 200MB disk
        )
        // AppState → AuthViewModel → Auth.auth() 호출 전에 Firebase 초기화 필수
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        // Firestore 오프라인 영속성: 200MB 캐시
        let firestoreSettings = Firestore.firestore().settings
        firestoreSettings.cacheSettings = PersistentCacheSettings(sizeBytes: 200 * 1024 * 1024 as NSNumber)
        Firestore.firestore().settings = firestoreSettings
        appState = AppState.shared
        ThemeManager.shared.applyAppearance()
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
                .environment(appState.insight)
                .onOpenURL { url in
                    deepLinkDestination = DeepLinkRouter.destination(from: url)
                }
        }
    }
}
