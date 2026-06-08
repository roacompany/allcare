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
    /// 유축 기록 telemetry — default-on 그리드 효과/Phase 2 우선순위 판단용 (spec §10).
    /// raw mL 금지: amount는 coarse bucket으로만 전송.
    static let pumpingRecorded = "pumping_recorded"

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

    // Weekly Highlights — v2.8.3+ AI 주간 하이라이트 ticker + sheet telemetry.
    static let highlightTickerShown = "highlight_ticker_shown"
    static let highlightTickerTapped = "highlight_ticker_tapped"
    static let highlightTickerPaused = "highlight_ticker_paused"
    static let highlightSheetOpened = "highlight_sheet_opened"
    static let highlightSheetDismissed = "highlight_sheet_dismissed"
    static let highlightCacheHit = "highlight_cache_hit"
    static let highlightPatternReportTapped = "highlight_pattern_report_tapped"
    static let highlightCardTapped = "highlight_card_tapped"
}

// MARK: - Parameter Keys

enum AnalyticsParams {
    static let screenName = "screen_name"
    static let actionType = "action_type"
    static let category = "category"
    static let source = "source"

    // Pumping (유축)
    static let amountBucket = "amount_bucket"
    static let side = "side"

    // Insights
    static let metricKey = "metric_key"
    static let position = "position"
    static let scorerMode = "scorer_mode"
    static let historyWeeks = "history_weeks"
}

// MARK: - Pumping Analytics

enum PumpingAnalytics {
    /// 유축량 coarse bucket — raw mL 노출 금지 (민감 건강정보 granularity 회피, spec §10).
    static func bucket(_ amount: Double?) -> String {
        guard let amount else { return "unknown" }
        switch amount {
        case ..<60: return "0-59"
        case ..<120: return "60-119"
        case ..<180: return "120-179"
        default: return "180+"
        }
    }
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
