import Foundation

/// 「오늘 하루」를 열었나 · 닫았나. **하루에 한 문서**(id = 로컬 날짜).
///
/// ⛔ 칸의 상태(무엇이 채워졌나)는 여기 저장하지 않는다 —
///    시간표 + 그날 기록에서 매번 다시 계산한다. 저장하면 기록을 고칠 때마다 갈라진다.
///
/// 왜 「시작」이 있나: 시작이 있으면 **안 한 날과 못 한 날이 갈린다.**
/// 시작 안 한 날은 실패가 아니다(설계 §2.2).
struct DayRun: Identifiable, Codable, Hashable {
    /// 로컬 날짜 `yyyy-MM-dd`. Firestore 문서 id 와 같다 — 같은 날 다시 열어도 덮어쓴다(멱등).
    var id: String
    /// 이 하루가 어느 시간표로 열렸나. nil = 시간표 없이 연 날(하위호환).
    var planId: String?
    var startedAt: Date
    /// nil = 아직 진행 중.
    var closedAt: Date?

    var isOpen: Bool { closedAt == nil }

    init(id: String, planId: String? = nil, startedAt: Date, closedAt: Date? = nil) {
        self.id = id
        self.planId = planId
        self.startedAt = startedAt
        self.closedAt = closedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        planId = try c.decodeIfPresent(String.self, forKey: .planId)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        closedAt = try c.decodeIfPresent(Date.self, forKey: .closedAt)
    }

    /// 로컬 달력 기준 날짜 문자열. **시간대를 타므로 달력을 받는다**(테스트가 고정할 수 있게).
    static func documentId(for day: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
