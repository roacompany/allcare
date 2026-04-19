import Foundation

enum FeatureFlags {
    static let cryAnalysisEnabled: Bool = true
    /// 임신 모드 게이팅. TestFlight v2.7.1 (빌드 56-61) 5회 회귀 누적으로 인해
    /// v2.7.2 (빌드 62)부터 false. UI 전체 hidden, Firestore 데이터는 보존.
    /// 재설계 spec(v2.8+) 완료 후 true 복귀 예정.
    /// 회귀 history: AddBabyView orphan(56) / gating(58) / index+UIView(59) /
    /// baby-pregnancy 우선순위(60) / H-4 배지+H-8 a11y(61).
    static let pregnancyModeEnabled: Bool = false
}
