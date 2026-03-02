import Foundation
import Combine

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

    // Summary
    var lastFeeding: Activity?
    var lastSleep: Activity?
    var lastDiaper: Activity?
    var todayFeedingCount = 0
    var todaySleepDuration: TimeInterval = 0
    var todayDiaperCount = 0
    var todayTotalMl: Double = 0

    private let firestoreService = FirestoreService.shared
    private var timerTask: Task<Void, Never>?

    func loadTodayActivities(userId: String, babyId: String) async {
        isLoading = true
        do {
            todayActivities = try await firestoreService.fetchActivities(
                userId: userId, babyId: babyId, date: Date()
            )
            computeSummary()
            await loadLatestActivities(userId: userId, babyId: babyId)
        } catch {
            errorMessage = "활동 기록을 불러오지 못했습니다."
        }
        isLoading = false
    }

    private func loadLatestActivities(userId: String, babyId: String) async {
        async let feeding = firestoreService.fetchLatestActivity(userId: userId, babyId: babyId, type: .feedingBreast)
        async let bottle = firestoreService.fetchLatestActivity(userId: userId, babyId: babyId, type: .feedingBottle)
        async let sleep = firestoreService.fetchLatestActivity(userId: userId, babyId: babyId, type: .sleep)
        async let diaper = firestoreService.fetchLatestActivity(userId: userId, babyId: babyId, type: .diaperWet)

        let (f, b, s, d) = (try? await feeding, try? await bottle, try? await sleep, try? await diaper)

        // 가장 최근 수유 (모유/분유 중 더 최근 것)
        if let f, let b {
            lastFeeding = f.startTime > b.startTime ? f : b
        } else {
            lastFeeding = f ?? b
        }
        lastSleep = s
        lastDiaper = d
    }

    private func computeSummary() {
        let feedings = todayActivities.filter { $0.type.category == .feeding }
        todayFeedingCount = feedings.count
        todayTotalMl = feedings.compactMap(\.amount).reduce(0, +)

        let sleeps = todayActivities.filter { $0.type == .sleep }
        todaySleepDuration = sleeps.compactMap(\.duration).reduce(0, +)

        todayDiaperCount = todayActivities.filter { $0.type.category == .diaper }.count
    }

    // MARK: - Timer

    func startTimer(type: Activity.ActivityType) {
        isTimerRunning = true
        timerStartTime = Date()
        activeTimerType = type
        elapsedTime = 0

        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if let start = timerStartTime {
                    elapsedTime = Date().timeIntervalSince(start)
                }
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

    // MARK: - Save Activity

    func saveActivity(userId: String, babyId: String, type: Activity.ActivityType) async {
        var activity = Activity(babyId: babyId, type: type)

        switch type {
        case .feedingBreast:
            if isTimerRunning {
                let duration = stopTimer()
                activity.duration = duration
                activity.startTime = Date().addingTimeInterval(-duration)
            }
            activity.side = selectedSide

        case .feedingBottle:
            if isTimerRunning {
                let duration = stopTimer()
                activity.duration = duration
                activity.startTime = Date().addingTimeInterval(-duration)
            }
            activity.amount = Double(amount) ?? 0

        case .feedingSolid, .feedingSnack:
            break

        case .sleep:
            if isTimerRunning {
                let duration = stopTimer()
                activity.duration = duration
                activity.startTime = Date().addingTimeInterval(-duration)
                activity.endTime = Date()
            }

        case .diaperWet, .diaperDirty, .diaperBoth:
            break

        case .temperature:
            activity.temperature = Double(temperatureInput)

        case .medication:
            activity.medicationName = medicationName.isEmpty ? nil : medicationName

        case .bath:
            if isTimerRunning {
                let duration = stopTimer()
                activity.duration = duration
                activity.startTime = Date().addingTimeInterval(-duration)
            }
        }

        if !note.isEmpty {
            activity.note = note
        }

        do {
            try await firestoreService.saveActivity(activity, userId: userId)
            todayActivities.insert(activity, at: 0)
            computeSummary()
            await loadLatestActivities(userId: userId, babyId: babyId)
            resetForm()
        } catch {
            errorMessage = "기록 저장에 실패했습니다."
        }
    }

    func quickSave(userId: String, babyId: String, type: Activity.ActivityType) async {
        let activity = Activity(babyId: babyId, type: type)
        do {
            try await firestoreService.saveActivity(activity, userId: userId)
            todayActivities.insert(activity, at: 0)
            computeSummary()
            await loadLatestActivities(userId: userId, babyId: babyId)
        } catch {
            errorMessage = "기록 저장에 실패했습니다."
        }
    }

    func deleteActivity(_ activity: Activity, userId: String) async {
        do {
            try await firestoreService.deleteActivity(activity.id, userId: userId, babyId: activity.babyId)
            todayActivities.removeAll { $0.id == activity.id }
            computeSummary()
        } catch {
            errorMessage = "기록 삭제에 실패했습니다."
        }
    }

    func resetForm() {
        selectedSide = .left
        amount = ""
        temperatureInput = ""
        medicationName = ""
        note = ""
    }
}
