import Foundation

@MainActor @Observable
final class ActivityViewModel {
    var todayActivities: [Activity] = []
    var isLoading = false
    var errorMessage: String?

    // Timer state (forwarded to timerManager)
    var isTimerRunning: Bool { timerManager.isTimerRunning }
    var elapsedTime: TimeInterval { timerManager.elapsedTime }
    var activeTimerType: Activity.ActivityType? { timerManager.activeTimerType }

    // Form state
    var selectedType: Activity.ActivityType = .feedingBreast
    var selectedSide: Activity.BreastSide = .left
    var amount: String = ""
    var temperatureInput: String = ""
    var medicationName: String = ""
    var note: String = ""

    // 시간 조정 (베이비타임 스타일)
    var manualStartTime: Date = Date()
    var manualEndTime: Date?
    var isTimeAdjusted = false   // 사용자가 시간을 직접 변경했는지

    // 기록 UX 강화 form state
    var foodName: String = ""
    var foodAmount: String = ""
    var foodReaction: Activity.FoodReaction?
    var stoolColor: Activity.StoolColor?
    var stoolConsistency: Activity.StoolConsistency?
    var hasRash: Bool = false
    var sleepQuality: Activity.SleepQualityType?
    var sleepMethod: Activity.SleepMethodType?
    var medicationDosage: String = ""

    // Latest activities (최근 기록)
    var lastFeeding: Activity?
    var lastSleep: Activity?
    var lastDiaper: Activity?

    // 중복 기록 경고 상태
    var showDuplicateWarning = false
    var pendingDuplicateSave: (() async -> Void)?

    let firestoreService = FirestoreService.shared
    let timerManager = ActivityTimerManager()

    // MARK: - Computed Summaries (중복 상태 제거)

    var todayFeedingCount: Int {
        todayActivities.filter { $0.type.category == .feeding }.count
    }

    var todaySleepDuration: TimeInterval {
        todayActivities.filter { $0.type == .sleep }.compactMap(\.duration).reduce(0, +)
    }

    var todayDiaperCount: Int {
        todayActivities.filter { $0.type.category == .diaper }.count
    }

    var todayTotalMl: Double {
        todayActivities.filter { $0.type.category == .feeding }.compactMap(\.amount).reduce(0, +)
    }

    // MARK: - Weekly Insights

    /// 주간 인사이트 (loadTodayActivities에서 함께 로드)
    var weeklyInsights: [WeeklyInsightService.Insight] = []

    // MARK: - Predictions

    /// 최근 7일 수유 데이터 (loadTodayActivities에서 함께 로드)
    var recentFeedingActivities: [Activity] = []
    /// 최근 48시간 체온 데이터 — 자정 경계 야간 발열 감지용
    var recentTemperatureActivities: [Activity] = []
    /// 아기 월령 (외부에서 주입)
    var babyAgeInMonths: Int = 3

    var averageFeedingIntervalResult: (interval: TimeInterval, isPersonalized: Bool) {
        FeedingPredictionService.averageInterval(
            todayActivities: todayActivities,
            recentActivities: recentFeedingActivities,
            babyAgeInMonths: babyAgeInMonths
        )
    }

    var averageFeedingInterval: TimeInterval {
        averageFeedingIntervalResult.interval
    }

    var nextFeedingEstimate: Date? {
        FeedingPredictionService.nextEstimate(
            lastFeeding: lastFeeding,
            averageInterval: averageFeedingInterval
        )
    }

    var nextFeedingText: String? {
        FeedingPredictionService.predictionText(
            estimate: nextFeedingEstimate,
            isPersonalized: averageFeedingIntervalResult.isPersonalized
        )
    }

    var isFeedingOverdue: Bool {
        FeedingPredictionService.isOverdue(estimate: nextFeedingEstimate)
    }

    var nextFeedingSubtitle: String {
        averageFeedingIntervalResult.isPersonalized ? "지난 7일 패턴 기준" : "월령 기준 평균"
    }

    // MARK: - Data Loading

    func loadTodayActivities(userId: String, babyId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            todayActivities = try await RetryHelper.withRetry {
                try await self.firestoreService.fetchActivities(
                    userId: userId, babyId: babyId, date: Date()
                )
            }

            // 수유 예측 정확도를 위해 최근 7일 수유 데이터도 로드
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
            if weekAgo < yesterday {
                recentFeedingActivities = try await RetryHelper.withRetry {
                    try await self.firestoreService.fetchActivities(
                        userId: userId, babyId: babyId, from: weekAgo, to: yesterday
                    )
                }.filter { $0.type.category == .feeding }
            }
            // recentFeedingActivities 로드 완료 후 derive — 자정 경계 fallback 가능
            deriveLatestActivities()

            // 주간 인사이트 생성 — 이전 7일(current) vs 이전 14일~8일(previous) 비교
            let twoWeeksAgo = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
            let eightDaysAgo = Calendar.current.date(byAdding: .day, value: -8, to: Calendar.current.startOfDay(for: Date())) ?? Date()
            let currentWeekActivities = recentFeedingActivities + todayActivities
            let previousWeekActivities: [Activity]
            if twoWeeksAgo < eightDaysAgo {
                previousWeekActivities = try await RetryHelper.withRetry {
                    try await self.firestoreService.fetchActivities(
                        userId: userId, babyId: babyId, from: twoWeeksAgo, to: eightDaysAgo
                    )
                }
            } else {
                previousWeekActivities = []
            }
            let currentReport = PatternAnalysisService.analyze(
                activities: currentWeekActivities,
                period: "이번 주",
                startDate: weekAgo,
                endDate: Date()
            )
            let comparisonReport = PatternAnalysisService.analyzeComparison(
                currentReport: currentReport,
                previousActivities: previousWeekActivities,
                previousPeriod: (start: twoWeeksAgo, end: eightDaysAgo)
            )
            weeklyInsights = WeeklyInsightService.generateInsights(from: comparisonReport)

            // 야간 발열 감지를 위해 최근 48시간 체온 데이터 로드 (자정 경계 문제 해결)
            let fortyEightHoursAgo = Date().addingTimeInterval(-172800)
            recentTemperatureActivities = try await RetryHelper.withRetry {
                try await self.firestoreService.fetchActivities(
                    userId: userId, babyId: babyId, from: fortyEightHoursAgo, to: Date()
                )
            }.filter { $0.type == .temperature }
        } catch {
            errorMessage = "활동 기록을 불러오지 못했습니다: \(error.localizedDescription)"
        }
    }

    /// todayActivities에서 최근 수유/수면/기저귀를 추출 (Firestore 추가 쿼리 없음)
    /// 자정 경계: todayActivities에 수유 기록이 없으면 recentFeedingActivities에서 fallback
    func deriveLatestActivities() {
        let feedings = todayActivities.filter { $0.type.category == .feeding }
        if let todayLatest = feedings.max(by: { $0.startTime < $1.startTime }) {
            lastFeeding = todayLatest
        } else {
            // 자정 경계 fallback — 오늘 수유가 없을 경우 최근 7일 수유 중 가장 최근 항목 사용
            lastFeeding = recentFeedingActivities.max(by: { $0.startTime < $1.startTime })
        }

        let sleeps = todayActivities.filter { $0.type == .sleep }
        lastSleep = sleeps.max(by: { $0.startTime < $1.startTime })

        let diapers = todayActivities.filter { $0.type.category == .diaper }
        lastDiaper = diapers.max(by: { $0.startTime < $1.startTime })
    }

    // MARK: - Timer (ActivityTimerManager에 위임)

    /// Live Activity 연동 위한 아기 이름 (외부에서 주입, timerManager에 전달)
    var currentBabyName: String {
        get { timerManager.currentBabyName }
        set { timerManager.currentBabyName = newValue }
    }

    func startTimer(type: Activity.ActivityType) {
        timerManager.startTimer(type: type)
        // form 상태 초기화 (타이머 측정값 리셋)
        manualStartTime = timerManager.timerStartTime ?? Date()
        manualEndTime = nil
        isTimeAdjusted = false
    }

    @discardableResult
    func stopTimer() -> TimeInterval {
        let endTime = Date()
        let duration = timerManager.stopTimer()
        // 타이머 측정값을 TimeAdjustmentSection에 반영 (사용자가 직접 수정하지 않은 경우)
        if !isTimeAdjusted && duration > 0 {
            manualStartTime = endTime.addingTimeInterval(-duration)
            manualEndTime = endTime
            isTimeAdjusted = true
        }
        return duration
    }

    /// 앱 시작 시 강제 종료 전에 진행 중이던 타이머 복구
    func resumeTimerIfNeeded() {
        guard let resumed = timerManager.resumeTimerIfNeeded() else { return }
        manualStartTime = resumed.startTime
        manualEndTime = nil
        isTimeAdjusted = false
    }

    // MARK: - Duplicate Check

    /// 같은 타입 + 시작시간 1분 이내 기록이 있는지 확인
    func hasDuplicateRecord(type: Activity.ActivityType, startTime: Date) -> Bool {
        todayActivities.contains { activity in
            activity.type == type &&
            abs(activity.startTime.timeIntervalSince(startTime)) < 60 // 1분 이내
        }
    }

    // MARK: - Validation

    var isTemperatureValid: Bool {
        guard let temp = Double(temperatureInput) else { return false }
        return temp >= 34.0 && temp <= 43.0
    }

    var temperatureWarning: String? {
        guard let temp = Double(temperatureInput) else { return nil }
        if temp >= 40.0 {
            return "⚠️ 체온이 40.0°C 이상입니다! 응급 상황일 수 있습니다. 즉시 소아과 또는 응급실을 방문하세요."
        }
        if temp >= 38.0 && babyAgeInMonths < 3 {
            return "⚠️ 생후 3개월 미만 아기의 38.0°C 이상 발열은 즉시 소아과 방문이 필요합니다."
        }
        if temp >= 38.0 {
            return "체온이 38.0°C 이상입니다. 발열 상태를 확인하고 소아과 상담을 권장합니다."
        }
        if temp <= 35.5 {
            return "체온이 35.5°C 이하입니다. 저체온 상태일 수 있으니 즉시 확인하세요."
        }
        return nil
    }

    var isAmountValid: Bool {
        guard let ml = Double(amount) else { return false }
        return ml > 0 && ml <= 500
    }

    // MARK: - Temperature Trend Detection

    /// 24시간 롤링 윈도우 내 38.0°C 이상 체온 기록 횟수
    /// recentTemperatureActivities(48h 범위)에서 최근 24시간만 필터링 — 야간 발열 페어 감지 가능
    var recentHighTemperatureCount: Int {
        return recentTemperatureActivities.filter {
            ($0.temperature ?? 0) >= 38.0 &&
            $0.startTime > Date().addingTimeInterval(-86400)
        }.count
    }

    /// 24시간 내 38.0°C 이상 체온이 2회 이상 기록된 경우 true
    var isFeverTrendDetected: Bool {
        recentHighTemperatureCount >= 2
    }
}
