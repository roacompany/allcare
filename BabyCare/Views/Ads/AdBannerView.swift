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
        return largeAnchoredAdaptiveBanner(width: Self.safeScreenWidth())
    }

    /// SwiftUI `.frame(height:)`에 넘길 수 있는 배너 높이.
    @MainActor
    static func currentBannerHeight() -> CGFloat {
        return largeAnchoredAdaptiveBanner(width: safeScreenWidth()).size.height
    }

    /// iOS 16+에서 deprecated된 `UIScreen.main` 대신 활성 WindowScene으로부터 안전하게
    /// 화면 너비를 조회한다. Scene 조회 실패 시 iPhone 기본폭(390pt)으로 fallback.
    @MainActor
    static func safeScreenWidth() -> CGFloat {
        let fallback: CGFloat = 390  // iPhone 14/15/16 표준 폭
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
