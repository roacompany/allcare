# 수유 예측 고도화 (FeedingPrediction v2)

> FeedingPredictionService를 월령 고정 간격에서 개인 패턴 학습 + 시간대 인식 기반으로 업그레이드
> Mode: standard/autopilot

## Assumptions

| Decision Point | Assumed Choice | Rationale | Source |
|---------------|---------------|-----------|--------|
| 오버듀 알림 방식 | ActivityReminderSettings에 standalone `feedingOverdueAlertEnabled` UserDefaults 프로퍼티 (default: false) | per-rule이 아닌 global toggle. Codable 스키마 변경 없음. | tradeoff-analyzer + plan-reviewer |
| Day/night 경계 | 06:00-22:00 day, 22:00-06:00 night (파라미터) | 테스트 용이성, 하드코딩 방지 | tradeoff-analyzer |
| Night interval gap filter | Night bucket: gap < 43200(12h) 허용, Day bucket: 기존 gap < 21600(6h) 유지 | Overnight feeding은 간격이 6h 초과 빈번 → 기존 6h 필터가 night 데이터 버림 | plan-reviewer |
| Interval 분류 기준 | 수유 startTime의 hour로 분류 (gap 중점 아님) | 단순하고 직관적 | plan-reviewer |
| isDayHour 접근 수준 | static func (internal, private 아님) | @testable import로 테스트 직접 호출 가능 | plan-reviewer |
| predictionText 데이터 소스 | `isPersonalized: Bool` 파라미터 추가 | 기존 `estimate: Date?` 만으로는 데이터 소스 구분 불가 | plan-reviewer |
| Cross-midnight lastFeeding | recentFeedingActivities에서 fallback 검색 | gap-analyzer 지적: 자정 이후 todayActivities 비어서 prediction nil | gap-analyzer |
| Subtitle 생성 위치 | ActivityViewModel (서비스가 아닌 VM) | 서비스는 순수 계산만, 표시 로직은 VM 담당 | tradeoff-analyzer |
| 알림 identifier | "feeding-overdue" (기존 "activity-*"와 분리) | 기존 activity reminder 취소 로직과 충돌 방지 | gap-analyzer |

> **Note**: Not confirmed by user — re-run with --interactive to override.

## Verification Summary

### Agent-Verifiable (A-items)
| ID | Criterion | Method | Related TODO |
|----|-----------|--------|-------------|
| A-1 | Day/night context-aware interval 정확 계산 | `make test` (unit tests) | TODO 1 |
| A-2 | Empty/insufficient data fallback 안전 동작 | `make test` (edge case) | TODO 1 |
| A-3 | Day/night 경계 분류 정확 (06:00=day, 22:00=night) | `make test` | TODO 1 |
| A-4 | Cross-midnight lastFeeding fallback 동작 | `make test` | TODO 2 |
| A-5 | 빌드 성공 | `make build` | TODO Final |
| A-6 | SwiftLint 0 warnings | `make lint` | TODO Final |
| A-7 | arch-test 0 violations | `make arch-test` | TODO Final |
| A-8 | make verify 통과 | `make verify` | TODO Final |

### Human-Required (H-items)
| ID | Criterion | Reason |
|----|-----------|--------|
| H-1 | 오버듀 알림 타이밍/톤 적절성 | 실 디바이스 주관적 판단 필요 |
| H-2 | 예측 정확도 체감 (실 수유 데이터) | 2-3일 관찰 필요 |
| H-3 | 대시보드 예측 카드 렌더링 | Dynamic Type 시각 확인 |

### Verification Gaps
- iOS 시뮬레이터에서 background notification 전달 불완전 — 실 디바이스 확인 필요

## External Dependencies Strategy

(none — 모든 의존성은 기존 iOS 프레임워크 + Firebase)

## Context

### Original Request
FeedingPredictionService를 월령 고정 간격에서 개인 패턴 학습 기반으로 업그레이드. 최근 7일 실제 수유 간격 평균 개인화, 시간대별 패턴(낮 vs 밤), 대시보드 표시 강화, 오버듀 푸시 알림.

### Research Findings
- FeedingPredictionService는 이미 7일 데이터를 받아 평균 계산하는 구조 (`averageInterval()`)
- 이미 overnight gap(>6h) 필터링 내장
- 데이터 <2건이면 age-based fallback
- Overdue 임계값 30분 (기존)
- Dashboard에 prediction 카드 이미 존재
- ActivityReminderSettings에 사용자 설정 간격 존재 (override 보호 필수)
- PatternReportViewModel도 FeedingPredictionService 호출 — 시그니처 변경 시 호환 필요

## Work Objectives

### Core Objective
수유 예측을 시간대 인식(낮/밤) 개인화 방식으로 업그레이드하고, 오버듀 알림을 opt-in 방식으로 추가.

### Concrete Deliverables
- FeedingPredictionService 업그레이드: 시간대 인식 개인화 간격
- ActivityViewModel 개선: cross-midnight fallback + 예측 subtitle
- 대시보드 표시 강화: "지난 7일 기준" subtitle
- 오버듀 푸시 알림: ActivityReminderSettings opt-in toggle
- 단위 테스트: 8개 이상 신규 테스트

### Definition of Done
- [ ] `make verify` → ALL CHECKS PASSED
- [ ] 새 단위 테스트 8개 이상 PASS
- [ ] Day/night context-aware 예측이 동작
- [ ] Cross-midnight lastFeeding fallback 동작
- [ ] 오버듀 알림 opt-in toggle 존재 (기본값 off)

### Must NOT Do
- AnalysisEngine, BaselineDetector, PatternClassifier 수정 금지
- FeedingPredictionService의 static enum 형태 변경 금지
- authVM.currentUserId 직접 사용 금지 (babyVM.dataUserId() 필수)
- ActivityReminderSettings.defaultRules 배열에 새 항목 추가 금지 (설정 UI 변경 없음)
- NotificationSettings.feedingReminderEnabled 삭제/이름 변경 금지
- 외부 의존성 추가 금지
- 의학적 판단 텍스트 금지
- git 명령 실행 금지

---

## Task Flow

```
TODO-1 (FeedingPredictionService 업그레이드)
    ↓
TODO-2 (ActivityViewModel + Dashboard 업데이트)
    ↓
TODO-3 (오버듀 알림 opt-in)
    ↓
TODO-4 (단위 테스트)
    ↓
TODO-Final (Verification)
```

## Dependency Graph

| TODO | Requires | Produces | Type |
|------|----------|----------|------|
| 1 | - | `service_updated` (bool) | work |
| 2 | TODO 1 | `vm_updated` (bool) | work |
| 3 | TODO 1 | `notification_updated` (bool) | work |
| 4 | TODO 1, 2, 3 | `tests_added` (list) | work |
| Final | all | - | verification |

## Parallelization

| Group | TODOs | Reason |
|-------|-------|--------|
| A | TODO 2, TODO 3 | 둘 다 TODO 1에만 의존. 서로 다른 파일 수정 |

## Commit Strategy

| After TODO | Message | Condition |
|------------|---------|-----------|
| 1 | `feat(prediction): add day/night context-aware feeding interval` | always |
| 2 | `feat(dashboard): add cross-midnight fallback + prediction subtitle` | always |
| 3 | `feat(notification): add overdue feeding alert opt-in toggle` | always |
| 4 | `test(prediction): add 8+ unit tests for personalized prediction` | always |

## Error Handling

| Scenario | Action |
|----------|--------|
| work fails | Retry up to 2 times → Fix Task |
| verification fails | Analyze → Fix Task or halt |
| Build error | Fix Task: compile error 수정 |

## Runtime Contract

| Aspect | Specification |
|--------|---------------|
| Working Directory | /Users/roque/BabyCare |
| Network Access | Denied |
| Package Install | Denied |
| File Access | Repository only |
| Max Execution Time | 10 minutes per TODO |
| Git Operations | Denied (Orchestrator handles) |

---

## TODOs

### [x] TODO 1: FeedingPredictionService 시간대 인식 업그레이드

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `service_updated` (bool): true

**Steps**:
- [ ] `FeedingPredictionService.swift` 읽어서 현재 구조 파악
- [ ] `static func isDayHour(_ hour: Int, dayStart: Int = 6, dayEnd: Int = 22) -> Bool` 추가 (internal 접근 — @testable import로 테스트 가능)
- [ ] `averageInterval()` 수정:
  - 각 수유의 startTime hour로 day/night 분류 (gap 중점이 아닌 수유 시점 기준)
  - Day bucket: gap < 21600(6h) 필터 유지 (기존 동일)
  - Night bucket: gap < 43200(12h) 필터 적용 (야간 수유 간격 6h 초과 허용)
  - 현재 시간이 night면 nightIntervals 평균 사용, day면 dayIntervals 평균 사용
  - 해당 시간대 intervals가 2개 미만이면 전체 intervals 평균으로 fallback
  - 전체도 2개 미만이면 기존 age-based fallback
  - 반환값에 `isPersonalized: Bool` 정보를 전달하기 위해 tuple 반환: `(interval: TimeInterval, isPersonalized: Bool)`
- [ ] 기존 호출 사이트 호환: ActivityViewModel, PatternReportViewModel에서 `.interval` 또는 `.0`으로 접근
- [ ] `predictionText()` 수정: `isPersonalized: Bool = false` 파라미터 추가 (default value로 기존 호출 사이트 호환). true면 "(지난 7일 기준)" suffix. PatternReportViewModel 등 기존 호출은 default false로 변경 없이 컴파일됨

**Must NOT do**:
- static enum 형태 변경 금지
- Firestore 호출 추가 금지 (순수 계산만)
- PatternReportViewModel 호출 시그니처 깨지지 않도록
- git 명령 실행 금지

**References**:
- `BabyCare/Services/FeedingPredictionService.swift:16-46` — averageInterval 현재 구현
- `BabyCare/Services/FeedingPredictionService.swift:56-59` — nextEstimate
- `BabyCare/Services/FeedingPredictionService.swift:67-86` — predictionText
- `BabyCare/Utils/Constants.swift:52-62` — feedingIntervalHours age-based table
- `BabyCare/ViewModels/ActivityViewModel.swift:77-98` — computed properties calling service

**Acceptance Criteria**:

*Functional:*
- [ ] `isDayHour(14)` returns true, `isDayHour(2)` returns false
- [ ] Day intervals과 night intervals이 분리 계산됨
- [ ] 현재 시간대에 맞는 interval이 반환됨

*Static:*
- [ ] `make build` → 빌드 성공
- [ ] `make lint` → 0 warnings

*Runtime:*
- [ ] 기존 테스트 통과

---

### [x] TODO 2: ActivityViewModel + Dashboard 업데이트

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `service_updated` (bool): `${todo-1.outputs.service_updated}`

**Outputs**:
- `vm_updated` (bool): true

**Steps**:
- [ ] `ActivityViewModel.swift` — `deriveLatestActivities()` 수정:
  - `lastFeeding`이 nil이고 `recentFeedingActivities`가 비어있지 않으면,
    `recentFeedingActivities`에서 최신 수유 기록을 `lastFeeding`으로 설정 (cross-midnight fallback)
  - 주의: 현재 `deriveLatestActivities()`는 line 112에서 todayActivities 로드 직후, recentFeedingActivities 로드 전에 호출됨. cross-midnight fallback이 동작하려면 **deriveLatestActivities() 호출을 recentFeedingActivities 로드 완료 후(line 123 이후)로 이동**해야 함
- [ ] `ActivityViewModel.swift` — `loadTodayActivities()` 내 `deriveLatestActivities()` 호출 위치를 line 112에서 line 123 이후로 이동 (recentFeedingActivities 로드 완료 후)
- [ ] `ActivityViewModel.swift` — `nextFeedingSubtitle` computed property 추가:
  - 7일 데이터 2건 이상이면 "지난 7일 패턴 기준"
  - 아니면 "월령 기준 평균"
- [ ] `DashboardView+Summary.swift` (또는 DashboardView+Shortcuts.swift) — predictionSection 업데이트:
  - subtitle 표시 추가 (기존 "다음 수유 예상" 아래에 작은 글씨로)

**Must NOT do**:
- 기존 predictionSection 레이아웃 크게 변경 금지 (compact card 유지)
- git 명령 실행 금지

**References**:
- `BabyCare/ViewModels/ActivityViewModel.swift:102-147` — loadTodayActivities, deriveLatestActivities
- `BabyCare/Views/Dashboard/DashboardView+Summary.swift:6-57` — predictionSection (또는 DashboardView+Shortcuts.swift)

**Acceptance Criteria**:

*Functional:*
- [ ] 자정 이후 todayActivities 비어도 lastFeeding이 recentFeedingActivities에서 가져와짐
- [ ] subtitle이 데이터 상태에 따라 올바르게 표시됨

*Static:*
- [ ] `make build` → 빌드 성공
- [ ] `make lint` → 0 warnings

*Runtime:*
- [ ] 기존 테스트 통과

---

### [x] TODO 3: 오버듀 알림 opt-in

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `service_updated` (bool): `${todo-1.outputs.service_updated}` — 예측 서비스 업데이트 완료

**Outputs**:
- `notification_updated` (bool): true

**Steps**:
- [ ] `NotificationSettings.swift` — `ActivityReminderSettings`에 standalone static computed property 추가:
  - `static var feedingOverdueAlertEnabled: Bool` (UserDefaults 기반, default: false)
  - Codable 스키마 변경 없음 (ActivityReminderRule struct 미수정)
- [ ] `NotificationService.swift` — `scheduleFeedingOverdueAlert(babyName:predictedTime:)` 메서드 추가:
  - identifier: "feeding-overdue"
  - 기존 "feeding-overdue" 취소 후 새로 스케줄
  - trigger: predictedTime + 30분 (기존 overdue 임계값)
  - content: "{babyName}의 수유 시간이 지났어요"
- [ ] `ActivityViewModel+Reminders.swift` — `scheduleActivityReminderIfNeeded()` 수정:
  - 수유 타입일 때 + `ActivityReminderSettings.feedingOverdueAlertEnabled` == true 이면
  - `nextFeedingEstimate`을 계산하여 `scheduleFeedingOverdueAlert` 호출
- [ ] `NotificationSettingsView.swift` — overdue alert toggle 추가 (수유 섹션 내)

**Must NOT do**:
- ActivityReminderSettings.defaultRules 배열 및 ActivityReminderRule struct 변경 금지
- 기존 "activity-feedingBreast" 등 identifier 재사용 금지
- auto-schedule 금지 (반드시 feedingOverdueAlertEnabled flag gate)
- git 명령 실행 금지

**References**:
- `BabyCare/Services/NotificationSettings.swift:79-90` — ActivityReminderSettings.defaultRules
- `BabyCare/Services/NotificationService.swift:24-51` — scheduleActivityReminder
- `BabyCare/ViewModels/ActivityViewModel+Reminders.swift:8-13` — scheduleActivityReminderIfNeeded

**Acceptance Criteria**:

*Functional:*
- [ ] feedingOverdueAlertEnabled = false (default) → 오버듀 알림 미스케줄
- [ ] feedingOverdueAlertEnabled = true → 수유 저장 시 overdue 알림 스케줄됨
- [ ] 새 수유 저장 시 이전 "feeding-overdue" 취소 후 재스케줄

*Static:*
- [ ] `make build` → 빌드 성공
- [ ] `make lint` → 0 warnings

*Runtime:*
- [ ] 기존 테스트 통과

---

### [x] TODO 4: 단위 테스트

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `notification_updated` (bool): `${todo-3.outputs.notification_updated}`

**Outputs**:
- `tests_added` (list): 추가된 테스트 함수 목록

**Steps**:
- [ ] `BabyCareTests.swift`에 append — `// MARK: - FeedingPrediction v2 Tests` 섹션:
  1. `testIsDayHour_daytime` — 14시 → true
  2. `testIsDayHour_nighttime` — 2시 → false
  3. `testIsDayHour_boundary` — 6시=day, 22시=night
  4. `testAverageInterval_dayContext` — 낮 시간에 호출 시 day intervals 우선 사용
  5. `testAverageInterval_nightContext` — 밤 시간에 호출 시 night intervals 우선 사용
  6. `testAverageInterval_insufficientDayData_fallsBackToAll` — day 데이터 1건 → 전체 평균
  7. `testAverageInterval_noData_fallsBackToAgebased` — 0건 → age-based
  8. `testCrossMidnight_lastFeedingFallback` — todayActivities 비어도 recentFeedings에서 가져옴

**Must NOT do**:
- 새 테스트 파일 생성 금지 (BabyCareTests.swift에 append)
- 기존 테스트 수정 금지
- git 명령 실행 금지

**References**:
- `BabyCareTests/BabyCareTests.swift:35-66` — Activity Model Tests 패턴
- `BabyCareTests/BabyCareTests.swift:219-282` — @MainActor 테스트 패턴

**Acceptance Criteria**:

*Functional:*
- [ ] 8개 이상 신규 테스트 함수 존재

*Static:*
- [ ] `make build` → 빌드 성공

*Runtime:*
- [ ] `make test` → 전체 테스트 통과 (기존 50 + 신규 8+ = 58+)

---

### [x] TODO Final: Verification

**Type**: verification

**Required Tools**: make, swiftlint, bash

**Inputs**:
- `tests_added` (list): `${todo-4.outputs.tests_added}`

**Outputs**: (none)

**Steps**:
- [ ] `make verify` 실행 — 전체 통과 확인
- [ ] `make lint` — 0 warnings 확인
- [ ] `make arch-test` — 0 violations 확인
- [ ] `make test` — 전체 테스트 통과 + 신규 테스트 8개 이상 확인

**Must NOT do**:
- Edit/Write 도구 사용 금지
- git 명령 실행 금지

**Acceptance Criteria**:

*Functional:*
- [ ] `make verify` → "━━━ ALL CHECKS PASSED ━━━"

*Static:*
- [ ] `make lint` → "0 violations"

*Runtime:*
- [ ] `make test` → "Executed 58 tests" 이상 + "0 failures"
