import SwiftUI
import FirebaseCore
import FirebaseFirestore

@main
struct BabyCareApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let appState: AppState
    private let flagService = FeatureFlagService.shared

    init() {
        // CI 단위 테스트 모드. xcodebuild test가 host process에 자동 주입하는
        // 환경변수로 감지. FirebaseApp.configure()는 유지해야 함 — FirestoreService.shared
        // 의 `let db = Firestore.firestore()` 가 AppState 초기화 chain에서 호출되어
        // configure 없으면 abort. PersistentCacheSettings(disk write)와 ThemeManager만 skip.
        // 실제 crash 지점인 Auth listener는 AuthViewModel 내부에서 별도 가드.
        // (rules/build-gotchas.md "signal abrt" 섹션)
        let isXCTest = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

        // URLCache 설정 (이미지 캐싱 지원)
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,   // 50MB memory
            diskCapacity: 200 * 1024 * 1024      // 200MB disk
        )

        // AppState → FirestoreService.shared → Firestore.firestore() 호출 전에 필수
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        if !isXCTest {
            // Firestore 오프라인 영속성: 200MB 캐시. XCTest에서는 stub project ID로
            // disk 캐시 생성 시 비결정적 동작 가능 — 기본 MemoryCacheSettings 사용.
            let firestoreSettings = Firestore.firestore().settings
            firestoreSettings.cacheSettings = PersistentCacheSettings(sizeBytes: 200 * 1024 * 1024 as NSNumber)
            Firestore.firestore().settings = firestoreSettings
        }

        appState = AppState.shared

        if !isXCTest {
            ThemeManager.shared.applyAppearance()
        }
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
                .environment(appState.pregnancy)
                .environment(flagService)
                .onOpenURL { url in
                    deepLinkDestination = DeepLinkRouter.destination(from: url)
                }
                // FeatureFlagService bootstrap: ContentView.task 외부에서 실행 (first render race 방지).
                // minimumFetchInterval 기본값(43200초=12시간) 유지 — ThrottledException 방지.
                .task {
                    let userId = appState.auth.currentUserId ?? "anonymous"
                    await flagService.bootstrap(userId: userId)
                }
                // 주: AI 요약 사전 캐시는 babycare-admin Vercel Cron + Mac LaunchAgent worker가
                // 본인 Claude Code Pro 구독으로 배치 처리한 후 Firestore에 저장한다.
                // iOS는 별도 launch hook 없이 HighlightAISummaryService.fetchCachedSummary로 read만 수행.
        }
    }
}
