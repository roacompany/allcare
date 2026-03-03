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

    private let firestoreService = FirestoreService.shared
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
    private func deriveLatestActivities() {
        let feedings = todayActivities.filter { $0.type.category == .feeding }
        lastFeeding = feedings.max(by: { $0.startTime < $1.startTime })

        let sleeps = todayActivities.filter { $0.type == .sleep }
        lastSleep = sleeps.max(by: { $0.startTime < $1.startTime })

        let diapers = todayActivities.filter { $0.type.category == .diaper }
        lastDiaper = diapers.max(by: { $0.startTime < $1.startTime })
    }

    // MARK: - Timer (스레드 안전)

    func startTimer(type: Activity.ActivityType) {
        isTimerRunning = true
        timerStartTime = Date()
        activeTimerType = type
        elapsedTime = 0

        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                // @MainActor 클래스이므로 self 접근은 MainActor에서 실행
                guard let self, let start = self.timerStartTime else { break }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }

    func stopTimer() -> TimeInterval {
        let duration = elapsedTime
        timerTask?.cancel()
        timerTask = nil
        isTimerRunning = false
        timerStartTime = nil
        activeTimerType = nil
        elapsedTime = 0
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

    // MARK: - Save Activity (낙관적 업데이트 + 롤백)

    func saveActivity(userId: String, babyId: String, type: Activity.ActivityType) async {
        var activity = Activity(babyId: babyId, type: type)

        let timerBelongsToMe = isTimerRunning && activeTimerType == type

        switch type {
        case .feedingBreast:
            if timerBelongsToMe {
                let duration = stopTimer()
                activity.duration = duration
                activity.startTime = Date().addingTimeInterval(-duration)
            }
            activity.side = selectedSide

        case .feedingBottle:
            guard isAmountValid else {
                errorMessage = "수유량을 올바르게 입력해주세요. (1~500ml)"
                return
            }
            if timerBelongsToMe {
                let duration = stopTimer()
                activity.duration = duration
                activity.startTime = Date().addingTimeInterval(-duration)
            }
            activity.amount = Double(amount)

        case .feedingSolid:
            activity.foodName = foodName.isEmpty ? nil : foodName
            activity.foodAmount = foodAmount.isEmpty ? nil : foodAmount
            activity.foodReaction = foodReaction

        case .feedingSnack:
            activity.foodName = foodName.isEmpty ? nil : foodName
            activity.foodAmount = foodAmount.isEmpty ? nil : foodAmount

        case .sleep:
            if timerBelongsToMe {
                let duration = stopTimer()
                activity.duration = duration
                activity.startTime = Date().addingTimeInterval(-duration)
                activity.endTime = Date()
            }
            activity.sleepQuality = sleepQuality
            activity.sleepMethod = sleepMethod

        case .diaperWet, .diaperDirty, .diaperBoth:
            if type == .diaperDirty || type == .diaperBoth {
                activity.stoolColor = stoolColor
                activity.stoolConsistency = stoolConsistency
                activity.hasRash = hasRash ? true : nil
            }

        case .temperature:
            guard isTemperatureValid else {
                errorMessage = "체온을 올바르게 입력해주세요. (34.0~43.0°C)"
                return
            }
            activity.temperature = Double(temperatureInput)

        case .medication:
            activity.medicationName = medicationName.isEmpty ? nil : medicationName
            activity.medicationDosage = medicationDosage.isEmpty ? nil : medicationDosage

        case .bath:
            if timerBelongsToMe {
                let duration = stopTimer()
                activity.duration = duration
                activity.startTime = Date().addingTimeInterval(-duration)
            }
        }

        // 수동 시간 조정 (타이머보다 우선)
        if isTimeAdjusted {
            activity.startTime = manualStartTime
            if let endTime = manualEndTime {
                activity.endTime = endTime
                activity.duration = endTime.timeIntervalSince(manualStartTime)
            }
        }

        if !note.isEmpty {
            activity.note = note
        }

        // 낙관적 업데이트: 먼저 UI 반영
        todayActivities.insert(activity, at: 0)
        let rollbackIndex = 0

        do {
            try await firestoreService.saveActivity(activity, userId: userId)
            deriveLatestActivities()
            scheduleActivityReminderIfNeeded(type: type, babyName: "아기")
            resetForm()
        } catch {
            // 롤백: 실패 시 UI에서 제거
            if rollbackIndex < todayActivities.count, todayActivities[rollbackIndex].id == activity.id {
                todayActivities.remove(at: rollbackIndex)
            }
            errorMessage = "기록 저장에 실패했습니다: \(error.localizedDescription)"
        }
    }

    /// QuickInputSheet에서 미리 구성된 Activity 저장 (체온/투약/분유 등)
    func savePrebuiltActivity(_ activity: Activity, userId: String) async {
        todayActivities.insert(activity, at: 0)

        do {
            try await firestoreService.saveActivity(activity, userId: userId)
            deriveLatestActivities()
            scheduleActivityReminderIfNeeded(type: activity.type, babyName: "아기")
        } catch {
            todayActivities.removeAll { $0.id == activity.id }
            errorMessage = "기록 저장에 실패했습니다."
        }
    }

    func quickSave(userId: String, babyId: String, type: Activity.ActivityType) async {
        var activity = Activity(babyId: babyId, type: type)

        // 빠른 기록에서도 최소한의 기본값 설정
        if type == .feedingBreast {
            activity.side = .left
        }

        todayActivities.insert(activity, at: 0)

        do {
            try await firestoreService.saveActivity(activity, userId: userId)
            deriveLatestActivities()
            scheduleActivityReminderIfNeeded(type: type, babyName: "아기")
        } catch {
            todayActivities.removeAll { $0.id == activity.id }
            errorMessage = "기록 저장에 실패했습니다."
        }
    }

    func updateActivity(_ activity: Activity, userId: String) async {
        guard let index = todayActivities.firstIndex(where: { $0.id == activity.id }) else { return }

        let backup = todayActivities[index]
        todayActivities[index] = activity

        do {
            try await firestoreService.saveActivity(activity, userId: userId)
        } catch {
            todayActivities[index] = backup
            errorMessage = "기록 수정에 실패했습니다."
        }
    }

    func deleteActivity(_ activity: Activity, userId: String) async {
        let backup = todayActivities
        todayActivities.removeAll { $0.id == activity.id }

        do {
            try await firestoreService.deleteActivity(activity.id, userId: userId, babyId: activity.babyId)
        } catch {
            todayActivities = backup
            errorMessage = "기록 삭제에 실패했습니다."
        }
    }

    func resetForm() {
        selectedSide = .left
        amount = ""
        temperatureInput = ""
        medicationName = ""
        note = ""
        errorMessage = nil
        foodName = ""
        foodAmount = ""
        foodReaction = nil
        stoolColor = nil
        stoolConsistency = nil
        hasRash = false
        sleepQuality = nil
        sleepMethod = nil
        medicationDosage = ""
        manualStartTime = Date()
        manualEndTime = nil
        isTimeAdjusted = false
    }

    // MARK: - Activity Reminder

    private func scheduleActivityReminderIfNeeded(type: Activity.ActivityType, babyName: String) {
        guard let rule = ActivityReminderSettings.rule(for: type), rule.enabled else { return }
        NotificationService.shared.scheduleActivityReminder(
            type: type, babyName: babyName, afterMinutes: rule.intervalMinutes
        )
    }

    // MARK: - Widget Data Sync

    func syncWidgetData(babyName: String, babyAge: String) {
        let interval = Int(NotificationSettings.feedingIntervalHours * 60)

        // 오늘 요약 데이터 — lastFeeding/lastSleep/lastDiaper 프로퍼티 재사용
        let sleepMinutes = Int(todaySleepDuration / 60)
        let sleepDurationText = lastSleep?.durationText

        // 최근 5개 활동 → WidgetActivity 변환
        let recent = todayActivities
            .sorted { $0.startTime > $1.startTime }
            .prefix(5)
            .map { activity -> WidgetActivity in
                let detail: String? = activity.durationText ?? activity.amountText
                let colorHex: String
                switch activity.type.category {
                case .feeding: colorHex = "#FF9FB5"
                case .sleep:   colorHex = "#7B9FE8"
                case .diaper:  colorHex = "#85C1A3"
                case .health:  colorHex = "#F4845F"
                }
                return WidgetActivity(
                    typeRaw: activity.type.rawValue,
                    displayName: activity.type.displayName,
                    icon: activity.type.icon,
                    colorHex: colorHex,
                    startTime: activity.startTime,
                    detail: detail
                )
            }

        WidgetDataStore.update(
            babyName: babyName,
            babyAge: babyAge,
            lastFeeding: lastFeeding?.startTime,
            lastFeedingType: lastFeeding?.type.displayName,
            lastSleep: lastSleep?.startTime,
            lastDiaper: lastDiaper?.startTime,
            feedingIntervalMinutes: interval,
            todayFeedingCount: todayFeedingCount,
            todaySleepMinutes: sleepMinutes,
            todayDiaperCount: todayDiaperCount,
            todayTotalMl: todayTotalMl,
            recentActivities: Array(recent),
            lastSleepDuration: sleepDurationText
        )
    }
}
