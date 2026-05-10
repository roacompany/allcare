import Foundation

// MARK: - Screen Names

enum AnalyticsScreens {
    static let dashboard = "dashboard"
    static let calendar = "calendar"
    static let health = "health"
    static let settings = "settings"
    static let recording = "recording"
    static let feedRecording = "feed_recording"
    static let sleepRecording = "sleep_recording"
    static let diaperRecording = "diaper_recording"
    static let aiAdvice = "ai_advice"
    static let growth = "growth"
    static let productList = "product_list"
}

// MARK: - Event Names

enum AnalyticsEvents {
    // Dashboard
    static let dashboardCardTap = "dashboard_card_tap"
    static let dashboardQuickRecord = "dashboard_quick_record"

    // Calendar
    static let calendarDateSelect = "calendar_date_select"
    static let calendarRecordOpen = "calendar_record_open"

    // Recording
    static let recordSave = "record_save"
    static let feedRecordSave = "feed_record_save"
    static let sleepRecordSave = "sleep_record_save"
    static let diaperRecordSave = "diaper_record_save"

    // Health
    static let healthDataView = "health_data_view"

    // AI
    static let aiAdviceRequest = "ai_advice_request"

    // Growth
    static let growthDataInput = "growth_data_input"

    // Products
    static let productView = "product_view"

    // Settings
    static let analyticsOptOutToggle = "analytics_opt_out_toggle"

    // Insights — Phase 2 ML 학습용 telemetry (engagement label 수집).
    // 임신 모드 데이터는 절대 포함 금지 (memory feedback_no_data_deletion / safety.md 준수).
    static let insightGenerated = "insight_generated"
    static let insightShown = "insight_shown"
    static let insightTapped = "insight_tapped"
}

// MARK: - Parameter Keys

enum AnalyticsParams {
    static let screenName = "screen_name"
    static let actionType = "action_type"
    static let category = "category"
    static let source = "source"

    // Insights
    static let metricKey = "metric_key"
    static let position = "position"
    static let scorerMode = "scorer_mode"
    static let historyWeeks = "history_weeks"
}

// MARK: - User Properties

enum AnalyticsUserProperties {
    static let babyCount = "baby_count"
    static let appVersion = "app_version"
    static let onboardingCompleted = "onboarding_completed"
    static let primaryFeature = "primary_feature"
    static let familySharingEnabled = "family_sharing_enabled"
    static let theme = "theme"
}
