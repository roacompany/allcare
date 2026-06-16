import Foundation

/// 진통 1회 (시작/끝, 임베딩 — KickEvent식, 서브컬렉션 생성 금지 룰).
struct ContractionEvent: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var startedAt: Date
    var endedAt: Date?

    var durationSeconds: TimeInterval? {
        guard let end = endedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }
}

/// 진통 세션 (신규 컬렉션 contractionSessions). 5-1-1 판정은 순수·절대시간 기반.
struct ContractionSession: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var pregnancyId: String
    var contractions: [ContractionEvent] = []
    var isFirstBirth: Bool = true   // 초산/경산 안내 분기
    var startedAt: Date = Date()
    var endedAt: Date?
    var createdAt: Date = Date()

    /// 5-1-1: 최근 1시간 동안 평균 간격 ≤ 5분 AND 평균 지속 ≥ 1분 AND 관찰창이 1시간 이상.
    /// 판정은 안내일 뿐 — 의료 단정 금지. 절대시간(startedAt) 기반(타이머 카운트 의존 금지).
    func meets511(asOf now: Date, window: TimeInterval = 3600) -> Bool {
        let recent = contractions
            .filter { $0.startedAt >= now.addingTimeInterval(-window) }
            .sorted { $0.startedAt < $1.startedAt }
        guard recent.count >= 2,
              let first = recent.first?.startedAt,
              now.timeIntervalSince(first) >= window - 1 else { return false }  // 1시간 지속

        // 평균 간격 ≤ 5분
        var intervals: [TimeInterval] = []
        for i in 1..<recent.count {
            intervals.append(recent[i].startedAt.timeIntervalSince(recent[i - 1].startedAt))
        }
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        guard avgInterval <= 300 else { return false }

        // 평균 지속 ≥ 1분 (지속 기록 있는 것만)
        let durations = recent.compactMap { $0.durationSeconds }
        guard !durations.isEmpty else { return false }
        let avgDuration = durations.reduce(0, +) / Double(durations.count)
        return avgDuration >= 60
    }
}
