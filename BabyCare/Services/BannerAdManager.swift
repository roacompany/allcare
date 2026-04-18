import Foundation
import GoogleMobileAds
import OSLog
import SwiftUI

/// 단일 BannerView를 모든 탭에서 재사용하기 위한 싱글톤.
/// 앱 런치 시 preload() 1회 호출 → 사용자가 광고 영역에 도달했을 때엔 이미 광고가 채워져 있음.
///
/// AdMob `BannerView` 자체는 로드 후 60초마다 자동 refresh (콘솔 default).
/// 즉 한 번 만들어둔 인스턴스를 재사용해도 광고는 계속 갱신된다.
@MainActor
@Observable
final class BannerAdManager: NSObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(attempt: Int)   // 1, 2, 3...
    }

    static let shared = BannerAdManager()

    private(set) var state: LoadState = .idle
    private(set) var bannerView: BannerView?

    private let logger = Logger(subsystem: "com.roacompany.allcare", category: "Ad")
    private static let maxRetryAttempts = 3
    private static let retryDelays: [UInt64] = [
        2_000_000_000,   // 2s
        5_000_000_000,   // 5s
        10_000_000_000   // 10s
    ]

    private var retryTask: Task<Void, Never>?

    private static var adUnitID: String {
        #if DEBUG
        return "ca-app-pub-3940256099942544/2435281174"   // Google Test Banner
        #else
        return "ca-app-pub-6369815556964095/1486596816"   // BabyCare Banner Inline (Production)
        #endif
    }

    /// 앱 런치 직후 호출. 이미 인스턴스가 있으면 no-op.
    func preload() {
        guard bannerView == nil else { return }
        let adSize = largeAnchoredAdaptiveBanner(width: Self.safeScreenWidth())
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = Self.adUnitID
        banner.delegate = self
        bannerView = banner
        state = .loading
        logger.log("Ad preload started — adUnit=\(Self.adUnitID, privacy: .public)")
        banner.load(Request())
    }

    /// 수동 재시도 (사용자가 강제로 트리거하지는 않지만 lifecycle 등에서 사용 가능)
    func retryNow() {
        guard let bannerView else {
            preload()
            return
        }
        retryTask?.cancel()
        state = .loading
        logger.log("Ad manual retry")
        bannerView.load(Request())
    }

    // MARK: - Private

    private func scheduleRetry(attempt: Int) {
        guard attempt < Self.maxRetryAttempts else {
            logger.error("Ad load: max retries (\(Self.maxRetryAttempts)) reached, giving up")
            return
        }
        let delay = Self.retryDelays[attempt]
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, let self else { return }
            self.state = .loading
            self.logger.log("Ad retry attempt=\(attempt + 1)")
            self.bannerView?.load(Request())
        }
    }

    /// iOS 16+ scene-aware screen width (UIScreen.main 회피 — iOS 26.5 Beta crash 대응).
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

// MARK: - BannerViewDelegate

extension BannerAdManager: BannerViewDelegate {
    nonisolated func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        Task { @MainActor in
            self.state = .loaded
            self.retryTask?.cancel()
            self.logger.info("Ad loaded successfully")
        }
    }

    nonisolated func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            let nextAttempt: Int
            if case .failed(let prev) = self.state {
                nextAttempt = prev + 1
            } else {
                nextAttempt = 1
            }
            self.state = .failed(attempt: nextAttempt)
            self.logger.error("Ad load failed (attempt \(nextAttempt)): \(message, privacy: .public)")
            self.scheduleRetry(attempt: nextAttempt)
        }
    }
}
