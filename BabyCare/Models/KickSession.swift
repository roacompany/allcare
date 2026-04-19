import Foundation

/// 태동 기록 세션 (ACOG "Count the Kicks" 표준).
/// KickEvent는 서브컬렉션이 아닌 배열 임베딩 — 세션당 수십 개 수준으로 서브컬렉션 오버헤드 불필요.
struct KickSession: Identifiable, Codable, Hashable {
    var id: String
    var pregnancyId: String
    var startedAt: Date
    var endedAt: Date?
    /// 개별 태동 이벤트 (타임스탬프 배열).
    var kicks: [KickEvent]
    /// 목표 카운트 (기본 10회 = ACOG 표준).
    var targetCount: Int?
    var notes: String?
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, pregnancyId, startedAt, endedAt, kicks, targetCount, notes, createdAt
    }

    init(
        id: String = UUID().uuidString,
        pregnancyId: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        kicks: [KickEvent] = [],
        targetCount: Int? = 10,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.pregnancyId = pregnancyId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.kicks = kicks
        self.targetCount = targetCount
        self.notes = notes
        self.createdAt = createdAt
    }

    /// 태동 횟수.
    var kickCount: Int { kicks.count }

    /// 목표 달성 여부.
    var reachedTarget: Bool {
        kickCount >= (targetCount ?? 10)
    }

    /// 세션 경과 시간 (초). endedAt 없으면 현재 시간 기준.
    var durationSeconds: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    /// ACOG 표준 2시간 초과 여부.
    var exceededTwoHours: Bool {
        durationSeconds > 7200
    }
}

struct KickEvent: Identifiable, Codable, Hashable {
    var id: String
    var timestamp: Date

    init(id: String = UUID().uuidString, timestamp: Date = Date()) {
        self.id = id
        self.timestamp = timestamp
    }
}
