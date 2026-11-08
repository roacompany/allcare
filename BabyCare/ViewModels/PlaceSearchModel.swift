import Foundation
import MapKit

/// 장소 찾기 — 애플 지도 자동완성(키·돈 없음). 숙소 이름·렌터카 장소·이동 장소를 적는 대신 고르게 한다(설계 §8).
@MainActor @Observable
final class PlaceSearchModel: NSObject, MKLocalSearchCompleterDelegate {
    struct Suggestion: Identifiable, Hashable {
        let id: Int
        let title: String
        let subtitle: String
    }

    /// 고른 곳 — 이름과 주소(주소는 지도에 넘긴다).
    struct Pick: Equatable {
        let name: String
        let address: String?
    }

    private(set) var suggestions: [Suggestion] = []
    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    @ObservationIgnored private var completions: [MKLocalSearchCompletion] = []
    @ObservationIgnored private var biased = false

    /// lodgingOnly = 숙소 찾기 — 지도에서 숙박 시설만 받는다(2026-11-06 실측: 「교토역」에 주차장·술집이 호텔보다 먼저 나왔다).
    /// 지도에 없는 숙소는 찾기 화면 첫 줄 「직접 입력」으로 넣는다.
    init(lodgingOnly: Bool = false) {
        super.init()
        completer.delegate = self
        if lodgingOnly {
            completer.resultTypes = [.pointOfInterest]
            completer.pointOfInterestFilter = MKPointOfInterestFilter(including: [.hotel])
        } else {
            completer.resultTypes = [.pointOfInterest, .address]
        }
    }

    /// 여행 도시 근처를 먼저 보여 준다(같은 이름이 여러 나라에 있다).
    func bias(toCity city: String) async {
        guard !biased else { return }
        biased = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = AppleMapsRouteTimeService.cityQuery(city)
        do {
            guard let center = try await MKLocalSearch(request: request).start().mapItems.first?.placemark.coordinate else { return }
            completer.region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 2))
        } catch {
            logSilent("여행 도시 찾기 실패", error: error, logger: AppLogger.travel)
        }
    }

    /// 적는 글자가 바뀔 때 — 두 글자부터 찾는다.
    func search(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            clear()
            return
        }
        completer.queryFragment = q
    }

    func clear() {
        completer.cancel()
        // 글자까지 비운다 — 안 비우면 같은 글자를 다시 넣어도 지도가 새로 안 물어, 다시 연 찾기 화면에 후보가 안 뜬다.
        completer.queryFragment = ""
        completions = []
        suggestions = []
    }

    /// 이름만 — 후보의 부제(우편번호·시 이름)를 주소로 넣지 않는다. 주소 칸이 없어 안 보이고, 길찾기는 이름보다 주소를 먼저 쓴다.
    nonisolated static func nameOnlyPick(_ suggestion: Suggestion) -> Pick {
        Pick(name: suggestion.title, address: nil)
    }

    /// 고른 제안 → 이름 · 주소. 지도에서 못 찾으면 이름만.
    func resolve(_ suggestion: Suggestion) async -> Pick {
        let fallback = Self.nameOnlyPick(suggestion)
        // 그사이 후보가 바뀌었으면 같은 순번이 다른 곳이다.
        guard suggestion.id < completions.count, completions[suggestion.id].title == suggestion.title else { return fallback }
        let request = MKLocalSearch.Request(completion: completions[suggestion.id])
        do {
            guard let item = try await MKLocalSearch(request: request).start().mapItems.first else { return fallback }
            return Pick(name: item.name ?? suggestion.title, address: PlaceAddressFormat.address(item.placemark))
        } catch {
            logSilent("장소 주소 찾기 실패", error: error, logger: AppLogger.travel)
            return fallback
        }
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // 받은 completer 를 넘기지 않고 메인 액터가 가진 자기 것을 읽는다(같은 개체 · Swift 6 데이터 경쟁 검사).
        MainActor.assumeIsolated {
            completions = Array(self.completer.results.prefix(6))
            suggestions = completions.enumerated().map { Suggestion(id: $0.offset, title: $0.element.title, subtitle: $0.element.subtitle) }
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            completions = []
            suggestions = []
        }
    }

}
