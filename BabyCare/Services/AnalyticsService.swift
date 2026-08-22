import Foundation
import FirebaseAnalytics

// MARK: - Protocol

protocol AnalyticsTracking: Sendable {
    func trackScreen(_ name: String, parameters: [String: String])
    func trackEvent(_ name: String, parameters: [String: String])
    func setUserProperty(_ value: String?, forName name: String)
    func setEnabled(_ enabled: Bool)
}

extension AnalyticsTracking {
    func trackScreen(_ name: String, parameters: [String: String] = [:]) {
        trackScreen(name, parameters: parameters)
    }
    func trackEvent(_ name: String, parameters: [String: String] = [:]) {
        trackEvent(name, parameters: parameters)
    }
}

// MARK: - AnalyticsService

final class AnalyticsService: AnalyticsTracking {
    static let shared = AnalyticsService()

    /// 단일 소스 — SettingsView @AppStorage도 이 상수를 참조 (문자열 이중 정의 drift 방지).
    static let optOutKey = "analytics_opt_out"

    var isEnabled: Bool {
        !UserDefaults.standard.bool(forKey: Self.optOutKey)
    }

    private init() {}

    /// AppDelegate에서 FirebaseApp.configure() 직후 호출
    func configure() {
        let enabled = isEnabled
        Analytics.setAnalyticsCollectionEnabled(enabled)
        AppLogger.analytics.info("Analytics collection \(enabled ? "enabled" : "disabled")")
    }

    func trackScreen(_ name: String, parameters: [String: String] = [:]) {
        guard isEnabled, !isPreview else { return }
        var params: [String: Any] = [AnalyticsParameterScreenName: name]
        for (key, value) in parameters { params[key] = value }
        Analytics.logEvent(AnalyticsEventScreenView, parameters: params)
    }

    func trackEvent(_ name: String, parameters: [String: String] = [:]) {
        guard isEnabled, !isPreview else { return }
        var params: [String: Any] = [:]
        for (key, value) in parameters { params[key] = value }
        Analytics.logEvent(name, parameters: params.isEmpty ? nil : params)
    }

    // MARK: - 기록 출처 (record_saved)

    /// 기록 저장 telemetry 파라미터 — **기록 자신이** 말한다.
    /// 진입점(앱/시리)이 각자 적으면 두 경로가 조용히 어긋난다 → activity.source 단일 소스.
    ///
    /// nil = **보내지 않는다**:
    /// - 출처 미상(v2.8.9 이하 기록) — 모르는 것을 app 으로 세면 채택률이 거짓이 된다
    /// - `.unknown` forward-compat 센티넬 — 영속 금지와 같은 원칙으로 밖에도 안 내보낸다
    nonisolated static func recordSavedParameters(for activity: Activity) -> [String: String]? {
        guard let source = activity.source, activity.type != .unknown else { return nil }
        return ["record_type": activity.type.rawValue, "source": source.rawValue]
    }

    /// 앱·시리 양쪽 저장 꼬리에서 호출.
    func logRecordSaved(_ activity: Activity) {
        guard let parameters = Self.recordSavedParameters(for: activity) else { return }
        trackEvent(AnalyticsEvents.recordSaved, parameters: parameters)
    }

    func setUserProperty(_ value: String?, forName name: String) {
        guard isEnabled, !isPreview else { return }
        Analytics.setUserProperty(value, forName: name)
    }

    func setEnabled(_ enabled: Bool) {
        if !enabled {
            // 끄기 직전이 전환을 계측할 수 있는 마지막 시점 (꺼진 후에는 전송 불가).
            trackEvent(AnalyticsEvents.analyticsOptOutToggle,
                       parameters: [AnalyticsParams.enabled: "false"])
        }
        UserDefaults.standard.set(!enabled, forKey: Self.optOutKey)
        Analytics.setAnalyticsCollectionEnabled(enabled)
        if enabled {
            trackEvent(AnalyticsEvents.analyticsOptOutToggle,
                       parameters: [AnalyticsParams.enabled: "true"])
        }
        AppLogger.analytics.info("Analytics opt-out toggled: collection \(enabled ? "enabled" : "disabled")")
    }

    // MARK: - Insights Telemetry (Phase 2 ML 학습용)

    /// 인사이트 카드 노출 시점에 호출. 카테고리, metric, 위치, scorer mode, history depth.
    /// 임신 데이터 포함 금지 (safety.md). 카테고리는 feeding/sleep/diaper/health만 사용.
    func logInsightGenerated(metricKey: String, category: String, position: Int, scorerMode: String, historyWeeks: Int) {
        trackEvent(AnalyticsEvents.insightGenerated, parameters: [
            AnalyticsParams.metricKey: metricKey,
            AnalyticsParams.category: category,
            AnalyticsParams.position: String(position),
            AnalyticsParams.scorerMode: scorerMode,
            AnalyticsParams.historyWeeks: String(historyWeeks)
        ])
    }

    /// 인사이트 카드 화면 노출 (impression). UI에서 onAppear 시 호출.
    func logInsightShown(metricKey: String, category: String, position: Int) {
        trackEvent(AnalyticsEvents.insightShown, parameters: [
            AnalyticsParams.metricKey: metricKey,
            AnalyticsParams.category: category,
            AnalyticsParams.position: String(position)
        ])
    }

    /// 인사이트 카드 탭. 탭 가능한 UI 추가 시 호출.
    func logInsightTapped(metricKey: String, category: String, position: Int) {
        trackEvent(AnalyticsEvents.insightTapped, parameters: [
            AnalyticsParams.metricKey: metricKey,
            AnalyticsParams.category: category,
            AnalyticsParams.position: String(position)
        ])
    }

    /// 사용자 속성 6종 업데이트
    @MainActor
    func updateUserProperties(babyCount: Int, familySharingEnabled: Bool, theme: String) {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let onboarded = babyCount > 0

        setUserProperty(String(babyCount), forName: AnalyticsUserProperties.babyCount)
        setUserProperty(version, forName: AnalyticsUserProperties.appVersion)
        setUserProperty(String(onboarded), forName: AnalyticsUserProperties.onboardingCompleted)
        setUserProperty(familySharingEnabled ? "true" : "false", forName: AnalyticsUserProperties.familySharingEnabled)
        setUserProperty(theme, forName: AnalyticsUserProperties.theme)
    }

    // MARK: - Private

    private var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

// MARK: - MockAnalyticsService (Testing)

final class MockAnalyticsService: AnalyticsTracking, @unchecked Sendable {
    private(set) var trackedScreens: [(name: String, parameters: [String: String])] = []
    private(set) var trackedEvents: [(name: String, parameters: [String: String])] = []
    private(set) var userProperties: [String: String?] = [:]
    private(set) var isCurrentlyEnabled: Bool = true

    func trackScreen(_ name: String, parameters: [String: String] = [:]) {
        guard isCurrentlyEnabled else { return }
        trackedScreens.append((name, parameters))
    }

    func trackEvent(_ name: String, parameters: [String: String] = [:]) {
        guard isCurrentlyEnabled else { return }
        trackedEvents.append((name, parameters))
    }

    func setUserProperty(_ value: String?, forName name: String) {
        userProperties[name] = value
    }

    func setEnabled(_ enabled: Bool) {
        isCurrentlyEnabled = enabled
    }

    func reset() {
        trackedScreens.removeAll()
        trackedEvents.removeAll()
        userProperties.removeAll()
        isCurrentlyEnabled = true
    }
}
