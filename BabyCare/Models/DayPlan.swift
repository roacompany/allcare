import Foundation

/// 부모가 짜는 하루 시간표. 루틴(체크리스트)과 다른 개념 —
/// 시간표는 **시각**을 갖고, 연속 일수·완료율을 세지 않는다(설계 §5).
struct DayPlan: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var entries: [Entry]
    var babyId: String?
    var isActive: Bool
    var createdAt: Date

    /// 아이 줄 / 내 줄. rawValue = Firestore 영구 계약.
    enum Lane: String, Codable, Hashable {
        case baby
        case parent
    }

    struct Entry: Identifiable, Codable, Hashable {
        var id: String
        var title: String
        /// `Activity.ActivityType.rawValue`. nil = 기록 종류가 없는 것(내 밥·샤워).
        var activityType: String?
        var lane: Lane
        var schedule: PlanSchedule
        var order: Int

        init(
            id: String = UUID().uuidString,
            title: String,
            activityType: String? = nil,
            lane: Lane = .baby,
            schedule: PlanSchedule,
            order: Int
        ) {
            self.id = id
            self.title = title
            self.activityType = activityType
            self.lane = lane
            self.schedule = schedule
            self.order = order
        }
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        entries: [Entry] = [],
        babyId: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.entries = entries
        self.babyId = babyId
        self.isActive = isActive
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        entries = try c.decodeIfPresent([Entry].self, forKey: .entries) ?? []
        babyId = try c.decodeIfPresent(String.self, forKey: .babyId)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
    }
}

/// 「언제」를 말하는 세 방식. 평평한 구조 + `kind` 판별자 —
/// 연관값 enum 의 중첩 JSON 은 Firestore 계약으로 쓰기 나쁘다.
struct PlanSchedule: Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case fixedTimes = "fixed_times"
        case afterFirst = "after_first"
        case afterEntry = "after_entry"
    }

    var kind: Kind
    /// fixedTimes — 자정으로부터 분(0..<1440), 오름차순.
    var minutesOfDay: [Int]?
    /// afterFirst — 정박할 기록 종류(`Activity.ActivityType.rawValue`).
    var anchorType: String?
    /// afterFirst — 간격(분).
    var everyMinutes: Int?
    /// afterFirst — 하루 몇 칸.
    var count: Int?
    /// afterEntry — 앞 항목의 `Entry.id`.
    var afterEntryId: String?
    /// afterEntry — 앞 항목 뒤 몇 분.
    var offsetMinutes: Int?

    static func fixedTimes(minutesOfDay: [Int]) -> PlanSchedule {
        PlanSchedule(kind: .fixedTimes, minutesOfDay: minutesOfDay.sorted())
    }

    static func afterFirst(anchorType: String, everyMinutes: Int, count: Int) -> PlanSchedule {
        PlanSchedule(kind: .afterFirst, anchorType: anchorType, everyMinutes: everyMinutes, count: count)
    }

    static func afterEntry(entryId: String, offsetMinutes: Int) -> PlanSchedule {
        PlanSchedule(kind: .afterEntry, afterEntryId: entryId, offsetMinutes: offsetMinutes)
    }
}
