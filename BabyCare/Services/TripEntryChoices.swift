import Foundation

/// 시간표 한 줄 → 항공편 예약 — 순수 함수.
/// ⛔ 상대 공항 쪽 시각은 시간표에 없다 — 사람이 고른 것만 넣는다(지어낸 기본값 금지).
enum TripFlightEntry {
    static let incheon = "ICN"

    /// 편명 앞 두 자 = 항공사 코드(「7c1301」 → 「7C」).
    static func airlineCode(_ flightNumber: String) -> String? {
        FlightNumber.normalize(flightNumber).map { String($0.prefix(2)) }
    }

    static func booking(from row: FlightScheduleRow, day: Date, otherTime: Date?, base: TripBooking, calendar: Calendar) -> TripBooking {
        var b = base
        b.flightNumber = row.flightId
        b.airline = airlineCode(row.flightId)
        let incheonTime = TripEntryChoices.combine(day: day, time: incheonClock(row, calendar: calendar), calendar: calendar)
        let other = otherTime.map { TripEntryChoices.combine(day: day, time: $0, calendar: calendar) }
        switch row.direction {
        case .departure:
            b.fromAirport = incheon
            b.toAirport = row.counterpartCode
            b.depart = .at(incheonTime)
            // 도착이 출발보다 이르면 다음 날(밤 비행).
            b.arrive = other.map { .at($0 > incheonTime ? $0 : (calendar.date(byAdding: .day, value: 1, to: $0) ?? $0)) }
        case .arrival:
            b.fromAirport = row.counterpartCode
            b.toAirport = incheon
            b.arrive = .at(incheonTime)
            // 출발이 도착보다 늦으면 전날.
            b.depart = other.map { .at($0 < incheonTime ? $0 : (calendar.date(byAdding: .day, value: -1, to: $0) ?? $0)) }
        }
        return b
    }

    private static func incheonClock(_ row: FlightScheduleRow, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: row.hour, minute: row.minute)) ?? Date()
    }
}

/// 넣기 화면의 고를 거리 — 순수 함수(PO 2026-11-05 「지금 개불편해」 → 적기 대신 고르기).
enum TripEntryChoices {
    /// 고를 장소 — 그 여행의 공항(편 순서) · 숙소(체크인 순) · 렌터카 장소 · 넣은 이동 장소. 겹치지 않게.
    static func places(in trip: Trip, calendar: Calendar) -> [String] {
        var out: [String] = []
        func add(_ s: String?) {
            guard let v = s?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty, !out.contains(v) else { return }
            out.append(v)
        }
        for f in flights(trip, calendar: calendar) {
            add(airportName(f.fromAirport))
            add(airportName(f.toAirport))
        }
        for h in trip.bookings.filter({ $0.kind == .hotel }).sorted(by: { $0.checkIn.sortKey(calendar) < $1.checkIn.sortKey(calendar) }) {
            add(h.name)
        }
        for c in trip.bookings where c.kind == .rentalCar {
            add(c.pickupPlace)
            add(c.returnPlace)
        }
        for m in trip.moves.sorted(by: { $0.startAt < $1.startAt }) {
            add(m.fromLabel)
            add(m.toLabel)
        }
        return out
    }

    /// 칩으로 보일 곳 — 그 여행의 곳 + 찾아서 고른 곳(입력 칸이 없어서 칩이 아니면 고른 곳이 안 보인다 · 시안 Entry-Move).
    static func chips(choices: [String], value: String) -> [String] {
        let picked = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !picked.isEmpty, !choices.contains(picked) else { return choices }
        return choices + [picked]
    }

    /// 칩을 눌렀을 때의 값 — 고른 칩을 다시 누르면 비운다(렌터카 장소는 안 넣어도 되는 칸이고, 글자 칸이 없어 비울 길이 이것뿐이다).
    static func tapping(_ place: String, value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines) == place ? "" : place
    }

    /// 공항 코드 → 손님이 쓰는 이름(「KIX」 → 「간사이공항」). 모르는 코드는 그대로.
    static func airportName(_ code: String?) -> String? {
        guard let code = code?.trimmingCharacters(in: .whitespaces).uppercased(), !code.isEmpty else { return nil }
        if let name = TripRoutePlace.airports.first(where: { $0.code == code })?.names.first { return name + "공항" }
        return code
    }

    /// 일정 출발 기본 = 그날 가장 늦게 끝나는 일 뒤(도착 · 렌터카 인수/반납 · 체크아웃 · 일정 끝). 체크인 마감은 끝이 아니라 뺀다. 없으면 nil.
    static func moveStart(in trip: Trip, day: Date, calendar: Calendar) -> Date? {
        moveStartSource(in: trip, day: day, calendar: calendar)?.end
    }

    /// 그 기본 시각이 무엇 다음인지 — 「그날 렌터카 인수(18:00) 다음으로 채웠어요」(시안 Entry-Move).
    static func moveStartSource(in trip: Trip, day: Date, calendar: Calendar) -> (label: String, end: Date)? {
        var ends: [(label: String, end: Date)] = trip.moves.map { ("\($0.toLabel) 도착", $0.endAt) }
        for b in trip.bookings {
            switch b.kind {
            case .flight:
                if let a = b.arrive?.time { ends.append(("\(airportName(b.toAirport) ?? "공항") 도착", a)) }
            case .rentalCar:
                if let p = b.pickup?.time { ends.append(("렌터카 인수", p)) }
                if let r = b.carReturn?.time { ends.append(("렌터카 반납", r)) }
            case .hotel:
                if let o = b.checkOut?.time { ends.append(("\(b.name ?? "숙소") 체크아웃", o)) }
            case .unknown:
                break
            }
        }
        return ends.filter { calendar.isDate($0.end, inSameDayAs: day) }.max { $0.end < $1.end }
    }

    /// 렌터카 인수 기본 = 가는 편이 내리는 날. ⛔ 날짜만 — 인수 시각은 예약에 적힌 값이라 도착 시각으로 짐작하지 않는다.
    static func rentalPickup(in trip: Trip, calendar: Calendar) -> TripWhen? {
        flights(trip, calendar: calendar).first.flatMap { $0.arrive ?? $0.depart }.map { .day($0.dayKey(calendar)) }
    }

    /// 렌터카 반납 기본 = 오는 편이 뜨는 날(편이 둘 이상일 때만).
    static func rentalReturn(in trip: Trip, calendar: Calendar) -> TripWhen? {
        let f = flights(trip, calendar: calendar)
        guard f.count > 1 else { return nil }
        return f.last.flatMap { $0.depart ?? $0.arrive }.map { .day($0.dayKey(calendar)) }
    }

    /// 날짜 칩 + 시각 고르기 → 하나의 시각.
    static func combine(day: Date, time: Date, calendar: Calendar) -> Date {
        let t = calendar.dateComponents([.hour, .minute], from: time)
        return calendar.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: 0, of: calendar.startOfDay(for: day)) ?? day
    }

    private static func flights(_ trip: Trip, calendar: Calendar) -> [TripBooking] {
        trip.bookings.filter { $0.kind == .flight }
            .sorted { $0.flightOrder(calendar) < $1.flightOrder(calendar) }
    }
}
