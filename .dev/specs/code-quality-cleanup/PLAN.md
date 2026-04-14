# BabyCare 코드 품질 개선

> arch-test 17건 위반 → 0건, SwiftLint 21 warnings → 0, dead code 정리
> Mode: standard/autopilot

## Verification Summary

### Agent-Verifiable (A-items)
| ID | Criterion | Method | Related TODO |
|----|-----------|--------|-------------|
| A-1 | SwiftLint 0 warnings | `make lint` → "0 warning" | TODO 1 |
| A-2 | arch-test 0 violations | `bash scripts/arch_test.sh` → "0 violations" | TODO 2, 3 |
| A-3 | 빌드 성공 | `make build` → exit 0 | TODO Final |
| A-4 | 테스트 통과 | `make test` → "Executed" 포함 | TODO Final |
| A-5 | make verify 통과 | `make verify` → "ALL CHECKS PASSED" | TODO Final |

### Human-Required (H-items)
| ID | Criterion | Reason |
|----|-----------|--------|
| H-1 | 리팩토링 후 기능 동작 확인 | 앱 실행하여 주요 화면 정상 표시 확인 |

### Verification Gaps
- Xcode 시뮬레이터 UI 테스트는 자동화 미포함 (H-1로 대체)

## External Dependencies Strategy

(none)

## Context

### Original Request
arch-test 17건 위반 해소, SwiftLint 21개 warning → 0 목표, dead code 정리

### Research Findings
- **arch-test 17건**: 모두 Views→Services 직접 참조. ViewModel 생성/확장으로 해결
  - FirestoreService(6), NotificationService(4), Export/PDF(2), Catalog(1), Sound(2), SwiftUI in Models(1)
- **SwiftLint 21건**: auto-fixable 15건 + manual 6건 (function_body_length 5, cyclomatic_complexity 1)
- **Dead code**: 0건. 정리 불필요
- **arch_test.sh baseline**: 현재 17. 0으로 줄인 후 baseline도 0으로 업데이트

## Work Objectives

### Core Objective
Views에서 Services 직접 참조를 제거하고, SwiftLint 경고를 0으로 만들어 make verify가 완벽히 통과하도록 한다.

### Concrete Deliverables
- 5개 신규 ViewModel: FamilySharingViewModel, GrowthViewModel, SoundPlayerViewModel, AdminDashboardViewModel, NotificationSettingsViewModel
- 3개 기존 ViewModel 확장: HealthViewModel, StatsViewModel, ProductViewModel
- arch_test.sh baseline 0으로 업데이트
- SwiftLint warnings 0

### Definition of Done
- [ ] `make verify` → ━━━ ALL CHECKS PASSED
- [ ] `make lint` → 0 warnings, 0 errors
- [ ] `bash scripts/arch_test.sh` → 0 violations
- [ ] `make test` → 전체 테스트 통과

### Must NOT Do (Guardrails)
- Baby.gender Optional 변경 금지
- AIGuardrailService.prohibitedRules 수정 금지
- 외부 라이브러리 추가 금지
- 기능 변경/추가 금지 (순수 리팩토링만)
- FirestoreCollections 하드코딩 금지 (상수 사용 필수)
- authVM.currentUserId 직접 사용 금지 (babyVM.dataUserId() 사용)
- 테스트 파일 신규 생성 금지 (BabyCareTests.swift에 append)

---

## Task Flow

```
TODO-1 (SwiftLint auto-fix)
    ↓
TODO-2 (신규 ViewModel 생성 + Views 업데이트) ─┐
TODO-3 (기존 ViewModel 확장 + Views 업데이트)  ─┤ 병렬 가능
    ↓                                           │
TODO-4 (함수 분할 리팩토링) ←───────────────────┘
    ↓
TODO-Final (Verification)
```

## Dependency Graph

| TODO | Requires | Produces | Type |
|------|----------|----------|------|
| 1 | - | `lint_fixed_files` (list) | work |
| 2 | - | `new_viewmodels` (list) | work |
| 3 | - | `extended_viewmodels` (list) | work |
| 4 | TODO 2, 3 | `refactored_functions` (list) | work |
| Final | all | - | verification |

## Parallelization

| Group | TODOs | Reason |
|-------|-------|--------|
| A | TODO 2, TODO 3 | 서로 다른 ViewModel/View 파일 수정, 충돌 없음 |

## Commit Strategy

| After TODO | Message | Condition |
|------------|---------|-----------|
| 1 | `style: fix 15 SwiftLint auto-fixable warnings` | always |
| 2 | `refactor: create 5 new ViewModels for arch boundary compliance` | always |
| 3 | `refactor: extend 3 existing ViewModels, fix Models SwiftUI import` | always |
| 4 | `refactor: split 5 long functions for SwiftLint compliance` | always |
| (after Final) | `chore: update arch_test baseline to 0` | if verification passes |

## Error Handling

### Failure Handling Flow

| Scenario | Action |
|----------|--------|
| work fails | Retry up to 2 times → Analyze → Fix Task |
| verification fails | Analyze → report (no auto-fix) |
| Build error after refactoring | Fix Task: compile error 수정 |

## Runtime Contract

| Aspect | Specification |
|--------|---------------|
| Working Directory | /Users/roque/BabyCare |
| Network Access | Denied (pure refactoring) |
| Package Install | Denied |
| File Access | Repository only |
| Max Execution Time | 10 minutes per TODO |
| Git Operations | Denied (Orchestrator handles) |

---

## TODOs

### [x] TODO 1: SwiftLint auto-fixable warnings 일괄 수정

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `lint_fixed_files` (list): 수정된 파일 목록

**Steps**:
- [ ] `SolidFoodSection.swift:3` — 중복 `import SwiftUI` 제거
- [ ] `TemperatureSection.swift:3` — 중복 `import SwiftUI` 제거
- [ ] `StoolDetailSection.swift:3` — 중복 `import SwiftUI` 제거
- [ ] `PatternModels.swift:3` — 중복 `import Foundation` 제거
- [ ] `NotificationSettings.swift:4-5` — 중복 `import Foundation`, `import UserNotifications` 제거
- [ ] `NotificationSettingsView.swift:212` — trailing newline 수정
- [ ] `CalendarRowViews.swift:146` — trailing newline 수정
- [ ] `SleepRecordView.swift:146` — vertical whitespace 수정 (연속 빈 줄 → 1줄)
- [ ] `DashboardView+Summary.swift:93` — vertical whitespace 수정
- [ ] `DashboardView+Header.swift:308` — vertical whitespace 수정
- [ ] `DashboardView+Shortcuts.swift:247` — vertical whitespace 수정
- [ ] `AuthViewModel.swift:68-69` — else/catch를 같은 줄로 이동 (statement_position)
- [ ] `AuthViewModel.swift:148` — 409자 라인 분할 (line_length)

**Must NOT do**:
- 로직 변경 금지 (포맷팅만)
- git 명령 실행 금지

**References**:
- `.swiftlint.yml` — 현재 규칙 설정

**Acceptance Criteria**:

*Functional:*
- [ ] 모든 대상 파일에서 해당 경고 제거됨

*Static:*
- [ ] `make lint` → warnings 6개 이하 (function_body_length/cyclomatic 만 남음)

*Runtime:*
- [ ] `make build` → 빌드 성공

---

### [x] TODO 2: 신규 ViewModel 5개 생성 + Views 업데이트

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `new_viewmodels` (list): 생성된 ViewModel 파일 경로 목록

**Steps**:
- [ ] `FamilySharingViewModel.swift` 생성 — FamilySharingView의 `FirestoreService.shared` 호출을 VM으로 이동 (generateInvite, joinFamily, removeSharedAccess, fetchSharedAccess)
- [ ] `FamilySharingView.swift` 업데이트 — `firestoreService` 제거, VM 사용
- [ ] `GrowthViewModel.swift` 생성 — GrowthView의 `FirestoreService.shared` + `NotificationService` 호출을 VM으로 이동 (loadRecords, saveRecord, scheduleGrowthVelocityAlert)
- [ ] `GrowthView.swift` 업데이트 — service 직접 참조 제거, VM 사용
- [ ] `SoundPlayerViewModel.swift` 생성 — SoundPlayerView의 `SoundPlayerService.shared` + `SoundLibraryService.shared` 래핑
- [ ] `SoundPlayerView.swift` 업데이트 — @State service 제거, VM 사용
- [ ] `AdminDashboardViewModel.swift` 생성 — AdminDashboardView의 `FirestoreService.shared.fetchUserCount()` 래핑
- [ ] `AdminDashboardView.swift` 업데이트 — service 직접 참조 제거
- [ ] `NotificationSettingsViewModel.swift` 생성 — NotificationSettingsView의 `NotificationService.shared` 호출 래핑
- [ ] `NotificationSettingsView.swift` 업데이트 — service 직접 참조 제거

**Must NOT do**:
- 기존 ViewModel(ActivityViewModel, BabyViewModel 등) 수정 금지
- 기능 변경 금지 (서비스 호출을 VM으로 위임만)
- 새 ViewModel은 `@MainActor @Observable` 패턴 준수
- git 명령 실행 금지

**References**:
- `BabyCare/ViewModels/ActivityViewModel.swift` — @MainActor @Observable VM 패턴
- `BabyCare/ViewModels/BabyViewModel.swift` — service 래핑 패턴 (dataUserId 사용)
- `BabyCare/Utils/Constants.swift:65-88` — FirestoreCollections 상수

**Acceptance Criteria**:

*Functional:*
- [ ] 5개 신규 ViewModel 파일 존재
- [ ] FamilySharingView, GrowthView, SoundPlayerView, AdminDashboardView, NotificationSettingsView에서 Service 직접 참조 0건

*Static:*
- [ ] `make build` → 빌드 성공

*Runtime:*
- [ ] `make test` → 기존 테스트 통과

---

### [x] TODO 3: 기존 ViewModel 확장 + 나머지 arch 위반 수정

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `extended_viewmodels` (list): 수정된 ViewModel/View 파일 경로 목록

**Steps**:
- [ ] `HealthViewModel.swift` 확장 — `loadAllergyRecords()`, `deleteAllergyRecord()`, `saveAllergyRecord()`, `scheduleHospitalReminder()`, `cancelHospitalReminder()` 추가
- [ ] `AllergyListView.swift` 업데이트 — `FirestoreService.shared` 제거, HealthViewModel 사용
- [ ] `AddAllergyView.swift` 업데이트 — `FirestoreService.shared` 제거, HealthViewModel 사용
- [ ] `HospitalVisitFormFields.swift` 업데이트 — `NotificationService.shared` 제거, HealthViewModel 사용
- [ ] `HospitalVisitFormSheet.swift` 업데이트 — `NotificationService.shared` 제거, HealthViewModel 사용
- [ ] `StatsViewModel.swift` 확장 — `generateCSVExport()`, `generatePDFReport()`, `fetchGrowthRecords()` 추가
- [ ] `StatsView.swift` 업데이트 — ExportService, FirestoreService, PDFReportService 직접 참조 제거
- [ ] `ProductViewModel.swift` 확장 — `fetchCatalogSuggestions()` 추가
- [ ] `AddProductView.swift` 업데이트 — CatalogService 직접 참조 제거
- [ ] `DashboardView+Actions.swift` 수정 — NotificationService.shared.requestPermission() 호출을 ActivityViewModel 경유로 변경
- [ ] `DevelopmentContent.swift` 수정 — `import SwiftUI` 제거, Color 참조를 String 색상코드로 변경 또는 파일을 Views/ 하위로 이동

**Must NOT do**:
- 기능 변경 금지 (서비스 호출을 VM으로 위임만)
- babyVM.dataUserId() 패턴 유지 (authVM.currentUserId 직접 사용 금지)
- git 명령 실행 금지

**References**:
- `BabyCare/ViewModels/HealthViewModel.swift` — 기존 health 관련 메서드 패턴
- `BabyCare/ViewModels/StatsViewModel.swift` — 기존 stats 메서드 패턴
- `BabyCare/ViewModels/ProductViewModel.swift` — 기존 product 메서드 패턴
- `BabyCare/Services/FirestoreService+Allergy.swift` — allergy CRUD 메서드
- `BabyCare/Services/FirestoreService+Health.swift` — hospital visit 메서드

**Acceptance Criteria**:

*Functional:*
- [ ] AllergyListView, AddAllergyView, HospitalVisitFormFields, HospitalVisitFormSheet, StatsView, AddProductView, DashboardView+Actions, DevelopmentContent에서 Service 직접 참조 0건

*Static:*
- [ ] `make build` → 빌드 성공

*Runtime:*
- [ ] `make test` → 기존 테스트 통과

---

### [x] TODO 4: 함수 분할 리팩토링 (function_body_length + cyclomatic_complexity)

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `new_viewmodels` (list): `${todo-2.outputs.new_viewmodels}` — TODO 2에서 생성된 VM (GrowthView 변경 확인용)
- `extended_viewmodels` (list): `${todo-3.outputs.extended_viewmodels}` — TODO 3에서 수정된 VM

**Outputs**:
- `refactored_functions` (list): 분할된 함수 목록

**Steps**:
- [ ] `ActivityViewModel+Save.swift:25` — `performSaveActivity()` (104줄, complexity 23) 분할:
  - 각 activity type별 핸들러 추출: `handleFeedingBreast()`, `handleSleep()`, `handleDiaper()` 등
  - 공통 로직 추출: `applyTimerDuration()`, `applyManualTimeAdjustment()`, `resetActivityForm()`
- [ ] `PDFReportService.swift:11` — `generateReport()` (275줄) 분할:
  - 섹션별 추출: `generateCoverPage()`, `generateFeedingSection()`, `generateSleepSection()`, `generateTemperatureSection()`, `generateGrowthSection()`
- [ ] `GrowthView+Records.swift:8` — `recordRow()` (90줄) 분할:
  - 반복 패턴 추출: `recordMetricView(label:value:metric:)` 헬퍼 생성
- [ ] `PatternReport+Feeding.swift:7` — `feedingSection()` (95줄) 분할:
  - `feedingSummaryBar()`, `feedingTrendChart()`, `feedingPeakHoursView()` 추출
- [ ] `PatternReport+Diaper.swift:7` — `diaperSection()` (95줄) 분할:
  - `diaperSummaryBar()`, `diaperTrendChart()`, `diaperDistributionView()` 추출

**Must NOT do**:
- 기능 변경 금지 (분할만, 로직 동일 유지)
- 새 파일 생성 지양 (같은 파일 내 private 함수 추출)
- git 명령 실행 금지

**References**:
- `BabyCare/ViewModels/ActivityViewModel+Save.swift:25` — performSaveActivity
- `BabyCare/Services/PDFReportService.swift:11` — generateReport
- `BabyCare/Views/Growth/GrowthView+Records.swift:8` — recordRow
- `BabyCare/Views/Stats/PatternReport+Feeding.swift:7` — feedingSection
- `BabyCare/Views/Stats/PatternReport+Diaper.swift:7` — diaperSection

**Acceptance Criteria**:

*Functional:*
- [ ] 분할 후 동일 기능 동작 (API 변경 없음)

*Static:*
- [ ] `make lint` → 0 warnings, 0 errors

*Runtime:*
- [ ] `make build` → 빌드 성공
- [ ] `make test` → 전체 테스트 통과

---

### [x] TODO Final: Verification

**Type**: verification

**Required Tools**: make, swiftlint, bash

**Inputs**:
- `lint_fixed_files` (list): `${todo-1.outputs.lint_fixed_files}`
- `new_viewmodels` (list): `${todo-2.outputs.new_viewmodels}`
- `extended_viewmodels` (list): `${todo-3.outputs.extended_viewmodels}`
- `refactored_functions` (list): `${todo-4.outputs.refactored_functions}`

**Outputs**: (none)

**Steps**:
- [ ] `make verify` 실행 — 전체 파이프라인 통과 확인
- [ ] `make lint` 실행 — 0 warnings 확인
- [ ] `bash scripts/arch_test.sh` 실행 — 0 violations 확인
- [ ] `make test` 실행 — 전체 테스트 통과 확인
- [ ] arch_test.sh baseline 17 → 0 업데이트 필요 여부 확인

**Must NOT do**:
- Edit/Write 도구 사용 금지
- 소스 코드 수정 금지 (보고만)
- git 명령 실행 금지
- Bash는 테스트/빌드/린트 실행에만 허용

**Acceptance Criteria**:

*Functional:*
- [ ] `make verify` → "━━━ ALL CHECKS PASSED ━━━" 출력
- [ ] `bash scripts/arch_test.sh` → "0 violations" 출력

*Static:*
- [ ] `make lint` → "0 warning(s), 0 error(s)" 출력

*Runtime:*
- [ ] `make test` → "Executed" + "0 failures" 포함
