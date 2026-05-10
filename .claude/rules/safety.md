---
globs: "**/*.swift"
---

# Safety Rules (Must NOT Do)

- Baby.gender Optional 변경 금지
- AIGuardrailService 금지어 수정 금지
- 백분위 의학적 판단 텍스트 금지
- 외부 차트 라이브러리 금지 (Apple Charts만)
- 데이터 로딩/저장 시 authVM.currentUserId 직접 사용 금지
- AI 가드레일: AIGuardrailService.prohibitedRules 수정 금지

## 임신 모드 전용

- 임신 데이터를 Firebase Analytics/Crashlytics custom params에 포함 금지 (민감 건강정보)
- KickEvent 별도 서브컬렉션 생성 금지 (KickSession.kicks 배열 임베딩)
- EDD 덮어쓰기 금지 (eddHistory append 강제)
- 출산 전환을 단일 write로 처리 금지 (WriteBatch + transitionState 필수)
- Pregnancy 위젯 데이터를 기존 WidgetDataStore에 병합 금지 (PregnancyWidgetDataStore 분리)
- baby > pregnancy UI gating: `babies.isEmpty`가 false이면 pregnancy UI 노출 금지 — `activePregnancy != nil` 단독 체크 금지

## FeatureFlag 게이팅

- **Compile-time FeatureFlag + RemoteConfig를 AND-combine 금지** (silent false 위험). Layer 1 compile-time flag는 `guard()` 패턴으로 조기 종료 — runtime RemoteConfig 평가는 compile-time true일 때만 진행. pregnancy-mode-v2 P2-4 Codex Rec-3 반영.
- **Fetch 실패 fallback은 반드시 `false`** (A-18 invariant). `try? fetchAndActivate()` 패턴으로 do/catch 없이 defaults=false 강제.
- **FeatureFlags.swift에 `import FirebaseRemoteConfig` 금지**. 단일 gateway(`FeatureFlagService`)로만 RC 접근.
- **Cohort bucketing은 DJB2 StableHash 사용**. `Swift.hashValue`나 `Int.random`은 non-deterministic — 금지.
