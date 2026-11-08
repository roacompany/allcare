import Foundation

/// 일시 — 날짜와, 알면 시각(GLOSSARY). 시각을 모르면 Date 가 없어서 00:00 으로 읽힐 길이 없다(ADR-0001).
/// 🔴 Comparable 을 주지 않는다 — 날짜만 있는 값은 몇 시와도 앞뒤를 못 잰다. 줄 순서는 일정표(Itinerary)가 정한다.
enum TripWhen: Hashable, Sendable {
    /// 시각까지 안다.
    case at(Date)
    /// 날짜만 안다("yyyy-MM-dd" · 그 나라 달력의 날짜) — 시각 미정.
    case day(String)

    /// 저장 칸 둘에서 읽는다 — 시각이 있으면 시각을 믿고, 날짜 글자가 깨졌으면 없는 것으로 친다(여행 문서가 통째로 버려지면 안 된다).
    init?(at time: Date?, day: String?) {
        if let time {
            self = .at(time)
        } else if let day, Trip.isDayKey(day) {
            self = .day(day)
        } else {
            return nil
        }
    }

    /// 시각. 시각 미정이면 nil.
    var time: Date? {
        if case .at(let date) = self { return date }
        return nil
    }

    /// 시각 미정일 때의 날짜 글자(저장용).
    var dayOnlyKey: String? {
        if case .day(let key) = self { return key }
        return nil
    }

    func dayKey(_ calendar: Calendar) -> String {
        switch self {
        case .at(let date): return Trip.dayKey(date, calendar: calendar)
        case .day(let key): return key
        }
    }

    /// 목록을 날짜 → 시각 순으로 세우는 글자(같은 날이면 시각 미정이 뒤). 일정표 줄 순서는 Itinerary 가 정한다.
    func sortKey(_ calendar: Calendar) -> String {
        dayKey(calendar) + (time.map { String(format: "%012.0f", $0.timeIntervalSince1970) } ?? "~")
    }

    /// 그날 0시.
    func startOfDay(_ calendar: Calendar) -> Date? {
        Trip.date(fromDayKey: dayKey(calendar), calendar: calendar)
    }

    /// n일 앞 — 아는 만큼만 안다(날짜만이면 날짜만).
    func daysBefore(_ days: Int, calendar: Calendar) -> TripWhen? {
        switch self {
        case .at(let date):
            return calendar.date(byAdding: .day, value: -days, to: date).map(TripWhen.at)
        case .day:
            return startOfDay(calendar).flatMap { calendar.date(byAdding: .day, value: -days, to: $0) }
                .map { .day(Trip.dayKey($0, calendar: calendar)) }
        }
    }

    /// 다른 날로 옮긴다 — 시각이 있으면 시각을 지킨다.
    func movedTo(_ day: Date, calendar: Calendar) -> TripWhen {
        if let time { return .at(TripEntryChoices.combine(day: day, time: time, calendar: calendar)) }
        return .day(Trip.dayKey(day, calendar: calendar))
    }
}

extension Optional where Wrapped == TripWhen {
    /// 일시가 없는 예약은 맨 뒤.
    func sortKey(_ calendar: Calendar) -> String {
        self?.sortKey(calendar) ?? "~"
    }
}

extension TripDateText {
    /// 「5.14(금) 10:00」 · 시각 미정이면 「5.14(금)」.
    static func when(_ when: TripWhen, calendar: Calendar) -> String {
        if let time = when.time { return dayTime(time, calendar: calendar) }
        return day(when, calendar: calendar)
    }

    /// 「5.14(금)」.
    static func day(_ when: TripWhen, calendar: Calendar) -> String {
        when.startOfDay(calendar).map { day($0, calendar: calendar) } ?? ""
    }
}
