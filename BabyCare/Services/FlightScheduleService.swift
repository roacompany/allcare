import Foundation

/// 인천공항 정기 시간표 한 줄(시즌 단위) — 편명만 넣으면 항공사·공항·인천 쪽 시각을 채운다(PO 2026-11-05 「넣기 편하게」 · 설계 §8).
struct FlightScheduleRow: Equatable, Sendable {
    let flightId: String
    let airlineName: String?
    let counterpartName: String?
    let counterpartCode: String?
    /// 인천 쪽 시각 — 출발 편은 인천 출발, 도착 편은 인천 도착. 상대 공항 쪽 시각은 시간표에 없다.
    let hour: Int
    let minute: Int
    /// 운항 기간 yyyyMMdd(양 끝 포함).
    let firstDay: String
    let lastDay: String
    /// 다니는 요일 — Calendar weekday(일=1 … 토=7).
    let weekdays: Set<Int>
    let direction: FlightDirection
}

enum FlightScheduleMatch: Equatable, Sendable {
    case found(FlightScheduleRow)
    /// 편은 있는데 그날(요일·기간)엔 다니지 않는다.
    case notOnThatDay
    case notFound
}

/// 「인천국제공항공사_여객편 정기운항편 일정」 응답 읽기 — 순수 함수.
/// 실측(2026-11-05): 필드가 소문자(flightid · airport · airportcode · st · firstdate · lastdate · monday…sunday=Y/N) ·
/// 편명 필터가 안 먹어 출발·도착 각 약 2,890줄(약 770KB)이 통째로 온다 · 같은 편이 기간별로 여러 줄.
enum FlightScheduleParser {
    private static let weekdayKeys: [(String, Int)] = [("sunday", 1), ("monday", 2), ("tuesday", 3), ("wednesday", 4),
                                                       ("thursday", 5), ("friday", 6), ("saturday", 7)]

    static func parse(_ data: Data, direction: FlightDirection) throws -> [FlightScheduleRow] {
        try FlightStatusParser.items(in: data).compactMap { row($0, direction: direction) }
    }

    private static func row(_ r: [String: Any], direction: FlightDirection) -> FlightScheduleRow? {
        guard let id = FlightNumber.normalize(FlightStatusParser.text(r["flightid"]) ?? ""),
              let st = FlightStatusParser.nonEmpty(r["st"]), st.count == 4,
              let hour = Int(st.prefix(2)), let minute = Int(st.suffix(2)),
              let first = FlightStatusParser.nonEmpty(r["firstdate"]), let last = FlightStatusParser.nonEmpty(r["lastdate"]) else { return nil }
        let weekdays = Set(weekdayKeys.compactMap { key, day in FlightStatusParser.text(r[key])?.uppercased() == "Y" ? day : nil })
        return FlightScheduleRow(flightId: id, airlineName: FlightStatusParser.nonEmpty(r["airline"]),
                                 counterpartName: FlightStatusParser.nonEmpty(r["airport"])?.replacingOccurrences(of: "/ ", with: "/"),
                                 counterpartCode: FlightStatusParser.nonEmpty(r["airportcode"])?.uppercased(),
                                 hour: hour, minute: minute, firstDay: first, lastDay: last, weekdays: weekdays, direction: direction)
    }
}

/// 그날 그 편 — 기간 안이고 그 요일에 다니는 줄.
enum FlightScheduleMatcher {
    static func match(rows: [FlightScheduleRow], flightNumber: String, day: Date, calendar: Calendar) -> FlightScheduleMatch {
        guard let id = FlightNumber.normalize(flightNumber) else { return .notFound }
        let same = rows.filter { $0.flightId == id }
        guard !same.isEmpty else { return .notFound }
        let key = dayKey(day, calendar: calendar)
        let weekday = calendar.component(.weekday, from: day)
        if let hit = same.first(where: { $0.firstDay <= key && key <= $0.lastDay && $0.weekdays.contains(weekday) }) {
            return .found(hit)
        }
        return .notOnThatDay
    }

    static func dayKey(_ day: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// 시간표를 받는 쪽 — 뷰모델이 이 면에만 의존한다(테스트는 목으로).
protocol FlightScheduleProviding: Sendable {
    func rows() async throws -> [FlightScheduleRow]
}

/// 인천공항 정기 시간표(공공데이터포털 PaxFltSched) — 여행 중계 서버를 거쳐 묻는다(키는 서버에만 · `TravelServer`).
/// 한 번 받으면 앱이 켜져 있는 동안 다시 받지 않는다.
actor IncheonFlightScheduleService: FlightScheduleProviding {
    static let shared = IncheonFlightScheduleService()
    static let service = "PaxFltSched"

    private let token: TravelServer.Token
    private let session: URLSession
    private var cache: [FlightScheduleRow]?

    init(token: @escaping TravelServer.Token = TravelServer.signedIn, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    func rows() async throws -> [FlightScheduleRow] {
        if let cache { return cache }
        let token: String
        do {
            token = try await self.token()
        } catch {
            throw FlightStatusError.notSignedIn
        }
        async let departures = Self.fetch("getPaxFltSchedDepartures", direction: .departure, token: token, session: session)
        async let arrivals = Self.fetch("getPaxFltSchedArrivals", direction: .arrival, token: token, session: session)
        let all = try await departures + arrivals
        cache = all
        return all
    }

    /// 중계 서버에 보낼 물음 — 키 없이 로그인 토큰만.
    static func request(_ operation: String, token: String) -> URLRequest? {
        TravelServer.airportRequest(service: service, operation: operation,
                                    query: [URLQueryItem(name: "type", value: "json"),
                                            URLQueryItem(name: "numOfRows", value: "9999"),
                                            URLQueryItem(name: "pageNo", value: "1")],
                                    token: token, timeout: 30)
    }

    private static func fetch(_ operation: String, direction: FlightDirection, token: String, session: URLSession) async throws -> [FlightScheduleRow] {
        guard let request = request(operation, token: token) else { throw FlightStatusError.badResponse("주소") }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FlightStatusError.network
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw FlightStatusError.badResponse("HTTP \(code)") }
        return try FlightScheduleParser.parse(data, direction: direction)
    }
}
