# pregnancy-mode-v2 Issues

## P0-1
- [ ] pregnancy-weeks.json 의료 검증은 외부 전문가 의존 — v2에서도 자동화 불가 (H-4 handoff).
- [ ] orphan pending 복구(Resume UI) XCUITest — 실제 pending 문서 생성 자동화 어려움, H-9 실기기 의존 그대로 유지.

## P0-2
- [ ] CLAUDE.md `Current Status` 섹션의 "v2.6.2 (빌드 52) WAITING_FOR_REVIEW" 표기 stale — APPROVED로 업데이트 필요 (Phase 4 또는 별도 docs sync TODO).

## P0-5
- [ ] H-11 (Partner visibility 실 배포 검증): Firebase Console Rules Simulator 3 시나리오 수동 테스트 필수 — (a) owner read ALLOW, (b) partner in sharedWith collectionGroup read ALLOW, (c) unknown uid read DENY. 자동화 불가.
- [ ] 향후 kickSessions/prenatalVisits/pregnancyChecklists/pregnancyWeights/pregnancySymptoms 하위 컬렉션의 partner-facing collectionGroup 쿼리가 추가되면 해당 collectionGroup 규칙 확장 필요. 현재 v2.8 spec 범위 외.

## P1-5
- [ ] birthCTABanner가 dueDate 설정된 모든 임신 주차에서 노출됨 (P1-5 literal spec 준수, UX 부작용 가능). H-2 (Product+QA) 수동 검토 후 `dDay <= 28` 또는 `<= 0` 게이트 추가 여부 결정.

## P1-2
- [ ] AddBabyView.swift의 임신 진입점을 AppContext 기반 gating으로 전환할지 P1-4/P3-1에서 결정. 현재는 XCUITest backward compat 목적으로 유지.
- [ ] FeatureFlags.pregnancyModeEnabled gate는 P2-4 FeatureFlagService 도입 후 동일 위치에서 교체.

## P0-3
- [ ] PLAN.md Research Findings의 gap-analyzer 전제 오류 — `markTransitionPending 명시적 호출 0건` 문구 수정 필요 (근거: `PregnancyViewModel.swift:365`).
- [ ] Orphan 시나리오(v1 빌드 56-61 기간 pending 문서)에 대한 Baby 존재 여부 체크 로직이 v1에 없음 — P2-1/P2-2에서 구현 필요.

