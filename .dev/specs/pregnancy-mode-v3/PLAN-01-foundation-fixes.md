# 임신모드 v3 — 서브프로젝트 1: 토대 수정 (국소 P0/P1 + ownerUserId) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** v2 임신 코드의 확정된 P0/P1 로직 버그 4건을 TDD로 국소 수정하고 `ownerUserId`를 영속화한다 — v3 "임신 노트" UI가 올라갈 토대.

**Architecture:** zero-base 검증대로 **데이터모델/컬렉션 변경·마이그레이션 없음**(v2는 이미 정규화됨). 기존 `Pregnancy`/`PregnancyViewModel`/`FirestoreService+Pregnancy`에 국소 수정 + 로직을 순수 computed/헬퍼로 추출해 단위 테스트 가능하게. 임신모드는 현재 `FeatureFlags.pregnancyModeEnabled=false`라 모든 변경은 **사용자 무영향**(v3 재활성 시 자동 적용).

**Tech Stack:** Swift 6.0, SwiftUI, XCTest, Firebase Firestore, `MockPregnancyFirestore`(in-memory 통합 테스트). 검증 = `make verify`(빌드+린트+arch+단위테스트+디자인).

**불변 규칙(safety.md):** 데이터 삭제 금지 · 임신 데이터 Analytics/Crashlytics 금지 · WriteBatch+transitionState 유지 · outcome/Gender rawValue 영구계약.

---

## File Structure

- `BabyCare/Models/Pregnancy.swift` — `genderPrefill`·`finalWeekAndDay` computed 추가 / CodingKeys에 `ownerUserId` 추가. (모델 책임: 임신 도메인 값 + 순수 파생)
- `BabyCare/Views/Pregnancy/PregnancyTransitionSheet.swift` — init의 잘못된 성별 switch 제거, `genderPrefill` 사용.
- `BabyCare/Views/Settings/PregnancyArchiveView.swift` — "최종 주차"를 `finalWeekAndDay`로.
- `BabyCare/ViewModels/PregnancyViewModel.swift` — `transitionToBaby`가 결정적 Baby.id 주입.
- `BabyCare/Services/FirestoreService+Pregnancy.swift` — `transitionPregnancyToBaby`에 멱등 가드(이미 생성됐으면 no-op).
- `BabyCareTests/MockPregnancyFirestore.swift` — 생성 Baby.id 기록 + `existingBabyIds` 스텁(멱등 시뮬).
- `BabyCareTests/BabyCareTests+Pregnancy.swift` — 신규 테스트 append(이 파일은 도메인 분리 예외, append 관례).

각 Task = 자체 완결 변경 + 커밋. 순서대로(1→4), 단 Task 1·2는 독립.

---

## Task 1: 성별 prefill 수정 (P1) — 여아도 항상 .male로 떨어지던 버그

**Files:**
- Modify: `BabyCare/Models/Pregnancy.swift` (computed 추가)
- Modify: `BabyCare/Views/Pregnancy/PregnancyTransitionSheet.swift:35-45`
- Test: `BabyCareTests/BabyCareTests+Pregnancy.swift` (append)

원인: `PregnancyTransitionSheet.init`이 `ultra.rawValue`("male"/"female")를 한글 displayName("남아"/"여아")과 비교 → 영영 미스 → 항상 `.male`. `ultrasoundGender`는 이미 `Baby.Gender?`이므로 직접 쓰면 됨. 테스트 가능하게 순수 computed로 추출.

- [ ] **Step 1: 실패 테스트 작성** (`BabyCareTests+Pregnancy.swift` 끝에 append)

```swift
final class PregnancyGenderPrefillTests: XCTestCase {
    func test_genderPrefill_female_returnsFemale() {
        var p = Pregnancy(fetusCount: 1)
        p.ultrasoundGender = .female
        XCTAssertEqual(p.genderPrefill, .female, "여아 초음파 → prefill 여아")
    }
    func test_genderPrefill_male_returnsMale() {
        var p = Pregnancy(fetusCount: 1)
        p.ultrasoundGender = .male
        XCTAssertEqual(p.genderPrefill, .male)
    }
    func test_genderPrefill_nil_defaultsToMale() {
        let p = Pregnancy(fetusCount: 1)   // ultrasoundGender nil
        XCTAssertEqual(p.genderPrefill, .male, "미설정 시 기본값")
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,arch=arm64,id=E8CF2728-092B-485D-BEF7-E959ED6B9435' -only-testing:BabyCareTests/PregnancyGenderPrefillTests`
Expected: 컴파일 실패 — `value of type 'Pregnancy' has no member 'genderPrefill'`

- [ ] **Step 3: 최소 구현** — `Pregnancy.swift`의 `dDay` computed 아래(line ~94 다음)에 추가

```swift
    /// 출산 전환 시트 성별 prefill. ultrasoundGender(Baby.Gender) 직접 사용, 없으면 .male.
    /// (구버전 버그: rawValue↔displayName 비교로 항상 .male로 떨어짐 — 직접 대입으로 수정.)
    var genderPrefill: Baby.Gender {
        ultrasoundGender ?? .male
    }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: 위 Step 2 명령
Expected: 3개 PASS

- [ ] **Step 5: View가 computed를 쓰도록 수정** — `PregnancyTransitionSheet.swift:35-45`의 `let prefillGender ... } else { prefillGender = .male }` 블록 전체를 교체

```swift
        _gender = State(initialValue: pregnancy.genderPrefill)
```
(기존 `let prefillGender: Baby.Gender` 선언 + if/switch/else + 마지막 `_gender = State(initialValue: prefillGender)` 를 위 한 줄로 대체.)

- [ ] **Step 6: 빌드 확인**

Run: `make build`
Expected: 빌드 성공 (사용하지 않게 된 변수 경고 없음)

- [ ] **Step 7: 커밋**

```bash
git add BabyCare/Models/Pregnancy.swift BabyCare/Views/Pregnancy/PregnancyTransitionSheet.swift BabyCareTests/BabyCareTests+Pregnancy.swift
git commit -m "fix(pregnancy): 출산전환 성별 prefill — rawValue↔displayName 비교 버그 (항상 .male) 수정"
```

---

## Task 2: 아카이브 "최종 주차" 클램프 (P2) — 종료된 임신 주차가 매일 증가하던 버그

**Files:**
- Modify: `BabyCare/Models/Pregnancy.swift` (computed 추가)
- Modify: `BabyCare/Views/Settings/PregnancyArchiveView.swift:113-116`
- Test: `BabyCareTests/BabyCareTests+Pregnancy.swift` (append)

원인: `PregnancyArchiveView`가 `pregnancy.currentWeekAndDay`(= `Date()` 기준)를 "최종 주차"로 표시 → 12주에 종료된 임신을 나중에 열면 30주로 보임. `PregnancyDateMath.weekAndDay(from:now:)`가 이미 `now`를 받는 순수 헬퍼이므로 `archivedAt` 기준으로 계산.

- [ ] **Step 1: 실패 테스트 작성** (`BabyCareTests+Pregnancy.swift` append)

```swift
final class PregnancyFinalWeekTests: XCTestCase {
    func test_finalWeekAndDay_usesArchivedAt_notToday() {
        let cal = Calendar.current
        // LMP 200일 전, archivedAt = LMP+84일(12주 0일) → 최종주차는 12주여야 함(오늘 기준 아님)
        let lmp = cal.date(byAdding: .day, value: -200, to: Date())!
        let archived = cal.date(byAdding: .day, value: 84, to: lmp)!
        var p = Pregnancy(lmpDate: lmp, outcome: .miscarriage, archivedAt: archived)
        let wd = p.finalWeekAndDay
        XCTAssertEqual(wd?.weeks, 12)
        XCTAssertEqual(wd?.days, 0)
    }
    func test_finalWeekAndDay_noArchivedAt_fallsBackToToday() {
        let lmp = Calendar.current.date(byAdding: .day, value: -70, to: Date())! // 10주 0일
        let p = Pregnancy(lmpDate: lmp)   // archivedAt nil
        XCTAssertEqual(p.finalWeekAndDay?.weeks, 10)
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ... -only-testing:BabyCareTests/PregnancyFinalWeekTests`
Expected: 컴파일 실패 — `no member 'finalWeekAndDay'`

- [ ] **Step 3: 최소 구현** — `Pregnancy.swift` `currentWeekAndDay` computed 아래에 추가

```swift
    /// 아카이브 표시용 "최종 주차" — 종료/출산 시각(archivedAt) 기준, 없으면 오늘.
    /// (currentWeekAndDay는 Date() 기준이라 종료된 임신에서 계속 증가하는 버그 회피.)
    var finalWeekAndDay: (weeks: Int, days: Int)? {
        PregnancyDateMath.weekAndDay(from: lmpDate, now: archivedAt ?? Date())
    }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: 위 Step 2 명령
Expected: 2개 PASS

- [ ] **Step 5: View 수정** — `PregnancyArchiveView.swift:113`의 `if let weeks = pregnancy.currentWeekAndDay {` 를 다음으로 교체

```swift
            if let weeks = pregnancy.finalWeekAndDay {
```
(line 115의 `LabeledContent("최종 주차", value: "\(weeks.weeks)주 \(weeks.days)일")` 는 변수명 그대로라 수정 불요.)

- [ ] **Step 6: 빌드 확인** — Run: `make build` / Expected: 성공

- [ ] **Step 7: 커밋**

```bash
git add BabyCare/Models/Pregnancy.swift BabyCare/Views/Settings/PregnancyArchiveView.swift BabyCareTests/BabyCareTests+Pregnancy.swift
git commit -m "fix(pregnancy): 아카이브 최종 주차를 archivedAt 기준으로 클램프 (종료 후 주차 증가 버그)"
```

---

## Task 3: 출산 전환 중복 아기 멱등화 (P0) — 재시도/크래시 후 아기 2개·babyCount 이중증가

**Files:**
- Modify: `BabyCare/ViewModels/PregnancyViewModel.swift:473-477` (결정적 Baby.id)
- Modify: `BabyCare/Services/FirestoreService+Pregnancy.swift:162-193` (멱등 가드)
- Modify: `BabyCareTests/MockPregnancyFirestore.swift` (생성 id 기록 + existing 스텁)
- Test: `BabyCareTests/BabyCareTests+Pregnancy.swift` (append)

원인: `transitionToBaby`가 `Baby(name:...)` 생성 → `Baby.init` 기본 `id = UUID().uuidString` → 매 호출 새 id. `transitionPregnancyToBaby`는 `merge:false`로 baby 쓰고 `babyCount` `FieldValue.increment(1)`. 재시도(resumePendingTransition) 시 새 UUID → 중복 baby + 카운트 이중증가. **수정: pregnancy 기반 결정적 id + 서비스에서 이미 존재하면 no-op.**

### 3a. Mock 확장 (테스트 토대)

- [ ] **Step 1: Mock에 생성 id 기록 + 멱등 스텁 추가** — `MockPregnancyFirestore.swift`

`transitionCalls` 선언(line 37) 아래에 추가:
```swift
    /// 멱등 시뮬: 이미 생성된 것으로 간주할 Baby.id (크래시 후 잔존 상태 재현).
    var existingBabyIds: Set<String> = []
    /// 실제로 새로 생성된 Baby.id (중복 생성 여부 검증용).
    private(set) var createdBabyIds: [String] = []
```

`transitionPregnancyToBaby`(line 69-72)를 다음으로 교체:
```swift
    func transitionPregnancyToBaby(pregnancy: Pregnancy, newBaby: Baby, userId: String) async throws {
        if let err = errorOnTransition { throw err }
        transitionCalls.append((pregnancy.id, newBaby.name))
        // 멱등: 이미 존재하면 no-op (실제 서비스의 존재 가드 미러)
        guard !existingBabyIds.contains(newBaby.id) else { return }
        existingBabyIds.insert(newBaby.id)
        createdBabyIds.append(newBaby.id)
    }
```

- [ ] **Step 2: 빌드 확인(Mock만)** — Run: `make build` / Expected: 성공(아직 VM 미변경, 기존 테스트 영향 없음)

### 3b. VM 결정적 id + 멱등 검증 테스트

- [ ] **Step 3: 실패 테스트 작성** (`BabyCareTests+Pregnancy.swift` append)

```swift
@MainActor
final class PregnancyTransitionIdempotencyTests: XCTestCase {
    private func makeVM(_ mock: MockPregnancyFirestore) -> PregnancyViewModel {
        PregnancyViewModel(firestoreService: mock)
    }
    func test_transition_normalFlow_createsOneBabyWithDeterministicId() async throws {
        let mock = MockPregnancyFirestore()
        let vm = makeVM(mock)
        var p = Pregnancy(fetusCount: 1); 
        vm.activePregnancy = p
        _ = try await vm.transitionToBaby(babyName: "콩이", gender: .female,
                                          birthDate: Date(), userId: "mom")
        XCTAssertEqual(mock.createdBabyIds, ["baby_\(p.id)"], "결정적 id 1개 생성")
    }
    func test_transition_retryWhenBabyExists_noDuplicate() async throws {
        let mock = MockPregnancyFirestore()
        let p = Pregnancy(fetusCount: 1)
        mock.existingBabyIds = ["baby_\(p.id)"]   // 1차 시도가 이미 생성(크래시 후 잔존)
        let vm = makeVM(mock)
        vm.activePregnancy = p
        _ = try await vm.transitionToBaby(babyName: "콩이", gender: .female,
                                          birthDate: Date(), userId: "mom")
        XCTAssertTrue(mock.createdBabyIds.isEmpty, "이미 존재하면 새 아기 생성 0 (멱등)")
    }
}
```
> 주의: `PregnancyViewModel(firestoreService:)` init이 mock 주입을 지원하는지 확인. 미지원이면 init에 `provider: PregnancyFirestoreProviding = FirestoreService.shared` default 주입 추가(narrow protocol 패턴, 기존 BadgeViewModel 선례)를 본 Step 전에 선행 — 1줄.

- [ ] **Step 4: 테스트 실패 확인**

Run: `xcodebuild test ... -only-testing:BabyCareTests/PregnancyTransitionIdempotencyTests`
Expected: FAIL — `createdBabyIds`가 `["baby_<id>"]`가 아닌 랜덤 UUID(첫 테스트), 둘째 테스트는 새 baby 생성됨

- [ ] **Step 5: VM 결정적 id 구현** — `PregnancyViewModel.swift:473-477`의 `Baby(...)` 생성을 교체

```swift
        let newBaby = Baby(
            id: "baby_\(p.id)",          // 결정적 id — 재시도 시 동일 문서로 수렴(중복 방지)
            name: babyName.isEmpty ? (p.babyNickname ?? "우리 아기") : babyName,
            birthDate: birthDate,
            gender: gender
        )
```

- [ ] **Step 6: 테스트 통과 확인** — Run: 위 Step 4 명령 / Expected: 2개 PASS

### 3c. 서비스 멱등 가드(실 Firestore)

- [ ] **Step 7: 서비스에 존재 가드 추가** — `FirestoreService+Pregnancy.swift:167`의 `let batch = db.batch()` 직전에 삽입

```swift
        // 멱등 가드: 이미 같은 id의 Baby가 존재하면(재시도/크래시 후) 중복 생성·카운트 이중증가 방지.
        let userRef = db.collection(FirestoreCollections.users).document(userId)
        let bRef = userRef.collection(FirestoreCollections.babies).document(newBaby.id)
        if try await bRef.getDocument().exists { return }
```
그리고 기존 batch 블록의 `let userRef = ...`(line 179)·`let bRef = ...`(line 180-182) 중복 선언 제거(위에서 이미 선언). batch.setData들은 `bRef`/`userRef` 그대로 사용.

- [ ] **Step 8: 빌드 + 전체 검증**

Run: `make verify`
Expected: 빌드+린트+arch(R1–R4=0)+단위테스트 전부 PASS, 신규 테스트 포함 green

- [ ] **Step 9: 커밋**

```bash
git add BabyCare/ViewModels/PregnancyViewModel.swift BabyCare/Services/FirestoreService+Pregnancy.swift BabyCareTests/MockPregnancyFirestore.swift BabyCareTests/BabyCareTests+Pregnancy.swift
git commit -m "fix(pregnancy): 출산전환 멱등화 — 결정적 Baby.id + 존재 가드로 중복아기·babyCount 이중증가 차단 (P0)"
```

---

## Task 4: ownerUserId 영속화 — 공유 임신 소유자 식별 토대

**Files:**
- Modify: `BabyCare/Models/Pregnancy.swift:37-42` (CodingKeys)
- Modify: `BabyCare/ViewModels/PregnancyViewModel.swift` (createPregnancy에서 ownerUserId 세팅 — 위치는 Step 3에서 grep 확인)
- Test: `BabyCareTests/BabyCareTests+Pregnancy.swift` (append)

원인: `ownerUserId`가 CodingKeys에서 제외(runtime-only) → 저장 안 됨. 공유 시 소유자 식별이 매 fetch 재계산에 의존. 영속화하면 소유자 트리 식별·공유 쓰기 라우팅 토대가 됨(비대칭 공유의 owner-write 기준).

- [ ] **Step 1: 실패 테스트 작성** (`BabyCareTests+Pregnancy.swift` append)

```swift
final class PregnancyOwnerPersistenceTests: XCTestCase {
    func test_ownerUserId_survivesEncodeDecodeRoundtrip() throws {
        var p = Pregnancy(fetusCount: 1)
        p.ownerUserId = "mom-uid"
        let data = try JSONEncoder().encode(p)
        let decoded = try JSONDecoder().decode(Pregnancy.self, from: data)
        XCTAssertEqual(decoded.ownerUserId, "mom-uid", "ownerUserId가 직렬화에 보존되어야 함")
    }
}
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `xcodebuild test ... -only-testing:BabyCareTests/PregnancyOwnerPersistenceTests`
Expected: FAIL — `decoded.ownerUserId == nil`(CodingKeys 제외라 미인코딩)

- [ ] **Step 3: CodingKeys에 추가** — `Pregnancy.swift:37-42`

```swift
    enum CodingKeys: String, CodingKey {
        case id, lmpDate, dueDate, eddHistory, fetusCount, babyNickname
        case ultrasoundGender, transitionState, outcome, archivedAt
        case prePregnancyWeight, weightUnit, sharedWith, createdAt, updatedAt
        case ownerUserId   // 영속화: 공유 임신 소유자 식별 (비대칭 공유 owner-write 기준)
    }
```
주석 line 41(`// ownerUserId intentionally excluded ...`)은 제거.

- [ ] **Step 4: 테스트 통과 확인** — Run: 위 Step 2 명령 / Expected: PASS

- [ ] **Step 5: 생성 시 ownerUserId 세팅** — `PregnancyViewModel`의 임신 생성 메서드 확인 후 세팅

Run: `grep -n "func createPregnancy\|func registerPregnancy\|savePregnancy" BabyCare/ViewModels/PregnancyViewModel.swift`
생성/등록 메서드에서 새 `Pregnancy`를 만들거나 save하기 직전에 `pregnancy.ownerUserId = userId`(현재 사용자 uid)를 세팅. (해당 메서드 시그니처를 확인해 정확한 위치에 1줄 추가 — userId/currentUserId 파라미터 사용.)

- [ ] **Step 6: 회귀 안전 확인** — 기존 fetchSharedPregnancy의 path 기반 stamp(`FirestoreService+Pregnancy` fetchSharedPregnancy)와 충돌 없는지 확인. 영속값이 있으면 그대로, 없으면(레거시 문서) path 기반 폴백 유지. 양쪽 모두 owner uid로 수렴해야 함.

- [ ] **Step 7: 전체 검증 + 커밋**

```bash
make verify
git add BabyCare/Models/Pregnancy.swift BabyCare/ViewModels/PregnancyViewModel.swift BabyCareTests/BabyCareTests+Pregnancy.swift
git commit -m "feat(pregnancy): ownerUserId 영속화 — 공유 임신 소유자 식별 토대 (CodingKeys + 생성 시 세팅)"
```

---

## Self-Review

- **Spec 커버**: DESIGN.md §2 "국소 P0/P1 수정 + ownerUserId 영속화" 4건(성별·중복아기·아카이브 주차·ownerUserId) 전부 Task화. 공유 쓰기 5경로 라우팅·partner read-only UI는 **서브프로젝트 7(공유)** 로 분리(v3 UI 의존) — 본 플랜 범위 외(의도적).
- **플레이스홀더**: 없음. 단 Task 3 Step 3·Task 4 Step 5는 기존 init/메서드 시그니처 확인 후 1줄 추가(grep 명령 명시) — 정확한 위치는 실행 시 확인.
- **타입 일관성**: `genderPrefill`/`finalWeekAndDay`(Pregnancy computed), `existingBabyIds`/`createdBabyIds`(Mock), `Baby(id:name:birthDate:gender:)`(검증된 시그니처), `PregnancyDateMath.weekAndDay(from:now:)`(검증), `Baby.id = "baby_\(p.id)"`(VM↔Mock↔Service 동일 규칙) — 일관.
- **리스크**: Task 3 Step 3의 `PregnancyViewModel(firestoreService:)` mock 주입 가능 여부 = 실행 전 확인 필요(미지원 시 narrow protocol default 주입 선행, 기존 패턴 존재).

## Execution Handoff
이 플랜은 4 Task, 모두 flag-off 상태라 사용자 영향 0. 실행 시 `make verify`로 게이트.
