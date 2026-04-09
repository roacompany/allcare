import Foundation
import FirebaseAnalytics
import OSLog

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
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BabyCare", category: "Analytics")

    private static let optOutKey = "analytics_opt_out"

    var isEnabled: Bool {
        !UserDefaults.standard.bool(forKey: Self.optOutKey)
    }

    private init() {}

    /// AppDelegate에서 FirebaseApp.configure() 직후 호출
    func configure() {
        let enabled = isEnabled
        Analytics.setAnalyticsCollectionEnabled(enabled)
        Self.logger.info("Analytics collection \(enabled ? "enabled" : "disabled")")
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

    func setUserProperty(_ value: String?, forName name: String) {
        guard isEnabled, !isPreview else { return }
        Analytics.setUserProperty(value, forName: name)
    }

    func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(!enabled, forKey: Self.optOutKey)
        Analytics.setAnalyticsCollectionEnabled(enabled)
        Self.logger.info("Analytics opt-out toggled: collection \(enabled ? "enabled" : "disabled")")
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
