# pregnancy-mode-v2 Issues

## P0-1
- [ ] pregnancy-weeks.json 의료 검증은 외부 전문가 의존 — v2에서도 자동화 불가 (H-4 handoff).
- [ ] orphan pending 복구(Resume UI) XCUITest — 실제 pending 문서 생성 자동화 어려움, H-9 실기기 의존 그대로 유지.

## P0-3
- [ ] PLAN.md Research Findings의 gap-analyzer 전제 오류 — `markTransitionPending 명시적 호출 0건` 문구 수정 필요 (근거: `PregnancyViewModel.swift:365`).
- [ ] Orphan 시나리오(v1 빌드 56-61 기간 pending 문서)에 대한 Baby 존재 여부 체크 로직이 v1에 없음 — P2-1/P2-2에서 구현 필요.

