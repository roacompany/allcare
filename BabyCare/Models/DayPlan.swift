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

    /// 아이 줄 / 내 줄. rawValue = Firestore 영구 계약. 미지의 rawValue는 .baby로 폴백 (문서 drop 방지).
    enum Lane: String, Codable, Hashable {
        case baby
        case parent

        /// 미지의 rawValue를 .baby로 폴백 (throw 대신) → 문서 손실 방지.
        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Lane(rawValue: raw) ?? .baby
        }

        /// 인코딩은 synthesized (rawValue 쓰기 정상).
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }

    struct Entry: Identifiable, Codable, Hashable {
        var id: String
        var title: String
        /// `Activity.ActivityType.rawValue`. nil = 기록 종류가 없는 것(내 밥·샤워).
        var activityType: String?
        var lane: Lane
        var schedule: PlanSchedule
        var order: Int

        /// 이 항목을 채우는 **기록의 종류**.
        /// 🔑 명시값이 없으면 「첫 기록부터 주기」의 정박 종류가 답이다 —
        ///    「첫 분유부터 3시간마다」로 짠 사람에게 「무슨 기록으로 채울까요?」를 또 묻지 않는다.
        /// nil = 기록이 없는 일(내 밥·샤워). 없는 종류를 지어내지 않는다.
        var recordType: String? { activityType ?? schedule.anchorType }

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
    enum Kind: String, Codable, Hashable, CaseIterable {
        case fixedTimes = "fixed_times"
        case afterFirst = "after_first"
        case afterEntry = "after_entry"
        /// 신버전이 추가한 미지의 kind rawValue를 디코드한 read-only 센티넬 (forward-compat).
        /// 구버전 가족기기가 모르는 종류를 만나도 문서 drop을 막기 위함. 절대 영속 금지.
        case unknown = "unknown"

        /// 미지의 rawValue를 .unknown으로 폴백 (throw 대신) → 문서 drop 방지.
        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: raw) ?? .unknown
        }

        /// .unknown 은 read-only 센티넬 — 인코딩(=영속) 시 fail-loud. 실제 rawValue 덮어쓰기(데이터 손실) 봉쇄.
        /// 정상 kind는 기존 synthesized와 동일하게 rawValue 단일값 인코딩.
        func encode(to encoder: Encoder) throws {
            guard self != .unknown else {
                throw EncodingError.invalidValue(self, EncodingError.Context(
                    codingPath: encoder.codingPath,
                    debugDescription: "PlanSchedule.Kind.unknown은 read-only 센티넬이라 영속될 수 없다."
                ))
            }
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
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
