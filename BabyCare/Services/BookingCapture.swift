import CoreGraphics
import Foundation

// MARK: - 캡처로 추가(PO 2026-11-05 「캡처본을 이미지로 올리면 그걸 분석해줄 수는 없나?」 · 설계 §9)
// 예약 확인 화면 캡처 → 글자 읽기(Vision) → 예약 뽑기(애플 인텔리전스 · 안 되면 규칙으로 항공편만) → TripBooking.
// 전부 폰 안에서 한다 — 캡처는 밖으로 나가지 않는다. ⛔ 모르는 칸은 지어 넣지 않고 「확인 필요」로 말한다.

/// 캡처 글에서 뽑은 예약 — 아직 글자 그대로(기기 모델·규칙이 같은 모양으로 낸다). 바꾸기는 CaptureBookingBuilder.
struct CaptureExtraction: Equatable, Sendable {
    struct Flight: Equatable, Sendable {
        var flightNumber: String?
        var date: String?
        var departTime: String?
        var arriveTime: String?
        var fromAirport: String?
        var toAirport: String?
    }

    struct Hotel: Equatable, Sendable {
        var name: String?
        var address: String?
        var checkInDate: String?
        var checkInTime: String?
        var checkOutDate: String?
        var checkOutTime: String?
        var freeCancelDate: String?
        var freeCancelTime: String?
    }

    struct Rental: Equatable, Sendable {
        var company: String?
        var pickupPlace: String?
        var pickupDate: String?
        var pickupTime: String?
        var returnPlace: String?
        var returnDate: String?
        var returnTime: String?
        var freeCancelDate: String?
        var freeCancelTime: String?
    }

    var flights: [Flight] = []
    var hotels: [Hotel] = []
    var rentals: [Rental] = []

    var isEmpty: Bool { flights.isEmpty && hotels.isEmpty && rentals.isEmpty }

    mutating func append(_ other: CaptureExtraction) {
        flights += other.flights
        hotels += other.hotels
        rentals += other.rentals
    }
}

/// 어떤 방식으로 읽었나 — 화면에 한 줄로 말한다.
enum CaptureReader: Equatable, Sendable {
    /// 애플 인텔리전스(기기 안 언어 모델) — 항공편·숙소·렌터카.
    case appleIntelligence
    /// 규칙 — 항공편만(편명 · 날짜 · 시각 · 공항).
    case rulesFlightsOnly
}

enum CaptureError: Error, Equatable {
    case unreadableImage
    case modelUnavailable
}

struct CaptureClock: Equatable, Sendable {
    let hour: Int
    let minute: Int
}

/// 캡처 → 글자. 캡처 한 장 = 글 하나(위에서 아래 줄 순서).
protocol CaptureTextReading: Sendable {
    func texts(from images: [Data]) async throws -> [String]
}

/// 글자 → 예약(아직 글자 그대로).
protocol CaptureExtracting: Sendable {
    var reader: CaptureReader { get }
    func extract(from text: String) async throws -> CaptureExtraction
}

/// 숙소 이름 → 주소(캡처에 주소가 없을 때 지도에서 한 번 찾는다).
protocol PlaceAddressLooking: Sendable {
    func address(for name: String, near area: TripRouteArea) async -> String?
}

// MARK: - 찾은 예약 하나(아직 저장 전)

struct CapturedBooking: Identifiable, Equatable, Sendable {
    /// 사람이 확인해야 하는 칸 — 화면에 빨갛게 「… 확인 필요」.
    enum Need: Int, Comparable, Hashable, Sendable {
        case date, departTime, arriveTime, airports
        case hotelName, stayDates, stayTime
        case pickupTime, returnTime
        case freeCancel

        static func < (lhs: Need, rhs: Need) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    var id: String { booking.id }
    var booking: TripBooking
    var needs: [Need]
    /// 여행에 이미 있는 예약 — 기본으로 끈다.
    var isDuplicate: Bool
    var selected: Bool
    /// 항공편 날 — 시각을 몰라도 날짜는 안다(시간표로 비는 칸을 채울 때 쓴다).
    var day: Date?
    /// 「이미 있음」이면 그 여행의 어느 예약과 같은가 — 넣을 때 새로 더하지 않고 그 예약을 고친다(2026-11-14).
    var existingBookingId: String? = nil
}

// MARK: - 날짜 · 시각 읽기 — 순수 함수

/// 캡처 글의 날짜·시각. 2027.05.10 · 2027년 5월 10일 · 5월 10일 · 5/10(월) · May 10 · 10 MAY 2027 · 10MAY · 2027年5月10日.
/// 연도가 없으면 여행 기간에 가장 가까운 해(연말 여행의 「1월 2일」은 다음 해).
enum CaptureDateParser {
    private static let monthNames = ["JAN": 1, "FEB": 2, "MAR": 3, "APR": 4, "MAY": 5, "JUN": 6,
                                      "JUL": 7, "AUG": 8, "SEP": 9, "OCT": 10, "NOV": 11, "DEC": 12]
    private static let mon = "(JAN|FEB|MAR|APR|MAY|JUN|JUL|AUG|SEP|OCT|NOV|DEC)[A-Z]*\\.?"

    private enum Shape { case ymd, md, mdNumeric, dMonY, monDY }

    private static let patterns: [(Shape, NSRegularExpression)] = [
        (.ymd, rx("(20\\d{2})\\s*[.\\-/년年]\\s*(\\d{1,2})\\s*[.\\-/월月]\\s*(\\d{1,2})(?!\\d)\\s*[일日]?")),
        (.md, rx("(?<!\\d)(\\d{1,2})\\s*[월月]\\s*(\\d{1,2})\\s*[일日]")),
        (.mdNumeric, rx("(?<![\\d.,/])(\\d{1,2})\\s*[./]\\s*(\\d{1,2})(?![\\d.:,])(\\s*\\(\\s*[월화수목금토일月火水木金土日]\\s*\\))?")),
        (.dMonY, rx("(?<![A-Z0-9])(\\d{1,2})\\s*\(mon)(?:,?\\s*(20\\d{2}))?")),
        (.monDY, rx("(?<![A-Z])\(mon)\\s+(\\d{1,2})(?:ST|ND|RD|TH)?(?!\\d)(?:,?\\s*(20\\d{2}))?")),
    ]

    private static func rx(_ p: String) -> NSRegularExpression {
        // 고정 패턴 — 틀리면 첫 테스트에서 죽는다.
        // swiftlint:disable:next force_try
        try! NSRegularExpression(pattern: p, options: [.caseInsensitive])
    }

    /// 글에서 처음 나오는 날짜(그날 0시).
    static func day(in text: String, tripDays: [Date], calendar: Calendar) -> Date? {
        matches(in: text, tripDays: tripDays, calendar: calendar).first?.date
    }

    /// 날짜가 있는 줄인가.
    static func hasDate(_ text: String, tripDays: [Date], calendar: Calendar) -> Bool {
        day(in: text, tripDays: tripDays, calendar: calendar) != nil
    }

    private static func matches(in text: String, tripDays: [Date], calendar: Calendar) -> [(range: NSRange, date: Date)] {
        let ns = text as NSString
        let upper = text.uppercased()
        var found: [(range: NSRange, date: Date)] = []
        for (shape, regex) in patterns {
            for m in regex.matches(in: upper, range: NSRange(location: 0, length: ns.length)) {
                guard !found.contains(where: { NSIntersectionRange($0.range, m.range).length > 0 }) else { continue }
                func g(_ i: Int) -> String? {
                    guard i < m.numberOfRanges else { return nil }
                    let r = m.range(at: i)
                    return r.location == NSNotFound ? nil : (upper as NSString).substring(with: r)
                }
                var year: Int?
                var month: Int?
                var dayNum: Int?
                switch shape {
                case .ymd: year = g(1).flatMap(Int.init); month = g(2).flatMap(Int.init); dayNum = g(3).flatMap(Int.init)
                case .md, .mdNumeric: month = g(1).flatMap(Int.init); dayNum = g(2).flatMap(Int.init)
                case .dMonY: dayNum = g(1).flatMap(Int.init); month = g(2).map { monthNames[String($0.prefix(3))] ?? 0 }; year = g(3).flatMap(Int.init)
                case .monDY: month = g(1).map { monthNames[String($0.prefix(3))] ?? 0 }; dayNum = g(2).flatMap(Int.init); year = g(3).flatMap(Int.init)
                }
                guard let month, let dayNum, (1...12).contains(month), (1...31).contains(dayNum) else { continue }
                guard let date = resolve(year: year, month: month, day: dayNum, tripDays: tripDays, calendar: calendar) else { continue }
                // 숫자만 있는 「1.5」 꼴은 요일이 붙었거나 여행 앞뒤 일주일 안일 때만 날짜로 본다(무게·금액과 헷갈린다).
                if shape == .mdNumeric, g(3) == nil, !nearTrip(date, tripDays: tripDays, calendar: calendar) { continue }
                found.append((m.range, date))
            }
        }
        return found.sorted { $0.range.location < $1.range.location }
    }

    private static func resolve(year: Int?, month: Int, day: Int, tripDays: [Date], calendar: Calendar) -> Date? {
        func make(_ y: Int) -> Date? {
            let c = DateComponents(year: y, month: month, day: day)
            guard c.isValidDate(in: calendar), let d = calendar.date(from: c) else { return nil }
            return calendar.startOfDay(for: d)
        }
        if let year { return make(year) }
        let reference = tripDays.first ?? calendar.startOfDay(for: Date())
        let base = calendar.component(.year, from: reference)
        let candidates = [base - 1, base, base + 1].compactMap(make)
        return candidates.min { distance($0, tripDays: tripDays, reference: reference) < distance($1, tripDays: tripDays, reference: reference) }
    }

    private static func distance(_ d: Date, tripDays: [Date], reference: Date) -> TimeInterval {
        guard let first = tripDays.first, let last = tripDays.last else { return abs(d.timeIntervalSince(reference)) }
        if d < first { return first.timeIntervalSince(d) }
        if d > last { return d.timeIntervalSince(last) }
        return 0
    }

    private static func nearTrip(_ d: Date, tripDays: [Date], calendar: Calendar) -> Bool {
        guard let first = tripDays.first, let last = tripDays.last,
              let lo = calendar.date(byAdding: .day, value: -7, to: first),
              let hi = calendar.date(byAdding: .day, value: 7, to: last) else { return false }
        return d >= lo && d <= hi
    }

    // MARK: 시각

    private static let colonTime = rx("(오전|오후|AM|PM|午前|午後)?\\s*(?<![\\d.:])([01]?\\d|2[0-3])\\s*:\\s*([0-5]\\d)(?![\\d:])(\\s*(?:AM|PM))?")
    private static let wordTime = rx("(오전|오후|午前|午後)?\\s*(?<!\\d)([01]?\\d|2[0-3])\\s*[시時](?!간)\\s*(?:([0-5]?\\d)\\s*[분分])?")

    /// 글의 시각들(나온 순서) — 15:10 · 오후 3:10 · 9:30 PM · 15시 10분 · 15時10分.
    static func times(in text: String) -> [CaptureClock] {
        let upper = text.uppercased()
        let ns = upper as NSString
        var found: [(Int, CaptureClock)] = []
        for regex in [colonTime, wordTime] {
            for m in regex.matches(in: upper, range: NSRange(location: 0, length: ns.length)) {
                func g(_ i: Int) -> String? {
                    guard i < m.numberOfRanges else { return nil }
                    let r = m.range(at: i)
                    return r.location == NSNotFound ? nil : ns.substring(with: r).trimmingCharacters(in: .whitespaces)
                }
                guard var hour = g(2).flatMap(Int.init) else { continue }
                let minute = g(3).flatMap(Int.init) ?? 0
                let marker = [g(1), g(4)].compactMap { $0 }.first ?? ""
                if ["오후", "PM", "午後"].contains(marker), hour < 12 { hour += 12 }
                if ["오전", "AM", "午前"].contains(marker), hour == 12 { hour = 0 }
                guard (0...23).contains(hour), (0...59).contains(minute) else { continue }
                found.append((m.range.location, CaptureClock(hour: hour, minute: minute)))
            }
        }
        return found.sorted { $0.0 < $1.0 }.map(\.1)
    }

    static func time(_ text: String) -> CaptureClock? {
        times(in: text).first
    }
}

// MARK: - 글자 조각 → 줄

enum CaptureTextLayout {
    /// Vision 조각(정규화 좌표 · 왼쪽 아래가 0) → 위에서 아래 줄 · 줄 안은 왼쪽부터 띄어 붙인다.
    static func lines(_ pieces: [(CGRect, String)]) -> String {
        let sorted = pieces.sorted { $0.0.midY > $1.0.midY }
        var rows: [[(CGRect, String)]] = []
        for p in sorted {
            if let anchor = rows.last?.first, abs(anchor.0.midY - p.0.midY) < max(anchor.0.height, p.0.height) * 0.5 {
                rows[rows.count - 1].append(p)
            } else {
                rows.append([p])
            }
        }
        return rows.map { row in row.sorted { $0.0.minX < $1.0.minX }.map(\.1).joined(separator: " ") }.joined(separator: "\n")
    }
}

// MARK: - 공항 이름 → 코드

enum CaptureAirports {
    private static let known: Set<String> = Set(TripRoutePlace.airports.map(\.code))
        .union(["TAE", "CJJ", "KWJ", "MWX", "RSU", "USN", "YNY", "KUV", "WJU", "HIN", "KPO", "SDJ", "HIJ", "KMQ", "TAK", "MYJ",
                "OIT", "KMJ", "NGS", "KOJ", "TPE", "TSA", "KHH", "HKG", "MFM", "BKK", "DMK", "SGN", "HAN", "DAD", "CXR", "MNL",
                "CEB", "SIN", "KUL", "DPS", "PVG", "SHA", "PEK", "PKX", "TAO", "GUM", "SPN", "HNL", "LAX", "SFO", "JFK"])

    /// 「ICN」 · 「인천 (ICN)」 · 「오사카/간사이」 · 「関西国際空港」 → 코드. 모르면 nil.
    static func code(for text: String) -> String? {
        let upper = text.uppercased()
        let found = codes(in: upper)
        if let first = found.first { return first }
        return byName(in: text).first
    }

    /// 글에 나온 공항 코드들(나온 순서).
    static func codes(in text: String) -> [String] {
        let upper = text.uppercased()
        let ns = upper as NSString
        let regex = try? NSRegularExpression(pattern: "(?<![A-Z])[A-Z]{3}(?![A-Z])")
        return (regex?.matches(in: upper, range: NSRange(location: 0, length: ns.length)) ?? [])
            .map { ns.substring(with: $0.range) }
            .filter { known.contains($0) }
    }

    /// 글에 나온 공항 이름들(나온 순서) — 한글 이름 · 공식 이름 앞 두 글자(関西 · 成田 …).
    static func byName(in text: String) -> [String] {
        var hits: [(Int, String)] = []
        for airport in TripRoutePlace.airports {
            let keys = airport.names + [String(airport.query.prefix(2))]
            if let pos = keys.compactMap({ text.range(of: $0)?.lowerBound }).min() {
                hits.append((text.distance(from: text.startIndex, to: pos), airport.code))
            }
        }
        return hits.sorted { $0.0 < $1.0 }.map(\.1)
    }
}

// MARK: - 규칙으로 항공편만

/// 애플 인텔리전스가 없는 기기 — 편명 · 날짜 · 시각 · 공항을 규칙으로 찾는다(숙소·렌터카는 못 읽는다).
struct RuleCaptureExtractor: CaptureExtracting {
    var reader: CaptureReader { .rulesFlightsOnly }

    func extract(from text: String) async throws -> CaptureExtraction {
        CaptureExtraction(flights: Self.flights(in: text))
    }

    /// 자주 타는 항공사 코드(한국·일본 노선 중심) — 아무 두 글자나 편명으로 읽지 않게.
    static let airlines: Set<String> = ["KE", "OZ", "7C", "LJ", "TW", "BX", "ZE", "RS", "YP", "RF", "4V", "JL", "NH", "MM", "GK",
                                        "BC", "7G", "IJ", "HD", "NU", "6J", "CI", "BR", "IT", "CX", "HX", "UO", "SQ", "TR", "TG",
                                        "VN", "VJ", "PR", "5J", "MU", "CA", "CZ", "HU", "MF", "FM", "UA", "DL", "AA", "AC", "AF",
                                        "KL", "LH", "BA", "EK", "QR", "EY", "TK", "QF", "NZ", "HA", "D7", "AK", "Z2", "MH", "GA"]

    private static let flightRegex = try? NSRegularExpression(pattern: "(?<![A-Z0-9])([A-Z][A-Z0-9]|[0-9][A-Z])\\s?(\\d{1,4})(?![0-9])")

    static func flightNumbers(in line: String) -> [String] {
        let upper = line.uppercased()
        let ns = upper as NSString
        return (flightRegex?.matches(in: upper, range: NSRange(location: 0, length: ns.length)) ?? []).compactMap { m in
            let code = ns.substring(with: m.range(at: 1))
            guard airlines.contains(code) else { return nil }
            return FlightNumber.normalize(code + ns.substring(with: m.range(at: 2)))
        }
    }

    static func flights(in text: String) -> [CaptureExtraction.Flight] {
        let lines = text.components(separatedBy: .newlines)
        let cal = Calendar(identifier: .gregorian)
        var out: [CaptureExtraction.Flight] = []
        var seen = Set<String>()
        for (i, line) in lines.enumerated() {
            for number in flightNumbers(in: line) {
                // 시각·공항: 그 줄부터 아래로, 다른 편이나 새 날짜가 나오기 전까지(최대 3줄 더).
                var window = [line]
                var j = i + 1
                while j < lines.count, j <= i + 3, flightNumbers(in: lines[j]).isEmpty,
                      !CaptureDateParser.hasDate(lines[j], tripDays: [], calendar: cal) {
                    window.append(lines[j])
                    j += 1
                }
                let body = window.joined(separator: "\n")
                // 날짜: 그 줄 → 위로 3줄(가까운 것부터) → 아래 창.
                let above = lines[max(0, i - 3)..<i].reversed()
                let date = ([line] + Array(above) + Array(window.dropFirst())).first { CaptureDateParser.hasDate($0, tripDays: [], calendar: cal) }
                let times = CaptureDateParser.times(in: body)
                var airports = CaptureAirports.codes(in: body)
                if airports.count < 2 { airports = CaptureAirports.byName(in: body) }
                let key = "\(number)|\(date ?? "")"
                guard seen.insert(key).inserted else { continue }
                out.append(CaptureExtraction.Flight(
                    flightNumber: number, date: date,
                    departTime: times.first.map(Self.clock), arriveTime: times.count > 1 ? Self.clock(times[1]) : nil,
                    fromAirport: airports.first, toAirport: airports.count > 1 ? airports[1] : nil))
            }
        }
        return out
    }

    static func clock(_ c: CaptureClock) -> String { String(format: "%02d:%02d", c.hour, c.minute) }
}

// MARK: - 글자 → 예약

enum CaptureBookingBuilder {
    static func build(_ x: CaptureExtraction, trip: Trip, calendar: Calendar) -> [CapturedBooking] {
        let days = trip.days(calendar: calendar)
        var items: [CapturedBooking] = []
        items += x.flights.compactMap { flight($0, days: days, calendar: calendar) }
        items += x.hotels.compactMap { hotel($0, days: days, calendar: calendar) }
        items += x.rentals.compactMap { rental($0, days: days, calendar: calendar) }
        // 캡처 여러 장에 같은 예약이 있으면 먼저 나온 하나만.
        var seen = Set<String>()
        items = items.filter { seen.insert(key($0.booking, day: $0.day, calendar: calendar)).inserted }
        // 여행에 이미 있는 예약은 「이미 있음」 — 기본으로 끈다. 어느 예약과 같은지 기억한다(넣을 때 그 예약을 고친다).
        var existing: [String: String] = [:]
        for booking in trip.bookings where existing[key(booking, day: nil, calendar: calendar)] == nil {
            existing[key(booking, day: nil, calendar: calendar)] = booking.id
        }
        return items.map { item in
            var i = item
            if let matched = existing[key(i.booking, day: i.day, calendar: calendar)] {
                i.isDuplicate = true
                i.selected = false
                i.existingBookingId = matched
            }
            return i
        }
    }

    /// 「이미 있음」 예약을 넣을 때 — 있던 예약을 캡처(사람이 고친 값)로 고친다.
    /// 이름표(id)·종류는 있던 것 · 캡처에 있는 칸은 캡처 · 캡처가 빈 칸은 있던 값(덜 아는 값으로 덮지 않는다).
    /// 이름과 주소는 짝 — 캡처의 이름이 다르면 있던 주소를 붙이지 않는다(옛 곳으로 길을 찾는다 · pickingHotel 과 같은 규칙).
    static func merged(_ captured: TripBooking, into existing: TripBooking, calendar: Calendar) -> TripBooking {
        var m = existing
        m.airline = captured.airline ?? existing.airline
        m.flightNumber = captured.flightNumber ?? existing.flightNumber
        m.fromAirport = captured.fromAirport ?? existing.fromAirport
        m.toAirport = captured.toAirport ?? existing.toAirport
        m.depart = richer(captured.depart, existing.depart, calendar)
        m.arrive = richer(captured.arrive, existing.arrive, calendar)
        (m.name, m.address) = paired(captured.name, captured.address, existing.name, existing.address)
        m.checkIn = richer(captured.checkIn, existing.checkIn, calendar)
        m.checkOut = richer(captured.checkOut, existing.checkOut, calendar)
        m.checkInUntilMinute = captured.checkInUntilMinute ?? existing.checkInUntilMinute
        m.company = captured.company ?? existing.company
        (m.pickupPlace, m.pickupAddress) = paired(captured.pickupPlace, captured.pickupAddress,
                                                  existing.pickupPlace, existing.pickupAddress)
        (m.returnPlace, m.returnAddress) = paired(captured.returnPlace, captured.returnAddress,
                                                  existing.returnPlace, existing.returnAddress)
        m.pickup = richer(captured.pickup, existing.pickup, calendar)
        m.carReturn = richer(captured.carReturn, existing.carReturn, calendar)
        m.freeCancel = richer(captured.freeCancel, existing.freeCancel, calendar)
        return m
    }

    /// 캡처가 날짜만 알고 있던 값이 같은 날의 시각을 알면 있던 값(시각)을 지킨다.
    private static func richer(_ captured: TripWhen?, _ existing: TripWhen?, _ calendar: Calendar) -> TripWhen? {
        guard let captured else { return existing }
        guard let existing else { return captured }
        if captured.time == nil, existing.time != nil, captured.dayKey(calendar) == existing.dayKey(calendar) {
            return existing
        }
        return captured
    }

    private static func paired(_ name: String?, _ address: String?, _ oldName: String?, _ oldAddress: String?)
        -> (String?, String?) {
        guard let name else { return (oldName, address ?? oldAddress) }
        if name != oldName { return (name, address) }
        return (name, address ?? oldAddress)
    }

    /// 확인 필요 칸 — 예약만 보고(사람이 고친 뒤에도 같은 판정).
    static func needs(for b: TripBooking, day: Date?) -> [CapturedBooking.Need] {
        var n: [CapturedBooking.Need] = []
        switch b.kind {
        case .flight:
            if day == nil && b.depart == nil && b.arrive == nil { n.append(.date) }
            if b.depart?.time == nil { n.append(.departTime) }
            if b.arrive?.time == nil { n.append(.arriveTime) }
            if b.fromAirport == nil || b.toAirport == nil { n.append(.airports) }
        case .hotel:
            if b.name == nil { n.append(.hotelName) }
            if b.checkIn == nil || b.checkOut == nil { n.append(.stayDates) }
            if (b.checkIn != nil && b.checkIn?.time == nil) || (b.checkOut != nil && b.checkOut?.time == nil) { n.append(.stayTime) }
            if b.freeCancel?.time == nil { n.append(.freeCancel) }
        case .rentalCar:
            if b.pickup?.time == nil { n.append(.pickupTime) }
            if b.carReturn?.time == nil { n.append(.returnTime) }
            if b.freeCancel?.time == nil { n.append(.freeCancel) }
        case .unknown:
            break
        }
        return n.sorted()
    }

    /// 사람이 「수정」에서 고친 뒤 — 확인 필요를 다시 잰다.
    /// RED 판(2026-11-14 검토): trip 을 아직 안 본다 — 고치기 전 동작 그대로(처음 맞춘 예약을 그대로 기억).
    static func edited(_ item: CapturedBooking, booking: TripBooking, trip: Trip, calendar: Calendar) -> CapturedBooking {
        var out = item
        out.booking = booking
        out.day = (booking.depart ?? booking.arrive)?.startOfDay(calendar) ?? item.day
        out.needs = needs(for: booking, day: out.day)
        return out
    }

    /// 인천공항 시간표 한 줄로 **비는 칸만** 채운다(캡처에 적힌 값은 그대로).
    static func fill(_ item: CapturedBooking, with row: FlightScheduleRow, calendar: Calendar) -> CapturedBooking {
        guard let day = item.day else { return item }
        var b = item.booking
        let incheonTime = at(day, CaptureClock(hour: row.hour, minute: row.minute), calendar: calendar)
        switch row.direction {
        case .departure:
            if b.fromAirport == nil { b.fromAirport = TripFlightEntry.incheon }
            if b.toAirport == nil { b.toAirport = row.counterpartCode }
            if b.depart?.time == nil { b.depart = .at(incheonTime) }
        case .arrival:
            if b.toAirport == nil { b.toAirport = TripFlightEntry.incheon }
            if b.fromAirport == nil { b.fromAirport = row.counterpartCode }
            if b.arrive?.time == nil { b.arrive = .at(incheonTime) }
        }
        if let d = b.depart?.time, let a = b.arrive?.time, a <= d { b.arrive = calendar.date(byAdding: .day, value: 1, to: a).map(TripWhen.at) }
        var out = item
        out.booking = b
        out.needs = needs(for: b, day: day)
        return out
    }

    // MARK: 종류별

    private static func flight(_ f: CaptureExtraction.Flight, days: [Date], calendar: Calendar) -> CapturedBooking? {
        guard let number = FlightNumber.normalize(f.flightNumber ?? "") else { return nil }
        let day = f.date.flatMap { CaptureDateParser.day(in: $0, tripDays: days, calendar: calendar) }
        var b = TripBooking(kind: .flight)
        b.flightNumber = number
        b.airline = TripFlightEntry.airlineCode(number)
        b.fromAirport = f.fromAirport.flatMap(CaptureAirports.code)
        b.toAirport = f.toAirport.flatMap(CaptureAirports.code)
        if let day {
            b.depart = when(day, f.departTime.flatMap(CaptureDateParser.time), calendar: calendar)
            if let t = f.arriveTime.flatMap(CaptureDateParser.time) {
                var arrive = at(day, t, calendar: calendar)
                // 밤 비행 — 도착이 출발보다 이르면 다음 날.
                if let d = b.depart?.time, arrive <= d { arrive = calendar.date(byAdding: .day, value: 1, to: arrive) ?? arrive }
                b.arrive = .at(arrive)
            }
        }
        return CapturedBooking(booking: b, needs: needs(for: b, day: day), isDuplicate: false, selected: true, day: day)
    }

    private static func hotel(_ h: CaptureExtraction.Hotel, days: [Date], calendar: Calendar) -> CapturedBooking? {
        let name = trimmed(h.name)
        let inDay = h.checkInDate.flatMap { CaptureDateParser.day(in: $0, tripDays: days, calendar: calendar) }
        let outDay = h.checkOutDate.flatMap { CaptureDateParser.day(in: $0, tripDays: days, calendar: calendar) }
        guard name != nil || inDay != nil else { return nil }
        var b = TripBooking(kind: .hotel)
        b.name = name
        b.address = trimmed(h.address)
        b.checkIn = inDay.map { when($0, h.checkInTime.flatMap(CaptureDateParser.time), calendar: calendar) }
        b.checkOut = outDay.map { when($0, h.checkOutTime.flatMap(CaptureDateParser.time), calendar: calendar) }
        b.freeCancel = h.freeCancelDate.flatMap { CaptureDateParser.day(in: $0, tripDays: days, calendar: calendar) }
            .map { when($0, h.freeCancelTime.flatMap(CaptureDateParser.time), calendar: calendar) }
        return CapturedBooking(booking: b, needs: needs(for: b, day: inDay), isDuplicate: false, selected: true, day: inDay)
    }

    private static func rental(_ r: CaptureExtraction.Rental, days: [Date], calendar: Calendar) -> CapturedBooking? {
        let pickDay = r.pickupDate.flatMap { CaptureDateParser.day(in: $0, tripDays: days, calendar: calendar) }
        let backDay = r.returnDate.flatMap { CaptureDateParser.day(in: $0, tripDays: days, calendar: calendar) }
        guard pickDay != nil || trimmed(r.pickupPlace) != nil || trimmed(r.company) != nil else { return nil }
        var b = TripBooking(kind: .rentalCar)
        b.company = trimmed(r.company)
        b.pickupPlace = trimmed(r.pickupPlace)
        b.returnPlace = trimmed(r.returnPlace)
        b.pickup = pickDay.map { when($0, r.pickupTime.flatMap(CaptureDateParser.time), calendar: calendar) }
        b.carReturn = backDay.map { when($0, r.returnTime.flatMap(CaptureDateParser.time), calendar: calendar) }
        b.freeCancel = r.freeCancelDate.flatMap { CaptureDateParser.day(in: $0, tripDays: days, calendar: calendar) }
            .map { when($0, r.freeCancelTime.flatMap(CaptureDateParser.time), calendar: calendar) }
        return CapturedBooking(booking: b, needs: needs(for: b, day: pickDay), isDuplicate: false, selected: true, day: pickDay)
    }

    // MARK: 같은 예약인가

    private static func key(_ b: TripBooking, day: Date?, calendar: Calendar) -> String {
        func dayKey(_ when: TripWhen?) -> String {
            when?.dayKey(calendar) ?? day.map { Trip.dayKey($0, calendar: calendar) } ?? "?"
        }
        switch b.kind {
        case .flight:
            return "F|\(b.flightNumber ?? "")|\(dayKey(b.depart ?? b.arrive))"
        case .hotel:
            return "H|\((b.name ?? "").lowercased())|\(dayKey(b.checkIn))"
        case .rentalCar:
            return "R|\(dayKey(b.pickup))|\((b.pickupPlace ?? b.company ?? "").lowercased())"
        case .unknown:
            return "U|\(b.id)"
        }
    }

    /// 시각을 읽었으면 그 시각, 못 읽었으면 날짜만 — ⛔ 지어 넣지 않는다(ADR-0001).
    private static func when(_ day: Date, _ t: CaptureClock?, calendar: Calendar) -> TripWhen {
        t.map { .at(at(day, $0, calendar: calendar)) } ?? .day(Trip.dayKey(day, calendar: calendar))
    }

    private static func at(_ day: Date, _ t: CaptureClock, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: t.hour, minute: t.minute, second: 0, of: calendar.startOfDay(for: day)) ?? day
    }

    private static func trimmed(_ s: String?) -> String? {
        guard let v = s?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return nil }
        return v
    }
}

// MARK: - 화면 글자 — 순수 함수

enum CaptureBookingText {
    static func title(_ b: TripBooking) -> String {
        switch b.kind {
        case .flight:
            let number = b.flightNumber ?? "항공편"
            if let from = b.fromAirport, TripRoutePlace.homeAirports.contains(from) { return "\(number) 가는 편" }
            if let to = b.toAirport, TripRoutePlace.homeAirports.contains(to) { return "\(number) 오는 편" }
            return number
        case .hotel:
            return b.name ?? "숙소"
        case .rentalCar:
            return "\(b.pickupPlace ?? b.company ?? "렌터카") 인수"
        case .unknown:
            return "예약"
        }
    }

    static func detail(_ b: TripBooking, calendar: Calendar) -> String {
        switch b.kind {
        case .flight:
            let day = (b.depart ?? b.arrive).map { TripDateText.day($0, calendar: calendar) }
            let left = [place(b.fromAirport), b.depart?.time.map { TripDateText.time($0, calendar: calendar) }].compactMap { $0 }.joined(separator: " ")
            let right = [place(b.toAirport), b.arrive?.time.map { TripDateText.time($0, calendar: calendar) }].compactMap { $0 }.joined(separator: " ")
            return [day, "\(left.isEmpty ? "?" : left) → \(right.isEmpty ? "?" : right)"].compactMap { $0 }.joined(separator: " ")
        case .hotel:
            let range = [b.checkIn, b.checkOut].compactMap { $0 }.map { TripDateText.day($0, calendar: calendar) }.joined(separator: "–")
            return [range.isEmpty ? nil : range, b.address].compactMap { $0 }.joined(separator: " · ")
        case .rentalCar:
            let pick = b.pickup.map { "인수 \(TripDateText.when($0, calendar: calendar))" }
            let back = b.carReturn.map { "반납 \(TripDateText.when($0, calendar: calendar))" }
            return [pick, back].compactMap { $0 }.joined(separator: " · ")
        case .unknown:
            return ""
        }
    }

    static func needs(_ needs: [CapturedBooking.Need]) -> String {
        needs.map(label).joined(separator: " · ")
    }

    static func label(_ need: CapturedBooking.Need) -> String {
        switch need {
        case .date: return "날짜 확인 필요"
        case .departTime: return "출발 시각 확인 필요"
        case .arriveTime: return "도착 시각 확인 필요"
        case .airports: return "공항 확인 필요"
        case .hotelName: return "숙소 이름 확인 필요"
        case .stayDates: return "체크인·체크아웃 날짜 확인 필요"
        case .stayTime: return "체크인·체크아웃 시각 확인 필요"
        case .pickupTime: return "인수 시각 확인 필요"
        case .returnTime: return "반납 시각 확인 필요"
        case .freeCancel: return "무료 취소 기한 확인 필요"
        }
    }

    private static func place(_ code: String?) -> String? {
        guard let code else { return nil }
        return TripRoutePlace.airports.first { $0.code == code }?.names.first ?? code
    }
}
