import Foundation

enum FeatureFlags {
    static let cryAnalysisEnabled: Bool = true
    /// 임신 모드 compile-time kill switch.
    /// true = 코드 활성화 (v2.8+ 재설계 이후). FeatureFlagService가 RemoteConfig +
    /// 코호트 rollout %를 조합해 최종 노출 여부를 결정한다.
    /// 이 값을 false로 설정하면 FeatureFlagService.bootstrap과 무관하게 완전 비활성.
    ///
    /// 회귀 history: AddBabyView orphan(56) / gating(58) / index+UIView(59) /
    /// baby-pregnancy 우선순위(60) / H-4 배지+H-8 a11y(61).
    ///
    /// NOTE: 이 값은 FeatureFlagService.compileTime으로 읽힌다.
    ///       FeatureFlagService 단독 게이트웨이 — 직접 FirebaseRemoteConfig 금지 (A-18).
    static let pregnancyModeEnabled: Bool = true
    /// 주간 하이라이트 compile-time kill switch.
    /// true = 코드 활성화. FeatureFlagService.isHighlightV2Enabled(userId:)가
    /// RemoteConfig highlight_enabled + StableHash 코호트 bucketing으로 최종 노출 여부 결정.
    /// false 설정 시 RC fetch 없이 즉시 비활성 (A-18 invariant).
    ///
    /// NOTE: 이 값은 FeatureFlagService.isHighlightV2Enabled에서 Layer 1 guard로 읽힌다.
    ///       FirebaseRemoteConfig 직접 import 금지 (FeatureFlagService 단독 게이트웨이).
    static let highlightsEnabled: Bool = true
}
