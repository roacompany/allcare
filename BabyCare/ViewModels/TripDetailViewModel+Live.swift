import Foundation

/// 한 편의 운항 정보 상태(화면이 그대로 그린다).
enum FlightLiveState: Equatable, Sendable {
    case loading
    case loaded(FlightLiveStatus)
    /// 오늘 인천공항 목록에 그 편명이 없다.
    case notFound
    case failed
    /// 그날(공항 기준 0시)에 보여요.
    case later(Date)
}

/// 이동 시간 한 번 묻기의 결과.
enum RouteLookup: Sendable {
    case found(RouteEstimate)
    case notFound
    case failed
}

/// 편명 찾기 결과(넣기 화면).
enum FlightLookupResult: Equatable, Sendable {
    case found(FlightScheduleRow)
    /// 편은 있는데 그날엔 다니지 않는다.
    case notOnThatDay
    /// 인천공항 시간표에 없다(인천 편이 아님) — 공항·시각을 고르게 한다.
    case notFound
    case failed
}

/// 여행 연동(2026-11-05) — 항공편 실시간 · 이동 시간.
/// ⛔ 뷰는 서비스를 직접 부르지 않는다 — 여기만 거친다(arch R1).
extension TripDetailViewModel {
    // MARK: - 항공편

    var flightBookings: [TripBooking] {
        trip.bookings.filter { $0.kind == .flight }
            .sorted { $0.flightOrder(calendar) < $1.flightOrder(calendar) }
    }

    /// 공항 날짜는 서울 기준(인천공항 목록이 그렇다).
    var flightPlan: TripFlightPlan {
        TripFlightStatusPlanner.plan(trip: trip, today: today, calendar: FlightStatusParser.seoul)
    }

    var hasFlightToday: Bool { !flightPlan.ask.isEmpty }

    /// 홈 항공편 칸 — 오늘 떠나는 편만(시안 Home-Flight · 캔버스 Version 84). 다른 날 편은 「다음 일정」 줄에 있다.
    var todayFlight: TripBooking? {
        TravelHomeSchedule.todayFlight(in: trip, today: today, calendar: calendar)
    }

    func isIncheonFlight(_ booking: TripBooking) -> Bool {
        TripFlightStatusPlanner.isIncheon(booking)
    }

    /// 화면이 그릴 상태 — 아직 안 물어봤어도 다른 날 편은 바로 「그날 보여요」(확인 중 빙글이를 띄우지 않는다).
    func flightState(for booking: TripBooking) -> FlightLiveState? {
        if let state = flightLive[booking.id] { return state }
        return flightPlan.later.first { $0.bookingId == booking.id }.map { .later($0.day) }
    }

    /// 오늘 편은 인천공항에 묻고, 다른 날 편은 「그날 보여요」로 둔다.
    /// 한 번 받은 정보는 다음 확인이 실패해도 지우지 않는다(지하 · 기내 모드에서 화면이 비지 않게).
    func refreshFlightStatus() async {
        let plan = flightPlan
        var next: [String: FlightLiveState] = [:]
        for q in plan.later { next[q.bookingId] = .later(q.day) }
        for q in plan.ask where flightLive[q.bookingId] == nil { flightLive[q.bookingId] = .loading }
        for q in plan.ask {
            let previous = flightLive[q.bookingId]
            do {
                if let status = try await flightStatus.status(flightId: q.flightId, direction: q.direction, day: q.day) {
                    next[q.bookingId] = .loaded(status)
                } else {
                    next[q.bookingId] = .notFound
                }
            } catch {
                logSilent("항공편 운항 정보를 못 받음", error: error, logger: AppLogger.travel)
                if case .loaded? = previous {
                    next[q.bookingId] = previous
                } else {
                    next[q.bookingId] = .failed
                }
            }
        }
        flightLive = next
    }

    /// 늦어진 가는 편 → 그날 뒤 일정에 닿는 것. 운항 정보를 아직 못 받았으면 nil.
    func delayOutlook(for flight: TripBooking) -> TripDelayOutlook? {
        guard case .loaded(let status)? = flightLive[flight.id] else { return nil }
        return TripDelayPlanner.outlook(trip: trip, flight: flight, status: status, routes: routes,
                                        bedtimeMinute: rhythm?.bedtimeMinute, calendar: calendar)
    }

    // MARK: - 이동 시간

    func knownDrivingRoute(from: String, to: String) -> RouteEstimate? {
        guard let key = routeKey(from: from, to: to), case .found(let route)? = routes[key] else { return nil }
        return route
    }

    /// 일정표가 묻는 구간을 차례로 묻는다. 답을 못 받은 구간은 일정표 줄에 「계산 중」으로 남는다.
    func loadRoutes() async {
        for key in itinerary.routeQuestions {
            _ = await drivingRoute(key)
        }
    }

    /// 차로 걸리는 시간 — 같은 두 곳은 한 번만 묻는다 · 못 찾은 곳은 다시 묻지 않는다(지도 검색 횟수에 상한이 있다).
    func drivingRoute(from: String, to: String) async -> RouteEstimate? {
        guard let key = routeKey(from: from, to: to) else { return nil }
        return await drivingRoute(key)
    }

    private func drivingRoute(_ key: TripRouteKey) async -> RouteEstimate? {
        if let known = routes[key] {
            if case .found(let route) = known { return route }
            return nil
        }
        let task: Task<RouteLookup, Never>
        if let running = routeTasks[key] {
            task = running
        } else {
            let provider = routeTime
            let area = TripRouteArea(city: trip.city, countryCode: trip.countryCode)
            task = Task {
                do {
                    return .found(try await provider.drivingRoute(from: key.from, to: key.to, near: area))
                } catch RouteTimeError.notFound {
                    return .notFound
                } catch {
                    logSilent("이동 시간 계산 실패", error: error, logger: AppLogger.travel)
                    return .failed
                }
            }
            routeTasks[key] = task
        }
        let result = await task.value
        routeTasks[key] = nil
        switch result {
        case .found(let estimate):
            routes[key] = .found(estimate)
            return estimate
        case .notFound:
            routes[key] = .notFound
            return nil
        case .failed:
            return nil
        }
    }

    private func routeKey(from: String, to: String) -> TripRouteKey? {
        guard let f = TripRoutePlace.query(for: from, trip: trip),
              let t = TripRoutePlace.query(for: to, trip: trip) else { return nil }
        return TripRouteKey(from: f, to: t)
    }

    // MARK: - 넣기(적기 → 고르기 · 설계 §8)

    /// 편명 + 날짜 → 인천공항 정기 시간표에서 찾기(표는 한 번 받으면 앱이 켜져 있는 동안 기억).
    func lookupFlight(number: String, day: Date) async -> FlightLookupResult {
        guard FlightNumber.normalize(number) != nil else { return .notFound }
        do {
            let rows = try await flightSchedule.rows()
            switch FlightScheduleMatcher.match(rows: rows, flightNumber: number, day: day, calendar: calendar) {
            case .found(let row): return .found(row)
            case .notOnThatDay: return .notOnThatDay
            case .notFound: return .notFound
            }
        } catch {
            logSilent("인천공항 시간표를 못 받음", error: error, logger: AppLogger.travel)
            return .failed
        }
    }

    /// 고를 장소 칩(공항 · 숙소 · 렌터카 장소 · 넣은 이동 장소).
    var entryPlaces: [String] { TripEntryChoices.places(in: trip, calendar: calendar) }

    /// 이동 출발 기본 — 그날 가장 늦게 끝나는 일 뒤.
    func moveStart(on day: Date) -> Date? {
        TripEntryChoices.moveStart(in: trip, day: day, calendar: calendar)
    }

    /// 렌터카 기본 날짜 — 인수 = 가는 편이 내리는 날 · 반납 = 오는 편이 뜨는 날(시각은 비운다).
    var rentalPickupDefault: TripWhen? { TripEntryChoices.rentalPickup(in: trip, calendar: calendar) }
    var rentalReturnDefault: TripWhen? { TripEntryChoices.rentalReturn(in: trip, calendar: calendar) }

    /// 이미 저장된 예약인가(새로 넣는 중이면 기본값을 채운다).
    func hasBooking(id: String) -> Bool { trip.bookings.contains { $0.id == id } }
}
