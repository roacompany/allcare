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

    // 중복 기록 경고 상태
    var showDuplicateWarning = false
    var pendingDuplicateSave: (() async -> Void)?

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

    /// 최근 7일 수유 데이터 (loadTodayActivities에서 함께 로드)
    var recentFeedingActivities: [Activity] = []
    /// 아기 월령 (외부에서 주입)
    var babyAgeInMonths: Int = 3

    var averageFeedingInterval: TimeInterval {
        // 최근 7일 + 오늘 데이터 합산 (중복 제거)
        let allFeedings = (recentFeedingActivities + todayActivities)
            .filter { $0.type.category == .feeding }
            .sorted { $0.startTime < $1.startTime }
        var seen = Set<String>()
        let unique = allFeedings.filter { seen.insert($0.id).inserted }

        guard unique.count >= 2 else {
            // 데이터 부족 시 월령별 기본값 사용
            return AppConstants.feedingIntervalHours(ageInMonths: babyAgeInMonths) * 3600
        }

        var intervals: [TimeInterval] = []
        for i in 1..<unique.count {
            let gap = unique[i].startTime.timeIntervalSince(unique[i-1].startTime)
            // 야간 gap (6시간 이상) 제외 — 낮 수유 패턴만 반영
            if gap > 0 && gap < 21600 {
                intervals.append(gap)
            }
        }

        guard !intervals.isEmpty else {
            return AppConstants.feedingIntervalHours(ageInMonths: babyAgeInMonths) * 3600
        }
        return intervals.reduce(0, +) / Double(intervals.count)
    }

    var nextFeedingEstimate: Date? {
        // 오늘 + 최근 데이터에서 가장 마지막 수유 기록 찾기
        let allFeedings = (recentFeedingActivities + todayActivities)
            .filter { $0.type.category == .feeding }
        guard let latest = allFeedings.max(by: { $0.startTime < $1.startTime }) else {
            return nil
        }
        return latest.startTime.addingTimeInterval(averageFeedingInterval)
    }

    var nextFeedingText: String? {
        guard let estimate = nextFeedingEstimate else { return nil }
        let now = Date()
        if estimate <= now {
            let overdue = now.timeIntervalSince(estimate)
            let overdueMins = Int(overdue / 60)
            if overdueMins > 30 {
                return "수유 시간이 \(overdueMins)분 지났어요"
            }
            return "곧 수유 시간이에요"
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
        // 30분 이상 지나야 overdue — 불필요한 빨간 경고 방지
        return Date().timeIntervalSince(estimate) > 1800
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

            // 수유 예측 정확도를 위해 최근 7일 수유 데이터도 로드
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Calendar.current.startOfDay(for: Date())) ?? Date()
            if weekAgo < yesterday {
                recentFeedingActivities = try await firestoreService.fetchActivities(
                    userId: userId, babyId: babyId, from: weekAgo, to: yesterday
                ).filter { $0.type.category == .feeding }
            }
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

    // MARK: - Timer Persistence Keys

    private static let timerStartKey = "babycare_timer_start"
    private static let timerTypeKey = "babycare_timer_type"

    func startTimer(type: Activity.ActivityType) {
        isTimerRunning = true
        let startTime = Date()
        timerStartTime = startTime
        activeTimerType = type
        elapsedTime = 0
        // 재시작 시 이전 타이머 측정값 초기화
        manualStartTime = startTime
        manualEndTime = nil
        isTimeAdjusted = false

        // UserDefaults에 시작 시간 + 타입 저장 (앱 강제 종료 후 복구용)
        UserDefaults.standard.set(startTime.timeIntervalSince1970, forKey: Self.timerStartKey)
        UserDefaults.standard.set(type.rawValue, forKey: Self.timerTypeKey)

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

        // UserDefaults 타이머 상태 제거
        UserDefaults.standard.removeObject(forKey: Self.timerStartKey)
        UserDefaults.standard.removeObject(forKey: Self.timerTypeKey)

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

    /// 앱 시작 시 강제 종료 전에 진행 중이던 타이머 복구
    func resumeTimerIfNeeded() {
        let startInterval = UserDefaults.standard.double(forKey: Self.timerStartKey)
        guard startInterval > 0,
              let typeRaw = UserDefaults.standard.string(forKey: Self.timerTypeKey),
              let type = Activity.ActivityType(rawValue: typeRaw) else { return }

        let startTime = Date(timeIntervalSince1970: startInterval)
        let elapsed = Date().timeIntervalSince(startTime)

        // 24시간 이상 지난 타이머는 복구하지 않음 (비정상 상태)
        guard elapsed < 86400 else {
            UserDefaults.standard.removeObject(forKey: Self.timerStartKey)
            UserDefaults.standard.removeObject(forKey: Self.timerTypeKey)
            return
        }

        isTimerRunning = true
        timerStartTime = startTime
        activeTimerType = type
        elapsedTime = elapsed
        manualStartTime = startTime
        manualEndTime = nil
        isTimeAdjusted = false

        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                guard let self, let start = self.timerStartTime else { break }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
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
    /// todayActivities + 24h 시간 필터 조합으로 자정 경계 문제를 부분 완화
    /// (완전한 수정: 온도 기록도 recentFeedingActivities처럼 전날 데이터를 별도 로드 필요)
    var recentHighTemperatureCount: Int {
        return todayActivities.filter {
            $0.type == .temperature &&
            ($0.temperature ?? 0) >= 38.0 &&
            $0.startTime > Date().addingTimeInterval(-86400)
        }.count
    }

    /// 24시간 내 38.0°C 이상 체온이 2회 이상 기록된 경우 true
    var isFeverTrendDetected: Bool {
        recentHighTemperatureCount >= 2
    }
}
