import Foundation

/// 그날 기록 → `DayPlanExpander` 가 쓰는 정박점.
/// **순수 함수만** — `Date()` 도, 저장소도 만지지 않는다.
enum DayAnchorsBuilder {

    /// 🔴 `activities` 는 **하루 목록 그대로** 넘겨도 된다 — 여기서 `startedOn` 으로 거른다.
    ///    (`fetchActivities(date:)` 는 「그날 끝난 것」도 합쳐 주므로, 안 거르면
    ///     어젯밤 잠이 오늘의 첫 기록이 된다 — `.claude/rules/day-attribution.md`)
    static func anchors(
        from activities: [Activity],
        on day: Date,
        calendar: Calendar = .current
    ) -> DayAnchors {
        let started = ActivityDayAttribution.startedOn(activities, day: day, calendar: calendar)
        var first: [String: Date] = [:]
        for a in started where a.type != .unknown {
            let key = a.type.rawValue
            if let existing = first[key], existing <= a.startTime { continue }
            first[key] = a.startTime
        }
        // `completedByEntry`(앞 일 뒤에)는 ②-B 이후 — 지금은 비운다.
        // 비워 두면 `afterEntry` 칸은 「미정」으로 남는다(설계대로: 자리는 있고 시각만 없다).
        return DayAnchors(firstRecordByType: first)
    }
}
