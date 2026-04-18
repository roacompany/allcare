# 배지 시스템 Phase 1 — Model + Service + Stats + Tests

> 사용자 행동(연속 기록/마일스톤) 기반 배지 획득 로직. 백엔드/데이터 레이어만 구현. UI(스낵바, 갤러리, 홈 스트립)는 Phase 2 별도 스펙(`badges-ui`)에서 구현.
>
> **Phase 1 범위**: Badge 모델 · BadgeCatalog 8개 · UserStats · BadgeEvaluator · 기록 저장 훅 · 단위 테스트
> **Phase 2 범위 (후속)**: BadgeSnackbarView · BadgeGalleryView · 홈 스트립 · 가족 공유 토글 UI · Retroactive 토글 UI

## Verification Summary

### Agent-Verifiable (A-items)
| ID | Criterion | Method | Related TODO |
|----|-----------|--------|-------------|
| A-1 | `Badge` 모델 Codable round-trip 성공 (필수 필드 + optional 필드 포함) | `make test` | TODO 2 |
| A-2 | `BadgeCatalog.all` 8개 배지 정의 (id, category, conditionVersion, iconSFSymbol, titleKey) | `make test` | TODO 2 |
| A-3 | `BadgeCategory` enum 모든 case에 scope (aggregate/streak/firstTime) 매핑 | `make test` | TODO 2 |
| A-4 | `FirestoreCollections.badges = "badges"` + `stats = "stats"` 상수 존재 | `make build` | TODO 3 |
| A-5 | 단일 경로 `users/{uid}/badges/{badgeId}` 저장/조회 (FirestoreService+Badge) | `make test` with mock | TODO 3 |
| A-6 | `badgeId` 중복 저장 방지 — 동일 id 재수여 시 기존 문서 유지 (`getDocument` 선확인 or `setData(merge:false)`) | `make test` | TODO 3 |
| A-7 | `UserStats` 모델 (lifetime counters — feedingCount, sleepCount, diaperCount, growthRecordCount) | `make test` | TODO 4 |
| A-8 | 기록 저장 훅에서 UserStats 원자적 증가 (FieldValue.increment(1)) | `make test` with mock | TODO 4 |
| A-9 | `BadgeEvaluator.evaluate(event:userId:babyId:)` — 모든 8개 배지 경계값 정확 (99/100/101, streak 6/7/8) | `make test` | TODO 5 |
| A-10 | BadgeEvaluator 판정 결과 `Badge` 저장 (earnedByUserId, babyId, earnedAt 채움) | `make test` | TODO 5 |
| A-11 | `routine.currentStreak` 증감 로직 회귀 없음 (기존 3일/7일/30일 경계 테스트 통과) | `make test` | TODO 1 |
| A-12 | 단위 테스트 63 → 75+ (Badge 12개 이상 추가) | `make test` | TODO 6 |
| A-13 | `make verify` ALL CHECKS PASSED | `make verify` | TODO Final |
| A-14 | `make lint` 0 violations | `make lint` | TODO Final |
| A-15 | `make arch-test` baseline 유지 | `make arch-test` | TODO Final |

### Human-Required (H-items)
| ID | Criterion | Reason | Review Material |
|----|-----------|--------|----------------|
| H-1 | 실기기/시뮬레이터에서 실제 기록 저장 시 UserStats 증가 확인 (Firestore 콘솔) | 통합 동작 확인 | Firestore 콘솔 |
| H-2 | 기존 사용자 데이터 회귀 없음 (루틴/활동/성장 정상 동작) | 광범위 regresion | 시뮬레이터 수동 QA |
| H-3 | BadgeEvaluator 실제 Firestore 호출 race condition 없음 (가족 공유 2계정 동시 기록) | 단위 테스트로 재현 불가 | 실기기 2대 |

### Sandbox Agent Testing (S-items)
none — iOS 네이티브 앱, sandbox infra 없음 (docker-compose/BDD features 미존재)

### Verification Gaps
- Race condition 완전 재현 불가 (H-3로 보완)
- Retroactive 기존 카운트 집계: Phase 1에서는 클린스타트 기본값이므로 영향 없음. Phase 2에서 재평가.
- 타임존 경계 테스트: `Date()` 주입 가능한 mockClock 도입 시 검증 가능 (A-9 범위)

## External Dependencies Strategy

### Pre-work (user prepares before AI work)
(none)

### During (AI work strategy)
| Dependency | Dev Strategy | Rationale |
|------------|-------------|-----------|
| Firestore | 스키마: 신규 컬렉션 `users/{uid}/badges`, `users/{uid}/stats/lifetime` 추가 | CryRecord 선례 일치 |
| FieldValue.increment | 원자 증가, 기존 Firebase SDK 내장 | 별도 의존성 없음 |
| OfflineQueue (기존) | Badge 저장 실패 시 enqueue | 기존 인프라 재사용 |

### Post-work (user actions after completion)
| Task | Related Dependency | Action | Command/Step |
|------|--------------------|--------|-------------|
| Firestore 보안 규칙 업데이트 | Firestore | 신규 컬렉션 read/write 권한 추가 | Firebase 콘솔 or `firestore.rules` 수정 |
| Phase 2 스펙 착수 | - | `/specify badges-ui` | UI 레이어 구현 |
| 실기기 QA | H-items | H-1~H-3 시뮬레이터 수동 확인 | - |

## Context

### Original Request
배지 시스템 추가 (연속 기록/마일스톤, 독립 Firestore 컬렉션, 설정 탭 갤러리, 홈 스트립). UX Reviewer 조언으로 Full 스코프 선택. 분석 결과 10 TODOs → Phase 1(backend)/Phase 2(UI) 분할.

### Interview Summary

**Key Discussions**:
- **Q1 스코프 (C)**: Full + 홈 스트립 채택 → 분석 후 Phase 1/2 분할 (DP-03)
- **Q2 경로 (D)**: 단일 `users/{uid}/badges` + `babyId: String?` 필드 — CryRecord 선례 일치, 쿼리 단순화 (Tradeoff + Codex SWITCH)
- **Q3 선행 TODO (A)**: `routine.currentStreak` 증감 — 이미 `todo-routine-automation`에서 구현 완료 확인됨 → 회귀 검증만
- **Q4 알림 UX (A)**: 스낵바 2초 자동 — Phase 2 UI 범위
- **Q5 초기 배지 (A 균형형 8개)**: 첫걸음, 수유100, 수면50, 기저귀200, 루틴3/7/30, 성장10
- **Q6 가족 공유 (B)**: Private 기본 + 토글 — Phase 2 UI 범위
- **DP-01 Retroactive (사용자 토글, Codex 권장)**: Phase 1은 클린스타트 기본값, Phase 2에서 토글 UI
- **DP-02 Stats 문서 신설**: `users/{uid}/stats/lifetime` — count() 쿼리 비용 회피
- **Codex 반영**: BadgeViewModel 생략, 단일 `BadgeEvaluator.evaluate(event:)` 진입점, `Badge.conditionVersion` 필드, `createdAtDate: YYYY-MM-DD UTC` 타임존 정규화

### Research Findings
- `BabyCare/Models/Routine.swift:9-10` — `lastResetDate: Date?`, `currentStreak: Int?` 필드 존재
- `BabyCare/ViewModels/RoutineViewModel.swift` — `checkAndAutoResetIfNeeded` 존재 (todo-routine-automation에서 구현)
- `BabyCareTests/BabyCareTests.swift` — 루틴 스트릭 경계 테스트 기존재
- `BabyCare/Utils/Constants.swift:65-88` — `FirestoreCollections` 21개 컬렉션, `cryRecords` 최근 추가
- `BabyCare/Models/CryRecord.swift` — 독립 컬렉션 선례 (Codable, Identifiable, Hashable)
- `BabyCare/Services/FirestoreService+*.swift` — 10개 도메인 확장 패턴
- `BabyCare/Services/NotificationService.swift` — Phase 2 스낵바 대체 가능 (현재 Phase 1 미사용)
- `.claude/rules/firestore-rules.md:7-8` — FirestoreCollections 상수, `babyVM.dataUserId()` 필수
- `.claude/rules/safety.md` — `authVM.currentUserId` 직접 사용 금지
- `.claude/rules/review.md` — Firestore 스키마 변경 시 `/review` 필수

## Work Objectives

### Core Objective
배지 시스템의 데이터 레이어(Badge 모델, UserStats, BadgeEvaluator, Firestore 연동)를 구현한다. Phase 2에서 UI 추가 시 즉시 활용 가능하도록 단일 진입점 API를 제공한다.

### Concrete Deliverables
- `BabyCare/Models/Badge.swift` — `Badge`, `BadgeCategory`, `BadgeCatalog` (8개 정의 + conditionVersion)
- `BabyCare/Models/UserStats.swift` — lifetime counters
- `BabyCare/Utils/Constants.swift` — `FirestoreCollections.badges`, `FirestoreCollections.stats` 추가
- `BabyCare/Services/FirestoreService+Badge.swift` — 저장/조회/중복 방지
- `BabyCare/Services/FirestoreService+Stats.swift` — 증가/조회 (FieldValue.increment)
- `BabyCare/Services/BadgeEvaluator.swift` — 단일 `evaluate(event:userId:babyId:)` 진입점
- `BabyCare/Services/Badge/` 디렉토리 — BadgeEvaluator 관련 파일
- `BabyCareTests/BabyCareTests.swift` — 12개 이상 신규 테스트 append

### Definition of Done
- [ ] `make verify` → ALL CHECKS PASSED
- [ ] 테스트: 80 → 92+ (12개 이상 추가)
- [ ] Firestore 저장: `users/{uid}/badges/{badgeId}` 단일 경로, `babyId` optional field
- [ ] BadgeEvaluator가 8개 배지 모두 정확 판정 (경계값 테스트 통과)
- [ ] UserStats가 기록 저장 시 증가 (단위 테스트 mock 검증)
- [ ] `Badge.conditionVersion: Int` 필드 존재 (향후 조건 변경 대비)

### Must NOT Do (Guardrails)
- Phase 2 UI(스낵바, 갤러리, 홈 스트립, 가족 공유 토글) 구현 금지 — 별도 스펙
- `Milestone` 모델 수정 금지 (별개 도메인)
- `AIGuardrailService` 수정 금지
- `Baby.gender` 변경 금지
- 배지 획득 시 자동 회수 로직 금지 (기록 삭제해도 배지 보존)
- `authVM.currentUserId` 직접 사용 금지 (모든 저장 경로는 `babyVM.dataUserId()` 경유)
- 혼합 경로 (babies/.../badges) 금지 — 단일 `users/{uid}/badges`만
- `default:` 추가로 enum exhaustive 우회 금지
- 외부 차트 라이브러리 금지
- 기존 `routine.currentStreak` 로직 변경 금지 (회귀만)
- 새 테스트 파일 생성 금지 (BabyCareTests.swift에만 append)
- git 명령 실행 금지

---

## Task Flow

```
TODO-1 (currentStreak 회귀 검증) ─┐
                                  │
TODO-2 (Badge 모델) ──────────────┼──→ TODO-5 (BadgeEvaluator)
TODO-3 (FirestoreService+Badge) ──┤         │
TODO-4 (UserStats + Service) ────┘         │
                                           ↓
                                     TODO-6 (Tests)
                                           ↓
                                     TODO-Final (verify)
```

TODO 1, 2, 3, 4는 서로 독립 → 병렬 가능.
TODO 5는 2, 3, 4 산출물 필요.
TODO 6은 2~5 산출물 필요.

## Dependency Graph

| TODO | Requires | Produces | Type |
|------|----------|----------|------|
| 1 | - | `streak_regression_ok` (bool) | work |
| 2 | - | `badge_model_path` (file), `catalog_count` (int) | work |
| 3 | todo-2 | `firestore_badge_service` (file) | work |
| 4 | - | `stats_service` (file) | work |
| 5 | todo-2, todo-3, todo-4 | `evaluator` (file) | work |
| 6 | all work TODOs | `tests_added` (list) | work |
| Final | all | - | verification |

## Parallelization

| Group | TODOs | Reason |
|-------|-------|--------|
| A | TODO 1, 2, 4 | 서로 다른 파일, 독립 |
| B | TODO 3 | TODO 2의 Badge 모델 type 필요 |
| C | TODO 5 | TODO 2, 3, 4 모두 완료 후 |
| D | TODO 6 | 모든 work TODOs 완료 후 (api 시그니처 의존) |

## Commit Strategy

| After TODO | Message | Condition |
|------------|---------|-----------|
| 1 | `test(routine): verify currentStreak regression (badge pre-req)` | only if any change |
| 2 | `feat(badges): add Badge model + BadgeCatalog (8 badges)` | always |
| 3 | `feat(badges): add FirestoreService+Badge with single-path + dedup` | always |
| 4 | `feat(stats): add UserStats model + atomic increment service` | always |
| 5 | `feat(badges): add BadgeEvaluator single-entry evaluator` | always |
| 6 | `test(badges): add 12+ unit tests for badge system Phase 1` | always |

## Error Handling

| Category | Examples | Detection Pattern |
|----------|----------|-------------------|
| `env_error` | xcodebuild 시뮬레이터 누락 | `xcrun\|simulator runtime` |
| `code_error` | Swift 컴파일, SwiftLint, arch-test violation | `error:\|violation` |
| `scope_internal` | 기존 필드 충돌, Firestore backward compat 깨짐 | `decode.*fail\|duplicate` |

| Scenario | Action |
|----------|--------|
| work fails | Retry up to 2 → Fix Task |
| verification fails | Analyze immediately |

## Runtime Contract

| Aspect | Specification |
|--------|---------------|
| Working Directory | /Users/roque/BabyCare |
| Network Access | Denied |
| Package Install | Denied |
| Max Execution Time | 15 minutes per TODO |
| Git Operations | Denied |

---

## TODOs

### [x] TODO 1: routine.currentStreak 회귀 검증

**Type**: work

**Required Tools**: make

**Inputs**: (none)

**Outputs**:
- `streak_regression_ok` (bool): true

**Steps**:
- [ ] Read `BabyCare/Models/Routine.swift` (line 1-30, lastResetDate + currentStreak 필드 확인)
- [ ] Read `BabyCare/ViewModels/RoutineViewModel.swift` (checkAndAutoResetIfNeeded 구현 확인)
- [ ] Read `BabyCareTests/BabyCareTests.swift`에서 `testRoutineStreak_*` 기존 테스트 확인 (3개 기존재)
- [ ] `make test` 실행 → 기존 루틴 스트릭 테스트 모두 PASS 확인
- [ ] 변경 없이 outputs 반환 (산출물 없음 — 검증만)

**Must NOT do**:
- Routine.swift 수정 금지
- RoutineViewModel 수정 금지
- 기존 테스트 수정 금지
- git 명령 실행 금지

**References**:
- `BabyCare/Models/Routine.swift:1-30`
- `BabyCare/ViewModels/RoutineViewModel.swift`
- `BabyCareTests/BabyCareTests.swift` — `testRoutineStreak_*`

**Acceptance Criteria**:

*Functional:*
- [ ] `Routine` 모델에 `lastResetDate: Date?`, `currentStreak: Int?` 두 필드 존재
- [ ] `RoutineViewModel.checkAndAutoResetIfNeeded` 메서드 존재

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 80+ tests PASS (기존 규모 유지)

---

### [x] TODO 2: Badge 모델 + BadgeCatalog

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `badge_model_path` (file): `BabyCare/Models/Badge.swift`
- `catalog_count` (int): 8

**Steps**:
- [ ] Read `BabyCare/Models/CryRecord.swift` — Codable 패턴 참고
- [ ] Create `BabyCare/Models/Badge.swift`:
  ```swift
  import Foundation

  struct Badge: Identifiable, Codable, Hashable {
      var id: String          // BadgeCatalog.id와 동일 (예: "feeding100")
      var category: BadgeCategory
      var earnedByUserId: String   // 획득자 (가족 공유 대비 Phase 2)
      var babyId: String?     // 아기 행동 배지인 경우 연결 (Phase 2 private 필터링)
      var earnedAt: Date
      var earnedAtDateUTC: String  // YYYY-MM-DD (타임존 정규화, Codex 권고)
      var conditionVersion: Int    // 조건 변경 대비 (초기 1)
  }

  enum BadgeCategory: String, Codable, CaseIterable {
      case firstTime   // 첫 기록 등 1회성
      case aggregate   // 누적 카운트 (수유 100회 등)
      case streak      // 연속 일수 (루틴 7일 등)
  }

  enum BadgeCatalog {
      struct Definition {
          let id: String
          let category: BadgeCategory
          let titleKey: String        // i18n key
          let descriptionKey: String  // i18n key
          let iconSFSymbol: String
          let conditionVersion: Int
          let threshold: Int          // 누적/스트릭 임계값 (firstTime은 1)
          let statsField: String?     // UserStats 필드명 (firstTime/streak은 nil)
      }

      static let all: [Definition] = [
          .init(id: "firstRecord",    category: .firstTime, titleKey: "badge.firstRecord",   descriptionKey: "badge.firstRecord.desc",   iconSFSymbol: "star.fill",                   conditionVersion: 1, threshold: 1,   statsField: nil),
          .init(id: "feeding100",     category: .aggregate, titleKey: "badge.feeding100",    descriptionKey: "badge.feeding100.desc",    iconSFSymbol: "drop.fill",                   conditionVersion: 1, threshold: 100, statsField: "feedingCount"),
          .init(id: "sleep50",        category: .aggregate, titleKey: "badge.sleep50",       descriptionKey: "badge.sleep50.desc",       iconSFSymbol: "moon.zzz.fill",               conditionVersion: 1, threshold: 50,  statsField: "sleepCount"),
          .init(id: "diaper200",      category: .aggregate, titleKey: "badge.diaper200",     descriptionKey: "badge.diaper200.desc",     iconSFSymbol: "drop.triangle.fill",          conditionVersion: 1, threshold: 200, statsField: "diaperCount"),
          .init(id: "routineStreak3", category: .streak,    titleKey: "badge.routineStreak3",descriptionKey: "badge.routineStreak3.desc",iconSFSymbol: "flame.fill",                  conditionVersion: 1, threshold: 3,   statsField: nil),
          .init(id: "routineStreak7", category: .streak,    titleKey: "badge.routineStreak7",descriptionKey: "badge.routineStreak7.desc",iconSFSymbol: "flame.fill",                  conditionVersion: 1, threshold: 7,   statsField: nil),
          .init(id: "routineStreak30",category: .streak,    titleKey: "badge.routineStreak30",descriptionKey: "badge.routineStreak30.desc",iconSFSymbol: "crown.fill",                 conditionVersion: 1, threshold: 30,  statsField: nil),
          .init(id: "growth10",       category: .aggregate, titleKey: "badge.growth10",      descriptionKey: "badge.growth10.desc",      iconSFSymbol: "chart.line.uptrend.xyaxis",   conditionVersion: 1, threshold: 10,  statsField: "growthRecordCount")
      ]

      static func definition(id: String) -> Definition? {
          all.first { $0.id == id }
      }
  }
  ```
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

**Must NOT do**:
- 다른 파일 수정 금지 (Badge.swift 신규 파일만)
- `Milestone` 관련 import 금지
- 외부 라이브러리 import 금지 (Foundation만)
- git 명령 실행 금지

**References**:
- `BabyCare/Models/CryRecord.swift` — Codable 패턴

**Acceptance Criteria**:

*Functional:*
- [ ] `Badge` struct에 id, category, earnedByUserId, babyId(optional), earnedAt, earnedAtDateUTC, conditionVersion 필드 존재
- [ ] `BadgeCategory` enum 3 case (firstTime/aggregate/streak)
- [ ] `BadgeCatalog.all.count == 8`
- [ ] 각 Definition에 iconSFSymbol, threshold, statsField 존재

*Static:*
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

*Runtime:*
- [ ] TODO 6에서 종합 테스트

---

### [x] TODO 3: FirestoreService+Badge

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `badge_model_path` (file): `${todo-2.outputs.badge_model_path}`

**Outputs**:
- `firestore_badge_service` (file): `BabyCare/Services/FirestoreService+Badge.swift`

**Steps**:
- [ ] Read `BabyCare/Services/FirestoreService.swift` — 기본 패턴
- [ ] Read `BabyCare/Services/FirestoreService+*.swift` 중 유사 패턴 하나 (예: Todo or Activity)
- [ ] Read `BabyCare/Utils/Constants.swift` — FirestoreCollections 현재 상태
- [ ] `Constants.swift`에 추가:
  ```swift
  static let badges = "badges"
  static let stats = "stats"
  ```
- [ ] Create `BabyCare/Services/FirestoreService+Badge.swift`:
  ```swift
  import Foundation
  import FirebaseFirestore

  extension FirestoreService {
      /// 단일 경로: users/{userId}/badges/{badgeId}
      /// 중복 방지: 기존 문서 있으면 덮어쓰지 않음
      func saveBadge(_ badge: Badge, userId: String) async throws {
          let ref = db.collection(FirestoreCollections.users)
              .document(userId)
              .collection(FirestoreCollections.badges)
              .document(badge.id)

          let snapshot = try await ref.getDocument()
          guard !snapshot.exists else { return }   // 이미 획득 → no-op

          try ref.setData(from: badge)
      }

      func fetchBadges(userId: String) async throws -> [Badge] {
          let snapshot = try await db.collection(FirestoreCollections.users)
              .document(userId)
              .collection(FirestoreCollections.badges)
              .getDocuments()
          return snapshot.documents.compactMap { try? $0.data(as: Badge.self) }
      }

      func badgeExists(userId: String, badgeId: String) async throws -> Bool {
          let ref = db.collection(FirestoreCollections.users)
              .document(userId)
              .collection(FirestoreCollections.badges)
              .document(badgeId)
          let snapshot = try await ref.getDocument()
          return snapshot.exists
      }
  }
  ```
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings
- [ ] `make arch-test` → baseline 유지

**Must NOT do**:
- 혼합 경로(babies/.../badges) 추가 금지
- 기존 FirestoreService 확장 수정 금지
- 하드코딩된 컬렉션명 사용 금지 (FirestoreCollections 상수만)
- git 명령 실행 금지

**References**:
- `BabyCare/Services/FirestoreService+Todo.swift` 또는 `FirestoreService+CryRecord.swift`
- `BabyCare/Utils/Constants.swift:65-88`

**Acceptance Criteria**:

*Functional:*
- [ ] `FirestoreCollections.badges == "badges"`, `FirestoreCollections.stats == "stats"`
- [ ] `saveBadge` 단일 경로 `users/{uid}/badges/{id}` 저장
- [ ] 기존 문서 존재 시 no-op (중복 방지)

*Static:*
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings
- [ ] `make arch-test` → baseline 유지

*Runtime:*
- [ ] TODO 6 종합 테스트

---

### [x] TODO 4: UserStats 모델 + FirestoreService+Stats

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `stats_service` (file): `BabyCare/Services/FirestoreService+Stats.swift`

**Steps**:
- [ ] Create `BabyCare/Models/UserStats.swift`:
  ```swift
  import Foundation

  struct UserStats: Identifiable, Codable, Hashable {
      var id: String              // "lifetime" 고정
      var feedingCount: Int
      var sleepCount: Int
      var diaperCount: Int
      var growthRecordCount: Int
      var firstRecordAt: Date?
      var updatedAt: Date

      static let lifetimeId = "lifetime"
      static func empty() -> UserStats {
          UserStats(id: lifetimeId, feedingCount: 0, sleepCount: 0, diaperCount: 0, growthRecordCount: 0, firstRecordAt: nil, updatedAt: Date())
      }
  }
  ```
- [ ] Create `BabyCare/Services/FirestoreService+Stats.swift`:
  ```swift
  import Foundation
  import FirebaseFirestore

  extension FirestoreService {
      /// users/{uid}/stats/lifetime 문서 원자 증가
      /// field: "feedingCount" | "sleepCount" | "diaperCount" | "growthRecordCount"
      func incrementStats(userId: String, field: String, by value: Int = 1) async throws {
          let ref = db.collection(FirestoreCollections.users)
              .document(userId)
              .collection(FirestoreCollections.stats)
              .document(UserStats.lifetimeId)

          try await ref.setData([
              field: FieldValue.increment(Int64(value)),
              "updatedAt": FieldValue.serverTimestamp()
          ], merge: true)
      }

      func fetchStats(userId: String) async throws -> UserStats? {
          let ref = db.collection(FirestoreCollections.users)
              .document(userId)
              .collection(FirestoreCollections.stats)
              .document(UserStats.lifetimeId)
          let snapshot = try await ref.getDocument()
          return try? snapshot.data(as: UserStats.self)
      }

      /// Phase 1: firstRecordAt 설정 (최초 1회만, 이미 존재 시 no-op)
      func setFirstRecordIfMissing(userId: String, at date: Date) async throws {
          let ref = db.collection(FirestoreCollections.users)
              .document(userId)
              .collection(FirestoreCollections.stats)
              .document(UserStats.lifetimeId)
          let snapshot = try await ref.getDocument()
          if let data = snapshot.data(), data["firstRecordAt"] != nil { return }
          try await ref.setData(["firstRecordAt": Timestamp(date: date)], merge: true)
      }
  }
  ```
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

**Must NOT do**:
- stats 문서 ID를 `lifetime` 외 다른 값으로 변경 금지 (향후 월별 stats 확장 가능하지만 이번 스코프 아님)
- 기존 기록 저장 훅에 직접 호출 로직 추가 금지 (BadgeEvaluator 경유)
- git 명령 실행 금지

**References**:
- `BabyCare/Models/CryRecord.swift` — Codable 패턴
- FieldValue.increment Firestore 공식 API

**Acceptance Criteria**:

*Functional:*
- [ ] `UserStats` 4개 count 필드 + `firstRecordAt: Date?` + `updatedAt: Date`
- [ ] `incrementStats` 호출 후 문서에 해당 필드 증가
- [ ] `setFirstRecordIfMissing`는 이미 값 있으면 no-op

*Static:*
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

*Runtime:*
- [ ] TODO 6 종합 테스트

---

### [x] TODO 5: BadgeEvaluator 단일 진입점

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `badge_model_path` (file): `${todo-2.outputs.badge_model_path}`
- `firestore_badge_service` (file): `${todo-3.outputs.firestore_badge_service}`
- `stats_service` (file): `${todo-4.outputs.stats_service}`

**Outputs**:
- `evaluator` (file): `BabyCare/Services/BadgeEvaluator.swift`

**Steps**:
- [ ] Read `BabyCare/Models/Badge.swift` — BadgeCatalog API 숙지
- [ ] Create `BabyCare/Services/BadgeEvaluator.swift`:
  ```swift
  import Foundation

  /// 모든 배지 판정의 단일 진입점.
  /// 기록 저장 직후 호출 (Phase 1: 수동 호출, Phase 2: 기록 저장 훅 자동 연동)
  @MainActor
  final class BadgeEvaluator {
      struct Event {
          enum Kind {
              case feedingLogged
              case sleepLogged
              case diaperLogged
              case growthLogged
              case routineStreakUpdated(newStreak: Int)
          }
          let kind: Kind
          let babyId: String?   // 아기 관련 이벤트면 포함
          let at: Date
      }

      private let firestoreService: FirestoreService
      private let clock: () -> Date

      init(firestoreService: FirestoreService = FirestoreService.shared,
           clock: @escaping () -> Date = { Date() }) {
          self.firestoreService = firestoreService
          self.clock = clock
      }

      /// 이벤트 수신 후 관련 배지 판정 + Firestore 저장
      /// Phase 1은 await 방식 (Phase 2 UI에서 결과 반환해 스낵바 트리거)
      @discardableResult
      func evaluate(event: Event, userId: String) async -> [Badge] {
          var newlyEarned: [Badge] = []

          // 1. firstRecord: 모든 로깅 이벤트에서 1회만
          if case .feedingLogged = event.kind { /* handled below */ }
          if shouldCheckFirstRecord(kind: event.kind) {
              if let badge = await tryEarn(id: "firstRecord", userId: userId, babyId: event.babyId) {
                  newlyEarned.append(badge)
                  try? await firestoreService.setFirstRecordIfMissing(userId: userId, at: event.at)
              }
          }

          // 2. aggregate badges: stats field 증가 후 threshold 체크
          if let (field, badgeIds) = aggregateMapping(kind: event.kind) {
              try? await firestoreService.incrementStats(userId: userId, field: field, by: 1)
              if let stats = try? await firestoreService.fetchStats(userId: userId) {
                  let value = statsValue(stats: stats, field: field)
                  for badgeId in badgeIds {
                      guard let def = BadgeCatalog.definition(id: badgeId) else { continue }
                      guard value >= def.threshold else { continue }
                      if let badge = await tryEarn(id: badgeId, userId: userId, babyId: event.babyId) {
                          newlyEarned.append(badge)
                      }
                  }
              }
          }

          // 3. streak badges
          if case .routineStreakUpdated(let streak) = event.kind {
              let streakBadges: [(String, Int)] = [
                  ("routineStreak3", 3),
                  ("routineStreak7", 7),
                  ("routineStreak30", 30)
              ]
              for (id, threshold) in streakBadges where streak >= threshold {
                  if let badge = await tryEarn(id: id, userId: userId, babyId: nil) {
                      newlyEarned.append(badge)
                  }
              }
          }

          return newlyEarned
      }

      // MARK: - Helpers

      private func shouldCheckFirstRecord(kind: Event.Kind) -> Bool {
          switch kind {
          case .feedingLogged, .sleepLogged, .diaperLogged, .growthLogged: return true
          case .routineStreakUpdated: return false
          }
      }

      private func aggregateMapping(kind: Event.Kind) -> (field: String, badgeIds: [String])? {
          switch kind {
          case .feedingLogged:  return ("feedingCount", ["feeding100"])
          case .sleepLogged:    return ("sleepCount", ["sleep50"])
          case .diaperLogged:   return ("diaperCount", ["diaper200"])
          case .growthLogged:   return ("growthRecordCount", ["growth10"])
          case .routineStreakUpdated: return nil
          }
      }

      private func statsValue(stats: UserStats, field: String) -> Int {
          switch field {
          case "feedingCount":      return stats.feedingCount
          case "sleepCount":        return stats.sleepCount
          case "diaperCount":       return stats.diaperCount
          case "growthRecordCount": return stats.growthRecordCount
          default: return 0
          }
      }

      /// 이미 획득했으면 nil, 신규 획득이면 Badge 저장 후 반환
      private func tryEarn(id: String, userId: String, babyId: String?) async -> Badge? {
          guard let def = BadgeCatalog.definition(id: id) else { return nil }
          let exists = (try? await firestoreService.badgeExists(userId: userId, badgeId: id)) ?? false
          guard !exists else { return nil }
          let now = clock()
          let dateUTC = Self.utcDateString(now)
          let badge = Badge(
              id: id,
              category: def.category,
              earnedByUserId: userId,
              babyId: babyId,
              earnedAt: now,
              earnedAtDateUTC: dateUTC,
              conditionVersion: def.conditionVersion
          )
          try? await firestoreService.saveBadge(badge, userId: userId)
          return badge
      }

      static func utcDateString(_ date: Date) -> String {
          let formatter = DateFormatter()
          formatter.dateFormat = "yyyy-MM-dd"
          formatter.timeZone = TimeZone(identifier: "UTC")
          return formatter.string(from: date)
      }
  }
  ```
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings
- [ ] `make arch-test` → baseline 유지

**Must NOT do**:
- 기록 저장 훅(`ActivityViewModel+Save` 등)에 BadgeEvaluator 호출 연결 금지 (Phase 1 스코프 외, Phase 2에서 연동)
- `@Observable` property wrapper 사용 금지 (서비스 계층이므로 VM 아님)
- `NotificationService` 호출 금지 (스낵바는 Phase 2 UI)
- git 명령 실행 금지

**References**:
- `BabyCare/Models/Badge.swift`
- `BabyCare/Services/FirestoreService+Badge.swift`
- `BabyCare/Services/FirestoreService+Stats.swift`

**Acceptance Criteria**:

*Functional:*
- [ ] `BadgeEvaluator.evaluate(event:userId:)` 8개 배지 모두 경계값에서 정확 판정
- [ ] `evaluate` → stats 먼저 증가 후 threshold 체크 (순서 보장)
- [ ] 이미 획득한 배지는 재획득 안 함 (badgeExists 체크)
- [ ] `earnedAtDateUTC`는 타임존 UTC 기준 "yyyy-MM-dd"
- [ ] `clock` 주입 가능 (테스트용)

*Static:*
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings
- [ ] `make arch-test` → baseline 유지

*Runtime:*
- [ ] TODO 6 종합 테스트

---

### [x] TODO 6: 단위 테스트 12+개

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `badge_model_path` (file): `${todo-2.outputs.badge_model_path}`
- `firestore_badge_service` (file): `${todo-3.outputs.firestore_badge_service}`
- `stats_service` (file): `${todo-4.outputs.stats_service}`
- `evaluator` (file): `${todo-5.outputs.evaluator}`

**Outputs**:
- `tests_added` (list): 테스트 함수 목록

**Steps**:
- [ ] Read `BabyCareTests/BabyCareTests.swift` 마지막 50줄 — 기존 패턴 확인
- [ ] `// MARK: - Badge Phase 1 Tests` 섹션 append:
  1. `testBadge_codableRoundTrip` — Encode + Decode 동일성
  2. `testBadgeCategory_allCases` — 3 case (firstTime/aggregate/streak)
  3. `testBadgeCatalog_hasEight` — `BadgeCatalog.all.count == 8`
  4. `testBadgeCatalog_allIdsUnique` — Set(ids).count == 8
  5. `testBadgeCatalog_iconNonEmpty` — 모든 iconSFSymbol 비어있지 않음
  6. `testBadgeCatalog_definitionLookup` — 존재/부재 id 조회
  7. `testFirestoreCollections_badgesAndStats` — "badges" / "stats" 상수 값
  8. `testUserStats_emptyFactory` — `UserStats.empty()` 모든 count == 0, firstRecordAt == nil
  9. `testBadgeEvaluator_utcDateString_format` — 특정 Date → "yyyy-MM-dd" UTC
  10. `testBadgeEvaluator_aggregateMapping` — feedingLogged → ("feedingCount", ["feeding100"]) (private이므로 skip or expose via internal helper)
  11. `testBadgeEvaluator_clockInjection` — 주입된 clock의 시간을 evaluate가 사용
  12. `testBadge_earnedAtDateUTC_matchesUtcDateString` — Badge 생성 시 UTC 포맷 일관
  13. `testBadgeCatalog_thresholds` — feeding=100, sleep=50, diaper=200, growth=10, streak=3/7/30 확인
  14. `testBadgeCatalog_statsFieldCoverage` — aggregate 배지는 모두 statsField 있음, firstTime/streak는 nil

  ⚠️ Firestore 실제 호출 테스트는 mock 필요 — 이번 스펙에서는 mock 도입 없이 static/순수 함수 테스트만. Firestore 연동 테스트는 TODO Final H-items로 이관 (H-1).

- [ ] `make test` → 92+ tests, 0 failures

**Must NOT do**:
- Firestore 실제 호출 테스트 작성 금지 (mock 없이 불가)
- 새 테스트 파일 생성 금지 (BabyCareTests.swift만)
- 기존 테스트 수정 금지
- private 함수를 public으로 노출 금지 (테스트 불가능한 건 H-item으로 이관)
- git 명령 실행 금지

**References**:
- `BabyCareTests/BabyCareTests.swift`
- `BabyCare/Models/Badge.swift`
- `BabyCare/Models/UserStats.swift`
- `BabyCare/Services/BadgeEvaluator.swift`

**Acceptance Criteria**:

*Functional:*
- [ ] 12개 이상 신규 테스트 함수 존재 (`test*` prefix)
- [ ] 모든 신규 테스트 PASS

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 92+ tests, 0 failures

---

### [x] TODO Final: Verification

**Type**: verification

**Required Tools**: make, xcodebuild, swiftlint, bash

**Inputs**:
- `streak_regression_ok` (bool): `${todo-1.outputs.streak_regression_ok}`
- `badge_model_path` (file): `${todo-2.outputs.badge_model_path}`
- `firestore_badge_service` (file): `${todo-3.outputs.firestore_badge_service}`
- `stats_service` (file): `${todo-4.outputs.stats_service}`
- `evaluator` (file): `${todo-5.outputs.evaluator}`
- `tests_added` (list): `${todo-6.outputs.tests_added}`

**Outputs**: (none)

**Steps**:
- [ ] `make verify` → ALL CHECKS PASSED
- [ ] `make lint` → 0 warnings
- [ ] `make arch-test` → baseline 유지
- [ ] `make test` → 92+ tests, 0 failures
- [ ] `make build` → exit 0

**Must NOT do**:
- Edit/Write 도구 사용 금지 (소스 수정 금지)
- 새 기능 추가/버그 수정 금지 (리포트만)
- Bash로 파일 변경 금지 (no `sed -i`, `echo >`)
- git 명령 실행 금지

**Acceptance Criteria**:

*Functional:*
- [ ] 모든 Outputs 수집됨
- [ ] `make verify` 출력 "ALL CHECKS PASSED"

*Static:*
- [ ] `make lint` → 0 warnings
- [ ] `make arch-test` → baseline 유지

*Runtime:*
- [ ] `make test` → 92+ tests, 0 failures
