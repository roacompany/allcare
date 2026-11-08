import Foundation

/// 운항 정보를 물을 한 편 — 어느 예약의 어느 편을 어느 목록(출발/도착)에서.
struct TripFlightQuery: Hashable, Sendable {
    let bookingId: String
    let flightId: String
    let direction: FlightDirection
    /// 그 편의 날(공항 기준 0시).
    let day: Date
}

struct TripFlightPlan: Equatable, Sendable {
    /// 오늘 물어볼 편.
    var ask: [TripFlightQuery]
    /// 아직 그날이 아닌 편 — 「그날 보여요」.
    var later: [TripFlightQuery]
}

/// 무엇을 언제 묻나 — 순수 함수.
/// 인천공항 정보는 **인천을 오가는 편**만 · **당일치**만 준다(2026-11-05 실측 · 파킹24 와 같은 API).
/// 인천에서 뜨면 출발 목록에서, 인천에 내리면 도착 목록에서 그날에 묻는다.
enum TripFlightStatusPlanner {
    static let incheon = "ICN"

    static func plan(trip: Trip, today: Date, calendar: Calendar) -> TripFlightPlan {
        let todayStart = calendar.startOfDay(for: today)
        let flights = trip.bookings.filter { $0.kind == .flight }
            .sorted { $0.flightOrder(calendar) < $1.flightOrder(calendar) }
        var plan = TripFlightPlan(ask: [], later: [])
        for f in flights {
            guard let id = FlightNumber.normalize(f.flightNumber ?? "") else { continue }
            let direction: FlightDirection
            let when: TripWhen?
            if f.fromAirport?.uppercased() == incheon {
                direction = .departure
                when = f.depart ?? f.arrive
            } else if f.toAirport?.uppercased() == incheon {
                direction = .arrival
                when = f.arrive ?? f.depart
            } else {
                continue
            }
            guard let day = when?.startOfDay(calendar) else { continue }
            let query = TripFlightQuery(bookingId: f.id, flightId: id, direction: direction, day: day)
            if day == todayStart {
                plan.ask.append(query)
            } else if day > todayStart {
                plan.later.append(query)
            }
        }
        return plan
    }

    /// 인천을 오가는 편인가 — 아니면 운항 정보를 못 본다고 말한다.
    static func isIncheon(_ booking: TripBooking) -> Bool {
        booking.fromAirport?.uppercased() == incheon || booking.toAirport?.uppercased() == incheon
    }
}
