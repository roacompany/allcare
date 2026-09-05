import Foundation

/// 밤에 하루를 닫으며 하는 말.
/// 🔴 **한 것만 말하고 못 한 것은 세지 않는다**(설계 §5). 분수·연속 일수·배지 없음.
/// 아무것도 없는 날엔 **아무 말도 하지 않는다** — 「0번」은 격려가 아니라 비난이다.
enum DaySummary {

    private static let korean = ["한", "두", "세", "네", "다섯", "여섯", "일곱", "여덟", "아홉", "열"]

    /// 「서준이 일곱 번 먹고 세 번 잤어요」. 셀 것이 없으면 nil.
    static func babyLine(cells: [DayCell], babyName: String) -> String? {
        // 아이 줄(.baby)만 본다 — DayPlan.Lane 에는 부모 줄(.parent)도 있고, 앞 단계(Expander·
        // SlotFiller)는 두 줄을 한 배열에 섞어 그대로 넘긴다. 여기서 거르지 않으면 부모의 잠·
        // 부모의 밥이 "아이가 잤어요"로 세어진다. 카운트도 nil 판정도 이 한 곳만 거친
        // `happened` 하나만 본다 — 필터 지점을 둘로 나누지 않는다.
        let babyCells = cells.filter { $0.lane == .baby }
        let happened = babyCells.filter { $0.kind != .planned }
        let feeds = happened.filter { isFeeding($0.activityType) }.count
        let sleeps = happened.filter { $0.activityType == Activity.ActivityType.sleep.rawValue }.count
        guard feeds > 0 || sleeps > 0 else { return nil }

        let subject = "\(babyName)\(KoreanParticle.subject(after: babyName))"
        if feeds > 0 && sleeps > 0 {
            return "\(subject) \(count(feeds)) 번 먹고 \(count(sleeps)) 번 잤어요"
        }
        if feeds > 0 { return "\(subject) \(count(feeds)) 번 먹었어요" }
        return "\(subject) \(count(sleeps)) 번 잤어요"
    }

    /// 섭취만 센다 — **유축(생산)은 먹은 것이 아니다**(용어 규칙).
    /// `default:` 없이 exhaustive 유지 — 새 ActivityType이 조용히 「먹은 것」에 안 섞이도록
    /// (swift-conventions.md: 도메인 enum switch 에 default: 금지).
    private static func isFeeding(_ rawValue: String?) -> Bool {
        guard let raw = rawValue, let type = Activity.ActivityType.known(rawValue: raw) else { return false }
        switch type {
        case .feedingBreast, .feedingBottle, .feedingSolid, .feedingSnack:
            return true
        case .feedingPumping:
            return false   // 유축 = 생산. 여기 넣으면 이 태스크가 막으려는 바로 그 버그다.
        case .sleep, .diaperWet, .diaperDirty, .diaperBoth, .bath, .temperature, .medication:
            return false
        case .unknown:
            return false   // known(rawValue:)가 이미 걸러내 실제 도달 불가 — exhaustive 요건상 존재.
        }
    }

    private static func count(_ n: Int) -> String {
        n >= 1 && n <= korean.count ? korean[n - 1] : "\(n)"
    }
}
