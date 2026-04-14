# Tier 1 기능 강화 Learnings (2026-04-14)

## SwiftLint 레거시 도입 전략

- 391 warnings + 15 errors → 0으로 줄이는 방법:
  1. 대규모 위반 규칙 (comma 108건, redundant_string_enum_value 38건) → `disabled_rules`
  2. 임계값 위반 → 현재 최댓값+여유분으로 완화
  3. 0~9건 위반 → 즉시 수정
- WHO LMS 의학 표준 변수 (L, M, S) → `identifier_name.excluded`에 도메인 예외

## arch_test.sh Baseline 패턴

- `BASELINE=N` 하드코딩 → 초과 시 실패, 이하 시 경고
- 위반 줄이면 baseline 낮춰 커밋 → CI가 퇴행 방지
- `((VIOLATIONS++)) || true`: set -e에서 0 반환 시 종료 방지

## FeedingPrediction Day/Night 분리

- 낮 gap filter: < 21600 (6h) — 기존 유지
- 밤 gap filter: < 43200 (12h) — 야간 수유 간격이 6h 초과 빈번
- 분류 기준: 수유 startTime의 hour (gap 중점 아님)
- `isDayHour` internal static func (not private) → @testable import 테스트 가능

## SourceKit 진단 ≠ 빌드 에러

- SourceKit diagnostics는 IDE 실시간 인덱싱 결과
- xcodebuild 컴파일과 별개 — make build 통과해도 SourceKit 에러 존재 가능
- Worker 에이전트 지침: "SourceKit 무시, make verify 결과만 신뢰"

## Plan Reviewer 효과

- cross-midnight lastFeeding 버그 사전 차단 (deriveLatestActivities 호출 순서)
- predictionText isPersonalized 파라미터 하위 호환성 (default=false)
- HealthPattern에 previousDailyAverage 없음 → 주간 인사이트에서 health 카테고리 제외

## 병렬 Worker 실행

- 조건: 수정 파일이 겹치지 않음 + 한쪽 결과가 다른 쪽 입력이 아님
- git commit만 순차 처리
- TODO 2a/2b/3 병렬 성공 (WeeklyInsight: 카드/알림/테스트 독립)
