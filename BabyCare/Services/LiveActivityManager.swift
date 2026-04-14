import ActivityKit
import Foundation
import OSLog

/// ActivityKit.Activity 타입 별칭 (BabyCare.Activity 모델과 이름 충돌 방지)
private typealias LiveActivity = ActivityKit.Activity<FeedingTimerAttributes>

/// Live Activity 수유 타이머 관리
/// 잠금화면과 Dynamic Island에서 실시간 경과 시간 표시
@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "BabyCare", category: "LiveActivity")
    private var currentActivity: LiveActivity?
    private var updateTask: Task<Void, Never>?

    /// 수유 타이머 Live Activity 시작
    func startFeedingTimer(
        babyName: String,
        feedingType: BabyCare.Activity.ActivityType
    ) {
        Task { [weak self] in
            await self?._startFeedingTimer(babyName: babyName, feedingType: feedingType)
        }
    }

    private func _startFeedingTimer(
        babyName: String,
        feedingType: BabyCare.Activity.ActivityType
    ) async {
        // 기존 Activity가 있으면 await로 완전히 종료한 후 새로 시작
        // (race condition 방지: 새 Activity가 등록된 후 stopFeedingTimer의 비동기 Task가 새 것까지 종료시키는 문제)
        for activity in LiveActivity.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        updateTask?.cancel()
        updateTask = nil

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Self.logger.warning("Live Activities are not enabled")
            return
        }

        let attributes = FeedingTimerAttributes(
            babyName: babyName,
            feedingTypeDisplay: feedingType.displayName,
            feedingTypeIcon: feedingType.icon,
            startTime: Date()
        )

        let initialState = FeedingTimerAttributes.ContentState(
            elapsedSeconds: 0,
            isRunning: true
        )

        do {
            let content = ActivityContent(state: initialState, staleDate: nil)
            currentActivity = try LiveActivity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            Self.logger.info("Live Activity started for \(feedingType.displayName)")

            // 주기적 업데이트 시작 (30초마다)
            startPeriodicUpdate(startTime: Date())
        } catch {
            Self.logger.error("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    /// 수유 타이머 Live Activity 종료
    /// 메모리에 캐시된 currentActivity뿐 아니라 시스템에 남아있는 모든 leftover Activity도 정리.
    func stopFeedingTimer() {
        updateTask?.cancel()
        updateTask = nil

        currentActivity = nil

        // 시스템에 등록된 모든 FeedingTimerAttributes Activity를 즉시 종료
        // (앱 재시작 후에는 currentActivity가 nil이라 이 경로로만 정리 가능)
        Task {
            for activity in LiveActivity.activities {
                let elapsed = Int(Date().timeIntervalSince(activity.attributes.startTime))
                let finalState = FeedingTimerAttributes.ContentState(
                    elapsedSeconds: elapsed,
                    isRunning: false
                )
                let content = ActivityContent(state: finalState, staleDate: nil)
                await activity.end(content, dismissalPolicy: .immediate)
                Self.logger.info("Live Activity ended (immediate)")
            }
        }
    }

    /// 앱 시작 시 호출 — 진행 중이지 않은 leftover Live Activity 정리.
    /// 타이머가 진행 중이면 그 Activity를 currentActivity에 다시 연결한다.
    func reconcileWithRunningTimer(isTimerRunning: Bool) {
        Task {
            let active = LiveActivity.activities
            if isTimerRunning {
                // 타이머가 진행 중이면 첫 번째 활성 Activity를 currentActivity에 재연결
                if currentActivity == nil, let first = active.first {
                    currentActivity = first
                    Self.logger.info("Reconnected to existing Live Activity")
                }
            } else {
                // 타이머가 없는데 leftover Activity가 있으면 모두 정리
                for activity in active {
                    await activity.end(nil, dismissalPolicy: .immediate)
                    Self.logger.info("Cleaned up leftover Live Activity on launch")
                }
                currentActivity = nil
            }
        }
    }

    /// 경과 시간 업데이트
    func updateElapsedTime(seconds: Int) {
        guard let activity = currentActivity else { return }

        let state = FeedingTimerAttributes.ContentState(
            elapsedSeconds: seconds,
            isRunning: true
        )

        nonisolated(unsafe) let activityToUpdate = activity
        Task {
            let content = ActivityContent(state: state, staleDate: nil)
            await activityToUpdate.update(content)
        }
    }

    /// 현재 Live Activity가 활성 상태인지
    var isActive: Bool {
        currentActivity != nil
    }

    // MARK: - Private

    /// 30초마다 경과 시간을 업데이트 (최대 8시간 후 자동 종료)
    private func startPeriodicUpdate(startTime: Date) {
        updateTask?.cancel()
        updateTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }

                let elapsed = Int(Date().timeIntervalSince(startTime))

                // 최대 8시간 자동 종료
                if elapsed >= FeedingTimerAttributes.maxDurationSeconds {
                    self?.stopFeedingTimer()
                    break
                }

                self?.updateElapsedTime(seconds: elapsed)
            }
        }
    }
}
