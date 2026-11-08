import Foundation

/// 인천공항 운항 정보의 두 목록 — 인천에서 뜨는 편 · 인천에 내리는 편.
enum FlightDirection: String, Sendable, Hashable {
    case departure
    case arrival
}

/// 인천공항이 알려 준 한 편의 지금 상태(공공데이터포털 「여객편 운항현황」 · 당일치만 준다).
struct FlightLiveStatus: Equatable, Sendable {
    let flightId: String
    let direction: FlightDirection
    /// 예정 시각 — 출발 편은 인천 출발, 도착 편은 인천 도착.
    let scheduled: Date?
    /// 공항이 새로 알린 시각.
    let estimated: Date?
    /// 공항 표기 그대로(출발 · 지연 · 결항 · 탑승중 …).
    let remark: String?
    let gate: String?
    /// T1 · T2 · 탑승동.
    let terminal: String?
    /// 상대 공항(공항 표기).
    let counterpart: String?
    /// 도착 편: 수하물 수취대 · 출구.
    let carousel: String?
    let exit: String?
    let fetchedAt: Date

    /// 예정보다 15분 이상 늦으면 지연 — 미국 교통통계국(BTS)의 정시 기준과 같은 선.
    static let delayThresholdMinutes = 15

    var delayMinutes: Int? {
        guard let scheduled, let estimated else { return nil }
        return Int((estimated.timeIntervalSince(scheduled) / 60).rounded())
    }

    var isCancelled: Bool { remark?.contains("결항") == true }
    var isDiverted: Bool { remark?.contains("회항") == true }

    var isDelayed: Bool {
        guard !isCancelled else { return false }
        return remark?.contains("지연") == true || (delayMinutes ?? 0) >= Self.delayThresholdMinutes
    }
}

enum FlightStatusError: Error, Equatable {
    /// 로그인 토큰을 못 받았다 — 여행 중계 서버에 묻지 않았다(키는 서버에만 · v2.8.13).
    case notSignedIn
    /// 답을 못 받았다(네트워크 · 시간 초과).
    case network
    /// 받았는데 읽을 수 없다(키 오류는 200 + XML 로 온다).
    case badResponse(String)
}

/// 편명 맞추기 — 「ke 725」 · 「KE0725」 → 「KE725」. 항공사 코드 두 자 + 숫자.
enum FlightNumber {
    static func normalize(_ raw: String) -> String? {
        let compact = raw.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        guard compact.count >= 3 else { return nil }
        let code = String(compact.prefix(2))
        let digits = compact.dropFirst(2)
        guard code.contains(where: \.isLetter), digits.count <= 5, digits.allSatisfy(\.isNumber) else { return nil }
        let number = digits.drop { $0 == "0" }
        return code + (number.isEmpty ? "0" : String(number))
    }
}

/// 공공데이터포털 응답 읽기 — 순수 함수.
/// ⚠️ 오류도 HTTP 200 으로 온다(틀린 키 = XML) · 한 편만 오면 items 가 {"item": {...}} · 없으면 [] 또는 "".
enum FlightStatusParser {
    /// 인천공항 시각은 한국 시각이다(기기 시간대와 무관).
    static let seoul: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return c
    }()

    static func parse(_ data: Data, direction: FlightDirection, day: Date, fetchedAt: Date, calendar: Calendar) throws -> [FlightLiveStatus] {
        try items(in: data).compactMap { row($0, direction: direction, day: day, fetchedAt: fetchedAt, calendar: calendar) }
    }

    /// 공공데이터포털 공통 — 헤더(resultCode 00)를 본 뒤 줄 목록. 운항 정보 · 정기 시간표가 같이 쓴다.
    static func items(in data: Data) throws -> [[String: Any]] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let response = root["response"] as? [String: Any] else {
            throw FlightStatusError.badResponse(errorText(data))
        }
        let code = text((response["header"] as? [String: Any])?["resultCode"])
        guard code == "00" else { throw FlightStatusError.badResponse("resultCode \(code ?? "?")") }
        let body = response["body"] as? [String: Any]
        return rows(body?["items"])
    }

    static func terminal(_ id: String) -> String? {
        switch id.uppercased() {
        case "P01": return "T1"
        case "P02": return "탑승동"
        case "P03": return "T2"
        default: return nil
        }
    }

    /// 「1510」(그날 시각) 또는 「202705101510」.
    static func time(_ raw: String?, day: Date, calendar: Calendar) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespaces), raw.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        func num(_ from: Int, _ length: Int) -> Int? {
            let start = raw.index(raw.startIndex, offsetBy: from)
            return Int(raw[start..<raw.index(start, offsetBy: length)])
        }
        switch raw.count {
        case 4:
            guard let h = num(0, 2), let m = num(2, 2) else { return nil }
            return calendar.date(bySettingHour: h, minute: m, second: 0, of: day)
        case 12:
            guard let y = num(0, 4), let mo = num(4, 2), let d = num(6, 2), let h = num(8, 2), let mi = num(10, 2) else { return nil }
            return calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))
        default:
            return nil
        }
    }

    private static func rows(_ items: Any?) -> [[String: Any]] {
        if let list = items as? [Any] { return list.compactMap { $0 as? [String: Any] } }
        if let wrapper = items as? [String: Any] {
            if let list = wrapper["item"] as? [Any] { return list.compactMap { $0 as? [String: Any] } }
            if let one = wrapper["item"] as? [String: Any] { return [one] }
        }
        return []
    }

    private static func row(_ r: [String: Any], direction: FlightDirection, day: Date, fetchedAt: Date, calendar: Calendar) -> FlightLiveStatus? {
        guard let id = FlightNumber.normalize(text(r["flightId"]) ?? "") else { return nil }
        let scheduled = time(text(r["scheduleDateTime"]), day: day, calendar: calendar)
        var estimated = time(text(r["estimatedDateTime"]), day: day, calendar: calendar)
        // 「2350 → 0030」 — 자정을 넘겨 늦어지면 바뀐 시각은 다음 날이다.
        if let s = scheduled, let e = estimated, e < s.addingTimeInterval(-12 * 3600) {
            estimated = calendar.date(byAdding: .day, value: 1, to: e)
        }
        return FlightLiveStatus(flightId: id, direction: direction, scheduled: scheduled, estimated: estimated,
                                remark: nonEmpty(r["remark"]), gate: nonEmpty(r["gatenumber"]),
                                terminal: terminal(text(r["terminalId"]) ?? ""),
                                counterpart: nonEmpty(r["airport"])?.replacingOccurrences(of: "/ ", with: "/"),
                                carousel: nonEmpty(r["carousel"]), exit: nonEmpty(r["exitnumber"]), fetchedAt: fetchedAt)
    }

    static func text(_ value: Any?) -> String? {
        if let s = value as? String { return s }
        if let n = value as? NSNumber { return n.stringValue }
        return nil
    }

    static func nonEmpty(_ value: Any?) -> String? {
        guard let s = text(value)?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else { return nil }
        return s
    }

    /// 키 오류 XML 의 사유만 — 기록용(키 값은 응답에 없다).
    private static func errorText(_ data: Data) -> String {
        let head = String(bytes: data.prefix(400), encoding: .utf8) ?? ""
        for tag in ["returnAuthMsg", "errMsg", "resultMsg"] {
            if let open = head.range(of: "<\(tag)>"), let close = head.range(of: "</\(tag)>", range: open.upperBound..<head.endIndex) {
                return String(head[open.upperBound..<close.lowerBound])
            }
        }
        return "JSON 아님"
    }
}

/// 운항 정보를 묻는 쪽 — 뷰모델이 이 면에만 의존한다(테스트는 목으로).
protocol FlightStatusProviding: Sendable {
    /// 오늘 인천공항 목록에서 그 편 — 목록에 없으면 nil.
    func status(flightId: String, direction: FlightDirection, day: Date) async throws -> FlightLiveStatus?
}

/// 공공데이터포털 「인천국제공항공사_여객편 운항현황(다국어)」 — 여행 중계 서버를 거쳐 묻는다(키는 서버에만 · `TravelServer`).
/// 🔑 서버의 키 = 파킹24 와 같은 개발계정 키(PO 2026-11-05 「파킹24에 썼던거 그대로 써」).
final class IncheonFlightStatusService: FlightStatusProviding {
    static let service = "StatusOfPassengerFlightsOdp"

    private let token: TravelServer.Token
    private let session: URLSession
    private let now: @Sendable () -> Date

    init(token: @escaping TravelServer.Token = TravelServer.signedIn, session: URLSession = .shared,
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.token = token
        self.session = session
        self.now = now
    }

    func status(flightId: String, direction: FlightDirection, day: Date) async throws -> FlightLiveStatus? {
        let token: String
        do {
            token = try await self.token()
        } catch {
            throw FlightStatusError.notSignedIn
        }
        let path = direction == .departure ? "getPassengerDeparturesOdp" : "getPassengerArrivalsOdp"
        guard let request = Self.request(path: path, flightId: flightId, token: token) else { throw FlightStatusError.badResponse("주소") }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FlightStatusError.network
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw FlightStatusError.badResponse("HTTP \(code)") }
        let rows = try FlightStatusParser.parse(data, direction: direction, day: day, fetchedAt: now(), calendar: FlightStatusParser.seoul)
        return rows.first { $0.flightId == flightId }
    }

    /// 중계 서버에 보낼 물음 — 편명으로, 키 없이 로그인 토큰만(키를 싸서 붙이는 일은 서버가 한다).
    static func request(path: String, flightId: String, token: String) -> URLRequest? {
        TravelServer.airportRequest(service: service, operation: path,
                                    query: [URLQueryItem(name: "type", value: "json"),
                                            URLQueryItem(name: "flight_id", value: flightId)],
                                    token: token, timeout: 15)
    }
}
