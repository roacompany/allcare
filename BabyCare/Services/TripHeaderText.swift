import Foundation

/// 여행 머리 문구 — 홈 · 일정 · 예약 · 준비 · 베이비케어 홈 카드가 같이 쓴다. 순수 함수.
enum TripHeaderText {
    /// 「5.10(월)–5.14(금)」.
    static func dates(_ trip: Trip, calendar: Calendar) -> String {
        guard let s = Trip.date(fromDayKey: trip.startDay, calendar: calendar),
              let e = Trip.date(fromDayKey: trip.endDay, calendar: calendar) else { return "" }
        return "\(TripDateText.day(s, calendar: calendar))–\(TripDateText.day(e, calendar: calendar))"
    }

    /// 「출발까지 5일」 · 「여행 2일째」 · 「다녀왔어요」.
    static func status(_ trip: Trip, today: Date, calendar: Calendar) -> String {
        guard let s = Trip.date(fromDayKey: trip.startDay, calendar: calendar),
              let e = Trip.date(fromDayKey: trip.endDay, calendar: calendar) else { return "" }
        let day = calendar.startOfDay(for: today)
        if day < s {
            let n = calendar.dateComponents([.day], from: day, to: s).day ?? 0
            return "출발까지 \(n)일"
        }
        if day <= e {
            let n = (calendar.dateComponents([.day], from: s, to: day).day ?? 0) + 1
            return "여행 \(n)일째"
        }
        return "다녀왔어요"
    }

    /// 홈 머리 칩(시안 Main 「D-21」) — 출발 전 「D-n」 · 출발일 「오늘 출발」 · 여행 중 「여행 n일째」 · 다녀온 뒤 「다녀왔어요」.
    static func badge(_ trip: Trip, today: Date, calendar: Calendar) -> String {
        guard let s = Trip.date(fromDayKey: trip.startDay, calendar: calendar) else { return "" }
        let day = calendar.startOfDay(for: today)
        if day < s {
            let n = calendar.dateComponents([.day], from: day, to: s).day ?? 0
            return "D-\(n)"
        }
        if day == s { return "오늘 출발" }
        return status(trip, today: today, calendar: calendar)
    }

    /// 홈 머리 둘째 줄(시안 Main) — 「5.10(월)–5.14(금) · 4박 5일」.
    static func homeDates(_ trip: Trip, calendar: Calendar) -> String {
        guard let s = Trip.date(fromDayKey: trip.startDay, calendar: calendar),
              let e = Trip.date(fromDayKey: trip.endDay, calendar: calendar) else { return "" }
        return "\(dates(trip, calendar: calendar)) · \(TripDateRangeText.nightsDays(start: s, end: e, calendar: calendar))"
    }

    /// 일정 · 예약 · 준비 머리 아래 줄(시안) — 「오사카·교토 · 5.10(월)–5.14(금)」.
    static func subtitle(_ trip: Trip, calendar: Calendar) -> String {
        let span = dates(trip, calendar: calendar)
        return span.isEmpty ? trip.city : "\(trip.city) · \(span)"
    }
}
