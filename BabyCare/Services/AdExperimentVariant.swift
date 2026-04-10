import Foundation

/// AdMob 배너 배치 실험 — A/B 테스트를 위한 feature flag
/// 변경 시 `currentVariant` 한 줄 수정으로 전환 가능
enum AdExperimentVariant {
    case allThreeTabs   // A: Dashboard + Calendar + Health
    case dashboardOnly  // B: Dashboard 1개 탭만

    /// 현재 활성 변형. A/B 테스트 시 이 값만 변경한다.
    static let currentVariant: AdExperimentVariant = .allThreeTabs

    /// 주어진 탭 인덱스에서 배너를 표시해야 하는지 판단.
    /// TabView tag: 0=Dashboard, 1=Calendar, 2=기록+, 3=Health, 4=Settings
    func shouldShowBanner(forTab tag: Int) -> Bool {
        switch self {
        case .allThreeTabs:
            return tag == 0 || tag == 1 || tag == 3
        case .dashboardOnly:
            return tag == 0
        }
    }
}
