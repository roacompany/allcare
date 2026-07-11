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
    /// 아직 미발화 — 인사이트 카드에 탭 가능한 UI가 추가될 때 logInsightTapped로 연결 (Phase 2 라벨).
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

    // App Review — 시스템 평가 시트/딥링크 요청 시점 (requestReview는 콜백 없음 → 유일한 계측).
    static let reviewPromptRequested = "review_prompt_requested"

    // First Record Guide — 이탈 방지 P0-1: 첫 기록/재시작 유도 카드 (아기등록→첫기록 퍼널 계측).
    static let firstRecordGuideShown = "first_record_guide_shown"
    static let firstRecordGuideTapped = "first_record_guide_tapped"

    // Return Nudge — 이탈 방지 P0-2: D1 복귀 넛지 알림 탭(복귀) 계측.
    static let returnNudgeOpened = "return_nudge_opened"

    // Widget Promo — 이탈 P1(C2): 위젯 설치 유도 카드 노출/해제 계측.
    static let widgetPromoShown = "widget_promo_shown"
    static let widgetPromoDismissed = "widget_promo_dismissed"

    // Partner Invite Promo — C3: 파트너 초대 유도 카드 노출/탭/해제 계측 (공유 사용률 퍼널).
    static let partnerInvitePromoShown = "partner_invite_promo_shown"
    static let partnerInvitePromoTapped = "partner_invite_promo_tapped"
    static let partnerInvitePromoDismissed = "partner_invite_promo_dismissed"
}

// MARK: - Parameter Keys

enum AnalyticsParams {
    static let screenName = "screen_name"
    static let actionType = "action_type"
    /// 값은 영어 안정 식별자(enum rawValue)만 사용 — 한글 displayName 금지 (GA4 차원 파편화 방지).
    static let category = "category"
    static let source = "source"
    static let trigger = "trigger"
    /// 병수유 내용물 — Activity.FeedingContent rawValue (formula / breast_milk).
    static let content = "content"
    /// analytics_opt_out_toggle — "true"/"false".
    static let enabled = "enabled"
    /// highlight_sheet_dismissed 체류 시간 (ms).
    static let dwellMs = "dwell_ms"

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
    static let familySharingEnabled = "family_sharing_enabled"
    static let theme = "theme"
}

// MARK: - Ticker Impression Dedupe

/// highlight_ticker_shown이 5초 tick마다 반복 발화되는 것을 막는다 —
/// 뷰 생애(대시보드 한 번 진입) 동안 metricKey당 1회만 true.
/// VoiceOver 공지는 dedupe 대상이 아님 (접근성은 매 tick 유지).
struct TickerImpressionDeduper {
    private var fired: Set<String> = []

    mutating func shouldFire(_ metricKey: String) -> Bool {
        fired.insert(metricKey).inserted
    }
}
