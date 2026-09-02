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

    /// `afterFirst` 의 count 방어적 상한 — 간격이 최소 1분이라도 하루(1440분)엔 이 이상 못 들어간다.
    /// 손상되거나 비정상적으로 큰 count 가 메인 스레드를 얼리는 것을 막는다(리뷰 F3).
    private static let maxOccurrencesPerDay = 1440

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
                // 하루 경계는 양쪽 다 잰다 — 음수(자정 이전으로 새는) minutesOfDay 도 버린다(리뷰 F2).
                guard let at = calendar.date(byAdding: .minute, value: m, to: start),
                      start <= at, at < end else { return nil }
                return slot(entry, index: idx, at: at)
            }

        case .afterFirst:
            // count 는 방어적 상한(리뷰 F3), every 는 최소 1분(0 이하면 제자리서 무한 반복할 수 있다).
            let count = min(max(0, entry.schedule.count ?? 0), maxOccurrencesPerDay)
            let every = max(1, entry.schedule.everyMinutes ?? 0)
            guard let type = entry.schedule.anchorType,
                  let anchor = anchors.firstRecordByType[type] else {
                // 정박 전 — 자리는 있고 시각만 미정이다.
                return (0..<count).map { slot(entry, index: $0, at: nil) }
            }
            // every*i 곱셈(everyMinutes 가 크면 Int 오버플로우로 trap) 대신
            // Calendar 로 한 칸씩 전진한다(리뷰 F3). every>=1 이라 매 칸은 앞으로만 가므로,
            // end 를 넘는 순간 이후 칸도 전부 넘는다 — 거기서 멈춘다(하루 경계는 양쪽 다, 리뷰 F2).
            var out: [Slot] = []
            var at = anchor
            for i in 0..<count {
                guard at < end else { break }
                if at >= start {
                    out.append(slot(entry, index: i, at: at))
                }
                guard let next = calendar.date(byAdding: .minute, value: every, to: at) else { break }
                at = next
            }
            return out

        case .afterEntry:
            guard let afterId = entry.schedule.afterEntryId,
                  let done = anchors.completedByEntry[afterId] else {
                // 앞 항목이 아직 안 끝났다 — 자리는 있고 시각만 미정이다.
                return [slot(entry, index: 0, at: nil)]
            }
            // 앞 항목은 끝났다 — 계산된 시각이 오늘(반열린 구간, 양쪽 다) 안일 때만 칸이 된다.
            // 밖이면 "미정"이 아니라 "오늘 것이 아님" — 자리 자체가 없다, afterFirst 가 end 넘는
            // 칸을 버리는 것과 같은 취급이다(리뷰 F1).
            guard let at = calendar.date(byAdding: .minute, value: entry.schedule.offsetMinutes ?? 0, to: done),
                  start <= at, at < end else {
                return []
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
