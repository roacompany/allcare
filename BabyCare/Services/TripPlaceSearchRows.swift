import Foundation

/// 장소 검색 화면의 줄 — 순수 함수(시안 Search-Move · Search-Hotel).
/// 첫 줄은 언제나 적은 글자 그대로(지도가 못 찾는 곳도 넣을 수 있게) · 그다음 공항 · 그다음 지도 후보(지도가 낸 순서 그대로).
enum TripPlaceSearchRows {
    struct Row: Identifiable, Equatable {
        let id: String
        let title: String
        let subtitle: String
        /// 바로 고를 수 있는 값. nil = 지도에 물어 주소를 받아야 하는 줄.
        let pick: PlaceSearchModel.Pick?
        let suggestion: PlaceSearchModel.Suggestion?

        var isTyped: Bool { id == typedRowId }
    }

    private static let typedRowId = "typed"

    /// 🩸 2026-11-06 실측: 「간사이」에 애플 지도 자동완성이 대학·병원만 내고 공항이 없었다 → 공항은 앱이 아는 목록에서 먼저 낸다.
    static func rows(text: String, suggestions: [PlaceSearchModel.Suggestion], includesAirports: Bool) -> [Row] {
        let typed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return [] }
        let airports = includesAirports ? TripRoutePlace.airports.filter { matches($0, typed: typed) } : []
        var rows = [Row(id: typedRowId, title: typed, subtitle: "직접 입력",
                        pick: PlaceSearchModel.Pick(name: typed, address: nil), suggestion: nil)]
        for airport in airports {
            let name = TripEntryChoices.airportName(airport.code) ?? airport.code
            rows.append(Row(id: "airport-\(airport.code)", title: name, subtitle: airport.query,
                            pick: PlaceSearchModel.Pick(name: name, address: nil), suggestion: nil))
        }
        for suggestion in suggestions where !airports.contains(where: { isSame($0, as: suggestion) }) {
            rows.append(Row(id: "map-\(suggestion.id)", title: suggestion.title, subtitle: suggestion.subtitle,
                            pick: nil, suggestion: suggestion))
        }
        return rows
    }

    /// 한 글자는 공항을 끌어오지 않는다(「간」으로 찾는 사람은 공항을 찾는 게 아니다).
    private static func matches(_ airport: TripRoutePlace.Airport, typed: String) -> Bool {
        airport.names.contains { typed.contains($0) || (typed.count >= 2 && $0.contains(typed)) }
    }

    /// 지도가 같은 공항을 또 낸 줄인가 — 이름이 공항 그 자체일 때만(「간사이공항역」은 다른 곳이다).
    private static func isSame(_ airport: TripRoutePlace.Airport, as suggestion: PlaceSearchModel.Suggestion) -> Bool {
        let title = suggestion.title.replacingOccurrences(of: " ", with: "")
        return airport.names.contains { title == "\($0)공항" || title == "\($0)국제공항" }
    }
}
