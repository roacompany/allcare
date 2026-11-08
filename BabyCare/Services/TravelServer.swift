import Foundation

/// 여행 중계 서버(Cloudflare Worker `babycare-travel` · 코드 = babycare-admin `workers/travel`) —
/// 지도·공항 키는 서버에만 있고, 앱은 로그인 토큰만 보낸다.
/// v2.8.13(2026-11-08 PO 「다 추가해서 여행기능 오픈」 · 「여행 중계만 cloudflare로」): 앱 안에 실린 키는 누구나 꺼낼 수 있어서
/// TestFlight 판의 키 파일을 없앴다. 서버가 여는 것은 앱이 쓰는 공항 물음 넷(시간표 출발·도착 · 운항 현황 출발·도착)과 차 이동 시간뿐이다.
enum TravelServer {
    static let base = URL(string: "https://babycare-travel.roafinance.workers.dev")!

    /// 로그인 토큰을 주는 쪽 — 시험은 고정 값이나 실패를 넣는다.
    typealias Token = @Sendable () async throws -> String

    /// 로그인한 사람의 Firebase ID 토큰 — 서버가 앱 사용자인지 확인한다(관리자일 필요는 없다).
    static let signedIn: Token = { try await AuthService.shared.idToken() }

    /// 공항(공공데이터포털) 물음 — 「PaxFltSched」 · 「getPaxFltSchedDepartures」 + 키를 뺀 나머지 물음.
    static func airportRequest(service: String, operation: String, query: [URLQueryItem],
                               token: String, timeout: TimeInterval) -> URLRequest? {
        var components = URLComponents(url: base.appending(path: "airport/\(service)/\(operation)"), resolvingAgainstBaseURL: false)
        components?.queryItems = query
        guard let url = components?.url else { return nil }
        return request(url, token: token, timeout: timeout)
    }

    /// 차 이동 시간(구글 Routes) 물음 — 본문은 앱이 짜던 그대로 보낸다(서버가 주소·나라만 받아 다시 짠다).
    static func routesRequest(body: Data, token: String, timeout: TimeInterval) -> URLRequest {
        var request = request(base.appending(path: "routes"), token: token, timeout: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        return request
    }

    private static func request(_ url: URL, token: String, timeout: TimeInterval) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }
}
