# 통합 기록 P0 — 단일 저장 파이프라인 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:executing-plans (또는 subagent-driven-development). 스텝은 `- [ ]` 체크박스로 추적.

**Goal:** 기록 저장 로직을 `ActivityDraft`(순수 스냅샷) + `ActivityDraftBuilder.build`(순수) + 단일 `commit`/persist 꼬리로 통합하고, 기존 4개 저장 진입점을 이 파이프라인으로 위임한다. **UI/UX 변화 0.** 부수효과(오프라인 큐·리마인더·발열 추세·배지)를 전 경로 일관 적용.

**Architecture:** 현행 `performSaveActivity`의 `applyTypeFields`+`validate`+시간/타이머 로직을 순수 함수 `ActivityDraftBuilder.build(_:) -> Result<Activity, RecordValidationError>`로 이관(TDD). VM은 폼 상태를 `ActivityDraft`로 스냅샷 → build → 공용 persist 꼬리(낙관적 insert → Firestore save → 부수효과 → 실패 시 오프라인 큐). `quickSave`/`savePrebuiltActivity`(현재 오프라인 유실)도 이 꼬리를 타 유실 비대칭 제거.

**Tech Stack:** Swift 6, SwiftUI, `@MainActor @Observable` MVVM, XCTest. 스펙: `docs/superpowers/specs/2026-07-11-unified-recording-design.md`(§3.6/§5/§6 P0 관련).

## Global Constraints

- **Firestore 마이그레이션 0 · `Activity.ActivityType` 등 enum raw value 불변** (영구 계약).
- **GA4 이벤트 이름·`category` rawValue 불변** (`record_save`/`dashboard_quick_record`/`feed_record_save`/`diaper_record_save`/`sleep_record_save`/`pumping_recorded`).
- **가족 공유**: 저장 path `userId = babyVM.dataUserId(currentUserId:) ?? currentUserId`, 배지 부여 path = `currentUserId`. `authVM.currentUserId` 직접 저장 금지.
- **arch R1–R4 = 0**: View→Service 직접 호출 금지, `Firestore.firestore()` 직접 호출 금지. 신규 컬렉션 없음 → Narrow Protocol 불필요.
- **검증 경계 불변**: 수유/유축 amount 1~500ml, 체온 34.0~43.0°C, duration 최소 1초(수동조정 예외), 수면 duration ≤ 24h.
- **`.unknown` 센티넬**: 저장/영속 불가 — 진입 가드 유지.
- **로깅**: `print()` 금지, `AppLogger.<category>` / `logSilent`.
- **테스트 파일**: 신규 순수 로직은 도메인 분리 파일 `BabyCareTests/BabyCareTests+ActivityDraft.swift`(자체 클래스)로. 기존 `BabyCareTests.swift` 첫 클래스 append 트랩 회피(선례: `BabyCareTests+ActivityEdit.swift`).
- 각 태스크 종료 시 `bash scripts/arch_test.sh` R1–4=0 + 해당 테스트 green. 마지막에 `make verify`.
- **UX 불변 계약**: 이 단계에서 화면·다이얼로그·탭 흐름 변화 금지. 눈에 보이지 않는 신뢰성(오프라인 큐·발열추세 일관화)만 개선.

---

## File Structure

- **Create** `BabyCare/Models/ActivityDraft.swift` — 순수 값 스냅샷 + `RecordValidationError`.
- **Create** `BabyCare/Models/ActivityDraftBuilder.swift` — `build(_:) -> Result<Activity, RecordValidationError>` 순수.
- **Create** `BabyCareTests/BabyCareTests+ActivityDraft.swift` — Builder 단위 테스트(자체 클래스).
- **Modify** `BabyCare/ViewModels/ActivityViewModel+Save.swift` — `commit`/`persist` 꼬리 신설, `makeDraft`, 기존 4경로 위임.
- **Modify** `BabyCare/Views/Dashboard/QuickInputSheet.swift` — `savePrebuiltActivity` 경유 유지(꼬리 공유로 오프라인 큐 획득) — 시그니처 무변경.
- 테스트: 기존 `MockActivityFirestore`(호출 카운터·에러 주입) 재사용.

---

## Task 1: `ActivityDraft` 값 타입 + `RecordValidationError`

**Files:**
- Create: `BabyCare/Models/ActivityDraft.swift`
- Test: `BabyCareTests/BabyCareTests+ActivityDraft.swift`

**Interfaces:**
- Produces: `struct ActivityDraft`(아래 필드), `enum RecordValidationError: Error, Equatable { case invalidAmount, invalidTemperature, tooShort, sleepTooLong, unknownType }`.

- [ ] **Step 1: 순수 타입 작성** — `BabyCare/Models/ActivityDraft.swift`

```swift
import Foundation

/// 저장 진입점(풀폼/빠른기록/미니시트)이 공통으로 채우는 순수 입력 스냅샷.
/// VM 라이브 상태(타이머 등)를 여기서 값으로 고정 → Builder는 부수효과 없이 매핑만.
struct ActivityDraft: Equatable {
    var babyId: String
    var type: Activity.ActivityType

    // 시간/타이머 (VM이 stopTimer/수동조정 해석 후 값으로 주입)
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval?
    var wasManuallyAdjusted: Bool = false

    // 타입별 값 (해당 없으면 무시)
    var side: Activity.BreastSide?
    var amountText: String = ""          // "" = 미입력; 검증은 Builder
    var feedingContent: Activity.FeedingContent = .formula
    var foodName: String = ""
    var foodAmount: String = ""
    var foodReaction: Activity.FoodReaction?
    var temperatureText: String = ""
    var medicationName: String = ""
    var medicationDosage: String = ""
    var sleepQuality: Activity.SleepQualityType?
    var sleepMethod: Activity.SleepMethodType?
    var stoolColor: Activity.StoolColor?
    var stoolConsistency: Activity.StoolConsistency?
    var hasRash: Bool = false
    var note: String = ""

    init(babyId: String, type: Activity.ActivityType, startTime: Date = Date()) {
        self.babyId = babyId
        self.type = type
        self.startTime = startTime
    }
}

enum RecordValidationError: Error, Equatable {
    case invalidAmount        // "수유량/유축량을 올바르게 입력해주세요. (1~500ml)"
    case invalidTemperature   // "체온을 올바르게 입력해주세요. (34.0~43.0°C)"
    case tooShort             // "최소 1초 이상 기록해주세요."
    case sleepTooLong         // "수면 시간이 24시간을 초과합니다. 시간을 확인해주세요."
    case unknownType          // .unknown 센티넬

    var message: String {
        switch self {
        case .invalidAmount: "수유량을 올바르게 입력해주세요. (1~500ml)"
        case .invalidTemperature: "체온을 올바르게 입력해주세요. (34.0~43.0°C)"
        case .tooShort: "최소 1초 이상 기록해주세요."
        case .sleepTooLong: "수면 시간이 24시간을 초과합니다. 시간을 확인해주세요."
        case .unknownType: "지원하지 않는 기록입니다."
        }
    }
}
```

- [ ] **Step 2: 테스트 파일 스캐폴드 + 기본 테스트** — `BabyCareTests/BabyCareTests+ActivityDraft.swift`

```swift
import XCTest
@testable import BabyCare

final class ActivityDraftBuilderTests: XCTestCase {
    func test_draft_defaults() {
        let d = ActivityDraft(babyId: "b1", type: .feedingBreast)
        XCTAssertEqual(d.feedingContent, .formula)
        XCTAssertFalse(d.wasManuallyAdjusted)
        XCTAssertEqual(d.amountText, "")
    }
}
```

- [ ] **Step 3: 빌드 + 실행** — `xcodebuild test ... -only-testing:BabyCareTests/ActivityDraftBuilderTests/test_draft_defaults` → PASS (실행 수 1 확인, vacuous 아님).

- [ ] **Step 4: 커밋**

```bash
git add BabyCare/Models/ActivityDraft.swift BabyCareTests/BabyCareTests+ActivityDraft.swift
git commit -m "feat(recording): ActivityDraft 순수 입력 스냅샷 + RecordValidationError"
```

---

## Task 2: `ActivityDraftBuilder.build` (순수) — TDD 핵심

**Files:**
- Create: `BabyCare/Models/ActivityDraftBuilder.swift`
- Test: `BabyCareTests/BabyCareTests+ActivityDraft.swift`(append)

**Interfaces:**
- Consumes: `ActivityDraft`, `RecordValidationError`(Task 1).
- Produces: `enum ActivityDraftBuilder { nonisolated static func build(_ draft: ActivityDraft) -> Result<Activity, RecordValidationError> }`.

**참조(현행 로직 이관 원본):** `ActivityViewModel+Save.swift`의 `applyTypeFields`(75–137) / `validateActivity`(159–169) / `applyManualTimeAdjustment`(149–156). 타이머 duration은 draft.duration/startTime/endTime으로 이미 해석돼 들어옴(VM `makeDraft`가 `stopTimer` 처리 — Task 5).

- [ ] **Step 1: 실패 테스트 작성**(append to `ActivityDraftBuilderTests`)

```swift
func test_build_bottle_requiresValidAmount() {
    var d = ActivityDraft(babyId: "b", type: .feedingBottle)
    d.amountText = "0"
    XCTAssertEqual(ActivityDraftBuilder.build(d), .failure(.invalidAmount))
    d.amountText = "120"
    let ok = try? ActivityDraftBuilder.build(d).get()
    XCTAssertEqual(ok?.amount, 120)
    XCTAssertEqual(ok?.feedingContent, .formula)
}

func test_build_breast_appliesSideAndDuration() {
    var d = ActivityDraft(babyId: "b", type: .feedingBreast)
    d.side = .right; d.duration = 600; d.startTime = Date(timeIntervalSince1970: 1000)
    let a = try? ActivityDraftBuilder.build(d).get()
    XCTAssertEqual(a?.side, .right)
    XCTAssertEqual(a?.duration, 600)
}

func test_build_temperature_boundaries() {
    var d = ActivityDraft(babyId: "b", type: .temperature)
    d.temperatureText = "50"; XCTAssertEqual(ActivityDraftBuilder.build(d), .failure(.invalidTemperature))
    d.temperatureText = "37.2"; XCTAssertEqual((try? ActivityDraftBuilder.build(d).get())?.temperature, 37.2)
}

func test_build_sleep_rejectsOver24h() {
    var d = ActivityDraft(babyId: "b", type: .sleep)
    d.duration = 90000; d.wasManuallyAdjusted = false
    XCTAssertEqual(ActivityDraftBuilder.build(d), .failure(.sleepTooLong))
}

func test_build_pumping_amountAndSide() {
    var d = ActivityDraft(babyId: "b", type: .feedingPumping)
    d.amountText = "80"; d.side = .both
    let a = try? ActivityDraftBuilder.build(d).get()
    XCTAssertEqual(a?.amount, 80); XCTAssertEqual(a?.side, .both)
}

func test_build_diaperDirty_stoolFields() {
    var d = ActivityDraft(babyId: "b", type: .diaperDirty)
    d.stoolColor = .yellow; d.hasRash = true
    let a = try? ActivityDraftBuilder.build(d).get()
    XCTAssertEqual(a?.stoolColor, .yellow); XCTAssertEqual(a?.hasRash, true)
}

func test_build_unknown_fails() {
    let d = ActivityDraft(babyId: "b", type: .unknown)
    XCTAssertEqual(ActivityDraftBuilder.build(d), .failure(.unknownType))
}

func test_build_manualTimeAdjustment_setsStartAndEnd() {
    var d = ActivityDraft(babyId: "b", type: .sleep)
    let start = Date(timeIntervalSince1970: 1000); let end = Date(timeIntervalSince1970: 4600)
    d.wasManuallyAdjusted = true; d.startTime = start; d.endTime = end; d.duration = 3600
    let a = try? ActivityDraftBuilder.build(d).get()
    XCTAssertEqual(a?.startTime, start); XCTAssertEqual(a?.endTime, end); XCTAssertEqual(a?.duration, 3600)
}
```

> 참고: `StoolColor.yellow` 등 실제 케이스명은 `Activity` 모델(`ActivityEnums.swift`/`Activity.swift`)에서 확인 후 사용(존재 케이스로 치환).

- [ ] **Step 2: 실행 → 실패 확인**(`build` 미정의로 컴파일/링커 FAIL).

- [ ] **Step 3: 구현** — `BabyCare/Models/ActivityDraftBuilder.swift`. `applyTypeFields`/`validate`/`applyManualTimeAdjustment` 로직을 순수 이관. amount 검증은 `1~500`, temp `34~43`. `Activity(babyId:type:)` 초기화 후 필드 세팅. duration<1 && !manual → `.tooShort`. sleep && duration>86400 → `.sleepTooLong`. note는 trim 후 비면 nil. `.unknown` → `.failure(.unknownType)`.

```swift
import Foundation

enum ActivityDraftBuilder {
    nonisolated static func build(_ draft: ActivityDraft) -> Result<Activity, RecordValidationError> {
        guard draft.type != .unknown else { return .failure(.unknownType) }
        var a = Activity(babyId: draft.babyId, type: draft.type)
        a.startTime = draft.startTime
        if let end = draft.endTime { a.endTime = end }
        if let dur = draft.duration { a.duration = dur }

        switch draft.type {
        case .feedingBreast:
            a.side = draft.side ?? .left
        case .feedingBottle:
            guard let ml = Double(draft.amountText), ml > 0, ml <= 500 else { return .failure(.invalidAmount) }
            a.amount = ml; a.feedingContent = draft.feedingContent
        case .feedingPumping:
            guard let ml = Double(draft.amountText), ml > 0, ml <= 500 else { return .failure(.invalidAmount) }
            a.amount = ml; a.side = draft.side
        case .feedingSolid:
            a.foodName = draft.foodName.isEmpty ? nil : draft.foodName
            a.foodAmount = draft.foodAmount.isEmpty ? nil : draft.foodAmount
            a.foodReaction = draft.foodReaction
        case .feedingSnack:
            a.foodName = draft.foodName.isEmpty ? nil : draft.foodName
            a.foodAmount = draft.foodAmount.isEmpty ? nil : draft.foodAmount
        case .sleep:
            a.sleepQuality = draft.sleepQuality; a.sleepMethod = draft.sleepMethod
        case .diaperWet:
            break
        case .diaperDirty, .diaperBoth:
            a.stoolColor = draft.stoolColor; a.stoolConsistency = draft.stoolConsistency
            a.hasRash = draft.hasRash ? true : nil
        case .temperature:
            guard let t = Double(draft.temperatureText), t >= 34.0, t <= 43.0 else { return .failure(.invalidTemperature) }
            a.temperature = t
        case .medication:
            a.medicationName = draft.medicationName.isEmpty ? nil : draft.medicationName
            a.medicationDosage = draft.medicationDosage.isEmpty ? nil : draft.medicationDosage
        case .bath:
            break
        case .unknown:
            return .failure(.unknownType)
        }

        // 검증: 최소 1초(수동조정 예외), 수면 24h 상한
        if let dur = a.duration, dur < 1, !draft.wasManuallyAdjusted { return .failure(.tooShort) }
        if draft.type == .sleep, let dur = a.duration, dur > AppConstants.secondsPerDay { return .failure(.sleepTooLong) }

        let trimmed = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { a.note = trimmed }
        return .success(a)
    }
}
```

- [ ] **Step 4: 실행 → 전부 PASS**(실행 수 = 작성한 테스트 수 확인).

- [ ] **Step 5: 커밋**

```bash
git add BabyCare/Models/ActivityDraftBuilder.swift BabyCareTests/BabyCareTests+ActivityDraft.swift
git commit -m "feat(recording): ActivityDraftBuilder 순수 빌더 (타입별 필드+검증 이관, TDD)"
```

---

## Task 3: 공용 persist 꼬리 — `commit`/`persist` (오프라인 큐 전 경로화)

**Files:**
- Modify: `BabyCare/ViewModels/ActivityViewModel+Save.swift`
- Test: `BabyCareTests/BabyCareTests+ActivityDraft.swift`(append; `MockActivityFirestore` 사용)

**Interfaces:**
- Consumes: `ActivityDraftBuilder.build`(Task 2), 기존 `enqueueOfflineActivity`/`deriveLatestActivities`/`scheduleActivityReminderIfNeeded`/`registerTemperature`/`evaluateBadgesIfNeeded`/`syncWidgetData`.
- Produces:
  - `func commit(draft: ActivityDraft, userId: String, currentUserId: String) async -> Activity?` — build 성공 시 persist 후 저장된 activity 반환(Undo/analytics 용), 실패 시 nil + errorMessage.
  - `private func persist(_ activity: Activity, userId: String, currentUserId: String) async -> Bool` — 낙관적 insert → save → 부수효과, 실패 시 오프라인 큐 + toast. 성공/큐잉 true.

- [ ] **Step 1: 테스트 작성** — 성공 insert, build 실패 시 errorMessage, save 실패 시 오프라인 큐 적재. `MockActivityFirestore`에 에러 주입.

```swift
@MainActor
func test_commit_success_insertsActivity() async {
    let mock = MockActivityFirestore()
    let vm = ActivityViewModel(firestoreService: mock)
    var d = ActivityDraft(babyId: "b", type: .feedingBottle); d.amountText = "100"
    let saved = await vm.commit(draft: d, userId: "u", currentUserId: "u")
    XCTAssertNotNil(saved)
    XCTAssertEqual(vm.todayActivities.first?.amount, 100)
    XCTAssertEqual(mock.saveActivityCalls.count, 1)
}

@MainActor
func test_commit_buildFailure_setsError_noSave() async {
    let mock = MockActivityFirestore()
    let vm = ActivityViewModel(firestoreService: mock)
    var d = ActivityDraft(babyId: "b", type: .feedingBottle); d.amountText = "0"
    let saved = await vm.commit(draft: d, userId: "u", currentUserId: "u")
    XCTAssertNil(saved)
    XCTAssertNotNil(vm.errorMessage)
    XCTAssertEqual(mock.saveActivityCalls.count, 0)
}
```

> `MockActivityFirestore` 실제 API: `errorOnSave: Error?`(에러 주입) · `saveActivityCalls: [Activity]`(카운터=`.count`).

- [ ] **Step 2: 실행 → 실패 확인**(`commit` 미정의).

- [ ] **Step 3: 구현** — `commit`/`persist` 추가. `persist`는 현행 `performSaveActivity`의 성공/실패 블록(46–63)을 그대로 이관하되 **모든 경로 공용**. 부수효과: `deriveLatestActivities` → reminder → (`temperature`면 `registerTemperature` 후 trend alert) → `evaluateBadgesIfNeeded`. 실패 시 `enqueueOfflineActivity` + `InfoToastCenter.shared.offlineSaved()`.

```swift
func commit(draft: ActivityDraft, userId: String, currentUserId: String) async -> Activity? {
    errorMessage = nil
    switch ActivityDraftBuilder.build(draft) {
    case .failure(let err):
        if err == .unknownType { logUnknownSaveBlocked() } else { errorMessage = err.message }
        return nil
    case .success(var activity):
        activity.createdBy = currentUserId
        let ok = await persist(activity, userId: userId, currentUserId: currentUserId)
        return ok ? activity : nil
    }
}

private func persist(_ activity: Activity, userId: String, currentUserId: String) async -> Bool {
    todayActivities.insert(activity, at: 0)   // 낙관적
    do {
        try await firestoreService.saveActivity(activity, userId: userId)
        deriveLatestActivities()
        scheduleActivityReminderIfNeeded(type: activity.type, babyName: "아기")
        if activity.type == .temperature, registerTemperature(activity) {
            NotificationService.shared.scheduleTemperatureTrendAlert(babyName: currentBabyName)
        }
        await evaluateBadgesIfNeeded(type: activity.type, babyId: activity.babyId, currentUserId: currentUserId, at: activity.startTime)
        return true
    } catch {
        enqueueOfflineActivity(activity, userId: userId, babyId: activity.babyId)
        deriveLatestActivities()
        InfoToastCenter.shared.offlineSaved()
        return true   // 큐잉=사용자 관점 저장 성공
    }
}
```

- [ ] **Step 4: 실행 → PASS.**
- [ ] **Step 5: 커밋** `feat(recording): 공용 commit/persist 꼬리 (오프라인 큐 전 경로화)`

---

## Task 4: VM `makeDraft(type:)` — 폼 상태 → 스냅샷 (타이머/수동시간 해석)

**Files:** Modify `BabyCare/ViewModels/ActivityViewModel+Save.swift`

**Interfaces:**
- Produces: `func makeDraft(type: Activity.ActivityType, babyId: String) -> ActivityDraft` — 현재 폼 상태를 draft로 캡처. **타이머가 이 타입이면 `stopTimer()`로 duration 확정**(현행 `applyTimerDuration` 대체), 수동조정 반영.

- [ ] **Step 1: 테스트** — 폼 값이 draft에 반영되는지(순수 캡처 부분). 타이머 경로는 통합 시나리오로 Task 6에서.

```swift
@MainActor
func test_makeDraft_capturesFormState() {
    let vm = ActivityViewModel(firestoreService: MockActivityFirestore())
    vm.selectedSide = .right; vm.note = "  hi "
    let d = vm.makeDraft(type: .feedingBreast, babyId: "b")
    XCTAssertEqual(d.side, .right); XCTAssertEqual(d.type, .feedingBreast)
}
```

- [ ] **Step 2: 실행 → 실패.**
- [ ] **Step 3: 구현** — 현행 `performSaveActivity`의 시간/타이머 처리(14, 34–40, `applyTimerDuration`, `applyManualTimeAdjustment`)를 draft 조립으로 이관.

```swift
func makeDraft(type: Activity.ActivityType, babyId: String) -> ActivityDraft {
    var d = ActivityDraft(babyId: babyId, type: type)
    let timerBelongsToMe = isTimerRunning && activeTimerType == type
    let wasManuallyAdjusted = isTimeAdjusted

    if timerBelongsToMe {
        let duration = stopTimer()            // 부수효과: 타이머 종료 + manualStart/End 채움
        d.duration = duration
        d.startTime = Date().addingTimeInterval(-duration)
        if type.needsTimer { d.endTime = (type == .sleep || type == .bath) ? Date() : nil }
    }
    if wasManuallyAdjusted {                    // 수동 조정이 타이머보다 우선
        d.startTime = manualStartTime
        if let end = manualEndTime { d.endTime = end; d.duration = end.timeIntervalSince(manualStartTime) }
        d.wasManuallyAdjusted = true
    } else if !timerBelongsToMe {
        d.startTime = isTimeAdjusted ? manualStartTime : Date()
    }

    d.side = selectedSide
    d.amountText = amount
    d.feedingContent = selectedFeedingContent
    d.foodName = foodName; d.foodAmount = foodAmount; d.foodReaction = foodReaction
    d.temperatureText = temperatureInput
    d.medicationName = medicationName; d.medicationDosage = medicationDosage
    d.sleepQuality = sleepQuality; d.sleepMethod = sleepMethod
    d.stoolColor = stoolColor; d.stoolConsistency = stoolConsistency; d.hasRash = hasRash
    d.note = note
    return d
}
```

> ⚠️ 현행 `applyTimerDuration`은 breast/bottle `includeEndTime:false`, sleep `true`, bath `false`. 위 `endTime` 분기를 현행과 1:1 대조 후 확정(회귀 방지). 원본 호출부(76/84/98/121) 재확인.

- [ ] **Step 4: 실행 → PASS.**
- [ ] **Step 5: 커밋** `feat(recording): ActivityViewModel.makeDraft (폼→스냅샷, 타이머/수동시간 이관)`

---

## Task 5: 풀폼 저장 경로를 `makeDraft`+`commit`으로 위임

**Files:** Modify `BabyCare/ViewModels/ActivityViewModel+Save.swift`(`saveActivity`)

**목표:** 현행 `saveActivity`(12–27)의 **중복 경고 UX 보존**(풀폼만) + 저장을 `commit`으로 위임. `performSaveActivity`는 제거하고 `commit`으로 대체.

- [ ] **Step 1: 회귀 테스트** — 중복이면 `showDuplicateWarning=true`, 아니면 commit 저장.

```swift
@MainActor
func test_saveActivity_duplicate_setsWarning() async {
    let vm = ActivityViewModel(firestoreService: MockActivityFirestore())
    var existing = Activity(babyId: "b", type: .diaperWet); existing.startTime = Date()
    vm.todayActivities = [existing]
    vm.isTimeAdjusted = true; vm.manualStartTime = existing.startTime   // 동일 시각
    await vm.saveActivity(userId: "u", currentUserId: "u", babyId: "b", type: .diaperWet)
    XCTAssertTrue(vm.showDuplicateWarning)
}
```

- [ ] **Step 2: 실행 → 실패/오류.**
- [ ] **Step 3: 구현** — `saveActivity`를 draft 기반으로 교체. `performSaveActivity`/`applyTypeFields`/`applyTimerDuration`/`applyManualTimeAdjustment`/`validateActivity` 삭제(Builder/makeDraft로 이관됨). resetForm은 commit 성공 후 호출.

```swift
func saveActivity(userId: String, currentUserId: String, babyId: String, type: Activity.ActivityType) async {
    let draft = makeDraft(type: type, babyId: babyId)
    if hasDuplicateRecord(type: type, startTime: draft.startTime) {
        pendingDuplicateSave = { [weak self] in
            guard let self else { return }
            _ = await self.commit(draft: draft, userId: userId, currentUserId: currentUserId)
            if self.errorMessage == nil { self.resetForm() }
        }
        showDuplicateWarning = true
        return
    }
    _ = await commit(draft: draft, userId: userId, currentUserId: currentUserId)
    if errorMessage == nil { resetForm() }
}
```

> ⚠️ `makeDraft`가 `stopTimer()` 부수효과를 내므로 중복 경고 후 재저장 시 draft는 이미 확정된 값을 재사용(현행처럼 타이머 재stop 안 함) — pendingDuplicateSave 클로저가 draft 캡처. 현행 대비 동치 확인.

- [ ] **Step 4: 실행 → PASS + 관련 기존 테스트(ActivityEdit 등) 무회귀.**
- [ ] **Step 5: 커밋** `refactor(recording): 풀폼 저장을 makeDraft+commit 위임, 죽은 저장코드 제거`

---

## Task 6: `quickSave` 위임 (빠른기록도 오프라인 큐 획득)

**Files:** Modify `BabyCare/ViewModels/ActivityViewModel+Save.swift`(`quickSave`)

**목표:** 현행 `quickSave`(206–228, 오프라인 유실)를 `commit`으로. **UX 불변**: 중복 경고는 이 단계에서 추가하지 않음(P2로 이연) — quick은 즉시저장 그대로, 단 실패 시 롤백 대신 **오프라인 큐**(유실→저장).

- [ ] **Step 1: 테스트** — save 실패 주입 시 롤백이 아니라 오프라인 큐 적재 + todayActivities 유지.

```swift
@MainActor
func test_quickSave_offlineFallback_keepsActivity() async {
    let mock = MockActivityFirestore(); mock.errorOnSave = NSError(domain: "test", code: 1)
    let vm = ActivityViewModel(firestoreService: mock)
    await vm.quickSave(userId: "u", currentUserId: "u", babyId: "b", type: .diaperWet)
    XCTAssertEqual(vm.todayActivities.count, 1)   // 롤백 안 됨 (큐잉됨)
    XCTAssertNil(vm.errorMessage)
}
```

- [ ] **Step 2: 실행 → 실패**(현행은 롤백+errorMessage).
- [ ] **Step 3: 구현** — quick 전용 최소 draft로 commit. 모유수유 방향 기본값(`.left`) 보존.

```swift
func quickSave(userId: String, currentUserId: String, babyId: String, type: Activity.ActivityType) async {
    var draft = ActivityDraft(babyId: babyId, type: type)
    if type == .feedingBreast { draft.side = .left }
    _ = await commit(draft: draft, userId: userId, currentUserId: currentUserId)
}
```

- [ ] **Step 4: 실행 → PASS.**
- [ ] **Step 5: 커밋** `refactor(recording): quickSave를 commit 위임 (오프라인 큐 유실 비대칭 해소)`

---

## Task 7: `savePrebuiltActivity`(미니시트) 위임 (오프라인 큐 획득)

**Files:** Modify `BabyCare/ViewModels/ActivityViewModel+Save.swift`(`savePrebuiltActivity`)

**목표:** 현행(188–204, 오프라인 유실)을 공용 `persist`로. `QuickInputSheet`는 이미 `Activity`를 완성해 넘기므로 시그니처 유지, 내부만 `persist` 위임.

- [ ] **Step 1: 테스트** — save 실패 주입 시 오프라인 큐 적재 + 유지.

```swift
@MainActor
func test_savePrebuilt_offlineFallback() async {
    let mock = MockActivityFirestore(); mock.errorOnSave = NSError(domain: "test", code: 1)
    let vm = ActivityViewModel(firestoreService: mock)
    var a = Activity(babyId: "b", type: .temperature); a.temperature = 37.0
    await vm.savePrebuiltActivity(a, userId: "u", currentUserId: "u")
    XCTAssertEqual(vm.todayActivities.count, 1)
    XCTAssertNil(vm.errorMessage)
}
```

- [ ] **Step 2: 실행 → 실패**(현행 롤백).
- [ ] **Step 3: 구현**

```swift
func savePrebuiltActivity(_ activity: Activity, userId: String, currentUserId: String) async {
    guard activity.type != .unknown else { return logUnknownSaveBlocked() }
    errorMessage = nil
    var a = activity; a.createdBy = currentUserId
    _ = await persist(a, userId: userId, currentUserId: currentUserId)
}
```

- [ ] **Step 4: 실행 → PASS.**
- [ ] **Step 5: 커밋** `refactor(recording): savePrebuiltActivity를 persist 위임 (미니시트 오프라인 큐)`

---

## Task 8: 통합 검증 + arch + `make verify`

- [ ] **Step 1:** `bash scripts/arch_test.sh` → R1–4=0.
- [ ] **Step 2:** `make verify` → ALL CHECKS PASSED (lint 0err·arch 0·design 100%·전체 테스트 green).
- [ ] **Step 3:** `make smoke-test` → 시뮬 런치 크래시 없음(로그인 렌더).
- [ ] **Step 4:** 수동 대조 — 저장 후 화면/토스트/시트 동작이 재설계 전과 동일한지(UX 불변) `git diff --stat`로 View 파일 무변경 확인(P0는 VM/Model만 수정).
- [ ] **Step 5: 커밋(있으면)** — 없으면 스킵. P0 완료.

---

## P0 완료 정의 (Definition of Done)

- `ActivityDraft` + `ActivityDraftBuilder`(순수·TDD) + `commit`/`persist`(공용 꼬리) 도입.
- 4개 저장 경로(풀폼·quick·미니시트) 전부 위임 → **저장 코드 1벌로 수렴**.
- quick/미니시트 **오프라인 유실 비대칭 해소** + 발열 추세/부수효과 일관.
- **UI/UX·화면·다이얼로그·탭 변화 0**(View 파일 무수정). `make verify` green.
- 다음: **P1(통합 기록 시트)** 플랜 작성. push/PR/머지는 PO 승인.
