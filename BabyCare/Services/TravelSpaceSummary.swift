import Foundation

/// 성장 기록 하나의 값과 잰 날 — 아이 칸이 「키 70.5cm, 10.3 측정」으로 보여 준다.
struct TripGrowthReading: Hashable, Sendable {
    let value: Double
    let measuredOn: Date
}

/// 여행 공간 홈 — 다음 할 일 · 이번 주 할 일 · 남은 수(설계 2026-11-05 §2 홈). 순수 함수.
struct TravelHomeSummary: Hashable, Sendable {
    let next: TripTask?
    let week: [TripTask]
    let openCount: Int
    /// 홈 할 일 줄(시안 Main 「출발 전 할 일」) — 다음 할 일 → 이번 주 → 남은 일(준비 칸과 같은 화면 순서), 앞 3개.
    /// 출발 3주 전처럼 이번 주 일이 없어도 3개를 채운다(시안은 두세 줄을 보인다).
    let homeRows: [TripTask]

    nonisolated static let weekLimit = 3
    nonisolated static let weekDays = 7

    /// tasks 는 화면 순서(TripTaskOrdering.ordered) 그대로 받는다.
    /// 다음 할 일 = 안 끝난 일 중 오늘 이후 마감이 가장 가까운 것 · 그런 마감이 없으면 순서 첫째.
    /// 이번 주 = 다음 할 일을 뺀 안 끝난 일 중 권장일이나 마감이 7일 안인 것 · 3개까지.
    static func build(tasks: [TripTask], states: [TripTaskState], today: Date, calendar: Calendar) -> TravelHomeSummary {
        let done = Set(states.filter(\.isDone).map(\.taskId))
        let open = tasks.filter { !done.contains($0.id) }
        let start = calendar.startOfDay(for: today)
        let limit = calendar.date(byAdding: .day, value: weekDays, to: start) ?? start

        func upcoming(_ task: TripTask) -> Date? {
            task.deadlines.map(\.at).filter { $0 >= start }.min()
        }
        let next = open
            .compactMap { task in upcoming(task).map { (task, $0) } }
            .min { $0.1 < $1.1 }?.0 ?? open.first

        let week = open.filter { task in
            guard task.id != next?.id else { return false }
            if task.recommendedOn < limit { return true }
            return task.deadlines.contains { $0.at >= start && $0.at < limit }
        }
        let weekRows = Array(week.prefix(weekLimit))
        var home: [TripTask] = []
        for task in [next].compactMap({ $0 }) + weekRows + open where !home.contains(where: { $0.id == task.id }) {
            home.append(task)
        }
        return TravelHomeSummary(next: next, week: weekRows, openCount: open.count, homeRows: Array(home.prefix(homeLimit)))
    }

    nonisolated static let homeLimit = 3
}

/// 담당별로 나눈 모습 — 안 끝난 일만 센다 · 정하지 않았거나 모르는 담당은 「담당 없음」.
enum TravelAssigneeSplit {
    static func counts(tasks: [TripTask], states: [TripTaskState]) -> [TripAssignee: Int] {
        var result: [TripAssignee: Int] = [:]
        for task in open(tasks, states) {
            result[bucket(states, task.id), default: 0] += 1
        }
        return result
    }

    static func unassignedOpen(tasks: [TripTask], states: [TripTaskState]) -> [TripTask] {
        open(tasks, states).filter { bucket(states, $0.id) == .unassigned }
    }

    /// mother · father · both · unassigned 넷 중 하나.
    static func bucket(_ states: [TripTaskState], _ taskId: String) -> TripAssignee {
        switch states.first(where: { $0.taskId == taskId })?.assignee {
        case .mother: return .mother
        case .father: return .father
        case .both: return .both
        case .unassigned, .unknown, nil: return .unassigned
        }
    }

    private static func open(_ tasks: [TripTask], _ states: [TripTaskState]) -> [TripTask] {
        let done = Set(states.filter(\.isDone).map(\.taskId))
        return tasks.filter { !done.contains($0.id) }
    }
}

/// 할 일 칸 담당으로 거르기 — 끝난 일도 담당대로 남긴다.
enum TripAssigneeFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all, mother, father, both, unassigned

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: return "전체"
        case .mother: return "엄마"
        case .father: return "아빠"
        case .both: return "함께"
        case .unassigned: return "담당 없음"
        }
    }

    func apply(_ tasks: [TripTask], states: [TripTaskState]) -> [TripTask] {
        let wanted: TripAssignee
        switch self {
        case .all: return tasks
        case .mother: wanted = .mother
        case .father: wanted = .father
        case .both: wanted = .both
        case .unassigned: wanted = .unassigned
        }
        return tasks.filter { TravelAssigneeSplit.bucket(states, $0.id) == wanted }
    }
}

/// 아이 칸 · 홈 아이 요약의 문구 — 시각은 「하루 중 몇 분째」를 받는다. 순수 함수.
enum TravelChildText {
    nonisolated static let windowDays = 7

    /// 그날까지 꽉 채운 달 수.
    static func months(at date: Date, birthDate: Date, calendar: Calendar) -> Int {
        max(0, calendar.dateComponents([.month], from: calendar.startOfDay(for: birthDate), to: calendar.startOfDay(for: date)).month ?? 0)
    }

    static func clock(_ minuteOfDay: Int) -> String {
        let m = ((minuteOfDay % 1440) + 1440) % 1440
        return String(format: "%02d:%02d", m / 60, m % 60)
    }

    static func naps(_ blocks: [BabyRhythm.Block]) -> String? {
        guard !blocks.isEmpty else { return nil }
        return blocks.map { "\(clock($0.startMinute))부터 \($0.minutes)분" }.joined(separator: ", ")
    }

    static func sleep(bedtime: Int?, wake: Int?) -> String? {
        switch (bedtime, wake) {
        case let (b?, w?): return "\(clock(b))에 자고 \(clock(w))에 깨요"
        case let (b?, nil): return "\(clock(b))에 자요"
        case let (nil, w?): return "\(clock(w))에 깨요"
        case (nil, nil): return nil
        }
    }

    static func feedInterval(_ minutes: Int?) -> String? {
        guard let minutes, minutes > 0 else { return nil }
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "낮 수유 약 \(m)분마다"
        case (_, 0): return "낮 수유 약 \(h)시간마다"
        default: return "낮 수유 약 \(h)시간 \(m)분마다"
        }
    }

    static func coverage(daysWithRecords: Int) -> String {
        if daysWithRecords <= 0 { return "최근 \(windowDays)일 기록이 없어요" }
        if daysWithRecords >= windowDays { return "\(windowDays)일 모두 기록이 있어요" }
        return "\(windowDays)일 중 \(daysWithRecords)일 기록이 있어요"
    }
}
