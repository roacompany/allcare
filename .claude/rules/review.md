---
globs: "**/*.swift"
---

# Code Review Process

## 주요 변경 시 리뷰 프로세스

1. **구현 완료 후**: `make verify` 통과 확인
2. **리뷰 요청**: `/review` 또는 `hoyeon:code-reviewer` (다중 모델 교차 검증)
3. **UI 변경 시**: 3-Agent QA (Visual/UX + Code Quality + Mobile Responsive)

## 교차 검증 도구

- `/review` — PR diff 기반 구조적 리뷰
- `hoyeon:code-reviewer` — Gemini + Codex + Claude 교차 리뷰, SHIP/NEEDS_FIXES 판정
- `/tribunal` — Risk/Value/Feasibility 3관점 리뷰
- `/qa` — 브라우저 기반 시각 검증 (웹 컴포넌트 해당 시)

## 리뷰 필수 대상

- Firestore 스키마/컬렉션 변경
- 인증/가족공유 로직 변경
- AI 가드레일 관련 코드
- 새 서비스 클래스 추가

## Verify/Review 방법론

- **git diff가 ground truth**: Verify agent는 반드시 `git diff HEAD -- <file>` 로 실제 변경 확인. Read tool은 세션 중 stale cache 반환 가능 — Read 결과와 git diff가 다르면 git diff 채택. pregnancy-mode-v2 P1-3에서 verify worker Read tool이 stale 내용 반환해 false FAILED 보고함.
- **XCUITest 실패 개수는 branch baseline과 diff**: 예를 들어 `FeatureFlags.pregnancyModeEnabled=false` 상태에서는 임신 UI 관련 XCUITest 6/10이 pre-existing 실패. 이를 regression으로 오판하지 말고 main 동일 branch에서 같은 failure pattern인지 확인.
- **3-Agent QA 실행 순서**: single-host machine에서 시뮬레이터 경합 방지 — Code Quality (no sim) → Mobile Responsive (static) → Visual/UX (sim). 병렬 launch 시 `signal kill` 발생하면 serial 재실행.
