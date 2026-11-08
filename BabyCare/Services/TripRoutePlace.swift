import Foundation

/// 지도에 넘길 이름 — 순수 함수.
/// 🩸 한글 「간사이공항」을 애플 지도에 그대로 넘기면 공항이 아니라 리무진 버스 사무소를 잡아
///    교토역까지 44분이라고 한다(2026-11-05 실측 · 공식 이름 「関西国際空港」은 76분). → 공항은 공식 이름으로 바꿔 넘긴다.
enum TripRoutePlace {
    struct Airport: Sendable {
        let code: String
        /// 지도 검색에 넘기는 공식 이름.
        let query: String
        /// 손님이 적는 한글 이름 조각.
        let names: [String]
    }

    static let airports: [Airport] = [
        Airport(code: "ICN", query: "인천국제공항", names: ["인천"]),
        Airport(code: "GMP", query: "김포국제공항", names: ["김포"]),
        Airport(code: "PUS", query: "김해국제공항", names: ["김해"]),
        Airport(code: "CJU", query: "제주국제공항", names: ["제주"]),
        Airport(code: "KIX", query: "関西国際空港", names: ["간사이", "칸사이"]),
        Airport(code: "ITM", query: "大阪国際空港", names: ["이타미"]),
        Airport(code: "UKB", query: "神戸空港", names: ["고베"]),
        Airport(code: "NRT", query: "成田国際空港", names: ["나리타"]),
        Airport(code: "HND", query: "羽田空港", names: ["하네다"]),
        Airport(code: "NGO", query: "中部国際空港", names: ["주부", "센트레아"]),
        Airport(code: "FUK", query: "福岡空港", names: ["후쿠오카"]),
        Airport(code: "CTS", query: "新千歳空港", names: ["치토세"]),
        Airport(code: "OKA", query: "那覇空港", names: ["나하", "오키나와"])
    ]

    /// 국내 공항 — 「공항」만 적었을 때 여행지 공항을 고르려고 뺀다.
    static let homeAirports: Set<String> = ["ICN", "GMP", "PUS", "CJU", "TAE", "CJJ", "KWJ", "MWX", "RSU", "USN", "YNY", "KUV", "WJU", "HIN", "KPO"]

    private static let airportWords = ["공항", "airport", "空港"]

    /// 손님이 적은 이름 → 지도에 넘길 이름. 비었으면 nil.
    static func query(for label: String, trip: Trip) -> String? {
        let text = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if let a = airports.first(where: { $0.code == text.uppercased() }) { return a.query }
        if let hotel = trip.bookings.first(where: { $0.kind == .hotel && sameName($0.name, text) }),
           let address = nonEmpty(hotel.address) {
            return address
        }
        let lower = text.lowercased()
        if airportWords.contains(where: { lower.contains($0) }) {
            if let a = airports.first(where: { a in a.names.contains { text.contains($0) } }) { return a.query }
            if airportWords.contains(lower), let code = foreignAirport(in: trip),
               let a = airports.first(where: { $0.code == code }) {
                return a.query
            }
        }
        return text
    }

    /// 그 여행에서 내리는 외국 공항.
    static func foreignAirport(in trip: Trip) -> String? {
        // 🩸 2026-11-08 CI(낮은 Xcode)가 「?? 네 번 겹친 비교식」의 타입을 제한 시간 안에 못 정해 빌드가 깨졌다 — 기준 시각을 함수로 뺀다.
        let flights = trip.bookings.filter { $0.kind == .flight }.sorted { flightSortTime($0) < flightSortTime($1) }
        for f in flights {
            let codes: [String] = [f.toAirport, f.fromAirport].compactMap { (code: String?) -> String? in code?.uppercased() }
            for code in codes where !homeAirports.contains(code) {
                return code
            }
        }
        return nil
    }

    /// 편을 시각 순으로 — 출발 시각, 없으면 도착 시각, 둘 다 없으면 맨 뒤.
    private static func flightSortTime(_ booking: TripBooking) -> Date {
        if let time = booking.depart?.time { return time }
        if let time = booking.arrive?.time { return time }
        return .distantFuture
    }

    private static func sameName(_ name: String?, _ text: String) -> Bool {
        guard let name = nonEmpty(name) else { return false }
        return name.caseInsensitiveCompare(text) == .orderedSame
    }

    private static func nonEmpty(_ s: String?) -> String? {
        guard let v = s?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return nil }
        return v
    }
}
