# 수면 장소 태그 (sleep-location)

> 기존 `SleepMethodType` enum을 확장하여 "잠든 곳" 정보 기록. 별도 스키마 추가 없이 3 case(`bed`/`bouncer`/`inArms`) 추가 + `@AppStorage` 아기별 기본값 + 섹션 레이블 통일.

## Verification Summary

### Agent-Verifiable (A-items)
| ID | Criterion | Method | Related TODO |
|----|-----------|--------|-------------|
| A-1 | `SleepMethodType.bed/.bouncer/.inArms` case 존재 및 rawValue = "bed"/"bouncer"/"inArms" | `make test` (unit) | TODO 1 |
| A-2 | 3 신규 case `displayName`과 `icon` 반환값 비어있지 않음 | `make test` | TODO 1 |
| A-3 | 기존 5 case rawValue(selfSettled/nursing/holding/stroller/carSeat) 유지 | `make test` | TODO 1 |
| A-4 | `allCases` 순서: bed, selfSettled, holding, inArms, bouncer, nursing, stroller, carSeat | `make test` | TODO 1 |
| A-5 | `SleepMethodType(rawValue:)` 구 데이터 decode 성공 ("selfSettled" 등) | `make test` | TODO 1 |
| A-6 | `@AppStorage("lastSleepMethod_<babyId>")` 키 포맷이 babyId별 분리 | `make test` (ViewModel 유닛) | TODO 2 |
| A-7 | `SleepPattern.methodDistribution`에 신규 case 포함 시 crash-free (0건 bucket 허용) | `make test` | TODO 3 |
| A-8 | `make build` exit 0 | `make build` | TODO Final |
| A-9 | `make lint` 0 warnings | `make lint` | TODO Final |
| A-10 | `make arch-test` baseline 유지 | `make arch-test` | TODO Final |
| A-11 | `make verify` ALL CHECKS PASSED | `make verify` | TODO Final |

### Human-Required (H-items)
| ID | Criterion | Reason | Review Material |
|----|-----------|--------|----------------|
| H-1 | Capsule 선택 버튼 3종 시각 레이아웃 자연스러움 | SwiftUI 렌더링 시각 품질 | iOS 시뮬레이터 SleepRecordView |
| H-2 | "잠든 곳" 섹션 레이블 한국어 UX 적합성 | 언어 품질 | 기록 화면 + 통계 화면 |
| H-3 | 실제 기기/시뮬레이터에서 `@AppStorage` babyId별 기본값 복원 정상 동작 | UserDefaults 실환경 의존 | 아기 A → bed 선택 → 아기 B 전환 → 기본값 다름 확인 |
| H-4 | 기존 `SleepMethodType` 사용자 데이터 표시 회귀 없음 | E2E 자동화 없음 | 기존 수면 기록(selfSettled 등) 표시 확인 |

### Sandbox Agent Testing (S-items)
none — iOS 네이티브 앱, sandbox infra 없음 (docker-compose/BDD features 미존재)

### Verification Gaps
- XCUITest 미적용으로 UI 플로우 자동 회귀 불가 → 시뮬레이터 수동 확인(H-1~H-4) 의존
- `@AppStorage` 퍼시스턴스는 UserDefaults 기반이라 unit test에서 mock 필요, 실기기 검증 병행 권장
- Firebase Analytics sleepMethod 미전송 확인됨 → 데이터 일관성 영향 없음

## External Dependencies Strategy

### Pre-work (user prepares before AI work)
(none)

### During (AI work strategy)
| Dependency | Dev Strategy | Rationale |
|------------|-------------|-----------|
| Firestore | 스키마 변경 없음, 기존 `sleepMethod` 필드 재사용 | Backward compat 유지 |
| `@AppStorage` (UserDefaults) | Unit test에서 `UserDefaults(suiteName:)` mock 사용 | 테스트 격리 |

### Post-work (user actions after completion)
| Task | Related Dependency | Action | Command/Step |
|------|--------------------|--------|-------------|
| 실기기 QA | `@AppStorage` | 아기 전환 시 기본값 복원 동작 확인 | iOS 시뮬레이터 수동 테스트 |
| TestFlight 배포 (선택) | - | v2.7 포함 시 함께 배포 | `make deploy` |

## Context

### Original Request
수면 활동 기록 시 수면 장소(침대/바운서/카시트/유모차/품안 등) 태그 선택 및 필터/통계 제공. P4~P6 로드맵 항목.

### Interview Summary

**Key Discussions**:
- **enum 전략 (A안)**: 별도 `SleepLocationType` 대신 기존 `SleepMethodType` 확장. 기존 `stroller/carSeat`가 이미 장소 의미를 겸하고 있어 중복 방지.
- **신규 case 범위**: 3개(`bed`, `bouncer`, `inArms`). 총 8개로 확장.
- **case 선언 순서 (DP-02)**: 실내 사용 빈도 우선 — `bed, selfSettled, holding, inArms, bouncer, nursing, stroller, carSeat`. 기존 rawValue 절대 불변, `allCases` 순서만 재배열.
- **`@AppStorage` key 전략 (DP-01)**: 아기별 분리 (`lastSleepMethod_<babyId>`). 멀티 아기 앱에서 아기 B 기록 시 아기 A의 마지막 선택이 기본값으로 뜨는 혼선 방지.
- **섹션 레이블**: "잠드는 방법" → "잠든 곳" 통일 (기록 화면 + 통계 화면).
- **displayName/icon**: 기존 5 case 모두 `displayName`과 `icon` 보유 → 신규 3 case도 **필수 추가** (일관성).
- **Firebase Analytics**: `sleepMethod` 전송 안 함 확인 → 영향 없음.

### Research Findings
- `BabyCare/Models/ActivityEnums.swift:84-106` — `SleepMethodType: String, Codable, CaseIterable`, 기존 5 case + displayName + icon
- `BabyCare/Models/Activity.swift:25-26, 175-176` — `sleepMethod: SleepMethodType?` optional 필드
- `BabyCare/ViewModels/ActivityViewModel.swift:34-35` — VM 바인딩
- `BabyCare/ViewModels/ActivityViewModel+Save.swift:89-92` — 저장 시 할당
- `BabyCare/Views/Recording/SleepRecordView.swift:79-113` — 잠드는 방법 Capsule 섹션
- `BabyCare/Views/Stats/PatternReport+Sleep.swift:59-77` — methodDistribution 분포 차트
- `BabyCare/Services/PatternAnalysisService.swift:192` — `if let method = act.sleepMethod` 집계 로직
- `BabyCare/Services/PatternModels.swift:35-45` — `SleepPattern.methodDistribution`
- `CLAUDE.md:54`, `.claude/rules/swift-conventions.md:8` — 신규 필드 optional 필수
- `.claude/rules/firestore-rules.md:7-8` — FirestoreCollections 상수, `babyVM.dataUserId()` 필수
- `.claude/rules/review.md` — Firestore 스키마 변경 시 `/review` 필수 (이번엔 enum case 추가라 스키마 유지)

## Work Objectives

### Core Objective
기존 `SleepMethodType`을 실내 장소 3종(`bed`/`bouncer`/`inArms`) 포함하도록 확장하여 수면 기록 + 통계에서 "잠든 곳" 차원을 노출한다. 스키마/데이터 마이그레이션 없이 역호환.

### Concrete Deliverables
- `BabyCare/Models/ActivityEnums.swift` — `SleepMethodType`에 3 case + displayName + icon, 순서 재배열
- `BabyCare/Views/Recording/SleepRecordView.swift` — 섹션 제목 "잠든 곳", `@AppStorage("lastSleepMethod_<babyId>")` 기본값 복원 + 선택 시 저장
- `BabyCare/Views/Stats/PatternReport+Sleep.swift` — 차트 섹션 제목 "잠든 곳"
- `BabyCareTests/BabyCareTests.swift` — 신규 8개 이상 테스트 (enum, displayName, icon, allCases 순서, rawValue 보존, decode, 분포 crash-free, @AppStorage 키 포맷)

### Definition of Done
- [ ] `make verify` → ALL CHECKS PASSED
- [ ] 테스트: 63 → 71+개 (8개 이상 추가)
- [ ] 기존 `sleepMethod` Firestore 데이터(rawValue="selfSettled" 등) decode 성공 확인 (테스트)
- [ ] `@AppStorage` key가 `lastSleepMethod_<babyId>` 포맷으로 저장/복원 (테스트)
- [ ] `SleepRecordView`, `PatternReport+Sleep` 두 화면 섹션 제목이 "잠든 곳"으로 통일

### Must NOT Do (Guardrails)
- 기존 5 case(`selfSettled/nursing/holding/stroller/carSeat`) rawValue 변경 금지 (Firestore decode 깨짐)
- 기존 case 삭제 금지
- `SleepMethodType`을 Int raw value로 변경 금지 (현재 String)
- `switch` 문에 `default:` 추가 금지 (exhaustive 컴파일 타임 안전성 유지)
- `SleepQualityType` 건드리지 않기 (별개 차원)
- `sleepMethod` 필드를 non-optional로 변경 금지
- `Activity` 모델에 신규 필드 추가 금지 (enum 확장만)
- Firestore 컬렉션/경로 변경 금지
- 외부 차트 라이브러리 추가 금지 (Apple Charts만)
- `babyVM.dataUserId()` 대신 `authVM.currentUserId` 직접 사용 금지 (신규 코드 한정)
- Firebase Analytics에 sleepMethod 전송 로직 추가 금지 (개인정보 + 스코프 외)
- 신규 테스트 파일 생성 금지 (`BabyCareTests.swift`에 append)
- `arch-test.sh` baseline 증가 금지
- git 명령 실행 금지

---

## Task Flow

```
TODO-1 (enum 확장) ─┐
                   ├─ TODO-2 (SleepRecordView) ─┐
                   ├─ TODO-3 (PatternReport)   ─┤
                   └─ TODO-4 (테스트)          ─┘
                                    ↓
                             TODO-Final (Verification)
```

TODO-2/3/4는 TODO-1 완료 후 병렬 가능 (서로 다른 파일).

## Dependency Graph

| TODO | Requires (Inputs) | Produces (Outputs) | Type |
|------|-------------------|-------------------|------|
| 1 | - | `enum_extended` (bool) | work |
| 2 | `todo-1.enum_extended` | `record_view_done` (bool) | work |
| 3 | `todo-1.enum_extended` | `stats_view_done` (bool) | work |
| 4 | `todo-1.enum_extended` | `tests_added` (list) | work |
| Final | all | - | verification |

## Parallelization

| Group | TODOs | Reason |
|-------|-------|--------|
| A | TODO 2, 3, 4 | TODO 1 완료 후. 서로 다른 파일 수정. 테스트는 enum/모델 시그니처만 의존. |

## Commit Strategy

| After TODO | Message | Files | Condition |
|------------|---------|-------|-----------|
| 1 | `feat(sleep): extend SleepMethodType with bed/bouncer/inArms` | `BabyCare/Models/ActivityEnums.swift` | always |
| 2 | `feat(sleep): add per-baby @AppStorage default + rename section to 잠든 곳` | `BabyCare/Views/Recording/SleepRecordView.swift` | always |
| 3 | `feat(sleep): rename pattern report section to 잠든 곳` | `BabyCare/Views/Stats/PatternReport+Sleep.swift` | always |
| 4 | `test(sleep): add 8+ unit tests for SleepMethodType expansion` | `BabyCareTests/BabyCareTests.swift` | always |

## Error Handling

### Failure Categories

| Category | Examples | Detection Pattern |
|----------|----------|-------------------|
| `env_error` | xcodebuild 시뮬레이터 누락, XcodeGen 실패 | `xcrun\|simulator runtime\|xcodegen` |
| `code_error` | Swift 컴파일 에러, SwiftLint violation, arch-test 위반 | `error:\|warning:\|violation` |
| `scope_internal` | 기존 case raw value 충돌 감지 | `rawValue.*duplicate` |
| `unknown` | 기타 | default |

### Failure Handling Flow

| Scenario | Action |
|----------|--------|
| work fails | Retry up to 2 times → Analyze → below |
| verification fails | Analyze immediately (no retry) → below |
| Worker times out | Halt and report |
| Missing Input | Skip dependent TODOs, halt |

### After Analyze

| Category | Action |
|----------|--------|
| `env_error` | Halt + log to `issues.md` |
| `code_error` | Create Fix Task (depth=1) |
| `scope_internal` | Halt — raw value 충돌은 스펙 위반 |
| `unknown` | Halt + log to `issues.md` |

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

### [x] TODO 1: SleepMethodType enum 확장

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `enum_extended` (bool): true

**Steps**:
- [ ] Read `BabyCare/Models/ActivityEnums.swift` (특히 line 84-106)
- [ ] `SleepMethodType` 선언 수정 — `case` 선언 순서를 다음으로 재배열 (기존 rawValue 유지):
  ```swift
  enum SleepMethodType: String, Codable, CaseIterable {
      case bed, selfSettled, holding, inArms, bouncer, nursing, stroller, carSeat
      // ...
  }
  ```
  - ⚠️ rawValue는 case 이름과 동일하게 자동 생성됨 (String raw enum) → 기존 `selfSettled/nursing/holding/stroller/carSeat` 문자열 보존
  - 신규 rawValue: "bed", "inArms", "bouncer"
- [ ] `displayName` switch에 3 case 추가:
  - `.bed`: "침대"
  - `.inArms`: "품안"
  - `.bouncer`: "바운서"
- [ ] `icon` switch에 3 case 추가 (SF Symbol):
  - `.bed`: "bed.double.fill" (※ 기존 `.selfSettled`와 중복 — `.bed`를 "bed.double.fill"로, `.selfSettled`는 기존 유지. 중복 아이콘이라도 OK, 라벨로 구분됨. 또는 `.bed`만 "bed.double.fill", `.selfSettled`를 `"moon.zzz.fill"`로 변경할 수도 있으나 **기존 선택값 변경 금지 원칙상 기존 `.selfSettled` 아이콘 유지 + `.bed`도 "bed.double.fill"` 허용**)
  - `.inArms`: "figure.arms.open"
  - `.bouncer`: "chair.lounge.fill"
- [ ] 최종 `switch` 문이 8개 case 모두 커버하는지 확인 (exhaustive, default 없음)
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

**Must NOT do**:
- 기존 case raw value 문자열 변경 금지
- 기존 case 삭제 금지
- `default:` 추가 금지
- `SleepQualityType` 건드리지 않기
- 새 파일 생성 금지
- git 명령 실행 금지

**References**:
- `BabyCare/Models/ActivityEnums.swift:84-106` — 기존 선언
- `BabyCare/Models/ActivityEnums.swift:9-40` — `SleepQualityType` 스타일 참고 (건드리지 말 것)

**Acceptance Criteria**:

*Functional:*
- [ ] `SleepMethodType.bed`, `.inArms`, `.bouncer` 3 case 존재
- [ ] 각 신규 case의 `displayName` 비어있지 않음
- [ ] 각 신규 case의 `icon` 비어있지 않음
- [ ] 기존 5 case rawValue 그대로 ("selfSettled", "nursing", "holding", "stroller", "carSeat")
- [ ] `allCases` 순서: `[bed, selfSettled, holding, inArms, bouncer, nursing, stroller, carSeat]`

*Static:*
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

*Runtime:*
- [ ] 해당 TODO에서는 테스트 작성 안 함 (TODO 4에서 작성)

---

### [ ] TODO 2: SleepRecordView 섹션 제목 + @AppStorage 기본값

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `enum_extended` (bool): `${todo-1.outputs.enum_extended}`

**Outputs**:
- `record_view_done` (bool): true

**Steps**:
- [ ] Read `BabyCare/Views/Recording/SleepRecordView.swift` (특히 line 79-113)
- [ ] 섹션 제목 텍스트를 "잠드는 방법"에서 **"잠든 곳"**으로 변경 (한 곳만)
- [ ] `babyVM.dataUserId()`와 `babyVM.currentBaby?.id` (또는 유사 접근자)를 이용하여 `babyId` 획득. ⚠️ `authVM.currentUserId` 직접 사용 금지
- [ ] `@AppStorage`는 컴파일 타임 key가 필요하므로, computed key 패턴 적용 — 다음 중 하나 선택:
  - (A) `@State` + `UserDefaults.standard`의 manual read/write (`.onAppear`에서 read, selection 바뀔 때 write)
  - (B) `@AppStorage`를 사용하되 key를 전역 상수 + babyId 별도 헬퍼 함수에서 조회/저장
  - 권장: (A) 방식 — `@AppStorage`는 고정 key 요구사항 때문에 babyId 동적 주입이 불편. `UserDefaults.standard.string(forKey: "lastSleepMethod_\(babyId)")` 패턴 사용.
- [ ] 구현:
  ```swift
  // View 내부
  private func lastMethodKey(babyId: String) -> String {
      "lastSleepMethod_\(babyId)"
  }

  // .onAppear { ... }
  if let babyId = babyVM.currentBaby?.id,
     viewModel.sleepMethod == nil,
     let raw = UserDefaults.standard.string(forKey: lastMethodKey(babyId: babyId)),
     let method = Activity.SleepMethodType(rawValue: raw) {
      viewModel.sleepMethod = method
  }

  // selection 변경 시 (기존 버튼 액션 내부)
  if let babyId = babyVM.currentBaby?.id, let selected = viewModel.sleepMethod {
      UserDefaults.standard.set(selected.rawValue, forKey: lastMethodKey(babyId: babyId))
  }
  ```
- [ ] `babyVM.currentBaby?.id` 접근자가 없다면 기존 코드에서 baby id 획득 패턴을 따를 것 (DRAFT references 참고). 없으면 skip 하고 전역 key `"lastSleepMethod"`로 degrade — 다만 반드시 **코드 주석에 TODO 명시** 후 진행.
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings
- [ ] `make arch-test` baseline 증가 없음

**Must NOT do**:
- `authVM.currentUserId` 직접 사용 금지
- 새 파일 생성 금지
- 섹션 전체 로직 리팩토링 금지 (최소 변경)
- Capsule 버튼 스타일 변경 금지 (일관성)
- `SleepQualityType` 섹션 건드리지 않기
- git 명령 실행 금지

**References**:
- `BabyCare/Views/Recording/SleepRecordView.swift:79-113` — 현재 섹션 구조
- `BabyCare/ViewModels/ActivityViewModel.swift:34-35` — `sleepMethod` 바인딩
- `.claude/rules/firestore-rules.md:8` — `babyVM.dataUserId()` 원칙

**Acceptance Criteria**:

*Functional:*
- [ ] 섹션 제목 "잠든 곳"
- [ ] 최근 선택값이 `UserDefaults`에 `lastSleepMethod_<babyId>` 형식으로 저장됨
- [ ] 기록 진입 시 `viewModel.sleepMethod == nil`이면 UserDefaults에서 복원

*Static:*
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings
- [ ] `make arch-test` baseline 유지

*Runtime:*
- [ ] 해당 TODO에서는 테스트 작성 안 함 (TODO 4에서 작성)

---

### [ ] TODO 3: PatternReport+Sleep 섹션 제목 변경

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `enum_extended` (bool): `${todo-1.outputs.enum_extended}`

**Outputs**:
- `stats_view_done` (bool): true

**Steps**:
- [ ] Read `BabyCare/Views/Stats/PatternReport+Sleep.swift` (line 59-77 중심)
- [ ] 차트 섹션 제목에서 "잠드는 방법" 문자열을 **"잠든 곳"**으로 변경
- [ ] 다른 하드코딩된 "잠드는 방법" 문구가 있는지 `grep` 필요 시 같은 파일 내에서만 업데이트 (다른 파일은 out of scope)
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

**Must NOT do**:
- 차트 로직/데이터 구조 변경 금지
- `methodDistribution` 계산 로직 변경 금지
- 차트 라이브러리 변경 금지
- 다른 파일 수정 금지 (PatternReport+Sleep.swift 한정)
- git 명령 실행 금지

**References**:
- `BabyCare/Views/Stats/PatternReport+Sleep.swift:59-77` — 분포 차트 섹션

**Acceptance Criteria**:

*Functional:*
- [ ] `PatternReport+Sleep.swift`에서 관련 섹션 제목이 "잠든 곳"

*Static:*
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

*Runtime:*
- [ ] 해당 TODO에서는 테스트 작성 안 함 (TODO 4에서 작성)

---

### [ ] TODO 4: 단위 테스트 추가

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `enum_extended` (bool): `${todo-1.outputs.enum_extended}`

**Outputs**:
- `tests_added` (list): 테스트 함수 이름 목록

**Steps**:
- [ ] Read `BabyCareTests/BabyCareTests.swift` — 기존 테스트 패턴 확인
- [ ] Read `BabyCare/Models/ActivityEnums.swift` — 확장된 `SleepMethodType` 확인 (TODO 1 완료 후)
- [ ] Read `BabyCare/Services/PatternModels.swift:35-45` — `SleepPattern` 구조 확인
- [ ] `BabyCareTests.swift`에 `// MARK: - Sleep Location Tests` 섹션 append, 다음 8개 이상 테스트:
  1. `testSleepMethodType_newCases_exist` — `.bed`, `.inArms`, `.bouncer` 존재 확인
  2. `testSleepMethodType_newCases_rawValues` — rawValue == "bed"/"inArms"/"bouncer"
  3. `testSleepMethodType_existingRawValuesPreserved` — 5개 기존 rawValue 보존 ("selfSettled", "nursing", "holding", "stroller", "carSeat")
  4. `testSleepMethodType_allCasesOrder` — `allCases == [.bed, .selfSettled, .holding, .inArms, .bouncer, .nursing, .stroller, .carSeat]`
  5. `testSleepMethodType_displayNames_nonEmpty` — 8 case 모두 `displayName.isEmpty == false`
  6. `testSleepMethodType_icons_nonEmpty` — 8 case 모두 `icon.isEmpty == false`
  7. `testSleepMethodType_backwardCompat_decode` — `SleepMethodType(rawValue: "selfSettled") != nil`, `SleepMethodType(rawValue: "nursing") != nil`, `SleepMethodType(rawValue: "unknownCase") == nil`
  8. `testSleepMethodType_appStorageKeyFormat` — 헬퍼 함수 또는 문자열 포맷 검증 `"lastSleepMethod_\(babyId)"` (TODO 2에서 헬퍼가 노출되지 않으면 이 테스트는 string format 검증으로 대체)
  9. `testMethodDistribution_crashFreeOnNewCases` — `SleepPattern(methodDistribution: [.bed: 3, .bouncer: 1, .inArms: 2])` 생성/접근 crash-free
- [ ] `make test` → 71+ tests, 0 failures

**Must NOT do**:
- 새 테스트 파일 생성 금지
- 기존 테스트 수정 금지
- `SleepRecordView`/`PatternReport+Sleep` 뷰 전체 렌더 테스트 금지 (SwiftUI view testing 범위 밖)
- `TodoViewModel`/`ActivityViewModel` Firestore 전체 경로 테스트 금지
- git 명령 실행 금지

**References**:
- `BabyCareTests/BabyCareTests.swift` — 기존 패턴
- `BabyCare/Models/ActivityEnums.swift` — 확장된 enum (TODO 1 산출물)
- `BabyCare/Services/PatternModels.swift:35-45` — SleepPattern

**Acceptance Criteria**:

*Functional:*
- [ ] 신규 테스트 함수 8개 이상 존재
- [ ] 모든 신규 테스트 PASS

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 71+ tests, 0 failures

---

### [ ] TODO Final: Verification

**Type**: verification

**Required Tools**: make, xcodebuild, swiftlint, bash

**Inputs**:
- `enum_extended` (bool): `${todo-1.outputs.enum_extended}`
- `record_view_done` (bool): `${todo-2.outputs.record_view_done}`
- `stats_view_done` (bool): `${todo-3.outputs.stats_view_done}`
- `tests_added` (list): `${todo-4.outputs.tests_added}`

**Outputs**: (none)

**Steps**:
- [ ] `make verify` → ALL CHECKS PASSED
- [ ] `make lint` → 0 warnings
- [ ] `make arch-test` → baseline 유지 (증가 없음)
- [ ] `make test` → 71+ tests, 0 failures
- [ ] `make build` → exit 0
- [ ] Git status 확인 (uncommitted changes는 Orchestrator 커밋 범위 내에서만)

**Must NOT do**:
- Edit/Write 도구 사용 금지 (소스 수정 금지)
- 새 기능 추가 또는 버그 수정 금지 (리포트만)
- Bash로 파일 변경 금지 (no `sed -i`, `echo >`)
- git 명령 실행 금지 (Orchestrator가 처리)

**Acceptance Criteria**:

*Functional:*
- [ ] 모든 TODO Outputs 수집됨
- [ ] `make verify` 출력 "ALL CHECKS PASSED"

*Static:*
- [ ] `make lint` → 0 warnings
- [ ] `make arch-test` → baseline 유지

*Runtime:*
- [ ] `make test` → 71+ tests, 0 failures
- [ ] `make build` → exit 0
