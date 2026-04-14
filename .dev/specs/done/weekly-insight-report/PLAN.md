# 주간 인사이트 리포트

> 매주 "지난주 육아 리포트" 인앱 카드 + 푸시 알림. 핵심 변화 3가지 자동 추출.
> Mode: standard/autopilot

## Assumptions

| Decision Point | Assumed Choice | Rationale | Source |
|---------------|---------------|-----------|--------|
| 인사이트 생성 위치 | WeeklyInsightService (static enum) | 기존 FeedingPredictionService/PatternAnalysisService 패턴 | codebase-pattern |
| 푸시 알림 시점 | 앱 포그라운드 시 주 1회 체크 (월요일) | 백그라운드 fetch 없이 심플하게 | lower-risk |
| 인사이트 개수 | 최대 3개 | 수면 부족 부모에게 정보 과부하 방지 | UX-review |
| 변화량 표시 | "↑15%" / "↓10%" 텍스트 + 색상 (초록/빨강) | Apple Charts 추가 불필요, 텍스트로 충분 | lower-risk |
| 데이터 소스 | PatternAnalysisService 기존 비교 데이터 (previousDailyAverage) | 이미 전주 대비 데이터 존재 | codebase-pattern |
| 카드 위치 | 대시보드 상단 (predictionSection 위) | 첫 화면에서 바로 보이도록 | UX-review |
| 알림 toggle | NotificationSettings에 weeklyInsightEnabled (default: true) | 기본 ON, 사용자가 끌 수 있도록 | lower-risk |

> **Note**: Not confirmed by user — re-run with --interactive to override.

## Verification Summary

### Agent-Verifiable (A-items)
| ID | Criterion | Method | Related TODO |
|----|-----------|--------|-------------|
| A-1 | WeeklyInsightService 인사이트 3개 생성 | `make test` | TODO 1 |
| A-2 | 빈 데이터 시 빈 배열 반환 | `make test` | TODO 1 |
| A-3 | 빌드 성공 | `make build` | TODO Final |
| A-4 | SwiftLint 0 warnings | `make lint` | TODO Final |
| A-5 | arch-test 0 violations | `make arch-test` | TODO Final |
| A-6 | make verify 통과 | `make verify` | TODO Final |

### Human-Required (H-items)
| ID | Criterion | Reason |
|----|-----------|--------|
| H-1 | 인사이트 카드 렌더링/레이아웃 | Dynamic Type 시각 확인 |
| H-2 | 푸시 알림 수신 확인 | 실 디바이스 |
| H-3 | 변화량 텍스트 자연스러움 | 한국어 표현 주관적 판단 |

### Verification Gaps
- 백그라운드 notification 전달 불완전 — 실 디바이스 확인 필요

## External Dependencies Strategy

(none)

## Context

### Original Request
매주 월요일 "지난주 육아 리포트" 푸시 알림 + 인앱 카드. 핵심 변화 3가지 자동 추출, 전주 대비 변화량 시각화, 대시보드 상단 "이번 주 하이라이트" 카드.

### Research Findings
- PatternModels에 `previousDailyAverage` 필드 이미 존재 (FeedingPattern, SleepPattern, DiaperPattern)
- `intervalTrend` (Trend enum: .increasing/.decreasing/.stable) 이미 있음
- PatternAnalysisService가 전주 대비 비교 분석 이미 수행
- PatternReportViewModel이 PatternAnalysisService 호출하여 주간/월간 리포트 생성
- NotificationService에 알림 스케줄링 인프라 완비
- DashboardView+Shortcuts에 predictionSection 이미 존재 (위에 카드 추가 가능)

## Work Objectives

### Core Objective
주간 패턴 변화를 자동 추출하여 대시보드 인사이트 카드와 푸시 알림으로 부모에게 능동적으로 전달.

### Concrete Deliverables
- `WeeklyInsightService.swift` — 인사이트 3개 자동 추출 서비스
- `WeeklyInsightCard` — 대시보드 상단 인사이트 카드 뷰
- 주간 알림 — 앱 포그라운드 시 월요일 1회 푸시
- 단위 테스트 5개 이상

### Definition of Done
- [ ] `make verify` → ALL CHECKS PASSED
- [ ] 대시보드에 인사이트 카드 표시
- [ ] 인사이트 3개 이하 생성 (빈 데이터 시 미표시)
- [ ] 월요일 알림 toggle 존재

### Must NOT Do
- PatternAnalysisService 수정 금지 (기존 비교 데이터만 소비)
- AnalysisEngine, BaselineDetector 수정 금지
- Apple Charts 외 외부 차트 금지
- 의학적 판단 텍스트 금지
- 새 Firestore 컬렉션 추가 금지 (로컬 UserDefaults만)
- authVM.currentUserId 직접 사용 금지
- git 명령 실행 금지

---

## Orchestrator

### Task Flow

```
TODO-1 (WeeklyInsightService 생성)
    ↓
TODO-2a (대시보드 인사이트 카드) ─┐
TODO-2b (주간 인사이트 알림)     ─┤ 병렬 (모두 TODO 1에만 의존)
TODO-3  (단위 테스트)            ─┘
    ↓
TODO-Final (Verification)
```

### Dependency Graph

| TODO | Requires | Produces | Type |
|------|----------|----------|------|
| 1 | - | `service_path` (file) | work |
| 2a | TODO 1 | `card_integrated` (bool) | work |
| 2b | TODO 1 | `notification_added` (bool) | work |
| 3 | TODO 1 | `tests_added` (list) | work |
| Final | all | - | verification |

### Parallelization

| Group | TODOs | Reason |
|-------|-------|--------|
| A | TODO 2a, 2b, 3 | 모두 TODO 1에만 의존, 서로 다른 파일 수정 |

### Commit Strategy

| After TODO | Message | Condition |
|------------|---------|-----------|
| 1 | `feat(insight): add WeeklyInsightService for pattern change extraction` | always |
| 2a | `feat(dashboard): add weekly insight card to dashboard` | always |
| 2b | `feat(notification): add weekly insight push notification` | always |
| 3 | `test(insight): add 5+ unit tests for weekly insight generation` | always |

## Error Handling

| Scenario | Action |
|----------|--------|
| work fails | Retry up to 2 times → Fix Task |
| verification fails | Analyze → report |

## Runtime Contract

| Aspect | Specification |
|--------|---------------|
| Working Directory | /Users/roque/BabyCare |
| Network Access | Denied |
| Package Install | Denied |
| Max Execution Time | 10 minutes per TODO |
| Git Operations | Denied |

---

## TODOs

### [x] TODO 1: WeeklyInsightService 생성

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `service_path` (file): `BabyCare/Services/WeeklyInsightService.swift`

**Steps**:
- [ ] Read `BabyCare/Services/PatternModels.swift` — PatternReport, FeedingPattern, SleepPattern, DiaperPattern 구조 파악
- [ ] Read `BabyCare/Services/PatternAnalysisService.swift` — 기존 비교 분석 로직 파악
- [ ] `BabyCare/Services/WeeklyInsightService.swift` 생성 (static enum):
  - `struct Insight: Identifiable` — id, category (feeding/sleep/diaper — health 제외: HealthPattern에 previousDailyAverage 없음), title (String), detail (String), changePercent (Double?), trend (Trend)
  - `static func generateInsights(from report: PatternReport) -> [Insight]` — 최대 3개 반환
  - 생성 로직:
    1. 각 카테고리의 dailyAverage vs previousDailyAverage 비교
    2. 변화율 계산: `(current - previous) / previous * 100`
    3. 변화율 절대값 기준 상위 3개 선택 (가장 큰 변화가 먼저)
    4. title 생성: "수유 횟수 15% 증가", "수면 시간 안정화", "배변 횟수 20% 감소"
    5. detail 생성: "일 평균 6.2회 → 7.1회 (전주 대비)"
  - 빈 데이터/previousDailyAverage nil → 해당 카테고리 스킵
  - 변화율 5% 미만 → "안정화" 표시
- [ ] Verify `make build` → exit 0
- [ ] Verify `make lint` → 0 warnings

**Must NOT do**:
- PatternAnalysisService 수정 금지
- Firestore 호출 금지 (순수 계산만)
- static enum 패턴 유지
- git 명령 실행 금지

**References**:
- `BabyCare/Services/PatternModels.swift:22-56` — FeedingPattern/SleepPattern/DiaperPattern (previousDailyAverage)
- `BabyCare/Services/FeedingPredictionService.swift` — static enum 패턴 참고
- `BabyCare/Services/PatternAnalysisService.swift` — 기존 분석 로직

**Acceptance Criteria**:

*Functional:*
- [ ] WeeklyInsightService.swift 존재
- [ ] generateInsights가 PatternReport에서 최대 3개 Insight 반환
- [ ] 빈 데이터 시 빈 배열 반환

*Static:*
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

*Runtime:*
- [ ] `make test` → 58 tests, 0 failures

---

### [x] TODO 2a: 대시보드 인사이트 카드

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `service_path` (file): `${todo-1.outputs.service_path}`

**Outputs**:
- `card_integrated` (bool): true

**Steps**:
- [ ] `ActivityViewModel.swift` — `weeklyInsights: [WeeklyInsightService.Insight]` property 추가
- [ ] `ActivityViewModel.swift` — `loadTodayActivities()` 내에서 주간 분석 호출 추가:
  - PatternAnalysisService로 지난 7일 + 그 전 7일 데이터 분석
  - WeeklyInsightService.generateInsights(from: report) 호출
  - weeklyInsights에 저장
- [ ] `DashboardView+Shortcuts.swift` (또는 별도 서브뷰) — 인사이트 카드 생성:
  - "이번 주 하이라이트" 헤더
  - 각 Insight를 행으로 표시: 아이콘 + title + changePercent (↑↓ 색상)
  - 빈 경우 미표시 (카드 자체 숨김)
  - SF Symbols 아이콘: 수유=fork.knife, 수면=moon.zzz, 배변=drop.fill
- [ ] predictionSection 위에 인사이트 카드 삽입
- [ ] Verify `make build` → exit 0
- [ ] Verify `make lint` → 0 warnings

**Must NOT do**:
- PatternAnalysisService 수정 금지
- WeeklyInsightService 수정 금지 (TODO 1에서 완료)
- NotificationService/NotificationSettings 수정 금지 (TODO 2b 범위)
- git 명령 실행 금지

**References**:
- `BabyCare/Views/Dashboard/DashboardView+Shortcuts.swift` — predictionSection 위치
- `BabyCare/ViewModels/PatternReportViewModel.swift` — 기존 PatternAnalysisService 호출 방식
- `BabyCare/ViewModels/ActivityViewModel.swift` — loadTodayActivities 패턴

**Acceptance Criteria**:

*Functional:*
- [ ] 대시보드에 인사이트 카드 표시 (데이터 있을 때)
- [ ] 빈 인사이트 시 카드 미표시

*Static:*
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

*Runtime:*
- [ ] `make test` → 58 tests, 0 failures

---

### [x] TODO 2b: 주간 인사이트 알림

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `service_path` (file): `${todo-1.outputs.service_path}`

**Outputs**:
- `notification_added` (bool): true

**Steps**:
- [ ] `NotificationSettings.swift` — `weeklyInsightEnabled: Bool` standalone UserDefaults 프로퍼티 추가 (default: true)
- [ ] `NotificationService.swift` — `scheduleWeeklyInsight(topInsightTitle: String)` 메서드 추가:
  - identifier: "weekly-insight"
  - 기존 "weekly-insight" 취소 후 스케줄
  - Content: title="주간 육아 리포트", body="{topInsightTitle}" (가장 큰 변화)
  - Trigger: 즉시 (앱 포그라운드 시 호출)
- [ ] `ActivityViewModel.swift` 또는 `AppDelegate.swift` — 앱 포그라운드 시 월요일 체크:
  - `lastWeeklyInsightDate` UserDefaults 저장
  - 현재 요일 == 월요일 AND lastDate != 오늘 AND weeklyInsightEnabled → 알림 스케줄
- [ ] `NotificationSettingsView.swift` — weeklyInsightEnabled toggle 추가 ("주간 리포트" 섹션)
- [ ] Verify `make build` → exit 0
- [ ] Verify `make lint` → 0 warnings

**Must NOT do**:
- DashboardView 수정 금지 (TODO 2a 범위)
- WeeklyInsightService 수정 금지
- 백그라운드 fetch 금지 (포그라운드 체크만)
- git 명령 실행 금지

**References**:
- `BabyCare/Services/NotificationService.swift` — 알림 스케줄링 패턴
- `BabyCare/Services/NotificationSettings.swift` — UserDefaults 프로퍼티 패턴 (feedingOverdueAlertEnabled 참고)
- `BabyCare/Views/Settings/NotificationSettingsView.swift` — toggle UI 패턴

**Acceptance Criteria**:

*Functional:*
- [ ] weeklyInsightEnabled toggle 존재
- [ ] 월요일 체크 로직 존재
- [ ] 알림 스케줄 시 기존 "weekly-insight" 취소 후 재스케줄

*Static:*
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

*Runtime:*
- [ ] `make test` → 58 tests, 0 failures

---

### [x] TODO 3: 단위 테스트

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `service_path` (file): `${todo-1.outputs.service_path}` — WeeklyInsightService만 필요

**Outputs**:
- `tests_added` (list): 테스트 함수 목록

**Steps**:
- [ ] `BabyCareTests.swift`에 `// MARK: - WeeklyInsight Tests` 섹션 추가:
  1. `testGenerateInsights_withComparisonData` — 전주 대비 데이터 있을 때 인사이트 생성
  2. `testGenerateInsights_maxThree` — 4개 카테고리 변화 있어도 최대 3개만 반환
  3. `testGenerateInsights_emptyPrevious` — previousDailyAverage nil → 빈 배열
  4. `testGenerateInsights_stableUnder5Percent` — 변화율 5% 미만 → "안정화"
  5. `testGenerateInsights_sortedByChangePercent` — 가장 큰 변화가 첫 번째
- [ ] Verify `make test` → 63+ tests, 0 failures

**Must NOT do**:
- 새 테스트 파일 생성 금지
- 기존 테스트 수정 금지
- git 명령 실행 금지

**References**:
- `BabyCareTests/BabyCareTests.swift` — 기존 테스트 패턴
- `BabyCare/Services/PatternModels.swift` — PatternReport 구조

**Acceptance Criteria**:

*Functional:*
- [ ] 5개 이상 신규 테스트 함수 존재

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 63+ tests, 0 failures

---

### [x] TODO Final: Verification

**Type**: verification

**Required Tools**: make, swiftlint, bash

**Inputs**:
- `tests_added` (list): `${todo-3.outputs.tests_added}`

**Outputs**: (none)

**Steps**:
- [ ] `make verify` → ALL CHECKS PASSED
- [ ] `make lint` → 0 warnings
- [ ] `make arch-test` → 0 violations
- [ ] `make test` → 63+ tests, 0 failures

**Must NOT do**:
- Edit/Write 금지
- git 명령 실행 금지

**Acceptance Criteria**:

*Functional:*
- [ ] `make verify` → "━━━ ALL CHECKS PASSED ━━━"

*Static:*
- [ ] `make lint` → "0 violations"

*Runtime:*
- [ ] `make test` → 63+ tests, 0 failures
