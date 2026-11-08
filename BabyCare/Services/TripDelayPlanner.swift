import Foundation

/// 늦어진 편이 그날 뒤 일정에 닿는 것 하나(시안 Home-Flight 「늦어진 시간으로 다시 봤어요」).
struct TripDelayImpact: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case rentalPickup
        case hotelArrival
        case bedtime
    }

    let kind: Kind
    let title: String
    let detail: String
}

struct TripDelayOutlook: Equatable, Sendable {
    /// 예약한 도착 + 늦어진 시간. 모르면 nil.
    let arrival: Date?
    let impacts: [TripDelayImpact]
}

/// 늦어진 시각을 일정표와 같은 계산에 넣어 본다. 순수 함수.
/// ⛔ 모르는 시간은 지어내지 않는다 — 입국·짐 찾기에 걸리는 시간은 모르므로 숙소 도착은 「빨라야」로만 말한다.
enum TripDelayPlanner {
    static func outlook(trip: Trip, flight: TripBooking, status: FlightLiveStatus, routes: [TripRouteKey: TripRouteAnswer],
                        bedtimeMinute: Int?, calendar: Calendar) -> TripDelayOutlook {
        let shift = status.delayMinutes ?? 0
        let arrival = flight.arrive?.time.map { $0.addingTimeInterval(TimeInterval(shift * 60)) }
        guard status.direction == .departure, status.isDelayed, shift >= FlightLiveStatus.delayThresholdMinutes,
              let arrival, let booked = flight.arrive?.time else {
            return TripDelayOutlook(arrival: arrival, impacts: [])
        }
        let walker = ItineraryWalker(trip: trip, rhythm: nil, routes: routes, calendar: calendar, delays: [flight.id: shift])
        let lines = walker.travel(on: Trip.dayKey(booked, calendar: calendar)).lines
        var items: [TripDelayImpact] = []
        if let pickup = lines.compactMap(\.event).first(where: { $0.kind == .carPickup })?.time, arrival > pickup {
            items.append(TripDelayImpact(kind: .rentalPickup, title: "렌터카 인수 \(clock(pickup, calendar))",
                                         detail: "도착이 \(clock(arrival, calendar))쯤이라 인수 시각보다 늦어요. 업체에 늦는다고 알려 두세요."))
        }
        let stay = lines.first { $0.reach != nil }
        let reach = stay?.reach
        if let reach, let route = lines.compactMap(\.route).first {
            items.append(TripDelayImpact(kind: .hotelArrival, title: "\(stay?.event?.booking?.name ?? "숙소") 가는 길",
                                         detail: "운전 약 \(durationText(route.minutes))(\(route.source.label))이라 빨라야 \(clock(reach, calendar))에 닿아요."))
        }
        if let bedtimeMinute,
           let bed = calendar.date(bySettingHour: bedtimeMinute / 60, minute: bedtimeMinute % 60, second: 0, of: booked) {
            if let reach, reach > bed {
                items.append(TripDelayImpact(kind: .bedtime, title: "밤잠 \(TravelChildText.clock(bedtimeMinute))",
                                             detail: "숙소에 닿기 전이라 이동 중에 맞게 돼요."))
            } else if reach == nil, arrival > bed {
                items.append(TripDelayImpact(kind: .bedtime, title: "밤잠 \(TravelChildText.clock(bedtimeMinute))",
                                             detail: "도착이 \(clock(arrival, calendar))쯤이라 공항이나 이동 중에 맞게 돼요."))
            }
        }
        return TripDelayOutlook(arrival: arrival, impacts: items)
    }

    /// 92 → 「1시간 32분」.
    static func durationText(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)시간 \(m)분" }
        if h > 0 { return "\(h)시간" }
        return "\(m)분"
    }

    private static func clock(_ date: Date, _ calendar: Calendar) -> String {
        TripDateText.time(date, calendar: calendar)
    }
}
