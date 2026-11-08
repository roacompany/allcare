import Foundation

enum FeatureFlags {
    /// 울음 분석 compile-time kill switch.
    /// ⚠️ false 유지 — CryAnalysisService.analyzeStub()가 고정 25% 확률(가짜)을 반환(실 CoreML 미통합, TODO v2.7+).
    /// true 면 라이브 사용자에게 가짜 분석 결과가 노출된다(의료 인접 신뢰 리스크). 실모델 통합 시 재활성.
    static let cryAnalysisEnabled: Bool = false
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
    ///
    /// 2026-06-11: false로 비활성 (v2.8.8 핫픽스). v2(현 구현)는 "임신=전역 모드 플래그"
    /// 데이터모델 결함으로 출산전환 중복아기(P0)·성별오류(P1)·가족공유 유실(P1)이 라이브.
    /// 임신을 '프로필 엔티티'로 재모델링하는 v3 재설계(.dev/specs/pregnancy-mode-v3/) 완료 시
    /// 새 구현으로 재활성. 기존 사용자 Firestore 데이터는 보존(삭제 금지 룰).
    static let pregnancyModeEnabled: Bool = false
    /// 주간 하이라이트 compile-time kill switch.
    /// true = 코드 활성화. FeatureFlagService.isHighlightV2Enabled(userId:)가
    /// RemoteConfig highlight_enabled + StableHash 코호트 bucketing으로 최종 노출 여부 결정.
    /// false 설정 시 RC fetch 없이 즉시 비활성 (A-18 invariant).
    ///
    /// NOTE: 이 값은 FeatureFlagService.isHighlightV2Enabled에서 Layer 1 guard로 읽힌다.
    ///       FirebaseRemoteConfig 직접 import 금지 (FeatureFlagService 단독 게이트웨이).
    static let highlightsEnabled: Bool = true

    /// 앱 평가(App Store 리뷰) 팝업 compile-time kill switch.
    /// true = 활성. 긍정적 성취(기록 20개 / 병원리포트 완료) 중 먼저 도달한 1개에서
    /// 시스템 평가 시트를 생애 1회 호출(AppReviewPromptService). RemoteConfig 미연결
    /// (FirebaseRemoteConfig import 금지, A-18). false 시 자동 팝업 + 설정 "리뷰 남기기" 행 모두 비활성.
    static let appReviewPromptEnabled: Bool = true

    /// 「우리 하루」 compile-time kill switch.
    /// ⚠️ false 유지 — 지금 코드(①시간표 짜기 ②오늘 열기·칸 채우기, v2.8.12 빌드 108)는 PO 가 TestFlight 로
    /// 써 보고 「목적에 맞지 않아서 테스트를 할 수가 없어요」(2026-09-27)라고 판정해 재설계 중이다.
    /// false 면 설정의 「우리 하루」 줄과 홈의 하루 띠 카드가 안 보이고, 홈에서 dayPlans·dayRuns 도 읽지 않는다.
    /// 저장된 데이터와 코드는 그대로 둔다(재설계에서 재사용 여부를 정한다). 재설계를 출시할 때 켠다.
    static let dayPlanEnabled: Bool = false

    /// 「여행 준비」(아기와 해외여행 — 여행 · 예약 · 할 일과 마감 · 규칙 카드 · 공항 수유실 · 하루 일정) compile-time kill switch.
    /// true = 손님 판(App Store)에도 연다 — 2026-11-08 PO 「다 추가해서 여행기능 오픈」(v2.8.13).
    /// 지도·공항 키는 앱에 없다 — 여행 중계 서버(TravelServer · Cloudflare Worker babycare-travel)에만 있고, 앱은 로그인 토큰만 보낸다.
    /// false 면 설정 「여행 준비」 줄 · 홈 여행 카드 · 여행 읽기(trips)가 전부 사라진다(데이터는 그대로).
    static let travelEnabled: Bool = true
}
