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
        // 기존 Activity가 있으면 종료
        stopFeedingTimer()

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
    func stopFeedingTimer() {
        updateTask?.cancel()
        updateTask = nil

        guard let activity = currentActivity else { return }

        let finalState = FeedingTimerAttributes.ContentState(
            elapsedSeconds: Int(Date().timeIntervalSince(activity.attributes.startTime)),
            isRunning: false
        )

        Task {
            let content = ActivityContent(state: finalState, staleDate: nil)
            await activity.end(content, dismissalPolicy: .after(.now + 60))
            Self.logger.info("Live Activity ended")
        }

        currentActivity = nil
    }

    /// 경과 시간 업데이트
    func updateElapsedTime(seconds: Int) {
        guard let activity = currentActivity else { return }

        let state = FeedingTimerAttributes.ContentState(
            elapsedSeconds: seconds,
            isRunning: true
        )

        Task {
            let content = ActivityContent(state: state, staleDate: nil)
            await activity.update(content)
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
