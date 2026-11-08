import Foundation

/// 할 일 한 묶음 — 시안 「여행: 할 일」의 「이번 주 10.19–10.25」.
struct TripTaskGroup: Equatable, Sendable {
    let title: String
    let range: String
    let tasks: [TripTask]
}

/// 할 일을 주(월요일 시작)로 묶는다 — 순수 함수.
/// 이번 주 · 다음 주 · 출발 전 주(출발 바로 앞 주) · 여행 중(출발 주부터) · 그 사이는 「N주 뒤」.
/// 권장일이 지난 일은 이번 주에 넣는다(늦은 일이 아래로 숨지 않게) · 묶음 안 순서는 받은 순서 그대로.
enum TripTaskWeekGroups {
    static func build(tasks: [TripTask], today: Date, tripStart: Date, calendar: Calendar) -> [TripTaskGroup] {
        var cal = calendar
        cal.firstWeekday = 2
        func weekStart(_ d: Date) -> Date {
            cal.dateInterval(of: .weekOfYear, for: d)?.start ?? cal.startOfDay(for: d)
        }
        let thisWeek = weekStart(today)
        let departureWeek = weekStart(tripStart)
        let beforeDeparture = cal.date(byAdding: .day, value: -7, to: departureWeek) ?? departureWeek

        var order: [Date] = []
        var buckets: [Date: [TripTask]] = [:]
        for task in tasks {
            let key = max(weekStart(task.recommendedOn), thisWeek)
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(task)
        }
        return order.sorted().map { start in
            let offset = cal.dateComponents([.day], from: thisWeek, to: start).day.map { $0 / 7 } ?? 0
            let title: String
            if offset == 0 {
                title = "이번 주"
            } else if offset == 1 {
                title = "다음 주"
            } else if start >= departureWeek {
                title = "여행 중"
            } else if start == beforeDeparture {
                title = "출발 전 주"
            } else {
                title = "\(offset)주 뒤"
            }
            let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
            return TripTaskGroup(title: title, range: "\(md(start, cal))–\(md(end, cal))", tasks: buckets[start] ?? [])
        }
    }

    private static func md(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.month, .day], from: date)
        return "\(c.month ?? 0).\(c.day ?? 0)"
    }
}

/// 담당 칩 글자 — 시안: 담당이 없으면 빨간 「담당 없음」.
enum TravelAssigneeChipText {
    static func isMissing(_ assignee: TripAssignee?) -> Bool {
        switch assignee {
        case .mother?, .father?, .both?: return false
        case .unassigned?, .unknown?, nil: return true
        }
    }

    static func text(_ assignee: TripAssignee?) -> String {
        isMissing(assignee) ? "담당 없음" : (assignee?.label ?? "담당 없음")
    }
}
