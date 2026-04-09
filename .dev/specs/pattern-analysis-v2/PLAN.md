# 패턴분석 고도화 v2

> PatternReportView에 발열 패턴 분석, 데이터 품질 경고, 기간 비교, 수유 예측 어노테이션 4개 기능을 추가한다.

---

## Verification Summary

### Agent-Verifiable (A-items)
| ID | Criterion | Method | Related TODO |
|----|-----------|--------|-------------|
| A-1 | PatternModels.swift 신규 필드 추가 후 컴파일 통과 | `make build` | TODO 1 |
| A-2 | PatternAnalysisService 신규 메서드 컴파일 통과 | `make build` | TODO 2 |
| A-3 | PatternReportViewModel 이전 기간 fetch + 토글 컴파일 통과 | `make build` | TODO 3 |
| A-4 | 뷰 파일 변경 후 컴파일 통과 | `make build` | TODO 4 |
| A-5 | 기존 30개 + 신규 테스트 전체 통과 | `make test` | TODO 5 |
| A-6 | 발열 연속일 계산 테스트 통과 | `make test` | TODO 5 |
| A-7 | 누락일 계산 테스트 통과 | `make test` | TODO 5 |
| A-8 | 기간 비교 델타 계산 테스트 통과 | `make test` | TODO 5 |
| A-9 | `make verify` 전체 통과 | `make verify` | TODO Final |

### Human-Required (H-items)
| ID | Criterion | Reason | Review Material |
|----|-----------|--------|----------------|
| H-1 | 발열 어노테이션이 시각적으로 명확한지 | SwiftUI 렌더링 품질 확인 | 시뮬레이터 실행 |
| H-2 | 데이터 품질 경고 톤이 부모에게 불안감 없는지 | UX 판단 필요 | Summary 섹션 확인 |
| H-3 | 기간 비교 토글 및 델타 표시 직관적인지 | UX 판단 필요 | 시뮬레이터 실행 |
| H-4 | 예측 어노테이션이 실제 데이터로 의미 있는지 | 도메인 유효성 판단 | 실 데이터 테스트 |
| H-5 | 이전 기간 Firestore 쿼리 성능/비용 확인 | 실환경 테스트 필요 | Firebase Console |
| H-6 | 데이터 없음/적음/많음 Edge case 레이아웃 | 시뮬레이터 확인 | 다양한 데이터 상황 |

### Verification Gaps
- Tier 2-4 부재: Firebase 통합 테스트, E2E, Sandbox 인프라 없음. 신규 로직은 순수 Swift 함수로 분리하여 Tier 1 단위 테스트로 커버.

---

## External Dependencies Strategy

### Pre-work (user prepares before AI work)
| Dependency | Action | Command/Step | Blocking? |
|------------|--------|-------------|-----------|
| (none) | - | - | - |

### During (AI work strategy)
| Dependency | Dev Strategy | Rationale |
|------------|-------------|-----------|
| Firebase Firestore | 신규 계산 로직을 순수 함수로 분리, Firebase 호출 없이 단위 테스트 | 기존 패턴 유지 |
| FeedingPredictionService | 기존 서비스 직접 호출 (internal 접근 제어) | 중복 구현 방지 |

### Post-work (user actions after completion)
| Task | Related Dependency | Action | Command/Step |
|------|--------------------|--------|-------------|
| 시뮬레이터 실행 확인 | Xcode | 실 데이터로 4개 기능 동작 확인 | Xcode Run |
| Firebase 읽기 비용 확인 | Firestore | 비교 토글 사용 시 읽기 횟수 모니터링 | Firebase Console |

---

## Context

### Original Request
패턴분석 고도화 — 기간 비교, 트렌드 예측, 온도 패턴 분석, 데이터 품질 경고

### Interview Summary
**Key Discussions**:
- 기간 비교: Firestore 이전 기간 fetch는 자동이 아닌 **토글 방식** (사용자 선택, DP-01 Option B)
- 트렌드 예측: Dashboard의 `FeedingPredictionService` 재사용, 새 서비스 작성 안 함
- 발열 임계값: `ReferenceTable.feverThreshold` (38.0°C) 단일 소스 사용
- 수면 예측: 범위 외 — 수유 예측만 포함 (SleepPredictionService 없음)
- UX: 모든 statItem에 델타 금지, 섹션 하단 1줄 요약만

**Research Findings**:
- `PatternAnalysisService`는 static enum (순수 계산), `PatternReportViewModel`이 Firestore fetch 담당 — 이 분리 유지
- `PatternClassifier`가 이미 infectionSuspected 감지하나 AnalysisEngine 전용 — PatternReport에서는 단순 연속일 계산으로 충분
- `FeedingPredictionService.nextEstimate()`, `predictionText()` internal 접근 가능

---

## Work Objectives

### Core Objective
PatternReportView에 발열 패턴 어노테이션, 데이터 품질 경고, 기간 비교 델타, 수유 예측 어노테이션을 추가하여 부모가 아기의 패턴 변화를 한눈에 파악할 수 있게 한다.

### Concrete Deliverables
- `PatternModels.swift` — HealthPattern에 `consecutiveFeverDays`, SummaryPattern에 `missingDays`, FeedingPattern/SleepPattern/DiaperPattern에 optional `previousDailyAverage`
- `PatternAnalysisService.swift` — `analyzeFeverPattern()`, `analyzeMissingDays()`, `analyzeComparison()` 메서드
- `PatternReportViewModel.swift` — 비교 토글 상태, 이전 기간 fetch, 예측 데이터 로드
- `PatternReport+Health.swift` — 발열 연속일 어노테이션 + 면책 문구
- `PatternReport+Summary.swift` — 누락일 경고 1줄
- `PatternReport+Feeding.swift` — 피크 시간 아래 예측 어노테이션
- `PatternReport+Helpers.swift` — `comparisonRow()` 헬퍼
- `PatternReportView.swift` — 비교 토글 UI
- 각 섹션 뷰 — 비교 모드 시 하단 델타 row
- `BabyCareTests.swift` — 신규 테스트 추가

### Definition of Done
- [ ] `make build` 성공
- [ ] `make test` 기존 30개 + 신규 테스트 통과
- [ ] `make verify` 성공
- [ ] 4개 기능 모두 컴파일 통과 및 UI 렌더링

### Must NOT Do (Guardrails)
- `AnalysisEngine`, `BaselineDetector`, `PatternClassifier` 수정 금지 — 별도 파이프라인
- `AIGuardrailService.prohibitedRules` 수정 금지
- 외부 차트 라이브러리 금지 (Apple Charts만)
- `authVM.currentUserId` 직접 사용 금지 — `babyVM.dataUserId()` 사용
- 모든 `statItem()`에 델타 배지 추가 금지 — 섹션 하단 1줄 요약만
- 새 테스트 파일 생성 금지 — `BabyCareTests.swift`에 append
- `Baby.gender` Optional 변경 금지
- 의학적 판단 텍스트 금지 ("정상"/"비정상" 등)
- `SleepPredictionService` 신규 생성 금지 — 수유 예측만
- `FeedingPredictionService` 로직 복사 금지 — 직접 호출
- 발열 임계값 하드코딩 금지 — `ReferenceTable.feverThreshold` 참조
- 새 패키지/의존성 추가 금지

---

## Task Flow

```
TODO-1 (모델 확장) → TODO-2 (서비스 확장) → TODO-3 (뷰모델) ─┐
                                                              ├→ TODO-4 (뷰) → TODO-5 (테스트) → TODO-Final
                                                              │
```

## Dependency Graph

| TODO | Requires (Inputs) | Produces (Outputs) | Type |
|------|-------------------|-------------------|------|
| 1 | - | `models_updated` (string) | work |
| 2 | `todo-1.models_updated` | `service_updated` (string) | work |
| 3 | `todo-2.service_updated` | `viewmodel_updated` (string) | work |
| 4 | `todo-3.viewmodel_updated` | `views_updated` (string) | work |
| 5 | `todo-4.views_updated` | `tests_added` (string) | work |
| Final | all outputs | - | verification |

## Parallelization

| Group | TODOs | Reason |
|-------|-------|--------|
| - | 순차 실행 | 각 TODO가 이전 출력에 의존 |

## Commit Strategy

| After TODO | Message | Files | Condition |
|------------|---------|-------|-----------|
| 2 | `feat(analysis): add fever pattern, missing days, comparison computation` | `PatternModels.swift`, `PatternAnalysisService.swift`, `PatternAnalysis+DiaperHealth.swift`, `PatternAnalysis+Summary.swift` | always |
| 4 | `feat(pattern-report): add fever annotation, data quality warning, comparison toggle, prediction` | `PatternReportViewModel.swift`, `PatternReport*.swift` | always |
| 5 | `test(pattern): add unit tests for fever, missing days, comparison, prediction` | `BabyCareTests.swift` | always |

## Error Handling

### Failure Categories

| Category | Examples | Detection Pattern |
|----------|----------|-------------------|
| `env_error` | xcodegen 실패, SPM resolve 실패 | `/error:\|fatal:\|xcodegen.*failed/i` |
| `code_error` | Swift 컴파일 에러, 타입 불일치, 동시성 warning | `/error:\|cannot find\|is not a member/i` |
| `scope_internal` | 모델 필드 누락, 참조 경로 변경 | Worker `suggested_adaptation` present |
| `unknown` | 분류 불가 에러 | Default fallback |

### Failure Handling Flow

| Scenario | Action |
|----------|--------|
| work fails | Retry up to 2 times → Analyze → (see below) |
| verification fails | Analyze immediately (no retry) → (see below) |
| Worker times out | Halt and report |
| Missing Input | Skip dependent TODOs, halt |

### After Analyze

| Category | Action |
|----------|--------|
| `env_error` | Halt + log to `issues.md` |
| `code_error` | Create Fix Task (depth=1 limit) |
| `scope_internal` | Adapt → Dynamic TODO (depth=1) |
| `unknown` | Halt + log to `issues.md` |

## Runtime Contract

| Aspect | Specification |
|--------|---------------|
| Working Directory | `/Users/roque/BabyCare` |
| Network Access | Allowed (SPM resolve) |
| Package Install | Denied |
| File Access | Repository only |
| Max Execution Time | 5 minutes per TODO |
| Git Operations | Denied (Orchestrator handles) |

---

## TODOs

### [x] TODO 1: Extend PatternModels with new fields

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `models_updated` (string): `done`

**Steps**:
- [ ] `PatternModels.swift`의 `HealthPattern`에 `consecutiveFeverDays: Int` 필드 추가 (기본값 0)
- [ ] `PatternModels.swift`의 `SummaryPattern`에 `missingDays: Int` 필드 추가 (기본값 0)
- [ ] `PatternModels.swift`의 `FeedingPattern`에 `previousDailyAverage: Double?` 필드 추가
- [ ] `PatternModels.swift`의 `SleepPattern`에 `previousDailyAverageHours: Double?` 필드 추가
- [ ] `PatternModels.swift`의 `DiaperPattern`에 `previousDailyAverage: Double?` 필드 추가
- [ ] `make build` 확인 (xcodegen + xcodebuild)

**Must NOT do**:
- 기존 필드 제거/변경 금지
- 새 struct 생성 금지 — 기존 struct에 optional 필드 추가만
- Do not run git commands

**References**:
- `BabyCare/Services/PatternModels.swift:24-70` — 기존 5개 패턴 struct 정의
- `BabyCare/Services/Analysis/ReferenceTable.swift` — `feverThreshold = 38.0`

**Acceptance Criteria**:

*Functional:*
- [ ] `HealthPattern`에 `consecutiveFeverDays` 필드 존재
- [ ] `SummaryPattern`에 `missingDays` 필드 존재
- [ ] 3개 패턴에 `previousDailyAverage` optional 필드 존재

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 기존 테스트 통과 (회귀 없음)

**Verify**:
```yaml
commands:
  - run: "grep 'consecutiveFeverDays' BabyCare/Services/PatternModels.swift"
    expect: "exit 0"
  - run: "grep 'missingDays' BabyCare/Services/PatternModels.swift"
    expect: "exit 0"
  - run: "grep 'previousDailyAverage' BabyCare/Services/PatternModels.swift"
    expect: "exit 0"
  - run: "make build"
    expect: "exit 0"
risk: LOW
```

---

### [x] TODO 2: Extend PatternAnalysisService with new computation methods

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `models_updated` (string): `${todo-1.outputs.models_updated}`

**Outputs**:
- `service_updated` (string): `done`

**Steps**:
- [ ] `PatternAnalysis+DiaperHealth.swift`의 `analyzeHealth()` 메서드에 `consecutiveFeverDays` 계산 추가:
  - 체온 기록을 날짜순 정렬
  - `ReferenceTable.feverThreshold` (38.0°C) 이상인 날짜를 추출
  - 연속된 발열 날짜의 최대 길이를 계산
  - 결과를 `HealthPattern.consecutiveFeverDays`에 할당
- [ ] `PatternAnalysis+Summary.swift`의 `analyzeSummary()` 메서드에 `missingDays` 계산 추가:
  - 기간 내 총 일수 계산 (`Calendar.dateComponents(.day, from: startDate, to: endDate).day`)
  - 기록이 있는 고유 날짜 수 계산 (`Set(activities.map { Calendar.startOfDay(for: $0.startTime) }).count`)
  - `missingDays = totalDays - recordedDays`
- [ ] `PatternAnalysisService.swift`에 `analyzeComparison()` static 메서드 추가:
  - 입력: `currentReport: PatternReport`, `previousActivities: [Activity]`, `previousPeriod: (start: Date, end: Date)`
  - 이전 기간의 feeding/sleep/diaper dailyAverage를 계산
  - `currentReport`의 각 패턴 struct에 `previousDailyAverage` 값 설정
  - 반환: 업데이트된 `PatternReport`
- [ ] `make build` 확인

**Must NOT do**:
- `AnalysisEngine`, `BaselineDetector`, `PatternClassifier` import/사용 금지
- 발열 임계값 하드코딩 금지 — `ReferenceTable.feverThreshold` 참조
- Firestore 호출 금지 — 순수 계산만
- Do not run git commands

**References**:
- `BabyCare/Services/PatternAnalysis+DiaperHealth.swift:53-81` — 기존 analyzeHealth()
- `BabyCare/Services/PatternAnalysis+Summary.swift:6-25` — 기존 analyzeSummary()
- `BabyCare/Services/PatternAnalysisService.swift:7-32` — analyze() 진입점
- `BabyCare/Services/Analysis/ReferenceTable.swift` — feverThreshold 상수

**Acceptance Criteria**:

*Functional:*
- [ ] `analyzeHealth()` 결과의 `consecutiveFeverDays`가 0 이상 정수
- [ ] `analyzeSummary()` 결과의 `missingDays`가 0 이상 정수
- [ ] `analyzeComparison()` 메서드 존재

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 기존 테스트 통과

**Verify**:
```yaml
commands:
  - run: "grep 'consecutiveFeverDays' BabyCare/Services/PatternAnalysis+DiaperHealth.swift"
    expect: "exit 0"
  - run: "grep 'missingDays' BabyCare/Services/PatternAnalysis+Summary.swift"
    expect: "exit 0"
  - run: "grep 'analyzeComparison' BabyCare/Services/PatternAnalysisService.swift"
    expect: "exit 0"
  - run: "make build"
    expect: "exit 0"
risk: MEDIUM
```

---

### [x] TODO 3: Update PatternReportViewModel with comparison toggle and prediction

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `service_updated` (string): `${todo-2.outputs.service_updated}`

**Outputs**:
- `viewmodel_updated` (string): `done`

**Steps**:
- [ ] `PatternReportViewModel.swift`에 비교 모드 상태 추가:
  - `@Published var showComparison = false` — 비교 토글 상태
  - `@Published var isLoadingComparison = false` — 비교 데이터 로딩 중
- [ ] `loadComparison()` 메서드 추가:
  - `selectedPeriod == .week`일 때만 동작 (월간은 skip)
  - 이전 7일 구간 계산 (startDate - 14일 ~ startDate - 7일)
  - Firestore에서 이전 기간 활동 fetch (`babyVM.dataUserId()` 사용)
  - `PatternAnalysisService.analyzeComparison()` 호출하여 report 업데이트
- [ ] `showComparison` 토글 변경 시 `loadComparison()` 호출
- [ ] 수유 예측 데이터 추가:
  - `var feedingPredictionText: String?` computed property
  - 기존 `FeedingPredictionService.nextEstimate()` + `predictionText()` 호출
  - 필요한 데이터: 최근 수유 활동, 아기 월령
- [ ] `make build` 확인

**Must NOT do**:
- `authVM.currentUserId` 직접 사용 금지 — `babyVM.dataUserId()` 사용
- `FeedingPredictionService` 로직 복사 금지 — 직접 호출
- `SleepPredictionService` 생성 금지
- 월간 비교 구현 금지 — 주간만
- Do not run git commands

**References**:
- `BabyCare/ViewModels/PatternReportViewModel.swift:7-107` — 기존 VM 구조
- `BabyCare/Views/Stats/PatternReport+Actions.swift:7-21` — loadReport(), requestAI()
- `BabyCare/Services/FeedingPredictionService.swift:56-59` — nextEstimate()
- `BabyCare/Services/FeedingPredictionService.swift:67-86` — predictionText()

**Acceptance Criteria**:

*Functional:*
- [ ] `showComparison` @Published 프로퍼티 존재
- [ ] `loadComparison()` 메서드 존재
- [ ] `feedingPredictionText` 프로퍼티 존재

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 기존 테스트 통과

**Verify**:
```yaml
commands:
  - run: "grep 'showComparison' BabyCare/ViewModels/PatternReportViewModel.swift"
    expect: "exit 0"
  - run: "grep 'loadComparison' BabyCare/ViewModels/PatternReportViewModel.swift"
    expect: "exit 0"
  - run: "grep 'feedingPredictionText' BabyCare/ViewModels/PatternReportViewModel.swift"
    expect: "exit 0"
  - run: "make build"
    expect: "exit 0"
risk: MEDIUM
```

---

### [x] TODO 4: Update view files with new UI elements

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `viewmodel_updated` (string): `${todo-3.outputs.viewmodel_updated}`

**Outputs**:
- `views_updated` (string): `done`

**Steps**:
- [ ] `PatternReport+Health.swift` — 발열 어노테이션 추가:
  - `consecutiveFeverDays > 0`일 때 차트 아래에 텍스트: "최근 {N}일 연속 발열 기록" (`.orange` foreground)
  - `consecutiveFeverDays >= 2`일 때 추가 안내: "연속 발열 시 소아과 상담을 권장합니다" (`.secondary` foreground)
  - 면책 문구 추가: "참고용이며 의학적 진단을 대체하지 않습니다" (`.caption`, `.secondary`)
- [ ] `PatternReport+Summary.swift` — 데이터 품질 경고 추가:
  - `missingDays > 2`일 때만 표시: "기록 누락 {N}일" (`.secondary` foreground, 비알람 톤)
  - 기존 가장 활발한 날/적은 날 아래에 1줄 추가
- [ ] `PatternReportView.swift` — 비교 토글 UI 추가:
  - 기간 피커 옆 또는 아래에 "지난주와 비교" Toggle (주간 모드에서만 표시)
  - 토글 변경 시 `vm.showComparison` 바인딩
  - 비교 로딩 중 ProgressView
- [ ] `PatternReport+Helpers.swift` — `comparisonRow()` 헬퍼 추가:
  - 입력: `current: Double`, `previous: Double?`, `unit: String`, `label: String`
  - previous가 nil이면 렌더링 안 함
  - 증감에 따라 기존 `trendBadge()` 스타일 재사용 (↑ orange, ↓ blue, → gray)
  - 포맷: "{label} {current}{unit} (지난주 {previous}{unit}, {+/-delta}{unit})"
- [ ] `PatternReport+Feeding.swift` — 비교 row + 예측 어노테이션:
  - 비교 모드일 때 섹션 하단에 `comparisonRow(current: feeding.dailyAverage, previous: feeding.previousDailyAverage, unit: "회/일", label: "일 평균")`
  - 피크 시간 칩 아래에 `vm.feedingPredictionText` 표시 (있을 때만, `.secondary` foreground, `.caption`)
- [ ] `PatternReport+Sleep.swift` — 비교 row:
  - 비교 모드일 때 섹션 하단에 `comparisonRow(current: sleep.dailyAverageHours, previous: sleep.previousDailyAverageHours, unit: "시간/일", label: "일 평균")`
- [ ] `PatternReport+Diaper.swift` — 비교 row:
  - 비교 모드일 때 섹션 하단에 `comparisonRow(current: diaper.dailyAverage, previous: diaper.previousDailyAverage, unit: "회/일", label: "일 평균")`
- [ ] `make build` 확인

**Must NOT do**:
- 모든 `statItem()`에 델타 배지 추가 금지
- 새 섹션/카드 추가 금지 — 기존 섹션 내 1줄 추가만
- 의학적 판단 텍스트 금지 ("정상"/"비정상"/"주의 필요")
- 발열 임계값 하드코딩 금지
- Apple Charts 외 차트 라이브러리 금지
- Do not run git commands

**References**:
- `BabyCare/Views/Stats/PatternReport+Health.swift:7-81` — 기존 Health 섹션
- `BabyCare/Views/Stats/PatternReport+Summary.swift:7-74` — 기존 Summary 섹션
- `BabyCare/Views/Stats/PatternReportView.swift:46-54` — 기존 기간 피커
- `BabyCare/Views/Stats/PatternReport+Helpers.swift:7-55` — statItem, trendBadge, chipView
- `BabyCare/Views/Stats/PatternReport+Feeding.swift:7-101` — 기존 Feeding 섹션 + 피크 시간 칩
- `BabyCare/Views/Stats/PatternReport+Sleep.swift:7-83` — 기존 Sleep 섹션
- `BabyCare/Views/Stats/PatternReport+Diaper.swift:7-107` — 기존 Diaper 섹션

**Acceptance Criteria**:

*Functional:*
- [ ] Health 섹션에 발열 어노테이션 코드 존재
- [ ] Summary 섹션에 누락일 경고 코드 존재
- [ ] PatternReportView에 비교 토글 존재
- [ ] Feeding 섹션에 예측 어노테이션 코드 존재
- [ ] Feeding/Sleep/Diaper 섹션에 comparisonRow 호출 존재
- [ ] Health 섹션에 면책 문구 존재

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 기존 테스트 통과

**Verify**:
```yaml
commands:
  - run: "grep '연속 발열' BabyCare/Views/Stats/PatternReport+Health.swift"
    expect: "exit 0"
  - run: "grep '기록 누락' BabyCare/Views/Stats/PatternReport+Summary.swift"
    expect: "exit 0"
  - run: "grep 'showComparison' BabyCare/Views/Stats/PatternReportView.swift"
    expect: "exit 0"
  - run: "grep 'comparisonRow' BabyCare/Views/Stats/PatternReport+Feeding.swift"
    expect: "exit 0"
  - run: "grep 'feedingPredictionText' BabyCare/Views/Stats/PatternReport+Feeding.swift"
    expect: "exit 0"
  - run: "grep '의학적 진단' BabyCare/Views/Stats/PatternReport+Health.swift"
    expect: "exit 0"
  - run: "make build"
    expect: "exit 0"
risk: LOW
```

---

### [x] TODO 5: Add unit tests for new computations

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `views_updated` (string): `${todo-4.outputs.views_updated}`

**Outputs**:
- `tests_added` (string): `done`

**Steps**:
- [ ] `BabyCareTests.swift`에 발열 연속일 테스트 추가:
  - 연속 3일 38.5°C → `consecutiveFeverDays == 3`
  - 발열 없음 → `consecutiveFeverDays == 0`
  - 간헐적 발열 (1일-쉼-1일) → `consecutiveFeverDays == 1`
- [ ] 누락일 계산 테스트 추가:
  - 7일 기간, 5일 기록 → `missingDays == 2`
  - 7일 기간, 7일 기록 → `missingDays == 0`
  - 데이터 없음 → `missingDays == 7`
- [ ] 기간 비교 델타 테산 테스트 추가:
  - 이번주 8회/일, 지난주 6회/일 → `previousDailyAverage == 6.0`
  - 이전 기간 데이터 없음 → `previousDailyAverage == nil`
- [ ] `make test` 전체 통과 확인

**Must NOT do**:
- 새 테스트 파일 생성 금지 — `BabyCareTests.swift`에 append
- Firebase 호출 테스트 금지 — 순수 계산 로직만 테스트
- Do not run git commands

**References**:
- `BabyCareTests/BabyCareTests.swift:283` — 마지막 테스트 위치 (append 지점)
- `BabyCare/Services/PatternAnalysisService.swift` — 테스트 대상 메서드

**Acceptance Criteria**:

*Functional:*
- [ ] 발열 연속일 테스트 3개 이상 존재
- [ ] 누락일 테스트 3개 이상 존재
- [ ] 비교 델타 테스트 2개 이상 존재

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 기존 30개 + 신규 모두 통과

**Verify**:
```yaml
commands:
  - run: "grep -c 'testFever\\|testMissing\\|testComparison' BabyCareTests/BabyCareTests.swift"
    expect: "≥ 8"
  - run: "make test"
    expect: "exit 0"
risk: LOW
```

---

### [x] TODO Final: Verification

**Type**: verification

**Required Tools**: `xcodebuild`, `xcodegen`

**Inputs**:
- `models_updated` (string): `${todo-1.outputs.models_updated}`
- `service_updated` (string): `${todo-2.outputs.service_updated}`
- `viewmodel_updated` (string): `${todo-3.outputs.viewmodel_updated}`
- `views_updated` (string): `${todo-4.outputs.views_updated}`
- `tests_added` (string): `${todo-5.outputs.tests_added}`

**Outputs**: (none)

**Steps**:
- [ ] `make verify` 실행 (build + test + design-verify)
- [ ] 모든 deliverable 파일 변경 확인
- [ ] 발열 어노테이션 코드 존재 확인 (grep)
- [ ] 데이터 품질 경고 코드 존재 확인 (grep)
- [ ] 비교 토글 코드 존재 확인 (grep)
- [ ] 예측 어노테이션 코드 존재 확인 (grep)
- [ ] 면책 문구 존재 확인 (grep)
- [ ] 신규 테스트 8개 이상 존재 확인 (grep count)
- [ ] `ReferenceTable.feverThreshold` 참조 확인 (하드코딩 없음)

**Must NOT do**:
- Do not use Edit or Write tools (source code modification forbidden)
- Do not add new features or fix errors (report only)
- Do not run git commands
- Bash is allowed for: running tests, builds, type checks
- Do not modify repo files via Bash (no `sed -i`, `echo >`, etc.)

**Acceptance Criteria**:

*Functional:*
- [ ] `grep 'consecutiveFeverDays' BabyCare/Services/PatternModels.swift` → exit 0
- [ ] `grep 'missingDays' BabyCare/Services/PatternModels.swift` → exit 0
- [ ] `grep 'previousDailyAverage' BabyCare/Services/PatternModels.swift` → exit 0
- [ ] `grep '연속 발열' BabyCare/Views/Stats/PatternReport+Health.swift` → exit 0
- [ ] `grep '기록 누락' BabyCare/Views/Stats/PatternReport+Summary.swift` → exit 0
- [ ] `grep 'showComparison' BabyCare/Views/Stats/PatternReportView.swift` → exit 0
- [ ] `grep 'comparisonRow' BabyCare/Views/Stats/PatternReport+Helpers.swift` → exit 0
- [ ] `grep 'feedingPredictionText' BabyCare/Views/Stats/PatternReport+Feeding.swift` → exit 0
- [ ] `grep '의학적 진단' BabyCare/Views/Stats/PatternReport+Health.swift` → exit 0
- [ ] `grep -c 'testFever\|testMissing\|testComparison' BabyCareTests/BabyCareTests.swift` → ≥ 8

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 모든 테스트 PASS
- [ ] `make verify` → exit 0

**Verify**:
```yaml
commands:
  - run: "make verify"
    expect: "exit 0"
risk: N/A
```
