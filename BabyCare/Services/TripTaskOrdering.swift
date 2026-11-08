import Foundation

/// 할 일의 순서와 표시 — PO 11/4 결정: 목록 순서 = 권장일 · D-day 와 빨강은 마감에만 · 빨강은 마감 3일 전부터.
enum TripTaskOrdering {
    /// 빨강을 켜는 날 수 — 마감 3일 전부터(지난 마감 포함).
    nonisolated static let urgentDays = 3

    /// 안 끝난 일 먼저: 권장일 → 가장 이른 마감(없으면 뒤) → 제목. 끝난 일은 뒤로(같은 규칙).
    static func ordered(_ tasks: [TripTask], states: [TripTaskState]) -> [TripTask] {
        let done = Set(states.filter(\.isDone).map(\.taskId))
        return tasks.sorted { a, b in
            let aDone = done.contains(a.id), bDone = done.contains(b.id)
            if aDone != bDone { return !aDone }
            if a.recommendedOn != b.recommendedOn { return a.recommendedOn < b.recommendedOn }
            switch (a.earliestDeadline, b.earliestDeadline) {
            case let (x?, y?) where x != y: return x < y
            case (.some, .none): return true
            case (.none, .some): return false
            default: return a.title < b.title
            }
        }
    }

    /// 달력 날짜로 센 남은 날 — 오늘이 마감일이면 0, 지났으면 음수.
    static func dDay(to deadline: Date, now: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: deadline)).day ?? 0
    }

    static func isUrgent(_ deadline: Date, now: Date, calendar: Calendar) -> Bool {
        dDay(to: deadline, now: now, calendar: calendar) <= urgentDays
    }
}

/// 여행 화면의 날짜 문구 — 「5.8(토) 15:10」 꼴.
enum TripDateText {
    static func dayTime(_ date: Date, calendar: Calendar) -> String {
        "\(day(date, calendar: calendar)) \(formatter("HH:mm", calendar).string(from: date))"
    }

    static func day(_ date: Date, calendar: Calendar) -> String {
        formatter("M.d(E)", calendar).string(from: date)
    }

    static func time(_ date: Date, calendar: Calendar) -> String {
        formatter("HH:mm", calendar).string(from: date)
    }

    static func recommended(_ date: Date, calendar: Calendar) -> String {
        "\(day(date, calendar: calendar))쯤 하면 좋아요"
    }

    static func dDayText(_ days: Int) -> String {
        if days < 0 { return "지남" }
        if days == 0 { return "D-day" }
        return "D-\(days)"
    }

    private static func formatter(_ format: String, _ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = calendar.timeZone
        f.dateFormat = format
        return f
    }
}
