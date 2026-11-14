import Foundation

/// 여행 준비 — 사람이 넣은 것만 저장한다(여행 · 예약 · 할 일의 완료/담당 · 이동).
/// 할 일 목록 · 마감 · 하루 일정은 저장하지 않고 그때그때 계산한다(TripTaskEngine · Itinerary).
/// 경로: users/{소유자}/babies/{아기}/trips/{id} — 여행 하나 = 문서 하나.
/// 🔴 저장 모양: bookings · taskStates · moves 는 **id 를 키로 한 맵**이다(배열 아님). 고칠 때 칸 하나씩만 쓴다
///    (FirestoreService+Trip) — 문서를 통째로 다시 쓰면 옛 사본이 새 예약을 지우고, 두 보호자 중 늦게 저장한 쪽이
///    상대 체크를 지운다(2026-11-04 검토). 메모리 안에서는 배열로 다룬다.
/// 설계 = docs/superpowers/specs/2026-11-04-travel-prep-design.md
struct Trip: Identifiable, Codable, Hashable {
    var id: String
    var babyId: String
    /// ISO 3166-1 alpha-2. 첫 판은 "JP" 만 고를 수 있다.
    var countryCode: String
    var city: String
    /// 여행 첫날·마지막 날 — "yyyy-MM-dd"(그 나라 달력의 날짜).
    var startDay: String
    var endDay: String
    var bookings: [TripBooking]
    var taskStates: [TripTaskState]
    var moves: [TripMove]
    var createdBy: String?
    var createdAt: Date
    var updatedAt: Date
    var schemaVersion: Int?

    init(
        id: String = UUID().uuidString,
        babyId: String,
        countryCode: String,
        city: String,
        startDay: String,
        endDay: String,
        bookings: [TripBooking] = [],
        taskStates: [TripTaskState] = [],
        moves: [TripMove] = [],
        createdBy: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        schemaVersion: Int? = 1
    ) {
        self.id = id
        self.babyId = babyId
        self.countryCode = countryCode
        self.city = city
        self.startDay = startDay
        self.endDay = endDay
        self.bookings = bookings
        self.taskStates = taskStates
        self.moves = moves
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.schemaVersion = schemaVersion
    }

    // 빠진 배열은 빈 배열로 읽는다 — 앞으로 칸이 늘어도 옛 문서가 버려지지 않게(decodeDocuments 는 실패한 문서를 조용히 버린다).
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        babyId = try c.decode(String.self, forKey: .babyId)
        countryCode = try c.decode(String.self, forKey: .countryCode)
        city = try c.decode(String.self, forKey: .city)
        startDay = try c.decode(String.self, forKey: .startDay)
        endDay = try c.decode(String.self, forKey: .endDay)
        bookings = try Trip.decodeKeyed(c, .bookings, as: TripBooking.self).sorted { $0.id < $1.id }
        taskStates = try Trip.decodeKeyed(c, .taskStates, as: TripTaskState.self).sorted { $0.taskId < $1.taskId }
        moves = try Trip.decodeKeyed(c, .moves, as: TripMove.self).sorted { $0.startAt < $1.startAt }
        createdBy = try c.decodeIfPresent(String.self, forKey: .createdBy)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(babyId, forKey: .babyId)
        try c.encode(countryCode, forKey: .countryCode)
        try c.encode(city, forKey: .city)
        try c.encode(startDay, forKey: .startDay)
        try c.encode(endDay, forKey: .endDay)
        try c.encode(Dictionary(bookings.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last }), forKey: .bookings)
        try c.encode(Dictionary(taskStates.map { ($0.taskId, $0) }, uniquingKeysWith: { _, last in last }), forKey: .taskStates)
        try c.encode(Dictionary(moves.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last }), forKey: .moves)
        try c.encodeIfPresent(createdBy, forKey: .createdBy)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encodeIfPresent(schemaVersion, forKey: .schemaVersion)
    }

    private enum CodingKeys: String, CodingKey {
        case id, babyId, countryCode, city, startDay, endDay, bookings, taskStates, moves, createdBy, createdAt, updatedAt, schemaVersion
    }

    /// 맵(지금 모양)을 읽고, 없으면 배열(초기 모양)도 읽는다. 빠졌으면 빈 배열.
    private static func decodeKeyed<T: Decodable>(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys, as type: T.Type) throws -> [T] {
        guard c.contains(key) else { return [] }
        if let map = try? c.decode([String: T].self, forKey: key) { return Array(map.values) }
        return try c.decodeIfPresent([T].self, forKey: key) ?? []
    }

    /// 여행 첫날부터 마지막 날까지 각 날의 0시. 날짜 키가 깨졌거나 거꾸로면 빈 배열.
    func days(calendar: Calendar) -> [Date] {
        guard let start = Trip.date(fromDayKey: startDay, calendar: calendar),
              let end = Trip.date(fromDayKey: endDay, calendar: calendar),
              start <= end else { return [] }
        var days: [Date] = []
        var day = start
        while day <= end {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        dayKeyFormatter(calendar).string(from: date)
    }

    /// 「2027-05-14」 모양인가.
    static func isDayKey(_ key: String) -> Bool {
        key.count == 10 && key.enumerated().allSatisfy { i, c in i == 4 || i == 7 ? c == "-" : c.isASCII && c.isNumber }
    }

    static func date(fromDayKey key: String, calendar: Calendar) -> Date? {
        guard let date = dayKeyFormatter(calendar).date(from: key) else { return nil }
        return calendar.startOfDay(for: date)
    }

    private static func dayKeyFormatter(_ calendar: Calendar) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = calendar.timeZone
        f.dateFormat = "yyyy-MM-dd"
        f.isLenient = false
        return f
    }
}

/// 예약 하나 — 항공편 · 숙소 · 렌터카. 종류에 맞는 칸만 채운다.
struct TripBooking: Identifiable, Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case flight
        case hotel
        case rentalCar = "rental_car"
        /// 신버전이 만든 종류를 읽기만 하는 센티넬 — 저장하면 throw(덮어써서 지우지 않게).
        case unknown

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Kind(rawValue: raw) ?? .unknown
        }

        func encode(to encoder: Encoder) throws {
            guard self != .unknown else {
                throw EncodingError.invalidValue(self, .init(codingPath: encoder.codingPath,
                                                             debugDescription: "unknown 예약 종류는 저장하지 않는다"))
            }
            var c = encoder.singleValueContainer()
            try c.encode(rawValue)
        }
    }

    var id: String
    var kind: Kind
    // 항공편
    /// IATA 항공사 코드(예: KE).
    var airline: String?
    var flightNumber: String?
    /// IATA 공항 코드(예: ICN · KIX).
    var fromAirport: String?
    var toAirport: String?
    // 숙소
    var name: String?
    var address: String?
    /// 체크인 마감 — 하루 중 몇 분째(22:00 = 1320). 날짜가 없어 체크인 날을 고쳐도 어긋나지 않는다.
    var checkInUntilMinute: Int?
    // 렌터카
    var company: String?
    var pickupPlace: String?
    var returnPlace: String?
    /// 인수·반납 장소를 찾아 골랐을 때의 주소 — 길찾기가 이름 대신 이것을 본다(같은 이름이 다른 지역에도 있다 · 2026-11-14).
    /// 이름을 칩·직접 입력으로 바꾸면 비운다(옛 주소로 길을 찾지 않게 · TripBookingForm).
    var pickupAddress: String?
    var returnAddress: String?
    // 일시 — 시각까지 알면 …At, 시각 미정이면 …Day 하나만 쓴다(ADR-0001).
    // 🔴 밖에서는 depart 처럼 TripWhen 으로만 읽는다 — 칸을 직접 읽으면 시각 미정을 00:00 으로 읽는 길이 다시 열린다.
    //    같은 키의 타입을 바꾸면 옛 빌드가 여행 문서를 통째로 버리므로 칸을 둘로 둔다.
    private var departAt: Date?
    private var departDay: String?
    private var arriveAt: Date?
    private var arriveDay: String?
    private var checkInAt: Date?
    private var checkInDay: String?
    private var checkOutAt: Date?
    private var checkOutDay: String?
    private var pickupAt: Date?
    private var pickupDay: String?
    private var returnAt: Date?
    private var returnDay: String?
    private var freeCancelUntil: Date?
    private var freeCancelDay: String?

    init(
        id: String = UUID().uuidString,
        kind: Kind,
        airline: String? = nil,
        flightNumber: String? = nil,
        fromAirport: String? = nil,
        toAirport: String? = nil,
        depart: TripWhen? = nil,
        arrive: TripWhen? = nil,
        name: String? = nil,
        address: String? = nil,
        checkIn: TripWhen? = nil,
        checkOut: TripWhen? = nil,
        checkInUntilMinute: Int? = nil,
        company: String? = nil,
        pickupPlace: String? = nil,
        pickupAddress: String? = nil,
        pickup: TripWhen? = nil,
        returnPlace: String? = nil,
        returnAddress: String? = nil,
        carReturn: TripWhen? = nil,
        freeCancel: TripWhen? = nil
    ) {
        self.id = id
        self.kind = kind
        self.airline = airline
        self.flightNumber = flightNumber
        self.fromAirport = fromAirport
        self.toAirport = toAirport
        self.name = name
        self.address = address
        self.checkInUntilMinute = checkInUntilMinute
        self.company = company
        self.pickupPlace = pickupPlace
        self.pickupAddress = pickupAddress
        self.returnPlace = returnPlace
        self.returnAddress = returnAddress
        self.depart = depart
        self.arrive = arrive
        self.checkIn = checkIn
        self.checkOut = checkOut
        self.pickup = pickup
        self.carReturn = carReturn
        self.freeCancel = freeCancel
    }

    // MARK: - 일시

    var depart: TripWhen? {
        get { TripWhen(at: departAt, day: departDay) }
        set { (departAt, departDay) = (newValue?.time, newValue?.dayOnlyKey) }
    }

    var arrive: TripWhen? {
        get { TripWhen(at: arriveAt, day: arriveDay) }
        set { (arriveAt, arriveDay) = (newValue?.time, newValue?.dayOnlyKey) }
    }

    var checkIn: TripWhen? {
        get { TripWhen(at: checkInAt, day: checkInDay) }
        set { (checkInAt, checkInDay) = (newValue?.time, newValue?.dayOnlyKey) }
    }

    var checkOut: TripWhen? {
        get { TripWhen(at: checkOutAt, day: checkOutDay) }
        set { (checkOutAt, checkOutDay) = (newValue?.time, newValue?.dayOnlyKey) }
    }

    var pickup: TripWhen? {
        get { TripWhen(at: pickupAt, day: pickupDay) }
        set { (pickupAt, pickupDay) = (newValue?.time, newValue?.dayOnlyKey) }
    }

    var carReturn: TripWhen? {
        get { TripWhen(at: returnAt, day: returnDay) }
        set { (returnAt, returnDay) = (newValue?.time, newValue?.dayOnlyKey) }
    }

    /// 예약 메일에 적힌 무료 취소 기한(숙소·렌터카). 그 예약의 아기 확인 일의 마감이 된다.
    var freeCancel: TripWhen? {
        get { TripWhen(at: freeCancelUntil, day: freeCancelDay) }
        set { (freeCancelUntil, freeCancelDay) = (newValue?.time, newValue?.dayOnlyKey) }
    }

    /// 국내 공항에서 떠나면 가는 편 · 국내 공항으로 오면 오는 편.
    var flightLeg: String? {
        if let from = fromAirport?.uppercased(), TripRoutePlace.homeAirports.contains(from) { return "가는 편" }
        if let to = toAirport?.uppercased(), TripRoutePlace.homeAirports.contains(to) { return "오는 편" }
        return nil
    }

    /// 편을 줄 세우는 글자 — 출발, 없으면 도착.
    func flightOrder(_ calendar: Calendar) -> String {
        (depart ?? arrive).sortKey(calendar)
    }
}

/// 할 일 하나의 사람 쪽 상태 — 할 일 자체는 계산하고, 완료·담당만 저장한다. taskId = TripTask.id(안정 id).
struct TripTaskState: Codable, Hashable {
    var taskId: String
    var isDone: Bool
    var doneAt: Date?
    /// 체크한 보호자의 Firebase UID.
    var doneBy: String?
    var assignee: TripAssignee?
}

/// 담당 — 계정이 아니라 넷 중에서 고른다(관계 값이 보호자마다 흩어져 있어 계정과 잇지 않는다).
enum TripAssignee: String, Codable, Hashable {
    case mother
    case father
    case both
    case unassigned
    /// 신버전 값을 읽기만 하는 센티넬 — 저장하면 throw.
    case unknown

    static let selectable: [TripAssignee] = [.mother, .father, .both, .unassigned]

    var label: String {
        switch self {
        case .mother: return "엄마"
        case .father: return "아빠"
        case .both: return "함께"
        case .unassigned: return "담당 없음"
        case .unknown: return "담당 없음"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TripAssignee(rawValue: raw) ?? .unknown
    }

    func encode(to encoder: Encoder) throws {
        guard self != .unknown else {
            throw EncodingError.invalidValue(self, .init(codingPath: encoder.codingPath,
                                                         debugDescription: "unknown 담당은 저장하지 않는다"))
        }
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

/// 직접 넣은 이동 — 이번 판은 구글지도로 열어 보고 걸리는 분을 사람이 적는다.
struct TripMove: Identifiable, Codable, Hashable {
    var id: String
    var startAt: Date
    var minutes: Int
    var fromLabel: String
    var toLabel: String
    /// 출발지·도착지를 찾아 골랐을 때의 주소 — 차 시간을 물을 때 이름 대신 이것을 본다(같은 이름 다른 지역 · 2026-11-14).
    var fromAddress: String? = nil
    var toAddress: String? = nil

    var endAt: Date { startAt.addingTimeInterval(TimeInterval(minutes * 60)) }
}
