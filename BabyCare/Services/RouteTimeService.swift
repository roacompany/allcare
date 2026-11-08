import Foundation
import MapKit

/// 이동 시간을 계산한 곳 — 화면에 「○○ 기준」으로 늘 같이 적는다.
enum RouteSource: String, Sendable, Hashable {
    case google
    case apple

    var label: String {
        switch self {
        case .google: return "구글지도 기준"
        case .apple: return "애플 지도 기준"
        }
    }
}

/// 차로 걸리는 시간 하나. 이름은 지도가 찾은 곳(맞게 찾았나 보이려고 · 구글은 주지 않는다).
struct RouteEstimate: Hashable, Sendable {
    let minutes: Int
    let fromName: String?
    let toName: String?
    let source: RouteSource
}

/// 어느 동네 안에서 찾나 — 같은 이름이 여러 나라에 있다.
struct TripRouteArea: Equatable, Sendable {
    let city: String
    let countryCode: String
}

enum RouteTimeError: Error, Equatable {
    /// 지도에서 그곳을 못 찾았다 · 길이 없다.
    case notFound
    case failed(String)
}

/// 이동 시간을 묻는 쪽 — 뷰모델이 이 면에만 의존한다(테스트는 목으로).
protocol RouteTimeProviding: Sendable {
    func drivingRoute(from: String, to: String, near area: TripRouteArea) async throws -> RouteEstimate
}

enum RouteTimeServices {
    /// 구글(여행 중계 서버를 거쳐 · 키는 서버에만) — 서버에 못 닿으면 애플 지도(키 · 결제 없음)로 대신 잰다.
    /// 🔑 v2.8.13(2026-11-08): 앱에 실린 키는 누구나 꺼내서 구글 키를 서버로 옮겼다.
    static func standard() -> RouteTimeProviding {
        FallbackRouteTimeService(primary: GoogleRoutesTimeService(), fallback: AppleMapsRouteTimeService())
    }
}

/// 첫째가 「못 받음」(서버 · 네트워크 · 로그인)이면 둘째에게 묻는다 — 이동 시간이 통째로 비지 않게.
/// 「길이 없다」(notFound)는 그대로 둔다: 둘째가 다른 곳을 잡아 틀린 시간을 낼 수 있다(간사이공항 → 리무진 사무소).
final class FallbackRouteTimeService: RouteTimeProviding {
    private let primary: RouteTimeProviding
    private let fallback: RouteTimeProviding

    init(primary: RouteTimeProviding, fallback: RouteTimeProviding) {
        self.primary = primary
        self.fallback = fallback
    }

    func drivingRoute(from: String, to: String, near area: TripRouteArea) async throws -> RouteEstimate {
        do {
            return try await primary.drivingRoute(from: from, to: to, near: area)
        } catch RouteTimeError.failed(let reason) {
            logSilent("여행 이동 시간 — 중계 서버 실패(\(reason)) → 애플 지도", logger: AppLogger.travel)
            return try await fallback.drivingRoute(from: from, to: to, near: area)
        }
    }
}

/// 애플 지도 — 아이폰에 들어 있어 키도 결제도 없다. 장소는 이름으로 찾고(MKLocalSearch) 차 시간을 받는다(MKDirections).
final class AppleMapsRouteTimeService: RouteTimeProviding {
    func drivingRoute(from: String, to: String, near area: TripRouteArea) async throws -> RouteEstimate {
        try await Self.compute(from: from, to: to, near: area)
    }

    @MainActor
    private static func compute(from: String, to: String, near area: TripRouteArea) async throws -> RouteEstimate {
        let center = try? await search(cityQuery(area.city), region: nil)?.placemark.coordinate
        let region = center.map { MKCoordinateRegion(center: $0, span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)) }
        guard let source = try? await search(from, region: region),
              let destination = try? await search(to, region: region) else { throw RouteTimeError.notFound }
        let request = MKDirections.Request()
        request.source = source
        request.destination = destination
        request.transportType = .automobile
        let eta: MKDirections.ETAResponse
        do {
            eta = try await MKDirections(request: request).calculateETA()
        } catch {
            throw RouteTimeError.notFound
        }
        return RouteEstimate(minutes: max(1, Int((eta.expectedTravelTime / 60).rounded())),
                             fromName: source.name, toName: destination.name, source: .apple)
    }

    @MainActor
    private static func search(_ query: String, region: MKCoordinateRegion?) async throws -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        if let region { request.region = region }
        return try await MKLocalSearch(request: request).start().mapItems.first
    }

    /// 「오사카·교토」 → 「오사카」 — 첫 도시로 동네를 잡는다.
    static func cityQuery(_ city: String) -> String {
        let first = city.split(whereSeparator: { "·,/ ".contains($0) }).first.map(String.init) ?? city
        return first.isEmpty ? city : first
    }
}

/// 구글 Routes API(computeRoutes) — 여행 중계 서버를 거쳐 묻는다(키는 서버에만 · `TravelServer`).
/// 서버가 시간·거리만 받는다(교통 반영 없음 = 가장 싼 단계) · 키는 PO 가 신청(2026-11-05).
final class GoogleRoutesTimeService: RouteTimeProviding {
    private let token: TravelServer.Token
    private let session: URLSession

    init(token: @escaping TravelServer.Token = TravelServer.signedIn, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    func drivingRoute(from: String, to: String, near area: TripRouteArea) async throws -> RouteEstimate {
        let token: String
        do {
            token = try await self.token()
        } catch {
            throw RouteTimeError.failed("로그인")
        }
        let request = try Self.request(from: from, to: to, area: area, token: token)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw RouteTimeError.failed("네트워크")
        }
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else { throw RouteTimeError.failed("HTTP \(code)") }
        guard let minutes = Self.minutes(from: data) else { throw RouteTimeError.notFound }
        return RouteEstimate(minutes: minutes, fromName: nil, toName: nil, source: .google)
    }

    /// 중계 서버에 보낼 물음 — 본문은 앱이 짜던 그대로, 키 없이 로그인 토큰만.
    static func request(from: String, to: String, area: TripRouteArea, token: String) throws -> URLRequest {
        let body = try JSONSerialization.data(withJSONObject: body(from: from, to: to, area: area))
        return TravelServer.routesRequest(body: body, token: token, timeout: 15)
    }

    static func body(from: String, to: String, area: TripRouteArea) -> [String: Any] {
        var body: [String: Any] = [
            "origin": ["address": from],
            "destination": ["address": to],
            "travelMode": "DRIVE",
            "languageCode": "ko"
        ]
        let region = area.countryCode.trimmingCharacters(in: .whitespaces).lowercased()
        if region.count == 2 { body["regionCode"] = region }
        return body
    }

    /// {"routes":[{"duration":"4560s"}]} → 76. 길이 없으면 {} 가 온다 → nil.
    static func minutes(from data: Data) -> Int? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (root["routes"] as? [[String: Any]])?.first,
              let raw = first["duration"] as? String, raw.hasSuffix("s"),
              let seconds = Double(raw.dropLast()) else { return nil }
        return max(1, Int((seconds / 60).rounded()))
    }
}
