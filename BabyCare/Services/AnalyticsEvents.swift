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
}

// MARK: - Parameter Keys

enum AnalyticsParams {
    static let screenName = "screen_name"
    static let actionType = "action_type"
    static let category = "category"
    static let source = "source"
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
