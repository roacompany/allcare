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

    /// 디자인 시스템 V2 미리보기 노출 게이트.
    /// true 시 Settings → 관리자 섹션에 "DS V2 미리보기" 진입점 노출.
    /// 폐기 가능 namespace (`BabyCare/DesignSystemV2/`) 이므로 compile-time 단독 게이트.
    /// RemoteConfig 미연결 — Lab/실험실 성격 (PO 직접 편집 UI 없이 코드로만 평가).
    static let designSystemV2Preview: Bool = true

    /// 앱 평가(App Store 리뷰) 팝업 compile-time kill switch.
    /// true = 활성. 긍정적 성취(기록 20개 / 병원리포트 완료) 중 먼저 도달한 1개에서
    /// 시스템 평가 시트를 생애 1회 호출(AppReviewPromptService). RemoteConfig 미연결
    /// (FirebaseRemoteConfig import 금지, A-18). false 시 자동 팝업 + 설정 "리뷰 남기기" 행 모두 비활성.
    static let appReviewPromptEnabled: Bool = true
}
