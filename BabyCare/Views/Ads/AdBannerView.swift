import SwiftUI
import UIKit
import GoogleMobileAds

// MARK: - AdBannerView
/// SwiftUI 래퍼 — `BannerAdManager.shared`의 단일 BannerView 인스턴스를 모든 탭에서 재사용.
/// 광고 로딩 중에는 placeholder 표시 (자연스러운 빈 박스, 로딩 텍스트 없음).

struct AdBannerView: View {
    @State private var manager = BannerAdManager.shared

    var body: some View {
        Group {
            switch manager.state {
            case .loaded:
                if let banner = manager.bannerView {
                    BannerViewRepresentable(banner: banner)
                } else {
                    placeholder
                }
            case .idle, .loading, .failed:
                placeholder
            }
        }
    }

    private var placeholder: some View {
        // 광고가 들어갈 자리만큼 자연스러운 빈 영역. 텍스트나 스피너는 의도적으로 생략 —
        // 사용자에게 "광고 로딩 중"임을 강조하지 않기 위함.
        Color.clear
    }

    /// SwiftUI `.frame(height:)`에 넘길 수 있는 배너 높이.
    @MainActor
    static func currentBannerHeight() -> CGFloat {
        return largeAnchoredAdaptiveBanner(width: BannerAdManager.safeScreenWidth()).size.height
    }
}

// MARK: - BannerViewRepresentable

/// AdMob `BannerView`(UIView)를 SwiftUI에 임베드. `manager`가 같은 BannerView 인스턴스를
/// 유지하므로 매번 새 광고를 로드하지 않는다 (auto-refresh는 AdMob 콘솔 default 60초).
private struct BannerViewRepresentable: UIViewRepresentable {
    typealias UIViewType = BannerView
    let banner: BannerView

    func makeUIView(context: Context) -> BannerView {
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}
}
