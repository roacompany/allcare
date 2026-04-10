import SwiftUI
import UIKit
import GoogleMobileAds
import OSLog

// MARK: - AdBannerView
/// Adaptive banner 광고를 SwiftUI에 임베드하는 UIViewRepresentable 래퍼.
/// SDK 13+ API만 사용 (GAD prefix 없음, rootViewController 수동 설정 없음).

@MainActor
struct AdBannerView: UIViewRepresentable {
    typealias UIViewType = BannerView

    func makeUIView(context: Context) -> BannerView {
        let adSize = currentAdSize()
        let banner = BannerView(adSize: adSize)

        #if DEBUG
        banner.adUnitID = "ca-app-pub-3940256099942544/2435281174"  // Google Test Banner
        #else
        banner.adUnitID = "ca-app-pub-6369815556964095/1486596816"  // BabyCare Banner Inline (Production)
        #endif

        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    func makeCoordinator() -> BannerCoordinator {
        BannerCoordinator(self)
    }

    /// 현재 화면 너비 기준 largeAnchoredAdaptiveBanner AdSize 반환.
    @MainActor
    func currentAdSize() -> AdSize {
        let width = UIScreen.main.bounds.width
        return largeAnchoredAdaptiveBanner(width: width)
    }

    /// SwiftUI `.frame(height:)`에 넘길 수 있는 배너 높이.
    @MainActor
    static func currentBannerHeight() -> CGFloat {
        let width = UIScreen.main.bounds.width
        return largeAnchoredAdaptiveBanner(width: width).size.height
    }
}

// MARK: - BannerCoordinator

@MainActor
final class BannerCoordinator: NSObject, BannerViewDelegate {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "BabyCare",
        category: "AdBanner"
    )

    let parent: AdBannerView

    init(_ parent: AdBannerView) {
        self.parent = parent
    }

    nonisolated func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        Task { @MainActor in
            Self.logger.info("AdBanner: 광고 수신 성공")
        }
    }

    nonisolated func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        Task { @MainActor in
            Self.logger.error("AdBanner: 광고 수신 실패 — \(error.localizedDescription)")
        }
    }
}
