import Foundation

// MARK: - 여행 수정·만들기 — 여행 일정 앱처럼(PO 2026-11-06 「여행일정 앱처럼... 제발....」) · 순수 판정

/// 여행 기간 고르기 — 달력에서 시작·끝을 차례로 누른다.
/// 첫 탭 = 시작(끝 비움) · 둘째 탭 = 끝(시작보다 앞이면 새 시작) · 셋째 탭 = 다시 시작.
struct TripDateRangeSelection: Equatable, Sendable {
    var start: Date?
    var end: Date?

    /// 달력 칸 하나가 기간에서 맡은 자리 — 그리기용.
    enum Role: Equatable, Sendable {
        case none
        /// 시작만 골랐거나 당일 여행 — 동그라미 하나(띠 없음).
        case single
        case start
        case inside
        case end
    }

    init(start: Date? = nil, end: Date? = nil) {
        self.start = start
        self.end = end
    }

    var isComplete: Bool { start != nil && end != nil }

    mutating func tap(_ date: Date, calendar: Calendar) {
        let day = calendar.startOfDay(for: date)
        if let start, end == nil, day >= start {
            end = day
        } else {
            start = day
            end = nil
        }
    }

    func role(of date: Date, calendar: Calendar) -> Role {
        let day = calendar.startOfDay(for: date)
        guard let start else { return .none }
        guard let end, end != start else { return day == start ? .single : .none }
        if day == start { return .start }
        if day == end { return .end }
        return day > start && day < end ? .inside : .none
    }
}

/// 기간 글자 — 「5.10(월) – 5.14(금)」 · 「4박 5일」 · 하루면 「당일」.
enum TripDateRangeText {
    static func span(start: Date, end: Date, calendar: Calendar) -> String {
        "\(TripDateText.day(start, calendar: calendar)) – \(TripDateText.day(end, calendar: calendar))"
    }

    static func nightsDays(start: Date, end: Date, calendar: Calendar) -> String {
        let nights = calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: end)).day ?? 0
        return nights <= 0 ? "당일" : "\(nights)박 \(nights + 1)일"
    }
}

/// 여행지 — 저장은 「·」로 이은 글자 그대로(Trip.city · 예: 「오사카·교토」). 화면은 도시 칩.
enum TripCityList {
    static let separator = "·"

    /// 자주 가는 일본 도시 — 「+ 도시 추가」 아래 칩.
    static let common = ["오사카", "교토", "도쿄", "후쿠오카", "삿포로", "오키나와", "나고야", "고베", "나라", "요코하마"]

    static func split(_ city: String) -> [String] {
        let parts = city.split(whereSeparator: { "·,/、".contains($0) }).map { String($0) }
        return clean(parts)
    }

    static func join(_ cities: [String]) -> String {
        clean(cities).joined(separator: separator)
    }

    static func adding(_ name: String, to cities: [String]) -> [String] {
        clean(cities + [name])
    }

    static func suggestions(excluding chosen: [String]) -> [String] {
        let taken = Set(clean(chosen))
        return common.filter { !taken.contains($0) }
    }

    /// 앞뒤 공백 · 빈칸 · 중복(먼저 나온 것만) 빼기.
    private static func clean(_ names: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for name in names {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }
}

/// 달력 한 달 — 일요일 시작 · 1일 앞은 빈칸(nil).
enum TripMonthGrid {
    static func monthStart(_ date: Date, calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: parts) ?? calendar.startOfDay(for: date)
    }

    static func cells(month: Date, calendar: Calendar) -> [Date?] {
        let first = monthStart(month, calendar: calendar)
        guard let days = calendar.range(of: .day, in: .month, for: first)?.count else { return [] }
        // weekday 1 = 일요일 — 기기 설정(첫 요일)과 상관없이 일요일 시작.
        let leading = calendar.component(.weekday, from: first) - 1
        let dates: [Date?] = (0..<days).map { calendar.date(byAdding: .day, value: $0, to: first) }
        return Array(repeating: nil, count: max(0, leading)) + dates
    }

    static func shift(_ month: Date, by months: Int, calendar: Calendar) -> Date {
        calendar.date(byAdding: .month, value: months, to: monthStart(month, calendar: calendar)) ?? month
    }

    static func title(_ month: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month], from: month)
        return "\(parts.year ?? 0)년 \(parts.month ?? 0)월"
    }
}

enum TripEditForm {
    /// 저장(만들기) 가능 — 도시 하나 이상 + 시작·끝 모두.
    static func canSave(cities: [String], selection: TripDateRangeSelection) -> Bool {
        guard !cities.isEmpty, let start = selection.start, let end = selection.end else { return false }
        return end >= start
    }
}
