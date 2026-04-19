import Foundation

enum FeatureFlags {
    static let cryAnalysisEnabled: Bool = true
    /// 임신 모드 게이팅. TestFlight 검증 후 App Store 빌드에서 true 유지.
    /// FeatureFlag=false 시 임신 관련 UI 전체 미노출 (진입 지점에서만 분기).
    static let pregnancyModeEnabled: Bool = true
}
