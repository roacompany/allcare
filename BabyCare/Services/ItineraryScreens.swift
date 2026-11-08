import Foundation

/// 일정표를 홈과 예약 칸이 읽는 모양으로 — 판단은 ItineraryWalker 가 끝냈고 여기는 줄을 고른다.
extension ItineraryWalker {
    nonisolated static let homeLineLimit = 5

    // MARK: - 홈

    /// 편은 한 줄로 접고, 이동은 다음 줄 아래 글자로 넣는다(시안 Main).
    func homeLines(_ lines: [PlacedLine], baby: ItineraryBabyDay?) -> [Itinerary.HomeLine] {
        var out: [Itinerary.HomeLine] = []
        var drive: String?
        for placed in lines {
            guard let event = placed.event else {
                drive = placed.route.map { "차로 약 \(TripDelayPlanner.durationText($0.minutes)) · \($0.source.label)" }
                continue
            }
            if let line = homeLine(placed, event: event, drive: drive, baby: baby) { out.append(line) }
            drive = nil
        }
        return Array(out.prefix(Self.homeLineLimit))
    }

    private func homeLine(_ placed: PlacedLine, event: ItineraryEvent, drive: String?, baby: ItineraryBabyDay?) -> Itinerary.HomeLine? {
        let line = placed.line
        var home = Itinerary.HomeLine(id: line.id, clock: line.clock, clockNote: line.clockNote, isOpen: line.isOpen, title: line.title, detail: line.detail)
        switch event.kind {
        case .flightDepart:
            guard let b = event.booking else { return nil }
            let arrive = b.arrive?.time.map { "\(clock($0)) 도착" }
            home = Itinerary.HomeLine(id: line.id, clock: line.clock, isOpen: line.isOpen, title: flightTitle(b),
                                      detail: [b.flightLeg, arrive].compactMap { $0 }.joined(separator: " · "))
            if let start = b.depart?.time {
                home.childNote = baby?.chip(from: start, to: max(start, b.arrive?.time ?? start), verb: "탑승", during: "비행")
            }
        case .flightArrive:
            guard let b = event.booking else { return nil }
            // 같은 날 떠난 편은 출발 줄에 접혀 있다.
            if b.depart?.dayKey(calendar) == b.arrive?.dayKey(calendar) || b.depart == nil || b.arrive == nil { return nil }
            home = Itinerary.HomeLine(id: line.id, clock: line.clock, isOpen: line.isOpen,
                                      title: "\(b.flightNumber ?? "항공편") \(airportName(b.toAirport) ?? "") 도착", detail: b.flightLeg)
            home.childNote = b.arrive?.time.flatMap { baby?.chip(at: $0) }
        case .carPickup:
            home.detail = event.booking?.pickupPlace
            home.childNote = event.time.flatMap { baby?.chip(at: $0) }
        case .move:
            if let move = event.move {
                home.childNote = baby?.chip(from: move.startAt, to: move.endAt, verb: "이동", during: "이동")
            }
        case .stayArrive:
            home.detail = drive ?? line.detail
            if line.caution != nil { home.childNote = baby?.cautionChip() }
        case .checkOut, .carReturn:
            break
        }
        return home
    }

    /// 「KE725 인천 → 간사이」 — 공항을 모르면 아는 만큼만.
    private func flightTitle(_ b: TripBooking) -> String {
        let number = b.flightNumber ?? b.airline ?? "항공편"
        switch (airportName(b.fromAirport), airportName(b.toAirport)) {
        case let (from?, to?): return "\(number) \(from) → \(to)"
        case let (from?, nil): return "\(number) \(from) 출발"
        case let (nil, to?): return "\(number) → \(to)"
        case (nil, nil): return number
        }
    }

    // MARK: - 예약 칸

    /// 가는 날 = 첫날에 걸린 편 · 인수하는 렌터카 · 체크인하는 숙소. 나머지는 「다른 날 예약」.
    func bookings() -> Itinerary.Bookings {
        let walked = travel(on: trip.startDay)
        var dayOne: [Itinerary.Stop] = []
        var source: String?
        var listed = Set<String>()
        for placed in walked.lines {
            guard let event = placed.event else {
                if !dayOne.isEmpty {
                    dayOne[dayOne.count - 1].legAfter = placed.line
                    source = source ?? placed.route?.source.label
                }
                continue
            }
            guard let b = event.booking, let stop = dayOneStop(event, booking: b, line: placed.line), listed.insert(stop.id).inserted else { continue }
            dayOne.append(stop)
        }
        attachCaution(&dayOne, walked: walked)
        let others = otherStops(excluding: listed).sorted { $0.order < $1.order }.map(\.stop)
        return Itinerary.Bookings(sourceLabel: source, dayOne: dayOne, otherDays: others)
    }

    /// 시안: 밤잠과 맞닿는 상자는 숙소 앞 이동 아래에 놓인다.
    private func attachCaution(_ stops: inout [Itinerary.Stop], walked: ItineraryWalk) {
        guard let rhythm, let day = Trip.date(fromDayKey: trip.startDay, calendar: calendar) else { return }
        let baby = ItineraryBabyDay(rhythm: rhythm, day: day, spans: walked.spans, flights: flights, arrivals: walked.arrivals, calendar: calendar)
        guard let caution = walked.lines.compactMap(\.reach).compactMap(baby.caution).first else { return }
        if let index = stops.lastIndex(where: { $0.legAfter != nil }) {
            stops[index].caution = caution
        } else if !stops.isEmpty {
            stops[stops.count - 1].caution = caution
        }
    }

    private func dayOneStop(_ event: ItineraryEvent, booking b: TripBooking, line: Itinerary.Line) -> Itinerary.Stop? {
        let leg = [b.flightLeg, b.flightNumber].compactMap { $0 }.joined(separator: " ")
        switch event.kind {
        case .flightArrive:
            let from = "\(airportName(b.fromAirport) ?? "") \(b.depart?.time.map { "\(clock($0)) 출발" } ?? "출발 시각 미정")"
            let title = airportName(b.toAirport).map { "\($0)공항 도착" } ?? "\(b.flightNumber ?? "항공편") 도착"
            return Itinerary.Stop(kind: .flight, booking: b, clock: line.clock, isOpen: line.isOpen, title: title, details: ["\(leg), \(from)"])
        case .flightDepart:
            // 밤 비행 — 첫날에 안 내려도 가는 날 줄에 둔다.
            guard let arrive = b.arrive?.time, b.arrive?.dayKey(calendar) != trip.startDay else { return nil }
            let title = airportName(b.fromAirport).map { "\($0)공항 출발" } ?? "\(b.flightNumber ?? "항공편") 출발"
            return Itinerary.Stop(kind: .flight, booking: b, clock: line.clock, isOpen: line.isOpen, title: title,
                                  details: ["\(leg), \(TripDateText.dayTime(arrive, calendar: calendar)) \(airportName(b.toAirport) ?? "") 도착"])
        case .carPickup:
            let name = [b.company, b.pickupPlace].compactMap { $0 }.joined(separator: ", ")
            return Itinerary.Stop(kind: .carPickup, booking: b, clock: line.clock, isOpen: line.isOpen, title: "렌터카 인수",
                                  details: ([name] + freeCancel(b)).filter { !$0.isEmpty })
        case .stayArrive:
            return Itinerary.Stop(kind: .hotel, booking: b, clock: line.clock, clockNote: line.clockNote, isOpen: line.isOpen, title: line.title,
                                  details: [line.detail].compactMap { $0 } + freeCancel(b))
        case .checkOut, .carReturn, .move:
            return nil
        }
    }

    private func otherStops(excluding shown: Set<String>) -> [(stop: Itinerary.Stop, order: String)] {
        var out: [(stop: Itinerary.Stop, order: String)] = []
        for b in trip.bookings {
            switch b.kind {
            case .flight:
                let stop = flightStop(b)
                if !shown.contains(stop.id) { out.append((stop, order(b.depart ?? b.arrive))) }
            case .hotel:
                let stop = hotelStop(b)
                if !shown.contains(stop.id) { out.append((stop, order(b.checkIn))) }
            case .rentalCar:
                let pickedUp = shown.contains(Itinerary.Stop(kind: .carPickup, booking: b, title: "").id)
                if pickedUp {
                    if let back = b.carReturn {
                        let place = b.returnPlace.map { ", \($0)" } ?? ""
                        out.append((Itinerary.Stop(kind: .carReturn, booking: b, title: "렌터카 반납", details: ["\(TripDateText.when(back, calendar: calendar))\(place)"]), order(back)))
                    }
                } else {
                    out.append((rentalStop(b), order(b.pickup ?? b.carReturn)))
                }
            case .unknown:
                break
            }
        }
        return out
    }

    private func flightStop(_ b: TripBooking) -> Itinerary.Stop {
        let day = (b.depart ?? b.arrive).map { TripDateText.day($0, calendar: calendar) } ?? ""
        let depart = b.depart?.time.map { "\(clock($0)) 출발" } ?? "출발 시각 미정"
        let arrive = b.arrive?.time.map { "\(clock($0)) 도착" } ?? "도착 시각 미정"
        let name = [b.flightLeg, b.flightNumber ?? b.airline].compactMap { $0 }.joined(separator: " ")
        return Itinerary.Stop(kind: .flight, booking: b, title: "\(name), \(airportName(b.fromAirport) ?? "?") → \(airportName(b.toAirport) ?? "?")",
                              details: ["\(day) \(depart), \(arrive)"])
    }

    private func hotelStop(_ b: TripBooking) -> Itinerary.Stop {
        let stay = [b.checkIn.map { "\(TripDateText.when($0, calendar: calendar)) 체크인" },
                    b.checkOut.map { "\(TripDateText.when($0, calendar: calendar)) 체크아웃" }].compactMap { $0 }.joined(separator: ", ")
        return Itinerary.Stop(kind: .hotel, booking: b, title: b.name ?? "숙소", details: ([stay] + freeCancel(b)).filter { !$0.isEmpty })
    }

    private func rentalStop(_ b: TripBooking) -> Itinerary.Stop {
        let pick = b.pickup.map { "\(TripDateText.when($0, calendar: calendar)) 인수" + (b.pickupPlace.map { ", \($0)" } ?? "") }
        let back = b.carReturn.map { "\(TripDateText.when($0, calendar: calendar)) 반납" + (b.returnPlace.map { ", \($0)" } ?? "") }
        return Itinerary.Stop(kind: .carRental, booking: b, title: b.company ?? "렌터카", details: [pick, back].compactMap { $0 } + freeCancel(b))
    }

    private func freeCancel(_ b: TripBooking) -> [String] {
        b.freeCancel.map { ["무료 취소 \(TripDateText.when($0, calendar: calendar))까지"] } ?? []
    }

    private func order(_ when: TripWhen?) -> String {
        when.sortKey(calendar)
    }
}
