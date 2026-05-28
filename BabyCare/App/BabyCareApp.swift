import SwiftUI
import FirebaseCore
import FirebaseFirestore
#if !DEBUG
import Sentry
#endif

@main
struct BabyCareApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let appState: AppState
    private let flagService = FeatureFlagService.shared

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
        Self.bootstrapSentry()
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

    /// Release 빌드에서만 Sentry 초기화. PII 차단 + 임신 데이터 redact (safety.md).
    private static func bootstrapSentry() {
        #if !DEBUG
        SentrySDK.start { options in
            options.dsn = "https://1cfdde9c49b2b39909667b2227c7b601@o4511464474607616.ingest.us.sentry.io/4511464483127296"
            options.tracesSampleRate = 0.1
            options.sendDefaultPii = false
            options.diagnosticLevel = .warning
            options.beforeBreadcrumb = { Self.redactPregnancyBreadcrumb($0) }
            options.beforeSend = { Self.redactPregnancyEvent($0) }
        }
        #endif
    }

    #if !DEBUG
    private static let pregnancyKeywords = ["pregnancy", "임신", "kick", "태동", "edd", "lmp", "prenatal"]

    private static func redactPregnancyBreadcrumb(_ crumb: Breadcrumb) -> Breadcrumb? {
        guard let msg = crumb.message?.lowercased() else { return crumb }
        return pregnancyKeywords.contains(where: msg.contains) ? nil : crumb
    }

    private static func redactPregnancyEvent(_ event: Event) -> Event? {
        guard let text = event.message?.formatted.lowercased() else { return event }
        if pregnancyKeywords.contains(where: text.contains) {
            event.message = SentryMessage(formatted: "[redacted: pregnancy context]")
        }
        return event
    }
    #endif
}
