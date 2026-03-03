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
            await loadLatestActivities(userId: userId, babyId: babyId)
        } catch {
            errorMessage = "활동 기록을 불러오지 못했습니다: \(error.localizedDescription)"
        }
    }

    private func loadLatestActivities(userId: String, babyId: String) async {
        // 각 쿼리 독립 실행, 개별 에러는 무시 (latest는 보조 정보)
        async let feeding = try? firestoreService.fetchLatestActivity(userId: userId, babyId: babyId, type: .feedingBreast)
        async let bottle = try? firestoreService.fetchLatestActivity(userId: userId, babyId: babyId, type: .feedingBottle)
        async let sleepAct = try? firestoreService.fetchLatestActivity(userId: userId, babyId: babyId, type: .sleep)
        async let diaperAct = try? firestoreService.fetchLatestActivity(userId: userId, babyId: babyId, type: .diaperWet)

        let (f, b, s, d) = await (feeding, bottle, sleepAct, diaperAct)

        // 가장 최근 수유 (모유/분유 중 더 최근)
        switch (f, b) {
        case let (f?, b?):
            lastFeeding = f.startTime > b.startTime ? f : b
        default:
            lastFeeding = f ?? b
        }
        lastSleep = s
        lastDiaper = d
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

        case .feedingSolid, .feedingSnack:
            break

        case .sleep:
            if timerBelongsToMe {
                let duration = stopTimer()
                activity.duration = duration
                activity.startTime = Date().addingTimeInterval(-duration)
                activity.endTime = Date()
            }

        case .diaperWet, .diaperDirty, .diaperBoth:
            break

        case .temperature:
            guard isTemperatureValid else {
                errorMessage = "체온을 올바르게 입력해주세요. (34.0~43.0°C)"
                return
            }
            activity.temperature = Double(temperatureInput)

        case .medication:
            activity.medicationName = medicationName.isEmpty ? nil : medicationName

        case .bath:
            if timerBelongsToMe {
                let duration = stopTimer()
                activity.duration = duration
                activity.startTime = Date().addingTimeInterval(-duration)
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
            await loadLatestActivities(userId: userId, babyId: babyId)
            scheduleFeedingReminderIfNeeded(type: type, babyId: babyId)
            resetForm()
        } catch {
            // 롤백: 실패 시 UI에서 제거
            if rollbackIndex < todayActivities.count, todayActivities[rollbackIndex].id == activity.id {
                todayActivities.remove(at: rollbackIndex)
            }
            errorMessage = "기록 저장에 실패했습니다: \(error.localizedDescription)"
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
            await loadLatestActivities(userId: userId, babyId: babyId)
            scheduleFeedingReminderIfNeeded(type: type, babyId: babyId)
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
    }

    // MARK: - Feeding Reminder

    private func scheduleFeedingReminderIfNeeded(type: Activity.ActivityType, babyId: String) {
        guard type.category == .feeding else { return }
        let minutes = Int(NotificationSettings.feedingIntervalHours * 60)
        NotificationService.shared.scheduleFeedingReminder(babyName: "아기", afterMinutes: minutes)
    }

    // MARK: - Widget Data Sync

    func syncWidgetData(babyName: String, babyAge: String) {
        let lastFeeding = todayActivities
            .filter { $0.type.category == .feeding }
            .sorted { $0.startTime > $1.startTime }.first?.startTime
        let lastFeedingType = todayActivities
            .filter { $0.type.category == .feeding }
            .sorted { $0.startTime > $1.startTime }.first?.type.displayName
        let lastSleep = todayActivities
            .filter { $0.type == .sleep }
            .sorted { $0.startTime > $1.startTime }.first?.startTime
        let lastDiaper = todayActivities
            .filter { $0.type.category == .diaper }
            .sorted { $0.startTime > $1.startTime }.first?.startTime
        let interval = Int(NotificationSettings.feedingIntervalHours * 60)

        WidgetDataStore.update(
            babyName: babyName,
            babyAge: babyAge,
            lastFeeding: lastFeeding,
            lastFeedingType: lastFeedingType,
            lastSleep: lastSleep,
            lastDiaper: lastDiaper,
            feedingIntervalMinutes: interval
        )
    }
}
