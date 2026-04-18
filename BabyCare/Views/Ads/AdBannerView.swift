import SwiftUI
import UIKit
import GoogleMobileAds
import OSLog

// MARK: - AdBannerView
/// 각 placement마다 자체 BannerView 인스턴스 소유 (UIView는 한 parent만 가능하므로 공유 불가).
/// 로딩 실패 시 backoff 재시도 (2s/5s/10s, 최대 3회). 로딩 중에는 Color.clear placeholder.

@MainActor
struct AdBannerView: UIViewRepresentable {
    typealias UIViewType = BannerView

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: currentAdSize())
        banner.adUnitID = BannerAdManager.adUnitID
        banner.delegate = context.coordinator
        context.coordinator.banner = banner
        context.coordinator.loadInitial()
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    func makeCoordinator() -> BannerCoordinator {
        BannerCoordinator()
    }

    @MainActor
    func currentAdSize() -> AdSize {
        return largeAnchoredAdaptiveBanner(width: BannerAdManager.safeScreenWidth())
    }

    /// SwiftUI `.frame(height:)`에 넘길 수 있는 배너 높이.
    @MainActor
    static func currentBannerHeight() -> CGFloat {
        return largeAnchoredAdaptiveBanner(width: BannerAdManager.safeScreenWidth()).size.height
    }
}

// MARK: - BannerCoordinator (per-instance)

@MainActor
final class BannerCoordinator: NSObject, BannerViewDelegate {
    weak var banner: BannerView?
    private var retryTask: Task<Void, Never>?
    private var attemptCount = 0
    private let manager = BannerAdManager.shared
    private var logger: Logger { manager.logger }

    func loadInitial() {
        attemptCount = 0
        retryTask?.cancel()
        manager.reportLoading()
        logger.log("Ad load: initial (placement)")
        banner?.load(Request())
    }

    nonisolated func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        Task { @MainActor in
            self.attemptCount = 0
            self.retryTask?.cancel()
            self.manager.reportLoaded()
            self.logger.info("Ad loaded successfully (placement)")
        }
    }

    nonisolated func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in
            self.attemptCount += 1
            self.manager.reportFailed(attempt: self.attemptCount)
            self.logger.error("Ad load failed (attempt \(self.attemptCount)): \(message, privacy: .public)")
            self.scheduleRetry()
        }
    }

    private func scheduleRetry() {
        guard attemptCount < BannerAdManager.maxRetryAttempts else {
            logger.error("Ad load: max retries reached")
            return
        }
        let delayIndex = min(attemptCount - 1, BannerAdManager.retryDelays.count - 1)
        let delay = BannerAdManager.retryDelays[max(0, delayIndex)]
        retryTask?.cancel()
        retryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled, let self else { return }
            self.logger.log("Ad retry attempt=\(self.attemptCount + 1)")
            self.banner?.load(Request())
        }
    }
}
