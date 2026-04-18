import Foundation
import OSLog
import UIKit

/// 광고 공유 상태 — SDK 준비/첫 성공/실패 여부만 추적.
/// BannerView UIView 자체는 각 placement(AdBannerView 인스턴스)가 소유한다.
/// UIView는 한 번에 하나의 parent만 가질 수 있으므로 3개 탭 공유는 불가.
@MainActor
@Observable
final class BannerAdManager {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(attempt: Int)
    }

    static let shared = BannerAdManager()

    /// 앱 전역 광고 SDK 상태 (첫 placement의 상태가 여기에 반영) —
    /// 다른 placement도 SDK가 warm-up 됐는지 확인용으로 참고.
    private(set) var sharedState: LoadState = .idle

    let logger = Logger(subsystem: "com.roacompany.allcare", category: "Ad")

    static let maxRetryAttempts = 3
    static let retryDelays: [UInt64] = [
        2_000_000_000,   // 2s
        5_000_000_000,   // 5s
        10_000_000_000   // 10s
    ]

    static var adUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2435281174"   // Google Test Banner
        #else
        return "ca-app-pub-6369815556964095/1486596816"   // BabyCare Banner Inline (Production)
        #endif
    }

    /// 각 AdBannerView 인스턴스가 성공/실패 보고.
    func reportLoaded() {
        sharedState = .loaded
    }

    func reportLoading() {
        if case .loaded = sharedState { return }   // 한 번 성공한 뒤엔 상태 유지
        sharedState = .loading
    }

    func reportFailed(attempt: Int) {
        if case .loaded = sharedState { return }
        sharedState = .failed(attempt: attempt)
    }

    /// iOS 16+ scene-aware screen width — UIScreen.main 회피 (iOS 26.5 Beta crash 대응).
    static func safeScreenWidth() -> CGFloat {
        let fallback: CGFloat = 390
        let scenes = UIApplication.shared.connectedScenes
        if let active = scenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            let width = active.screen.bounds.width
            return width > 0 ? width : fallback
        }
        if let any = scenes.first as? UIWindowScene {
            let width = any.screen.bounds.width
            return width > 0 ? width : fallback
        }
        return fallback
    }
}
