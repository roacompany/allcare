# pregnancy-mode-v2 Learnings

## P0-3
- gap-analyzer의 `markTransitionPending 0건 호출` 분석은 오류. 실제 호출은 `PregnancyViewModel.swift:365`에 존재. Scenario (c) 채택 → `pending_is_valid=valid`, P2-2 Resume UI 유효.
- v1은 이미 2단계 commit 패턴(markTransitionPending → WriteBatch)을 올바르게 구현. v2에서도 동일 패턴 보존 권장.
- Scenario 분류 전 실제 코드 grep 필수 — 분석 전제 오류 가능.

## P0-4
- PLAN.md Verification Summary에 H-item이 10개가 아닌 12개(H-1~H-12) — Spec 내 숫자 표기(`H-items 10개`)와 실제 데이터 불일치. 실제는 12개 채택.
- v2.7.1 QA evidence 포맷(`H | 영역 | 자동검증 | 결과 | 비고`)에서 v2는 `평가자`, `기준`, `Evidence 포맷`, `기한` 4컬럼 확장.
- H-4/H-10 외부 의존은 평가자 셀에 "AI 에이전트 불가" 태그로 명시 필요 — 할당 혼동 방지.

