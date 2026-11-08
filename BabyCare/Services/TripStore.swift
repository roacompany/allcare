import Foundation

/// 여행 저장소를 고르는 한 곳 — 평소엔 Firestore, UI 시험(`UI_TESTING_WITH_TRIP`)에서만 메모리.
enum TripStore {
    static var live: TripFirestoreProviding {
        #if DEBUG
        if UITestTripFirestore.isOn { return UITestTripFirestore.shared }
        #endif
        return FirestoreService.shared
    }

    static var routeTime: RouteTimeProviding {
        #if DEBUG
        if UITestTripFirestore.isFixed { return UITestRouteTime() }
        #endif
        return RouteTimeServices.standard()
    }

    static var flightSchedule: FlightScheduleProviding {
        #if DEBUG
        if UITestTripFirestore.isFixed { return UITestFlightSchedule() }
        #endif
        return IncheonFlightScheduleService.shared
    }

    static var childData: TripChildDataProviding {
        #if DEBUG
        if UITestTripFirestore.isFullTrip { return UITestChildData() }
        #endif
        return FirestoreService.shared
    }
}

#if DEBUG
/// UI 시험 전용 여행 저장소 — 로그인 없이 넣는 창까지 눌러 가려고 쓴다.
/// 🩸 2026-11-06: 흐름 시험에 여행이 없어 넣는 창에 한 번도 못 갔고, 자판에 가린 후보를 PO 가 기기에서 잡았다.
/// ⛔ 출시 빌드에 안 들어간다 · 실제 아이 이름·예약을 넣지 않는다(저장소가 공개다).
final class UITestTripFirestore: TripFirestoreProviding, @unchecked Sendable {
    static let shared = UITestTripFirestore()
    static var isOn: Bool { CommandLine.arguments.contains("UI_TESTING_WITH_TRIP") }
    /// 빈 여행에서 시작해 전부 넣는 흐름 시험.
    static var isWholeTrip: Bool { CommandLine.arguments.contains("UI_TESTING_TRIP_EMPTY") }
    /// 다 넣은 여행 + 아기 기록 — 손님이 실제로 보는 일정표를 잰다.
    static var isFullTrip: Bool { CommandLine.arguments.contains("UI_TESTING_TRIP_FULL") }
    /// 시간표·지도를 고정한다.
    static var isFixed: Bool { isWholeTrip || isFullTrip }

    private let lock = NSLock()
    private var trip: Trip?
    private var listeners: [AsyncStream<Trip?>.Continuation] = []

    /// 사흘 뒤 출발 — 공항 칩이 나오게 가는 편·오는 편 · 숙소 하나.
    private func sample(babyId: String) -> Trip {
        let cal = Calendar.current
        let start = cal.startOfDay(for: cal.date(byAdding: .day, value: 3, to: Date()) ?? Date())
        func at(_ day: Int, _ hour: Int) -> Date {
            cal.date(byAdding: .hour, value: day * 24 + hour, to: start) ?? start
        }
        let out = TripBooking(id: "ui-f1", kind: .flight, airline: "KE", flightNumber: "KE999",
                              fromAirport: "ICN", toAirport: "KIX", depart: .at(at(0, 15)), arrive: .at(at(0, 17)))
        let back = TripBooking(id: "ui-f2", kind: .flight, airline: "KE", flightNumber: "KE998",
                               fromAirport: "KIX", toAirport: "ICN", depart: .at(at(4, 12)), arrive: .at(at(4, 14)))
        let hotel = TripBooking(id: "ui-h1", kind: .hotel, name: "시험 숙소", address: "시험 주소",
                                checkIn: .at(at(0, 22)), checkOut: .at(at(4, 10)))
        func minute(_ day: Int, _ hour: Int, _ minute: Int) -> TripWhen {
            .at(cal.date(byAdding: .minute, value: minute, to: at(day, hour)) ?? start)
        }
        let full = [
            TripBooking(id: "ui-f1", kind: .flight, airline: "KE", flightNumber: "KE999", fromAirport: "ICN", toAirport: "KIX",
                        depart: minute(0, 15, 10), arrive: minute(0, 17, 0)),
            TripBooking(id: "ui-f2", kind: .flight, airline: "KE", flightNumber: "KE998", fromAirport: "KIX", toAirport: "ICN",
                        depart: minute(4, 11, 55), arrive: minute(4, 14, 0)),
            TripBooking(id: "ui-c1", kind: .rentalCar, company: "시험 렌터카", pickupPlace: "간사이공항", pickup: minute(0, 18, 0),
                        returnPlace: "간사이공항", carReturn: minute(4, 10, 0)),
            TripBooking(id: "ui-h1", kind: .hotel, name: "교토 숙소", checkIn: minute(0, 15, 0), checkOut: minute(2, 10, 0), checkInUntilMinute: 22 * 60),
            TripBooking(id: "ui-h2", kind: .hotel, name: "오사카 숙소", checkIn: minute(2, 15, 0),
                        checkOut: .day(Trip.dayKey(at(4, 0), calendar: cal)))
        ]
        return Trip(id: "ui-trip", babyId: babyId, countryCode: "JP", city: "오사카",
                    startDay: Trip.dayKey(start, calendar: cal), endDay: Trip.dayKey(at(4, 0), calendar: cal),
                    bookings: Self.isFullTrip ? full : Self.isWholeTrip ? [] : [out, back, hotel], createdBy: "ui-test-user")
    }

    private func change(_ update: (inout Trip) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard var current = trip else { return }
        update(&current)
        trip = current
        listeners.forEach { $0.yield(current) }
    }

    func fetchTrips(userId: String, babyId: String) async throws -> [Trip] {
        lock.withLock {
            let current = trip ?? sample(babyId: babyId)
            trip = current
            return [current]
        }
    }

    func createTrip(_ trip: Trip, userId: String) async throws {}

    func deleteTrip(_ tripId: String, userId: String, babyId: String) async throws {}

    func tripUpdates(userId: String, babyId: String, tripId: String) -> AsyncStream<Trip?> {
        AsyncStream { continuation in
            lock.lock()
            defer { lock.unlock() }
            listeners.append(continuation)
            continuation.yield(trip)
        }
    }

    func saveBooking(_ booking: TripBooking, tripId: String, babyId: String, userId: String) async throws {
        change { trip in
            trip.bookings.removeAll { $0.id == booking.id }
            trip.bookings.append(booking)
        }
    }

    func deleteBooking(_ bookingId: String, tripId: String, babyId: String, userId: String) async throws {
        change { $0.bookings.removeAll { $0.id == bookingId } }
    }

    func saveTaskState(_ state: TripTaskState, tripId: String, babyId: String, userId: String) async throws {
        change { trip in
            trip.taskStates.removeAll { $0.taskId == state.taskId }
            trip.taskStates.append(state)
        }
    }

    func saveMove(_ move: TripMove, tripId: String, babyId: String, userId: String) async throws {
        change { trip in
            trip.moves.removeAll { $0.id == move.id }
            trip.moves.append(move)
        }
    }

    func deleteMove(_ moveId: String, tripId: String, babyId: String, userId: String) async throws {
        change { $0.moves.removeAll { $0.id == moveId } }
    }

    func updateTripInfo(city: String, startDay: String, endDay: String, tripId: String, babyId: String, userId: String) async throws {
        change { trip in
            trip.city = city
            trip.startDay = startDay
            trip.endDay = endDay
        }
    }
}

/// 일정표 흐름 시험 전용 아기 기록 — 시안의 리듬(낮잠 09:40·14:10 · 밤잠 20:10 · 이유식 08:10·17:40 · 수유 3시간 50분마다).
struct UITestChildData: TripChildDataProviding {
    func fetchGrowthRecords(userId: String, babyId: String) async throws -> [GrowthRecord] { [] }

    func fetchActivities(userId: String, babyId: String, from startDate: Date, to endDate: Date) async throws -> [Activity] {
        let cal = Calendar.current
        var out: [Activity] = []
        var day = cal.startOfDay(for: startDate)
        var index = 0
        while day < endDate {
            func at(_ minute: Int) -> Date { day.addingTimeInterval(TimeInterval(minute * 60)) }
            out.append(Activity(id: "n1-\(index)", babyId: babyId, type: .sleep, startTime: at(580), endTime: at(650), sleepMethod: index < 2 ? .carSeat : .bed))
            if index != 3 { out.append(Activity(id: "n2-\(index)", babyId: babyId, type: .sleep, startTime: at(850), endTime: at(930))) }
            out.append(Activity(id: "bed-\(index)", babyId: babyId, type: .sleep, startTime: at(1210), endTime: at(1850)))
            for (i, minute) in [410, 640, 870, 1100].enumerated() {
                out.append(Activity(id: "f\(i)-\(index)", babyId: babyId, type: .feedingBottle, startTime: at(minute)))
            }
            out.append(Activity(id: "s1-\(index)", babyId: babyId, type: .feedingSolid, startTime: at(490)))
            out.append(Activity(id: "s2-\(index)", babyId: babyId, type: .feedingSolid, startTime: at(1060)))
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
            index += 1
        }
        return out
    }
}

/// 전부 넣기 흐름 시험 전용 시간표 — 네트워크에 흔들리지 않게 고정한다. 인천 쪽 시각만 준다(실제 시간표와 같다).
struct UITestFlightSchedule: FlightScheduleProviding {
    func rows() async throws -> [FlightScheduleRow] {
        func row(_ id: String, _ hour: Int, _ minute: Int, _ direction: FlightDirection) -> FlightScheduleRow {
            FlightScheduleRow(flightId: id, airlineName: "대한항공", counterpartName: "오사카/간사이", counterpartCode: "KIX", hour: hour, minute: minute,
                              firstDay: "20000101", lastDay: "20991231", weekdays: Set(1...7), direction: direction)
        }
        return [row("KE999", 15, 10, .departure), row("KE998", 14, 0, .arrival)]
    }
}

/// 전부 넣기 흐름 시험 전용 지도 — 구글 경로로 잰 값(2026-11-06)으로 고정한다.
struct UITestRouteTime: RouteTimeProviding {
    func drivingRoute(from: String, to: String, near area: TripRouteArea) async throws -> RouteEstimate {
        let minutes: Int
        switch (from, to) {
        case ("関西国際空港", "교토 숙소"): minutes = 96
        case ("교토 숙소", "오사카 숙소"): minutes = 66
        case ("오사카 숙소", "関西国際空港"): minutes = 44
        default: throw RouteTimeError.notFound
        }
        return RouteEstimate(minutes: minutes, fromName: nil, toName: nil, source: .google)
    }
}
#endif
