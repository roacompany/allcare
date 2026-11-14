import MapKit
import XCTest
@testable import BabyCare

/// 애플 지도가 이동 시간을 못 줄 때 — 「길이 없다」와 「잠깐 못 받음」을 가른다.
/// 「길이 없다」(.notFound)는 화면이 기억해 다시 묻지 않고, 「못 받음」(.failed)은 앱이 다시 열리거나 망이 돌아오면 다시 묻는다.
/// 고치기 전: 망 끊김·서버 오류·횟수 제한까지 「길이 없다」로 접어, 한 번 끊기면 그 화면 동안 다시 묻지 않았다.
final class RouteErrorTests: XCTestCase {

    private func mapKit(_ code: MKError.Code) -> NSError {
        NSError(domain: MKErrorDomain, code: Int(code.rawValue))
    }

    func test_noSuchPlaceOrRoute_isNotFound() {
        XCTAssertEqual(AppleMapsRouteTimeService.routeError(for: mapKit(.placemarkNotFound)), .notFound)
        XCTAssertEqual(AppleMapsRouteTimeService.routeError(for: mapKit(.directionsNotFound)), .notFound)
    }

    func test_networkServerAndThrottling_areRetryable() {
        for code in [MKError.Code.serverFailure, .loadingThrottled, .unknown] {
            if case .failed = AppleMapsRouteTimeService.routeError(for: mapKit(code)) { continue }
            XCTFail("다시 물어야 하는데 「길이 없다」로 접었다: MKError \(code.rawValue)")
        }
        let offline = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        if case .failed = AppleMapsRouteTimeService.routeError(for: offline) {} else {
            XCTFail("망 끊김을 「길이 없다」로 접었다")
        }
    }
}
