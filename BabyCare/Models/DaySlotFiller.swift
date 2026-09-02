import Foundation

/// 하루 띠의 한 칸.
struct DayCell: Identifiable, Hashable {
    enum Kind: Hashable {
        /// 짜 뒀고 아직 안 왔다 — **세지 않는다. 빨갛게 하지 않는다.**
        case planned
        /// 짜 뒀고 기록이 왔다.
        case done
        /// 짜 두지 않았는데 왔다 — 칸이 하나 늘어난 것(시안 「끼어든 칸」).
        case extra
    }

    var id: String
    /// 계획된 칸이면 그 칸의 id, 끼어든 칸이면 nil.
    var slotId: String?
    var title: String
    var activityType: String?
    var lane: DayPlan.Lane
    var kind: Kind
    /// 채워졌으면 **기록의 실제 시각**, 아니면 계획된 시각. 정박 전이면 nil.
    var at: Date?
    var order: Int
}

/// 칸 + 그날 기록 → 하루 띠.
/// **순수 함수만** — `Date()` 도, 저장소도 만지지 않는다.
///
/// 규칙(설계 §3.3 의 미결을 여기서 정했다):
/// - 같은 종류끼리 **가까운 짝부터 1:1**로 붙인다. **거리 문턱은 없다** — 지어낸 숫자가 되기 때문이다.
/// - 짝 없는 기록 = 끼어든 칸 · 짝 없는 칸 = 빈 칸(그냥 남는다).
/// - 채워진 칸은 **기록의 실제 시각**으로 보인다 — 밑그림을 실제가 덮어쓴다(결정 5).
enum DaySlotFiller {

    static func fill(
        slots: [DayPlanExpander.Slot],
        activities: [Activity],
        on day: Date,
        calendar: Calendar = .current
    ) -> [DayCell] {
        // 🔴 하루 목록에는 「어제 시작해 오늘 끝난 것」이 섞여 있다 — 오늘 시작한 것만 센다.
        let todays = ActivityDayAttribution.startedOn(activities, day: day, calendar: calendar)
            .filter { $0.type != .unknown }

        // 가까운 쌍부터 확정한다(그리디). 입력 순서가 답을 바꾸지 않도록 결정적으로 정렬한다.
        struct Pair { let slotIndex: Int; let actIndex: Int; let distance: TimeInterval }
        var pairs: [Pair] = []
        for (si, s) in slots.enumerated() {
            guard let type = s.activityType else { continue }   // 기록 종류 없는 항목은 안 채워진다
            for (ai, a) in todays.enumerated() where a.type.rawValue == type {
                // 정박 전(plannedAt=nil) 칸은 **최후 순위**다 —
                // 어떤 예정 칸도 원하지 않는 기록만 가져간다. 0 으로 두면 시각이 잘 맞는
                // 예정 칸이 미정 칸에 굶는다(Task 3 리뷰 Important).
                let d = s.plannedAt.map { abs($0.timeIntervalSince(a.startTime)) } ?? .greatestFiniteMagnitude
                pairs.append(Pair(slotIndex: si, actIndex: ai, distance: d))
            }
        }
        pairs.sort {
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            if $0.slotIndex != $1.slotIndex { return $0.slotIndex < $1.slotIndex }
            return $0.actIndex < $1.actIndex
        }

        var slotToAct: [Int: Int] = [:]
        var usedActs = Set<Int>()
        for p in pairs where slotToAct[p.slotIndex] == nil && !usedActs.contains(p.actIndex) {
            slotToAct[p.slotIndex] = p.actIndex
            usedActs.insert(p.actIndex)
        }

        var cells: [DayCell] = slots.enumerated().map { si, s in
            if let ai = slotToAct[si] {
                return DayCell(id: s.id, slotId: s.id, title: s.title, activityType: s.activityType,
                               lane: s.lane, kind: .done, at: todays[ai].startTime, order: s.order)
            }
            return DayCell(id: s.id, slotId: s.id, title: s.title, activityType: s.activityType,
                           lane: s.lane, kind: .planned, at: s.plannedAt, order: s.order)
        }

        // 짝을 못 찾은 기록 = 끼어든 칸. order 는 계획 칸보다 뒤에 둬서 동시각 정렬을 안정시킨다.
        for (ai, a) in todays.enumerated() where !usedActs.contains(ai) {
            cells.append(DayCell(id: "extra-\(a.id)", slotId: nil, title: a.type.displayName,
                                 activityType: a.type.rawValue, lane: .baby, kind: .extra,
                                 at: a.startTime, order: Int.max))
        }

        // 미정(nil)은 맨 앞 — 하루가 거기서 시작하기를 기다리는 자리다(①단계 Expander 와 같은 규칙).
        return cells.sorted { l, r in
            let lt = l.at ?? .distantPast
            let rt = r.at ?? .distantPast
            if lt != rt { return lt < rt }
            if l.order != r.order { return l.order < r.order }
            return l.id < r.id
        }
    }
}
