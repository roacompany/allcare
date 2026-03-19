import Foundation

@MainActor @Observable
final class ActivityViewModel {
    var todayActivities: [Activity] = []
    var isLoading = false
    var errorMessage: String?

    // Timer state
    var isTimerRunning = false
    var timerStartTime: Date?
    var elapsedTime: TimeInterval = 0
    var activeTimerType: Activity.ActivityType?

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

    let firestoreService = FirestoreService.shared
    private var timerTask: Task<Void, Never>?

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

    // MARK: - Predictions

    var averageFeedingInterval: TimeInterval {
        let feedings = todayActivities
            .filter { $0.type.category == .feeding }
            .sorted { $0.startTime < $1.startTime }

        guard feedings.count >= 2 else {
            return AppConstants.defaultFeedingIntervalHours * 3600
        }

        var intervals: [TimeInterval] = []
        for i in 1..<feedings.count {
            intervals.append(feedings[i].startTime.timeIntervalSince(feedings[i-1].startTime))
        }
        return intervals.reduce(0, +) / Double(intervals.count)
    }

    var nextFeedingEstimate: Date? {
        guard let last = lastFeeding else { return nil }
        return last.startTime.addingTimeInterval(averageFeedingInterval)
    }

    var nextFeedingText: String? {
        guard let estimate = nextFeedingEstimate else { return nil }
        let now = Date()
        if estimate <= now {
            return "수유 시간이 지났어요!"
        }
        let remaining = estimate.timeIntervalSince(now)
        let minutes = Int(remaining / 60)
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "약 \(hours)시간 \(mins)분 후"
        }
        return "약 \(mins)분 후"
    }

    var isFeedingOverdue: Bool {
        guard let estimate = nextFeedingEstimate else { return false }
        return estimate <= Date()
    }

    // MARK: - Data Loading

    func loadTodayActivities(userId: String, babyId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            todayActivities = try await firestoreService.fetchActivities(
                userId: userId, babyId: babyId, date: Date()
            )
            deriveLatestActivities()
        } catch {
            errorMessage = "활동 기록을 불러오지 못했습니다: \(error.localizedDescription)"
        }
    }

    /// todayActivities에서 최근 수유/수면/기저귀를 추출 (Firestore 추가 쿼리 없음)
    func deriveLatestActivities() {
        let feedings = todayActivities.filter { $0.type.category == .feeding }
        lastFeeding = feedings.max(by: { $0.startTime < $1.startTime })

        let sleeps = todayActivities.filter { $0.type == .sleep }
        lastSleep = sleeps.max(by: { $0.startTime < $1.startTime })

        let diapers = todayActivities.filter { $0.type.category == .diaper }
        lastDiaper = diapers.max(by: { $0.startTime < $1.startTime })
    }

    // MARK: - Timer (스레드 안전)

    /// Live Activity 연동 위한 아기 이름 (외부에서 주입)
    var currentBabyName: String = "아기"

    func startTimer(type: Activity.ActivityType) {
        isTimerRunning = true
        timerStartTime = Date()
        activeTimerType = type
        elapsedTime = 0
        // 재시작 시 이전 타이머 측정값 초기화
        manualStartTime = Date()
        manualEndTime = nil
        isTimeAdjusted = false

        // Live Activity 시작 (수유 타이머만)
        if type.category == .feeding || type == .sleep {
            LiveActivityManager.shared.startFeedingTimer(
                babyName: currentBabyName,
                feedingType: type
            )
        }

        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                // @MainActor 클래스이므로 self 접근은 MainActor에서 실행
                guard let self, let start = self.timerStartTime else { break }
                self.elapsedTime = Date().timeIntervalSince(start)

                // Live Activity 업데이트 (30초 간격은 LiveActivityManager 내부에서 처리)
            }
        }
    }

    func stopTimer() -> TimeInterval {
        let duration = elapsedTime
        let endTime = Date()
        timerTask?.cancel()
        timerTask = nil
        isTimerRunning = false
        timerStartTime = nil
        activeTimerType = nil
        elapsedTime = 0

        // Live Activity 종료
        LiveActivityManager.shared.stopFeedingTimer()

        // 타이머 측정값을 TimeAdjustmentSection에 반영 (사용자가 직접 수정하지 않은 경우)
        if !isTimeAdjusted && duration > 0 {
            manualStartTime = endTime.addingTimeInterval(-duration)
            manualEndTime = endTime
            isTimeAdjusted = true
        }
        return duration
    }

    // MARK: - Validation

    var isTemperatureValid: Bool {
        guard let temp = Double(temperatureInput) else { return false }
        return temp >= 34.0 && temp <= 43.0
    }

    var isAmountValid: Bool {
        guard let ml = Double(amount) else { return false }
        return ml > 0 && ml <= 500
    }
}
