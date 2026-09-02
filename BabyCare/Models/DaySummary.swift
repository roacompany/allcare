import Foundation

/// 밤에 하루를 닫으며 하는 말.
/// 🔴 **한 것만 말하고 못 한 것은 세지 않는다**(설계 §5). 분수·연속 일수·배지 없음.
/// 아무것도 없는 날엔 **아무 말도 하지 않는다** — 「0번」은 격려가 아니라 비난이다.
enum DaySummary {

    private static let korean = ["한", "두", "세", "네", "다섯", "여섯", "일곱", "여덟", "아홉", "열"]

    /// 「서준이 일곱 번 먹고 세 번 잤어요」. 셀 것이 없으면 nil.
    static func babyLine(cells: [DayCell], babyName: String) -> String? {
        let happened = cells.filter { $0.kind != .planned }
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
    private static func isFeeding(_ rawValue: String?) -> Bool {
        guard let raw = rawValue, let type = Activity.ActivityType.known(rawValue: raw) else { return false }
        switch type {
        case .feedingBreast, .feedingBottle, .feedingSolid, .feedingSnack: return true
        default: return false
        }
    }

    private static func count(_ n: Int) -> String {
        n >= 1 && n <= korean.count ? korean[n - 1] : "\(n)"
    }
}
