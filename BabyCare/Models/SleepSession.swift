import Foundation

/// 자고 있는 구간 — 시작만 있고 아직 안 끝난 상태.
/// 끝나는 순간 `ActivityDraftBuilder` 가 24시간 초과를 거절하므로 여기서 규칙을 다시 쓰지 않는다.
struct SleepSession: Equatable, Sendable {
    let startedAt: Date

    func duration(now: Date) -> TimeInterval { now.timeIntervalSince(startedAt) }
}
