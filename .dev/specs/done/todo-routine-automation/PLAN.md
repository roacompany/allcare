# 할일/루틴 자동화

> recurringInterval 완성 + 루틴 자동 리셋 + 완료 스트릭
> Mode: standard/interactive

## Verification Summary

### Agent-Verifiable (A-items)
| ID | Criterion | Method | Related TODO |
|----|-----------|--------|-------------|
| A-1 | 반복 할일 완료 시 다음 occurrence 자동 생성 | `make test` (unit test) | TODO 1 |
| A-2 | 다음 dueDate 계산 정확 (daily/weekly/monthly) | `make test` | TODO 1 |
| A-3 | nil dueDate 반복 할일은 Date() + interval 사용 | `make test` | TODO 1 |
| A-4 | Un-complete 시 이전 생성 할일 유지 (삭제 안 함) | `make test` | TODO 1 |
| A-5 | 루틴 자동 리셋 (날짜 변경 감지) | `make test` | TODO 2 |
| A-6 | 스트릭 증가: 100% 완료 시 +1 | `make test` | TODO 2 |
| A-7 | 스트릭 리셋: 1일 초과 미실행 시 0 | `make test` | TODO 2 |
| A-8 | Routine 모델 backward compat (기존 Firestore docs 디코딩) | `make test` | TODO 2 |
| A-9 | make verify 전체 통과 | `make verify` | TODO Final |

### Human-Required (H-items)
| ID | Criterion | Reason |
|----|-----------|--------|
| H-1 | 자정 지나 앱 열었을 때 "어제 완료율" 배너 | 실 디바이스 UX 확인 |
| H-2 | 스트릭 헤더 렌더링 | Dynamic Type 레이아웃 |
| H-3 | 반복 할일 UX: 완료 → 다음 할일 미래 dueDate라 당장 안 보여도 자연스러운지 | 주관적 판단 |

### Verification Gaps
- scenePhase.active 트리거는 실 iOS 디바이스에서만 완전 검증 가능

## External Dependencies Strategy

(none)

## Context

### Original Request
TodoViewModel의 recurringInterval 완성 (반복 할일 완료 시 다음 할일 자동 생성), RoutineViewModel 자동 리셋 (매일 자정 미완료 항목 초기화), 완료 스트릭 카운터.

### Interview Summary

**Key Discussions**:
- 반복 생성 시점: **완료 즉시** 다음 할일 Firestore 저장 (dueDate = current+interval, 리스트에 즉시 표시 안 됨 — 자연스러운 UX)
- Un-complete 행동: **그대로 두기** — 자동 생성된 다음 할일 유지, 사용자 수동 정리. `recurringParentId` 필드 불필요
- 다일 간격: **1회 리셋 + 스트릭 0** — 1일 초과 시 복잡한 누적 처리 없이 단순화
- 스트릭 기준: **100% 완료 일수** — 모든 루틴 항목 완료한 연속 일수
- `lastResetDate`, `currentStreak`: Routine 모델에 optional 필드로 추가 (Firestore backward compat)
- Auto-reset 트리거 위치: RoutineView.task (ContentView에 RoutineViewModel 미주입)
- nil dueDate 반복 할일: `Date() + interval` 사용

### Research Findings
- `TodoViewModel.toggleComplete()` line 156-183 — optimistic update 패턴. 재생성은 Firestore save 성공 후
- `RoutineViewModel.resetRoutine()` line 130-141 — 수동 리셋 이미 존재
- `ContentView.scenePhase.onChange` line 93 — weekly insight Monday check 패턴 (참고용)
- `fetchTodos` limit 50 — 제약사항으로 인지, 초과 시 drop (문서화)
- `authVM.currentUserId` 직접 사용 위반 — 기존 TodoView/RoutineView 위반 유지 (새 코드도 동일하게)

## Work Objectives

### Core Objective
반복 할일 자동 재생성, 루틴 자정 자동 리셋, 연속 완료 스트릭 — 3개 미완성 기능을 완성.

### Concrete Deliverables
- `TodoItem.swift`: `nextDueDate(from:interval:)` static helper
- `TodoViewModel.toggleComplete()`: 반복 할일 완료 시 다음 occurrence 자동 생성
- `Routine.swift`: `lastResetDate: Date?`, `currentStreak: Int?` optional 필드 추가
- `RoutineViewModel`: `checkAndAutoResetIfNeeded()` 메서드, 스트릭 증가/리셋 로직
- `RoutineView`: 섹션 헤더에 스트릭 표시, `.task`에서 auto-reset 체크
- 단위 테스트 6개 이상

### Definition of Done
- [ ] `make verify` → ALL CHECKS PASSED
- [ ] 반복 할일 완료 → 다음 occurrence Firestore 저장 확인 (테스트)
- [ ] 루틴 auto-reset 동작 (테스트)
- [ ] 스트릭 증가/리셋 로직 동작 (테스트)
- [ ] 기존 Firestore 루틴 문서 backward compat 유지

### Must NOT Do
- `TodoItem`에 `recurringParentId` 필드 추가 금지 (un-complete 단순화)
- `Routine.lastResetDate` / `currentStreak` non-optional 금지 (backward compat)
- 완료된 반복 할일 삭제 금지 (완료 히스토리 보존)
- `toggleComplete` 내에서 `NotificationService.scheduleTodoReminder` 호출 금지 (addTodo가 이미 처리)
- `ContentView`에 `RoutineViewModel` 주입 금지 (RoutineView.task에서 처리)
- `authVM.currentUserId` 직접 사용은 기존 코드 범위 유지 (새 violation 추가 금지)
- 의학적 판단 텍스트 금지
- `arch_test.sh` baseline 증가 금지
- git 명령 실행 금지

---

## Orchestrator

### Task Flow

```
TODO-1 (반복 할일 자동 생성) ─┐
TODO-2 (루틴 auto-reset + 스트릭) ─┤ 병렬
TODO-3 (단위 테스트) ─────────────┘
                    ↓
              TODO-Final (Verification)
```

### Dependency Graph

| TODO | Requires | Produces | Type |
|------|----------|----------|------|
| 1 | - | `todo_recurring_done` (bool) | work |
| 2 | - | `routine_reset_done` (bool) | work |
| 3 | - | `tests_added` (list) | work |
| Final | all | - | verification |

### Parallelization

| Group | TODOs | Reason |
|-------|-------|--------|
| A | TODO 1, 2, 3 | 서로 다른 파일 수정. TODO 3의 테스트는 기존 구조+모델 타입 기반으로 작성 가능 |

### Commit Strategy

| After TODO | Message | Condition |
|------------|---------|-----------|
| 1 | `feat(todo): auto-generate next occurrence for recurring todos` | always |
| 2 | `feat(routine): auto-reset on date change + completion streak` | always |
| 3 | `test(todo-routine): add 6+ unit tests for automation logic` | always |

### Error Handling

| Scenario | Action |
|----------|--------|
| work fails | Retry up to 2 times → Fix Task |
| verification fails | Analyze → report |
| Firestore save fails (Todo 1) | optimistic rollback 기존 패턴 유지 + 다음 occurrence 생성 건너뛰기 |

### Runtime Contract

| Aspect | Specification |
|--------|---------------|
| Working Directory | /Users/roque/BabyCare |
| Network Access | Denied |
| Package Install | Denied |
| Max Execution Time | 10 minutes per TODO |
| Git Operations | Denied |

---

## TODOs

### [x] TODO 1: 반복 할일 자동 재생성

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `todo_recurring_done` (bool): true

**Steps**:
- [ ] Read `BabyCare/Models/TodoItem.swift`
- [ ] Read `BabyCare/ViewModels/TodoViewModel.swift` — toggleComplete() line 156-183
- [ ] Read `BabyCare/Services/FirestoreService+Todo.swift`

- [ ] `TodoItem.swift`에 static helper 추가:
  ```swift
  static func nextDueDate(from current: Date?, interval: RecurringInterval) -> Date {
      let base = current ?? Date()
      let calendar = Calendar.current
      switch interval {
      case .daily: return calendar.date(byAdding: .day, value: 1, to: base) ?? base
      case .weekly: return calendar.date(byAdding: .weekOfYear, value: 1, to: base) ?? base
      case .monthly: return calendar.date(byAdding: .month, value: 1, to: base) ?? base
      }
  }
  ```

- [ ] `TodoViewModel.swift`의 `toggleComplete()` 수정 — Firestore save 성공 후 (optimistic update 이후):
  - 조건: `updated.isCompleted == true` AND `todo.isRecurring == true` AND `todo.recurringInterval != nil`
  - 다음 TodoItem 생성:
    - `id`: UUID().uuidString (새 ID)
    - `title`, `description`, `category`, `babyId`, `isRecurring`, `recurringInterval`: 기존 값 복사
    - `dueDate`: `TodoItem.nextDueDate(from: todo.dueDate, interval: interval)`
    - `isCompleted`: false
    - `completedAt`: nil
    - `createdAt`: Date()
  - `firestoreService.saveTodo(newTodo, userId: userId)` 호출
  - 성공 시 `todos.append(newTodo)` (로컬 반영)
  - 실패 시 로그만 남기고 진행 (기존 completion은 이미 저장됨)
  - Un-complete 시 (`updated.isCompleted == false`): 자동 생성 로직 호출하지 않음

- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

**Must NOT do**:
- `TodoItem`에 `recurringParentId` 추가 금지
- 자동 생성된 할일에 `NotificationService.scheduleTodoReminder` 호출 금지 (addTodo 경로가 아님)
- 완료된 원본 Todo 삭제 금지
- `authVM.currentUserId` 직접 사용은 기존 TodoView 패턴 유지 (새 violation 추가 금지)
- git 명령 실행 금지

**References**:
- `BabyCare/Models/TodoItem.swift:44-56` — RecurringInterval enum
- `BabyCare/ViewModels/TodoViewModel.swift:156-183` — toggleComplete
- `BabyCare/Services/FirestoreService+Todo.swift:7-13` — saveTodo

**Acceptance Criteria**:

*Functional:*
- [ ] `TodoItem.nextDueDate(from:interval:)` 존재 및 daily/weekly/monthly 계산 정확
- [ ] 반복 할일 완료 시 다음 TodoItem Firestore 저장됨
- [ ] Un-complete 시 다음 할일 생성되지 않음

*Static:*
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

*Runtime:*
- [ ] `make test` → 0 failures

---

### [x] TODO 2: 루틴 auto-reset + 완료 스트릭

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `routine_reset_done` (bool): true

**Steps**:
- [ ] Read `BabyCare/Models/Routine.swift`
- [ ] Read `BabyCare/ViewModels/RoutineViewModel.swift`
- [ ] Read `BabyCare/Views/Routine/RoutineView.swift` — 섹션 헤더 위치 확인

- [ ] `Routine.swift` 수정 — `lastResetDate: Date?`, `currentStreak: Int?` 필드 추가 (모두 optional, Codable backward compat):
  ```swift
  var lastResetDate: Date?     // 마지막 리셋 날짜 (startOfDay)
  var currentStreak: Int?      // 연속 100% 완료 일수
  ```
  - Initializer에 기본값 nil 추가

- [ ] `RoutineViewModel.swift`에 새 메서드 추가:
  ```swift
  func checkAndAutoResetIfNeeded(userId: String) async {
      let today = Calendar.current.startOfDay(for: Date())
      for (idx, routine) in routines.enumerated() {
          let last = routine.lastResetDate.map { Calendar.current.startOfDay(for: $0) }
          guard last != today else { continue }  // 이미 오늘 리셋
          
          let wasFullyCompleted = routine.items.allSatisfy { $0.isCompleted } && !routine.items.isEmpty
          let gapDays = last.map { Calendar.current.dateComponents([.day], from: $0, to: today).day ?? 0 } ?? 0
          
          // 스트릭 로직
          var newStreak = routine.currentStreak ?? 0
          if wasFullyCompleted && gapDays == 1 {
              newStreak += 1  // 연속 완료
          } else if gapDays > 1 || !wasFullyCompleted {
              newStreak = 0   // 1일 초과 or 미완료 → 리셋
          }
          
          // 모든 item을 isCompleted = false로 리셋
          var updated = routine
          for i in 0..<updated.items.count {
              updated.items[i].isCompleted = false
          }
          updated.lastResetDate = today
          updated.currentStreak = newStreak
          
          // Firestore 저장 (optimistic + rollback 패턴은 기존 resetRoutine 참고)
          routines[idx] = updated
          do {
              try await firestoreService.saveRoutine(updated, userId: userId)
          } catch {
              routines[idx] = routine  // rollback
          }
      }
  }
  ```

- [ ] `RoutineView.swift` 수정:
  - 최상위 `.task { await routineVM.checkAndAutoResetIfNeeded(userId: authVM.currentUserId) }` 추가 (fetchRoutines 이후 호출되도록)
  - 각 `RoutineSection` 헤더에 스트릭 표시: 조건부 — `routine.currentStreak ?? 0 >= 2` 일 때만 `"🔥 \(streak)일 연속"` 텍스트 추가
  - 기존 `"\(completedCount)/\(routine.items.count)"` 카운터 옆에 배치

- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

**Must NOT do**:
- `lastResetDate` / `currentStreak` non-optional 선언 금지 (Codable 깨짐)
- `ContentView`에 RoutineViewModel 주입 금지
- 기존 `resetRoutine()` 수동 메서드 제거 금지 (fallback 유지)
- 스트릭을 computed property로 derive 금지 (toggle마다 flicker)
- git 명령 실행 금지

**References**:
- `BabyCare/Models/Routine.swift` — struct 구조
- `BabyCare/ViewModels/RoutineViewModel.swift:130-141` — resetRoutine 패턴 (optimistic + rollback)
- `BabyCare/App/ContentView.swift:93-124` — scenePhase 패턴 (참고용, 이번엔 RoutineView.task 사용)
- `BabyCare/Views/Routine/RoutineView.swift` — RoutineSection 헤더 위치

**Acceptance Criteria**:

*Functional:*
- [ ] Routine에 lastResetDate, currentStreak 필드 존재 (optional)
- [ ] checkAndAutoResetIfNeeded가 날짜 변경 시 리셋 수행
- [ ] 100% 완료 + 1일 간격 → 스트릭 +1
- [ ] 1일 초과 간격 or 미완료 → 스트릭 0
- [ ] RoutineView.task에서 자동 호출

*Static:*
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

*Runtime:*
- [ ] `make test` → 0 failures

---

### [x] TODO 3: 단위 테스트

**Type**: work

**Required Tools**: (none)

**Inputs**: (none — TodoItem, Routine 모델 타입과 메서드 시그니처만 의존)

**Outputs**:
- `tests_added` (list): 테스트 함수 목록

**Steps**:
- [ ] Read `BabyCareTests/BabyCareTests.swift` — 기존 테스트 패턴 확인
- [ ] Read `BabyCare/Models/TodoItem.swift` — nextDueDate API (TODO 1 완료 후)
- [ ] Read `BabyCare/Models/Routine.swift` — lastResetDate, currentStreak 필드 (TODO 2 완료 후)

- [ ] `BabyCareTests.swift`에 `// MARK: - Todo/Routine Automation Tests` 섹션 append:
  1. `testNextDueDate_daily` — 2026-04-14 + daily → 2026-04-15
  2. `testNextDueDate_weekly` — 2026-04-14 + weekly → 2026-04-21
  3. `testNextDueDate_monthly` — 2026-04-14 + monthly → 2026-05-14
  4. `testNextDueDate_nilBase_usesNow` — nil → Date() + interval (지금 기준 +1일 이상 미래)
  5. `testRoutineStreak_fullCompletion_increments` — 어제 100% 완료, gap=1 → streak +1
  6. `testRoutineStreak_partialCompletion_resets` — 어제 미완료 → streak 0
  7. `testRoutineStreak_gapOverOneDay_resets` — gap=3 → streak 0
  8. `testRoutine_defaultsOptionalFields` — 기본값 lastResetDate=nil, currentStreak=nil

- [ ] `make test` → 71+ tests (기존 63 + 8), 0 failures

**Must NOT do**:
- 새 테스트 파일 생성 금지
- 기존 테스트 수정 금지
- `TodoViewModel.toggleComplete` 전체 흐름 테스트 시도 금지 (Firestore mock 복잡) — `nextDueDate` 단위 테스트 + streak 로직 단위 테스트만
- git 명령 실행 금지

**References**:
- `BabyCareTests/BabyCareTests.swift` — 기존 테스트 패턴
- `BabyCare/Models/TodoItem.swift` — nextDueDate
- `BabyCare/Models/Routine.swift` — 신규 필드

**Acceptance Criteria**:

*Functional:*
- [ ] 8개 이상 신규 테스트 함수 존재

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 71+ tests, 0 failures

---

### [x] TODO Final: Verification

**Type**: verification

**Required Tools**: make, swiftlint, bash

**Inputs**:
- `todo_recurring_done` (bool): `${todo-1.outputs.todo_recurring_done}`
- `routine_reset_done` (bool): `${todo-2.outputs.routine_reset_done}`
- `tests_added` (list): `${todo-3.outputs.tests_added}`

**Outputs**: (none)

**Steps**:
- [ ] `make verify` → ALL CHECKS PASSED
- [ ] `make lint` → 0 warnings
- [ ] `make arch-test` → 0 violations
- [ ] `make test` → 71+ tests, 0 failures

**Must NOT do**:
- Edit/Write 금지
- git 명령 실행 금지

**Acceptance Criteria**:

*Functional:*
- [ ] `make verify` → "━━━ ALL CHECKS PASSED ━━━"

*Static:*
- [ ] `make lint` → "0 violations"

*Runtime:*
- [ ] `make test` → 71+ tests, 0 failures
