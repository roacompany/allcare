import Foundation

/// 타이머 상태 및 로직을 전담하는 매니저
/// ActivityViewModel에서 분리된 타이머 관련 코드 (UserDefaults 영속화, Live Activity 연동 포함)
@MainActor @Observable
final class ActivityTimerManager {

    // MARK: - Timer State

    var isTimerRunning = false
    var timerStartTime: Date?
    var elapsedTime: TimeInterval = 0
    var activeTimerType: Activity.ActivityType?

    /// Live Activity 연동용 아기 이름 (ActivityViewModel에서 주입)
    var currentBabyName: String = "아기"

    private var timerTask: Task<Void, Never>?

    // MARK: - Timer Persistence Keys

    private static let timerStartKey = "babycare_timer_start"
    private static let timerTypeKey = "babycare_timer_type"

    // MARK: - Timer Control

    func startTimer(type: Activity.ActivityType) {
        isTimerRunning = true
        let startTime = Date()
        timerStartTime = startTime
        activeTimerType = type
        elapsedTime = 0

        // UserDefaults에 시작 시간 + 타입 저장 (앱 강제 종료 후 복구용)
        UserDefaults.standard.set(startTime.timeIntervalSince1970, forKey: Self.timerStartKey)
        UserDefaults.standard.set(type.rawValue, forKey: Self.timerTypeKey)

        // Live Activity 시작 (수유/수면 타이머만)
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
                guard let self, let start = self.timerStartTime else { break }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }

    /// 타이머를 중지하고 경과 시간을 반환한다.
    /// - Returns: 경과 시간 (초). 호출자(ActivityViewModel)가 form 상태를 업데이트하는 데 사용.
    @discardableResult
    func stopTimer() -> TimeInterval {
        let duration = elapsedTime
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

        return duration
    }

    /// 앱 시작 시 강제 종료 전에 진행 중이던 타이머 복구
    /// - Returns: 복구된 경우 (타입, 시작 시간) 튜플; 복구되지 않은 경우 nil
    @discardableResult
    func resumeTimerIfNeeded() -> (type: Activity.ActivityType, startTime: Date)? {
        let startInterval = UserDefaults.standard.double(forKey: Self.timerStartKey)
        guard startInterval > 0,
              let typeRaw = UserDefaults.standard.string(forKey: Self.timerTypeKey),
              let type = Activity.ActivityType(rawValue: typeRaw) else {
            // 복구할 타이머 없음 — 시스템에 leftover Live Activity가 있으면 정리
            LiveActivityManager.shared.reconcileWithRunningTimer(isTimerRunning: false)
            return nil
        }

        let startTime = Date(timeIntervalSince1970: startInterval)
        let elapsed = Date().timeIntervalSince(startTime)

        // 24시간 이상 지난 타이머는 복구하지 않음 (비정상 상태)
        guard elapsed < 86400 else {
            UserDefaults.standard.removeObject(forKey: Self.timerStartKey)
            UserDefaults.standard.removeObject(forKey: Self.timerTypeKey)
            LiveActivityManager.shared.reconcileWithRunningTimer(isTimerRunning: false)
            return nil
        }

        isTimerRunning = true
        timerStartTime = startTime
        activeTimerType = type
        elapsedTime = elapsed

        // 진행 중인 타이머 — 시스템의 Live Activity와 재연결
        LiveActivityManager.shared.reconcileWithRunningTimer(isTimerRunning: true)

        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                guard let self, let start = self.timerStartTime else { break }
                self.elapsedTime = Date().timeIntervalSince(start)
            }
        }

        return (type, startTime)
    }
}
