import Foundation

/// 홈이 어느 날을 보이나 · 칸 이름. 줄은 일정표(Itinerary.Day.homeLines)가 낸다. 순수 함수.
enum TravelHomeSchedule {
    /// 보일 날 — 출발 전이면 첫날 · 여행 중이면 오늘 · 다녀온 뒤면 nil(칸을 숨긴다).
    static func focusDay(days: [Date], today: Date, calendar: Calendar) -> Date? {
        guard let first = days.first, let last = days.last else { return nil }
        let day = calendar.startOfDay(for: today)
        if day < first { return first }
        if day <= last { return days.first { calendar.isDate($0, inSameDayAs: day) } ?? day }
        return nil
    }

    /// 「다음 일정 · 1일차 5.10(월)」 · 오늘이면 「오늘 일정 · 3일차 5.12(수)」.
    static func title(day: Date, days: [Date], today: Date, calendar: Calendar) -> String {
        let label = calendar.isDate(day, inSameDayAs: today) ? "오늘 일정" : "다음 일정"
        let number = days.firstIndex { calendar.isDate($0, inSameDayAs: day) }.map { "\($0 + 1)일차 " } ?? ""
        return "\(label) · \(number)\(TripDateText.day(day, calendar: calendar))"
    }

    /// 홈 할 일 칸 이름 — 출발 전 「출발 전 할 일」 · 출발일부터 「남은 할 일」.
    static func taskTitle(days: [Date], today: Date, calendar: Calendar) -> String {
        guard let first = days.first, calendar.startOfDay(for: today) >= first else { return "출발 전 할 일" }
        return "남은 할 일"
    }

    /// 홈 항공편 칸(시안 Home-Flight) — 오늘 떠나는 편만. 없으면 nil.
    static func todayFlight(in trip: Trip, today: Date, calendar: Calendar) -> TripBooking? {
        let key = Trip.dayKey(today, calendar: calendar)
        return trip.bookings
            .filter { $0.kind == .flight && ($0.depart ?? $0.arrive)?.dayKey(calendar) == key }
            .min { $0.flightOrder(calendar) < $1.flightOrder(calendar) }
    }
}
