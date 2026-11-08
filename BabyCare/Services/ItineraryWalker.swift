import Foundation

/// 예약 하나가 그날 내는 일.
struct ItineraryEvent {
    /// 일의 논리 순서 — 시각이 없는 일이 들어갈 자리를 정한다.
    enum Kind: Int {
        case checkOut, carReturn, flightDepart, flightArrive, carPickup, move, stayArrive
    }

    let kind: Kind
    let booking: TripBooking?
    let move: TripMove?
    /// 약속의 시각. 시각 미정과 시간대(숙소)는 nil.
    let time: Date?
    /// 이 일을 시작하는 곳 · 끝내는 곳.
    let startPlace: String?
    let endPlace: String?
    /// 줄 순서를 정하는 시각 — 편이 늦어도 예약한 차례는 그대로다.
    var bookedTime: Date?
}

/// 시각이 붙은 줄 — 아기 줄과 맞출 때 쓴다.
struct PlacedLine {
    var line: Itinerary.Line
    let at: Date?
    /// 숙소 도착 예상.
    var reach: Date?
    /// 이 줄을 낸 일. 찾아낸 이동은 nil.
    var event: ItineraryEvent?
    /// 찾아낸 이동의 구간과 지도 답.
    var leg: TripRouteKey?
    var route: RouteEstimate?
}

/// 하루를 걸은 결과.
struct ItineraryWalk {
    var lines: [PlacedLine] = []
    var spans: [ItinerarySpan] = []
    var arrivals: [Date] = []
}

/// 비행·운전 구간.
struct ItinerarySpan {
    let start: Date
    let end: Date
    let isFlight: Bool
}

/// 일정표의 계산 — 하루의 일을 세우고, 사이 이동을 찾고, 앞 시각을 이어 걷는다. 순수.
struct ItineraryWalker {
    let trip: Trip
    let rhythm: BabyRhythm?
    let routes: [TripRouteKey: TripRouteAnswer]
    let calendar: Calendar
    /// 늦어진 편 — 예약 id → 분. 지연 영향을 볼 때만 쓴다.
    var delays: [String: Int] = [:]

    private var hotels: [TripBooking] { trip.bookings.filter { $0.kind == .hotel } }
    private var isJapan: Bool { trip.countryCode.uppercased() == "JP" }

    /// 체크인 날부터 체크아웃 전날까지.
    func tonight(_ key: String) -> String? {
        hotels.filter { hotel in
            guard let start = hotel.checkIn?.dayKey(calendar) else { return false }
            guard let end = hotel.checkOut?.dayKey(calendar) else { return start == key }
            return start <= key && key < end
        }
        .max { (a: TripBooking, b: TripBooking) -> Bool in
            // CI(Xcode 26.3) 대비 — 비교식의 ?? 를 타입 적은 중간값으로(2026-11-08).
            let left: String = a.checkIn?.dayKey(calendar) ?? ""
            let right: String = b.checkIn?.dayKey(calendar) ?? ""
            return left < right
        }?
        .name
    }

    /// 그날 여행 줄을 걸어 일정 칸·홈이 읽을 줄을 만든다.
    func day(_ key: String) -> (lines: [Itinerary.Line], home: [Itinerary.HomeLine], legs: [TripRouteKey]) {
        var walked = travel(on: key)
        let baby = rhythm.flatMap { rhythm in
            Trip.date(fromDayKey: key, calendar: calendar).map {
                ItineraryBabyDay(rhythm: rhythm, day: $0, spans: walked.spans, flights: flights, arrivals: walked.arrivals, calendar: calendar)
            }
        }
        if let baby {
            for index in walked.lines.indices {
                walked.lines[index].line.caution = walked.lines[index].reach.flatMap(baby.caution)
            }
        }
        return (merged(walked.lines, baby?.lines() ?? []), homeLines(walked.lines, baby: baby), walked.lines.compactMap(\.leg))
    }

    /// 아기 줄을 시각에 맞춰 끼운다 — 여행 줄 순서는 그대로다. 시각 미정 줄은 다음 시각 줄 바로 앞, 시각 없는 이동은 앞 줄 바로 뒤.
    private func merged(_ travel: [PlacedLine], _ baby: [PlacedLine]) -> [Itinerary.Line] {
        var out: [Itinerary.Line] = []
        var rest = baby[...]
        for (index, placed) in travel.enumerated() {
            let anchor = placed.at ?? (placed.line.isOpen ? travel[(index + 1)...].lazy.compactMap(\.at).first : nil)
            if let anchor {
                while let next = rest.first, let at = next.at, at < anchor {
                    out.append(next.line)
                    rest = rest.dropFirst()
                }
            }
            out.append(placed.line)
        }
        return out + rest.map(\.line)
    }

    /// 여행 줄 — 일을 세워 걷는다.
    func travel(on key: String) -> ItineraryWalk {
        let events = ordered(events(on: key))
        var walk = ItineraryWalk(spans: trip.moves.map { ItinerarySpan(start: $0.startAt, end: $0.endAt, isFlight: false) } + flightSpans)
        for (index, event) in events.enumerated() {
            let earlier = events[..<index]
            var reach: Date?
            if let previous = earlier.last {
                if let leg = leg(from: previous, to: event) {
                    let walked = self.walk(leg, id: "leg-\(key)-\(index)", from: previous, to: event, earlier: earlier)
                    walk.lines.append(PlacedLine(line: walked.line, at: walked.leave, leg: leg.key, route: answer(leg.key)))
                    reach = walked.reach
                    if let span = walked.span { walk.spans.append(span) }
                } else if let move = previous.move, samePlace(move.toLabel, event.startPlace) {
                    reach = move.endAt
                }
            }
            var line = line(for: event, reach: reach, afterAppointment: earlier.contains { $0.time != nil })
            line.alert = alert(for: event, reach: reach, among: events, earlier: earlier, key: key)
            let shown = at(event, reach: reach, afterAppointment: earlier.contains { $0.time != nil })
            walk.lines.append(PlacedLine(line: line, at: shown, reach: event.kind == .stayArrive ? reach : nil, event: event))
            if event.kind == .stayArrive, let reach { walk.arrivals.append(reach) }
        }
        return walk
    }

    private func answer(_ key: TripRouteKey) -> RouteEstimate? {
        if case .found(let route)? = routes[key] { return route }
        return nil
    }

    /// 아기 줄과 맞출 시각 — 줄 왼쪽에 적히는 시각.
    private func at(_ event: ItineraryEvent, reach: Date?, afterAppointment: Bool) -> Date? {
        switch event.kind {
        case .checkOut: return event.booking?.checkOut?.time
        case .stayArrive: return reach ?? (afterAppointment ? nil : event.booking?.checkIn?.time)
        case .carReturn, .flightDepart, .flightArrive, .carPickup, .move: return event.time
        }
    }

    var flights: [TripBooking] { trip.bookings.filter { $0.kind == .flight } }

    private var flightSpans: [ItinerarySpan] {
        flights.compactMap { f in
            guard let start = f.depart?.time, let end = f.arrive?.time, start < end else { return nil }
            return ItinerarySpan(start: start, end: end, isFlight: true)
        }
    }

    /// 찾아낸 이동 한 줄 — 앞이 시각 있는 약속이면 앞 약속 중 가장 늦은 시각에 더하고, 뒤가 렌터카 반납이면 뺀다.
    /// ⛔ 항공 출발 앞은 빼지 않는다 — 공항에 미리 가야 하는 시간을 몰라서, 「늦어도」를 말하면 비행기를 놓친다.
    private func walk(_ leg: (key: TripRouteKey, title: String), id: String, from previous: ItineraryEvent, to next: ItineraryEvent,
                      earlier: ArraySlice<ItineraryEvent>) -> (line: Itinerary.Line, reach: Date?, leave: Date?, span: ItinerarySpan?) {
        guard let answer = routes[leg.key] else {
            return (Itinerary.Line(id: id, title: "\(leg.title)까지 이동", detail: "소요 시간 계산 중", lane: .route, route: leg.key), nil, nil, nil)
        }
        guard case .found(let route) = answer else {
            return (Itinerary.Line(id: id, title: "\(leg.title)까지 이동", detail: "지도에서 길을 찾지 못했어요", lane: .route, route: leg.key), nil, nil, nil)
        }
        var line = Itinerary.Line(id: id, title: "\(leg.title)까지 차로 약 \(TripDelayPlanner.durationText(route.minutes)), \(route.source.label)",
                                  lane: .route, route: leg.key)
        if let from = route.fromName, let to = route.toName { line.detail = "지도가 찾은 곳: \(from) → \(to)" }
        let drive = TimeInterval(route.minutes * 60)
        if previous.time != nil, let ready = ready(after: previous, earlier: earlier) {
            let reach = ready.addingTimeInterval(drive)
            return (line, reach, nil, ItinerarySpan(start: ready, end: reach, isFlight: false))
        }
        if next.kind == .carReturn, let due = next.time {
            let leave = due.addingTimeInterval(-drive)
            line.clock = clock(leave)
            line.clockNote = "늦어도"
            return (line, nil, leave, ItinerarySpan(start: leave, end: due, isFlight: false))
        }
        return (line, nil, nil, nil)
    }

    /// 움직일 수 있는 때 — 앞 약속 중 가장 늦은 시각. 그날 안 내리는 밤 비행은 내린 뒤다.
    private func ready(after previous: ItineraryEvent, earlier: ArraySlice<ItineraryEvent>) -> Date? {
        if previous.kind == .flightDepart, let b = previous.booking {
            return b.arrive?.time.map { $0.addingTimeInterval(TimeInterval((delays[b.id] ?? 0) * 60)) }
        }
        return earlier.compactMap(\.time).max()
    }

    /// 앞뒤가 안 맞는 것 — 그 줄에서 말한다.
    private func alert(for event: ItineraryEvent, reach: Date?, among events: [ItineraryEvent], earlier: ArraySlice<ItineraryEvent>, key: String) -> String? {
        switch event.kind {
        case .stayArrive:
            // 지도 답이 없어도 앞 약속만으로 이미 늦은 것은 말한다.
            guard let arrive = reach ?? earlier.compactMap(\.time).max(), let booking = event.booking,
                  let until = deadline(of: booking, on: key), arrive > until else { return nil }
            return "체크인 마감 \(clock(until))을 넘겨요"
        case .carPickup:
            guard let time = event.time else { break }
            if let landed = events.first(where: { $0.kind == .flightArrive })?.time {
                if time < landed { return "비행기 도착 \(clock(landed))보다 빨라요" }
            } else if events.contains(where: { $0.kind == .flightArrive }),
                      let takeoff = events.first(where: { $0.kind == .flightDepart })?.time, time < takeoff {
                return "비행기 출발 \(clock(takeoff))보다 빨라요"
            }
        case .carReturn:
            if let time = event.time, let takeoff = events.first(where: { $0.kind == .flightDepart })?.time, time > takeoff {
                return "비행기 출발 \(clock(takeoff))보다 늦어요"
            }
        case .checkOut, .flightDepart, .flightArrive, .move:
            break
        }
        if let reach, let time = event.time, reach > time {
            return "이동하면 빨라야 \(clock(reach))에 닿아요"
        }
        return midnightQuestion(event)
    }

    /// 🩸 옛 빌드가 모르는 시각을 00:00 으로 저장했다 — 진짜인지 알 수 없어 믿되, 그 줄에서 묻는다.
    private func midnightQuestion(_ event: ItineraryEvent) -> String? {
        guard let time = event.booking.flatMap({ _ in event.bookedTime ?? event.time }),
              calendar.component(.hour, from: time) == 0, calendar.component(.minute, from: time) == 0 else { return nil }
        switch event.kind {
        case .flightDepart: return "00:00 출발이 맞나요?"
        case .flightArrive: return "00:00 도착이 맞나요?"
        case .carPickup: return "00:00 인수가 맞나요?"
        case .carReturn: return "00:00 반납이 맞나요?"
        case .checkOut, .stayArrive, .move: return nil
        }
    }

    /// 체크인 마감 시각.
    private func deadline(of booking: TripBooking, on key: String) -> Date? {
        guard let minute = booking.checkInUntilMinute, let day = Trip.date(fromDayKey: key, calendar: calendar) else { return nil }
        let start = booking.checkIn?.time.map { calendar.component(.hour, from: $0) * 60 + calendar.component(.minute, from: $0) }
        // 체크인 시작보다 이른 마감(시작을 모르면 낮 12시 전)은 자정 넘어 다음 날이다.
        let shifted = minute + (minute < (start ?? 12 * 60) ? 24 * 60 : 0)
        return calendar.date(byAdding: .minute, value: shifted, to: day)
    }

    // MARK: - 일 세우기

    private func events(on key: String) -> [ItineraryEvent] {
        var out: [ItineraryEvent] = []
        for b in trip.bookings {
            switch b.kind {
            case .flight:
                // 한쪽 일시만 있어도 두 일을 다 세운다 — 도착을 비워도 가는 편이 사라지면 안 된다.
                let late = TimeInterval((delays[b.id] ?? 0) * 60)
                if (b.depart ?? b.arrive)?.dayKey(calendar) == key {
                    out.append(ItineraryEvent(kind: .flightDepart, booking: b, move: nil, time: b.depart?.time.map { $0.addingTimeInterval(late) },
                                              startPlace: b.fromAirport, endPlace: b.toAirport, bookedTime: b.depart?.time))
                }
                if (b.arrive ?? b.depart)?.dayKey(calendar) == key {
                    out.append(ItineraryEvent(kind: .flightArrive, booking: b, move: nil, time: b.arrive?.time.map { $0.addingTimeInterval(late) },
                                              startPlace: b.toAirport, endPlace: b.toAirport, bookedTime: b.arrive?.time))
                }
            case .rentalCar:
                if b.pickup?.dayKey(calendar) == key {
                    out.append(ItineraryEvent(kind: .carPickup, booking: b, move: nil, time: b.pickup?.time,
                                              startPlace: b.pickupPlace, endPlace: b.pickupPlace))
                }
                if b.carReturn?.dayKey(calendar) == key {
                    out.append(ItineraryEvent(kind: .carReturn, booking: b, move: nil, time: b.carReturn?.time,
                                              startPlace: b.returnPlace, endPlace: b.returnPlace))
                }
            case .hotel:
                if b.checkIn?.dayKey(calendar) == key {
                    out.append(ItineraryEvent(kind: .stayArrive, booking: b, move: nil, time: nil, startPlace: b.name, endPlace: b.name))
                }
                if b.checkOut?.dayKey(calendar) == key {
                    out.append(ItineraryEvent(kind: .checkOut, booking: b, move: nil, time: nil, startPlace: b.name, endPlace: b.name))
                }
            case .unknown:
                break
            }
        }
        for m in trip.moves where Trip.dayKey(m.startAt, calendar: calendar) == key {
            out.append(ItineraryEvent(kind: .move, booking: nil, move: m, time: m.startAt, startPlace: m.fromLabel, endPlace: m.toLabel))
        }
        return out
    }

    /// 약속은 시각 순으로 놓고, 시각이 없는 일은 자기보다 뒤 순위인 첫 일 앞에 끼운다.
    /// 시각과 논리 순서를 비교 함수 하나에 섞으면 앞뒤 관계가 꼬인다.
    private func ordered(_ events: [ItineraryEvent]) -> [ItineraryEvent] {
        func order(_ event: ItineraryEvent) -> Date { event.bookedTime ?? event.time ?? .distantPast }
        var line = events.filter { $0.time != nil }.sorted {
            order($0) == order($1) ? $0.kind.rawValue < $1.kind.rawValue : order($0) < order($1)
        }
        for event in events.filter({ $0.time == nil }).sorted(by: { $0.kind.rawValue < $1.kind.rawValue }) {
            let at = pairIndex(of: event, in: line) ?? line.firstIndex { $0.kind.rawValue > event.kind.rawValue } ?? line.count
            line.insert(event, at: at)
        }
        return line
    }

    /// 시각 없는 편의 자리 — 같은 편의 짝 바로 옆.
    private func pairIndex(of event: ItineraryEvent, in line: [ItineraryEvent]) -> Int? {
        func index(_ kind: ItineraryEvent.Kind) -> Int? {
            line.firstIndex { $0.kind == kind && $0.booking?.id == event.booking?.id }
        }
        switch event.kind {
        case .flightArrive: return index(.flightDepart).map { $0 + 1 }
        case .flightDepart: return index(.flightArrive)
        case .checkOut, .carReturn, .carPickup, .move, .stayArrive: return nil
        }
    }

    // MARK: - 이동

    /// 앞 예약이 끝난 곳과 다음 예약이 시작하는 곳이 다르면 이동이다. 사람이 넣은 이동이 끼면 찾지 않는다.
    private func leg(from previous: ItineraryEvent, to next: ItineraryEvent) -> (key: TripRouteKey, title: String)? {
        guard previous.kind != .move, next.kind != .move,
              let from = previous.endPlace, let to = next.startPlace,
              let start = TripRoutePlace.query(for: from, trip: trip), let end = TripRoutePlace.query(for: to, trip: trip),
              start != end, !isHomeAirport(start), !isHomeAirport(end) else { return nil }
        return (TripRouteKey(from: start, to: end), placeName(to))
    }

    /// 여행지에서 차로 한국 공항에 갈 일은 없다 — 앞뒤가 어긋난 예약이 유령 이동을 만들지 않게.
    private func isHomeAirport(_ query: String) -> Bool {
        TripRoutePlace.airports.contains { $0.query == query && TripRoutePlace.homeAirports.contains($0.code) }
    }

    /// 공항 코드는 손님이 쓰는 이름으로, 나머지는 사람이 적은 그대로.
    private func placeName(_ place: String) -> String {
        TripRoutePlace.airports.contains { $0.code == place.uppercased() } ? (TripEntryChoices.airportName(place) ?? place) : place
    }

    private func samePlace(_ a: String?, _ b: String?) -> Bool {
        guard let a, let b, let left = TripRoutePlace.query(for: a, trip: trip) else { return false }
        return left == TripRoutePlace.query(for: b, trip: trip)
    }

    // MARK: - 글자

    private func line(for event: ItineraryEvent, reach: Date?, afterAppointment: Bool) -> Itinerary.Line {
        let id = "\(event.kind)-\(event.booking?.id ?? event.move?.id ?? "")"
        let target = event.booking.map { Itinerary.Line.Target.booking($0.id) } ?? event.move.map { .move($0.id) }
        let b = event.booking
        func plain(_ title: String, _ detail: String? = nil, airportCode: String? = nil) -> Itinerary.Line {
            Itinerary.Line(id: id, clock: event.time.map(clock) ?? Itinerary.openClock, title: title, detail: detail, needsTime: event.time == nil,
                           target: target, airportCode: airportCode)
        }
        switch event.kind {
        case .flightDepart:
            let number = b?.flightNumber ?? "항공편"
            let title = airportName(b?.fromAirport).map { "\($0) 출발 \(number)" } ?? "\(number) 출발"
            return plain(title, b.map(arrivalText), airportCode: b?.fromAirport)
        case .flightArrive:
            guard let name = airportName(b?.toAirport) else { return plain("\(b?.flightNumber ?? "항공편") 도착") }
            if isHome(b?.toAirport) { return plain("\(name) 도착", b?.flightNumber, airportCode: b?.toAirport) }
            guard isJapan else { return plain("\(name) 도착, 입국", b?.flightNumber) }
            var line = plain("\(name) 도착, 입국", "고기 든 음식이 남았으면 자진폐기함에")
            line.rule = .solidsQuarantine
            return line
        case .carPickup:
            return plain("렌터카 인수", [b?.pickupPlace, isJapan ? "카시트 확인" : nil].compactMap { $0 }.joined(separator: ", "))
        case .carReturn:
            return plain("렌터카 반납", b?.returnPlace)
        case .move:
            return plain("\(event.startPlace ?? "") → \(event.endPlace ?? "")", event.move.map { "약 \(TripDelayPlanner.durationText($0.minutes))" })
        case .checkOut:
            let name = b?.name ?? "숙소"
            guard let due = b?.checkOut?.time else {
                return Itinerary.Line(id: id, clock: Itinerary.openClock, title: "\(name) 체크아웃", needsTime: true, target: target)
            }
            return Itinerary.Line(id: id, clock: clock(due), clockNote: "까지", title: "\(name) 체크아웃", target: target)
        case .stayArrive:
            var line = stayLine(id: id, booking: b, reach: reach, afterAppointment: afterAppointment)
            line.target = target
            return line
        }
    }

    /// 출발 줄 아래 — 「17:00 간사이 도착」. 날이 다르면 날짜까지.
    private func arrivalText(_ b: TripBooking) -> String {
        let place = airportName(b.toAirport) ?? ""
        guard let arrive = b.arrive?.time else { return "\(place) 도착 시각 미정".trimmingCharacters(in: .whitespaces) }
        if let depart = b.depart?.time, !calendar.isDate(depart, inSameDayAs: arrive) {
            return "\(TripDateText.dayTime(arrive, calendar: calendar)) \(place) 도착"
        }
        return "\(clock(arrive)) \(place) 도착"
    }

    private func stayLine(id: String, booking b: TripBooking?, reach: Date?, afterAppointment: Bool) -> Itinerary.Line {
        let name = b?.name ?? "숙소"
        let start = b?.checkIn?.time.map(clock)
        let until = b?.checkInUntilMinute.map(minuteClock)
        let hours: String?
        switch (start, until) {
        case let (s?, u?): hours = "체크인 \(s)~\(u)"
        case let (s?, nil): hours = "체크인 \(s)부터"
        case let (nil, u?): hours = "체크인 \(u)까지"
        case (nil, nil): hours = "체크인 시각 미정"
        }
        let unknown = start == nil && until == nil
        if let reach {
            return Itinerary.Line(id: id, clock: clock(reach), clockNote: "빨라야", title: "\(name) 도착", detail: hours, needsTime: unknown)
        }
        if afterAppointment {
            return Itinerary.Line(id: id, title: "\(name) 체크인", detail: hours, needsTime: unknown)
        }
        if let start {
            return Itinerary.Line(id: id, clock: start, clockNote: "부터", title: "\(name) 체크인", detail: until.map { "\($0)까지" })
        }
        if let until {
            return Itinerary.Line(id: id, clock: until, clockNote: "까지", title: "\(name) 체크인")
        }
        return Itinerary.Line(id: id, clock: Itinerary.openClock, title: "\(name) 체크인", needsTime: true)
    }

    func clock(_ date: Date) -> String {
        Itinerary.clock(date, calendar: calendar)
    }

    private func minuteClock(_ minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }

    /// 손님이 쓰는 짧은 이름(「간사이」) · 모르는 코드는 그대로 · 공항을 모르면 nil.
    func airportName(_ code: String?) -> String? {
        guard let value = code?.trimmingCharacters(in: .whitespaces).uppercased(), !value.isEmpty else { return nil }
        return TripRoutePlace.airports.first { $0.code == value }?.names.first ?? value
    }

    func isHome(_ code: String?) -> Bool {
        code.map { TripRoutePlace.homeAirports.contains($0.uppercased()) } ?? false
    }
}
