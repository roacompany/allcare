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

    // MARK: - Timer Persistence
    // 상태는 App Group(`RunningTimerStore`)에 둔다 — 시리(별도 진입점)가 같은 것을 봐야
    // 「잠들었어」와 앱 배너가 갈라지지 않는다.

    // MARK: - Timer Control

    func startTimer(type: Activity.ActivityType) {
        // .unknown(forward-compat 센티넬)은 타이머 대상 아님 (needsTimer=false) — 진입 차단
        guard type != .unknown else { return }
        isTimerRunning = true
        let startTime = Date()
        timerStartTime = startTime
        activeTimerType = type
        elapsedTime = 0

        // App Group 에 시작 시간 + 타입 저장 (앱 강제 종료 후 복구용 + 시리 공유)
        RunningTimerStore.start(type: type, at: startTime)

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

        RunningTimerStore.clear()

        // Live Activity 종료
        LiveActivityManager.shared.stopFeedingTimer()

        return duration
    }

    /// 앱 시작 시 강제 종료 전에 진행 중이던 타이머 복구
    /// - Returns: 복구된 경우 (타입, 시작 시간) 튜플; 복구되지 않은 경우 nil
    @discardableResult
    func resumeTimerIfNeeded() -> (type: Activity.ActivityType, startTime: Date)? {
        RunningTimerStore.migrateFromStandardDefaultsIfNeeded()

        guard let running = RunningTimerStore.current() else {
            // 복구할 타이머 없음 — 시스템에 leftover Live Activity가 있으면 정리
            LiveActivityManager.shared.reconcileWithRunningTimer(isTimerRunning: false)
            return nil
        }

        let startTime = running.startedAt
        let type = running.type
        let elapsed = Date().timeIntervalSince(startTime)

        // 24시간 이상 지난 타이머는 복구하지 않음 (비정상 상태)
        guard elapsed < AppConstants.secondsPerDay else {
            RunningTimerStore.clear()
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
