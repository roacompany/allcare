import Foundation

/// 그날의 정박점. 시간표를 실제 시각으로 펼치는 데 필요한 두 가지.
struct DayAnchors: Hashable {
    /// 오늘 그 종류의 **첫 기록** 시각 — `afterFirst` 가 쓴다.
    var firstRecordByType: [String: Date]
    /// 오늘 그 항목이 **끝난** 시각 — `afterEntry` 가 쓴다.
    var completedByEntry: [String: Date]

    init(firstRecordByType: [String: Date] = [:], completedByEntry: [String: Date] = [:]) {
        self.firstRecordByType = firstRecordByType
        self.completedByEntry = completedByEntry
    }
}

/// 시간표 + 그날의 정박점 → 하루의 칸.
/// **순수 함수만** — Date() 도, 저장소도 만지지 않는다.
enum DayPlanExpander {

    struct Slot: Identifiable, Hashable {
        let id: String
        let entryId: String
        let title: String
        let activityType: String?
        let lane: DayPlan.Lane
        /// nil = 아직 정박 안 됨(첫 기록이나 앞 일을 기다리는 중).
        let plannedAt: Date?
        let order: Int
    }

    static func slots(
        plan: DayPlan,
        day: Date,
        anchors: DayAnchors,
        calendar: Calendar = .current
    ) -> [Slot] {
        guard plan.isActive else { return [] }

        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        var out: [Slot] = []
        for entry in plan.entries {
            out.append(contentsOf: expand(entry, start: start, end: end, anchors: anchors, calendar: calendar))
        }

        // 미정(nil)은 맨 앞 — 하루가 거기서 시작하기를 기다리는 자리다.
        return out.sorted { a, b in
            let ta = a.plannedAt ?? .distantPast
            let tb = b.plannedAt ?? .distantPast
            if ta != tb { return ta < tb }
            if a.order != b.order { return a.order < b.order }
            return a.id < b.id
        }
    }

    private static func expand(
        _ entry: DayPlan.Entry,
        start: Date,
        end: Date,
        anchors: DayAnchors,
        calendar: Calendar
    ) -> [Slot] {
        switch entry.schedule.kind {

        case .fixedTimes:
            let minutes = entry.schedule.minutesOfDay ?? []
            return minutes.enumerated().compactMap { idx, m in
                guard let at = calendar.date(byAdding: .minute, value: m, to: start), at < end else { return nil }
                return slot(entry, index: idx, at: at)
            }

        case .afterFirst:
            let count = max(0, entry.schedule.count ?? 0)
            let every = max(1, entry.schedule.everyMinutes ?? 0)
            guard let type = entry.schedule.anchorType,
                  let anchor = anchors.firstRecordByType[type] else {
                // 정박 전 — 자리는 있고 시각만 미정이다.
                return (0..<count).map { slot(entry, index: $0, at: nil) }
            }
            return (0..<count).compactMap { i in
                guard let at = calendar.date(byAdding: .minute, value: every * i, to: anchor), at < end else { return nil }
                return slot(entry, index: i, at: at)
            }

        case .afterEntry:
            guard let afterId = entry.schedule.afterEntryId,
                  let done = anchors.completedByEntry[afterId],
                  let at = calendar.date(byAdding: .minute, value: entry.schedule.offsetMinutes ?? 0, to: done),
                  at < end else {
                return [slot(entry, index: 0, at: nil)]
            }
            return [slot(entry, index: 0, at: at)]

        case .unknown:
            // 신버전이 추가한 미지의 종류(forward-compat 센티넬, Task 1) — 언제인지 알 수 없다.
            // 시각을 지어내면 부모의 하루에 잘못된 칸이 생긴다 — 조용히 0칸으로 둔다.
            // entry 단위 독립 처리라 이 항목만 비고, 같은 plan 의 형제 entry 는 그대로 펼쳐진다.
            return []
        }
    }

    private static func slot(_ entry: DayPlan.Entry, index: Int, at: Date?) -> Slot {
        Slot(
            id: "\(entry.id)#\(index)",
            entryId: entry.id,
            title: entry.title,
            activityType: entry.activityType,
            lane: entry.lane,
            plannedAt: at,
            order: entry.order
        )
    }
}
