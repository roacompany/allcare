# 우리 하루 ① — 시간표 모델 + 짜는 화면 · 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 부모가 「우리 집 하루」를 시간표로 짜서 저장하고, 그 시간표가 하루의 칸으로 펼쳐지는 순수 로직까지 완성한다.

**Architecture:** 저장 모델 `DayPlan`(신규 Firestore 컬렉션 `dayPlans`) + 펼치는 순수 함수 `DayPlanExpander` + 화면 둘(목록·「언제」 고르기). 잠금화면·오늘 만들기·기록 붙이기는 **범위 밖**(②③④단계).

**Tech Stack:** Swift 6.0 · iOS 17+ · SwiftUI · Firebase Firestore · XCTest · DS2 토큰

**Spec:** `docs/superpowers/specs/2026-09-02-our-day-timetable-design.md`

## Global Constraints

- 모델은 `Identifiable, Codable, Hashable` 채택 · **신규 필드는 전부 optional**
- Firestore 컬렉션명은 **`FirestoreCollections.*` 상수만** — 하드코딩 금지
- 신규 컬렉션 = **Narrow Protocol 5단계** 필수 · `arch_test.sh` **R1=R2=R3=R4=0**
- `Firestore.firestore()` 직접 호출은 `Services/FirestoreService*.swift` 밖에서 금지
- 프로토콜 시그니처에 **`[String: Any]` 금지**(Swift 6 Sendable)
- `print()` 금지 = `AppLogger` · non-fatal 은 `logSilent(_:error:logger:)`
- View → Service 직접 호출 금지(R1) · `NavigationStack` 중첩 금지
- 저장 userId 는 **owner-path**(`dataUserId`) · `@AppStorage` 에 사용자 데이터 금지
- Firestore 에 저장되는 **rawValue 는 영구 계약** — 바꾸면 기존 문서가 깨진다
- 색은 **DS2 토큰만**(`DS2.Color.*` · `DS2.Spacing.*` · `DS2.Radius.*`) — hex 하드코딩 금지
- 100% SF Symbols
- 용어: **'짜기' 금지** — 유축(생산) / 모유(병)(섭취)
- **의학 단정 금지** — 「이제 먹일 때예요」류 문구 금지. 시간표 시각은 **부모가 정한 것**으로만 표현
- ⛔ **지연·재촉·경고 문구 금지** · ⛔ **연속 일수·완료율 분수·배지 금지**(설계 §5)
- ⛔ `FeedingPredictionService` 사용 금지 — 예측이 아니라 부모가 짠 것(설계 결정 4)
- 테스트는 **`BabyCareTests/BabyCareTests+DayPlan.swift`** 신규 파일(도메인 분리 선례 준수)
- 임신 v3 는 flag-off 휴면 — 건드리지 않는다

---

## ⚠️ 설계 문서에서 바뀐 것 (실행 전 PO 확인 대상)

설계 §7 은 「`Routine` 을 시간표 그릇으로 재사용」이라고 적었다. **계획을 짜면서 실측한 결과 그게 틀렸다:**

1. `Routine.currentStreak`(연속 100% 완료 일수)이 모델에 박혀 있고 `RoutineView.swift:87` 이
   「🔥 N일 연속」과 「3/5」를 상시 표시한다. 설계 §5 가 **금지한 바로 그것**이다.
   재사용하면 출시된 화면 안에서 분기해야 한다.
2. 재사용해도 **싸지지 않는다** — `RoutineViewModel:15` 가 `FirestoreService.shared` 를 직접 들고 있어
   narrow protocol 이 **없다**(완성 11종에 Routine 없음). 어느 쪽이든 프로토콜을 새로 짜야 한다.
3. 루틴은 **체크리스트**(시각 없음), 시간표는 **시각이 있는 하루**다. 개념이 다르다.

→ **신규 컬렉션 `dayPlans` + Narrow Protocol 5단계로 간다.** 루틴은 손대지 않는다.

---

## File Structure

| 파일 | 책임 |
|---|---|
| `BabyCare/Models/DayPlan.swift` (신규) | 시간표 저장 모델 · `PlanSchedule` 세 방식의 영구 계약 |
| `BabyCare/Models/DayPlanExpander.swift` (신규) | **순수 함수** — 시간표 + 그날 정박점 → 칸 목록 |
| `BabyCare/Utils/Constants.swift` (수정) | `FirestoreCollections.dayPlans` 추가 |
| `BabyCare/Services/FirestoreService+DayPlan.swift` (신규) | `DayPlanFirestoreProviding` + 구현 |
| `BabyCareTests/MockDayPlanFirestore.swift` (신규) | in-memory + 호출 카운터 + 에러 주입 |
| `BabyCare/ViewModels/DayPlanViewModel.swift` (신규) | 로드·저장·삭제 · owner-path |
| `BabyCare/Views/DayPlan/DayPlanListView.swift` (신규) | 짜 둔 시간표 목록 |
| `BabyCare/Views/DayPlan/PlanEntrySheet.swift` (신규) | 「언제」 고르는 시트 — 세 방식 |
| `BabyCare/Views/Settings/SettingsView.swift` (수정) | 진입점 한 줄 |
| `BabyCareTests/BabyCareTests+DayPlan.swift` (신규) | 전 태스크 테스트 |

---

## Task 1: 저장 모델 `DayPlan` + `PlanSchedule`

**Files:**
- Create: `BabyCare/Models/DayPlan.swift`
- Test: `BabyCareTests/BabyCareTests+DayPlan.swift`

**Interfaces:**
- Consumes: 없음
- Produces: `DayPlan`, `DayPlan.Entry`, `DayPlan.Lane`, `PlanSchedule`, `PlanSchedule.Kind`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`BabyCareTests/BabyCareTests+DayPlan.swift` 를 새로 만든다:

```swift
import XCTest
@testable import BabyCare

final class DayPlanTests: XCTestCase {

    // rawValue 는 Firestore 영구 계약 — 바뀌면 기존 문서가 깨진다
    func testScheduleKindRawValuesAreContract() {
        XCTAssertEqual(PlanSchedule.Kind.fixedTimes.rawValue, "fixed_times")
        XCTAssertEqual(PlanSchedule.Kind.afterFirst.rawValue, "after_first")
        XCTAssertEqual(PlanSchedule.Kind.afterEntry.rawValue, "after_entry")
        XCTAssertEqual(DayPlan.Lane.baby.rawValue, "baby")
        XCTAssertEqual(DayPlan.Lane.parent.rawValue, "parent")
    }

    func testDayPlanRoundTripsThroughJSON() throws {
        let plan = DayPlan(
            id: "p1",
            name: "신생아 시간표",
            entries: [
                DayPlan.Entry(
                    id: "e1", title: "분유", activityType: "feeding_bottle", lane: .baby,
                    schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 6),
                    order: 0
                ),
                DayPlan.Entry(
                    id: "e2", title: "내 밥", activityType: nil, lane: .parent,
                    schedule: .fixedTimes(minutesOfDay: [720]),
                    order: 1
                )
            ]
        )
        let data = try JSONEncoder().encode(plan)
        let back = try JSONDecoder().decode(DayPlan.self, from: data)
        XCTAssertEqual(back, plan)
        XCTAssertEqual(back.entries[0].schedule.everyMinutes, 180)
        XCTAssertEqual(back.entries[1].schedule.minutesOfDay, [720])
    }

    // 옛 문서에 없던 필드가 들어와도 깨지지 않아야 한다
    func testDecodesDocumentWithoutOptionalFields() throws {
        let json = """
        {"id":"p1","name":"표","entries":[],"createdAt":0}
        """.data(using: .utf8)!
        let back = try JSONDecoder().decode(DayPlan.self, from: json)
        XCTAssertEqual(back.entries.count, 0)
        XCTAssertNil(back.babyId)
        XCTAssertTrue(back.isActive)   // 없으면 활성으로 본다
    }
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests/DayPlanTests 2>&1 | grep -E "error:|Executed"
```

기대: 컴파일 실패 — `cannot find 'DayPlan' in scope`.

> 🩸 **컴파일 에러 RED 는 RED 가 아니다.** GREEN 에서 `Executed 3 tests` 가 실제로 찍히는지 눈으로 볼 것.

- [ ] **Step 3: 모델을 만든다**

`BabyCare/Models/DayPlan.swift`:

```swift
import Foundation

/// 부모가 짜는 하루 시간표. 루틴(체크리스트)과 다른 개념 —
/// 시간표는 **시각**을 갖고, 연속 일수·완료율을 세지 않는다(설계 §5).
struct DayPlan: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var entries: [Entry]
    var babyId: String?
    var isActive: Bool
    var createdAt: Date

    /// 아이 줄 / 내 줄. rawValue = Firestore 영구 계약.
    enum Lane: String, Codable, Hashable {
        case baby
        case parent
    }

    struct Entry: Identifiable, Codable, Hashable {
        var id: String
        var title: String
        /// `Activity.ActivityType.rawValue`. nil = 기록 종류가 없는 것(내 밥·샤워).
        var activityType: String?
        var lane: Lane
        var schedule: PlanSchedule
        var order: Int

        init(
            id: String = UUID().uuidString,
            title: String,
            activityType: String? = nil,
            lane: Lane = .baby,
            schedule: PlanSchedule,
            order: Int
        ) {
            self.id = id
            self.title = title
            self.activityType = activityType
            self.lane = lane
            self.schedule = schedule
            self.order = order
        }
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        entries: [Entry] = [],
        babyId: String? = nil,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.entries = entries
        self.babyId = babyId
        self.isActive = isActive
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        entries = try c.decodeIfPresent([Entry].self, forKey: .entries) ?? []
        babyId = try c.decodeIfPresent(String.self, forKey: .babyId)
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date(timeIntervalSince1970: 0)
    }
}

/// 「언제」를 말하는 세 방식. 평평한 구조 + `kind` 판별자 —
/// 연관값 enum 의 중첩 JSON 은 Firestore 계약으로 쓰기 나쁘다.
struct PlanSchedule: Codable, Hashable {
    enum Kind: String, Codable, Hashable {
        case fixedTimes = "fixed_times"
        case afterFirst = "after_first"
        case afterEntry = "after_entry"
    }

    var kind: Kind
    /// fixedTimes — 자정으로부터 분(0..<1440), 오름차순.
    var minutesOfDay: [Int]?
    /// afterFirst — 정박할 기록 종류(`Activity.ActivityType.rawValue`).
    var anchorType: String?
    /// afterFirst — 간격(분).
    var everyMinutes: Int?
    /// afterFirst — 하루 몇 칸.
    var count: Int?
    /// afterEntry — 앞 항목의 `Entry.id`.
    var afterEntryId: String?
    /// afterEntry — 앞 항목 뒤 몇 분.
    var offsetMinutes: Int?

    static func fixedTimes(minutesOfDay: [Int]) -> PlanSchedule {
        PlanSchedule(kind: .fixedTimes, minutesOfDay: minutesOfDay.sorted())
    }

    static func afterFirst(anchorType: String, everyMinutes: Int, count: Int) -> PlanSchedule {
        PlanSchedule(kind: .afterFirst, anchorType: anchorType, everyMinutes: everyMinutes, count: count)
    }

    static func afterEntry(entryId: String, offsetMinutes: Int) -> PlanSchedule {
        PlanSchedule(kind: .afterEntry, afterEntryId: entryId, offsetMinutes: offsetMinutes)
    }
}
```

- [ ] **Step 4: 통과를 확인한다**

Step 2 와 같은 명령. 기대: `Executed 3 tests, with 0 failures`. **숫자를 눈으로 볼 것.**

- [ ] **Step 5: 커밋**

```bash
cd /Users/roque/BabyCare
git add BabyCare/Models/DayPlan.swift BabyCareTests/BabyCareTests+DayPlan.swift
git commit -m "feat(dayplan): 시간표 저장 모델 — 세 방식의 영구 계약"
```

---

## Task 2: 펼치는 순수 함수 `DayPlanExpander`

이 태스크가 ①단계의 핵심이다. 시간표는 저장 형태일 뿐이고, **하루의 칸**은 여기서 나온다.

**Files:**
- Create: `BabyCare/Models/DayPlanExpander.swift`
- Test: `BabyCareTests/BabyCareTests+DayPlan.swift` (append)

**Interfaces:**
- Consumes: `DayPlan`, `DayPlan.Entry`, `DayPlan.Lane`, `PlanSchedule` (Task 1)
- Produces: `DayAnchors`, `DayPlanExpander.Slot`, `DayPlanExpander.slots(plan:day:anchors:calendar:)`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`BabyCareTests/BabyCareTests+DayPlan.swift` 끝에 **새 클래스**로 추가한다:

```swift
final class DayPlanExpanderTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    /// 2026-09-02 정오 — 월 중간·정오로 잡아 타임존 경계 이슈를 피한다
    private var day: Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: 12))!
    }

    private func at(_ hour: Int, _ minute: Int) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: 2, hour: hour, minute: minute))!
    }

    private func plan(_ entries: [DayPlan.Entry]) -> DayPlan {
        DayPlan(id: "p", name: "표", entries: entries)
    }

    // A — 고정 시각은 정박점 없이도 바로 자리를 잡는다
    func testFixedTimesProducesOneSlotPerTime() {
        let p = plan([
            DayPlan.Entry(id: "e1", title: "목욕", lane: .baby,
                          schedule: .fixedTimes(minutesOfDay: [19 * 60 + 30]), order: 0)
        ])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal)
        XCTAssertEqual(slots.count, 1)
        XCTAssertEqual(slots[0].plannedAt, at(19, 30))
        XCTAssertEqual(slots[0].title, "목욕")
    }

    // B — 첫 기록이 없으면 자리는 있되 시각이 미정이다
    func testAfterFirstWithoutAnchorIsUnscheduledButPresent() {
        let p = plan([
            DayPlan.Entry(id: "e1", title: "분유", activityType: "feeding_bottle", lane: .baby,
                          schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 6),
                          order: 0)
        ])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal)
        XCTAssertEqual(slots.count, 6)
        XCTAssertTrue(slots.allSatisfy { $0.plannedAt == nil })
    }

    // B — 첫 기록이 들어오면 그 시각부터 펼쳐진다
    func testAfterFirstAnchorsOnFirstRecord() {
        let p = plan([
            DayPlan.Entry(id: "e1", title: "분유", activityType: "feeding_bottle", lane: .baby,
                          schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 4),
                          order: 0)
        ])
        let anchors = DayAnchors(firstRecordByType: ["feeding_bottle": at(6, 20)])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: anchors, calendar: cal)
        XCTAssertEqual(slots.compactMap(\.plannedAt), [at(6, 20), at(9, 20), at(12, 20), at(15, 20)])
    }

    // B — 그날을 넘어가는 칸은 버린다(하루 시간표는 그날 것이다)
    func testAfterFirstDropsSlotsPastEndOfDay() {
        let p = plan([
            DayPlan.Entry(id: "e1", title: "분유", activityType: "feeding_bottle", lane: .baby,
                          schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 6),
                          order: 0)
        ])
        let anchors = DayAnchors(firstRecordByType: ["feeding_bottle": at(20, 0)])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: anchors, calendar: cal)
        XCTAssertEqual(slots.compactMap(\.plannedAt), [at(20, 0), at(23, 0)])
    }

    // D — 앞 일이 끝나야 다음이 자리를 잡는다
    func testAfterEntryAnchorsOnPrecedingCompletion() {
        let p = plan([
            DayPlan.Entry(id: "bath", title: "목욕", lane: .baby,
                          schedule: .fixedTimes(minutesOfDay: [19 * 60 + 30]), order: 0),
            DayPlan.Entry(id: "bed", title: "잠자리", lane: .baby,
                          schedule: .afterEntry(entryId: "bath", offsetMinutes: 30), order: 1)
        ])
        let none = DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal)
        XCTAssertNil(none.first(where: { $0.entryId == "bed" })?.plannedAt)

        let done = DayAnchors(completedByEntry: ["bath": at(19, 45)])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: done, calendar: cal)
        XCTAssertEqual(slots.first(where: { $0.entryId == "bed" })?.plannedAt, at(20, 15))
    }

    // 정렬 — 시각이 정해진 것은 시각순, 미정은 맨 앞(하루의 시작을 기다리는 자리)
    func testSlotsSortUnscheduledFirstThenByTime() {
        let p = plan([
            DayPlan.Entry(id: "bath", title: "목욕", lane: .baby,
                          schedule: .fixedTimes(minutesOfDay: [19 * 60 + 30]), order: 1),
            DayPlan.Entry(id: "milk", title: "분유", activityType: "feeding_bottle", lane: .baby,
                          schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 1),
                          order: 0),
            DayPlan.Entry(id: "lunch", title: "내 밥", lane: .parent,
                          schedule: .fixedTimes(minutesOfDay: [12 * 60]), order: 2)
        ])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal)
        XCTAssertEqual(slots.map(\.entryId), ["milk", "lunch", "bath"])
    }

    // 줄이 둘이다 — 내 줄이 섞여 나온다
    func testSlotsCarryLane() {
        let p = plan([
            DayPlan.Entry(id: "lunch", title: "내 밥", lane: .parent,
                          schedule: .fixedTimes(minutesOfDay: [12 * 60]), order: 0)
        ])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal)
        XCTAssertEqual(slots[0].lane, .parent)
    }

    // 같은 항목의 칸들은 서로 다른 id 를 갖는다(붙이기 단계가 이걸 쓴다)
    func testSlotIdsAreUniquePerOccurrence() {
        let p = plan([
            DayPlan.Entry(id: "e1", title: "분유", activityType: "feeding_bottle", lane: .baby,
                          schedule: .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 3),
                          order: 0)
        ])
        let slots = DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal)
        XCTAssertEqual(Set(slots.map(\.id)).count, 3)
    }

    // 비활성 시간표는 펼쳐지지 않는다
    func testInactivePlanProducesNoSlots() {
        var p = plan([
            DayPlan.Entry(id: "e1", title: "목욕", lane: .baby,
                          schedule: .fixedTimes(minutesOfDay: [1170]), order: 0)
        ])
        p.isActive = false
        XCTAssertTrue(DayPlanExpander.slots(plan: p, day: day, anchors: DayAnchors(), calendar: cal).isEmpty)
    }
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests/DayPlanExpanderTests 2>&1 | grep -E "error:|Executed"
```

기대: `cannot find 'DayPlanExpander' in scope`.

- [ ] **Step 3: 순수 함수를 만든다**

`BabyCare/Models/DayPlanExpander.swift`:

```swift
import Foundation

/// 그날의 정박점. 시간표를 실제 시각으로 펼치는 데 필요한 두 가지.
struct DayAnchors: Hashable {
    /// 오늘 그 종류의 **첫 기록** 시각 — `afterFirst` 가 쓴다.
    var firstRecordByType: [String: Date]
    /// 오늘 그 항목이 **끝난** 시각 — `afterEntry` 가 쓴다.
    var completedByEntry: [String: Date]

    init(firstRecordByType: [String: Date] = [:], completedByEntry: [String: Date] = [:]) {
        self.firstRecordByType = firstRecordByType
        self.completedByEntry = completedByEntry
    }
}

/// 시간표 + 그날의 정박점 → 하루의 칸.
/// **순수 함수만** — Date() 도, 저장소도 만지지 않는다.
enum DayPlanExpander {

    struct Slot: Identifiable, Hashable {
        let id: String
        let entryId: String
        let title: String
        let activityType: String?
        let lane: DayPlan.Lane
        /// nil = 아직 정박 안 됨(첫 기록이나 앞 일을 기다리는 중).
        let plannedAt: Date?
        let order: Int
    }

    static func slots(
        plan: DayPlan,
        day: Date,
        anchors: DayAnchors,
        calendar: Calendar = .current
    ) -> [Slot] {
        guard plan.isActive else { return [] }

        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }

        var out: [Slot] = []
        for entry in plan.entries {
            out.append(contentsOf: expand(entry, start: start, end: end, anchors: anchors, calendar: calendar))
        }

        // 미정(nil)은 맨 앞 — 하루가 거기서 시작하기를 기다리는 자리다.
        return out.sorted { a, b in
            let ta = a.plannedAt ?? .distantPast
            let tb = b.plannedAt ?? .distantPast
            if ta != tb { return ta < tb }
            if a.order != b.order { return a.order < b.order }
            return a.id < b.id
        }
    }

    private static func expand(
        _ entry: DayPlan.Entry,
        start: Date,
        end: Date,
        anchors: DayAnchors,
        calendar: Calendar
    ) -> [Slot] {
        switch entry.schedule.kind {

        case .fixedTimes:
            let minutes = entry.schedule.minutesOfDay ?? []
            return minutes.enumerated().compactMap { idx, m in
                guard let at = calendar.date(byAdding: .minute, value: m, to: start), at < end else { return nil }
                return slot(entry, index: idx, at: at)
            }

        case .afterFirst:
            let count = max(0, entry.schedule.count ?? 0)
            let every = max(1, entry.schedule.everyMinutes ?? 0)
            guard let type = entry.schedule.anchorType,
                  let anchor = anchors.firstRecordByType[type] else {
                // 정박 전 — 자리는 있고 시각만 미정이다.
                return (0..<count).map { slot(entry, index: $0, at: nil) }
            }
            return (0..<count).compactMap { i in
                guard let at = calendar.date(byAdding: .minute, value: every * i, to: anchor), at < end else { return nil }
                return slot(entry, index: i, at: at)
            }

        case .afterEntry:
            guard let afterId = entry.schedule.afterEntryId,
                  let done = anchors.completedByEntry[afterId],
                  let at = calendar.date(byAdding: .minute, value: entry.schedule.offsetMinutes ?? 0, to: done),
                  at < end else {
                return [slot(entry, index: 0, at: nil)]
            }
            return [slot(entry, index: 0, at: at)]
        }
    }

    private static func slot(_ entry: DayPlan.Entry, index: Int, at: Date?) -> Slot {
        Slot(
            id: "\(entry.id)#\(index)",
            entryId: entry.id,
            title: entry.title,
            activityType: entry.activityType,
            lane: entry.lane,
            plannedAt: at,
            order: entry.order
        )
    }
}
```

- [ ] **Step 4: 통과를 확인한다**

Step 2 와 같은 명령. 기대: `Executed 9 tests, with 0 failures`.

- [ ] **Step 5: 커밋**

```bash
cd /Users/roque/BabyCare
git add BabyCare/Models/DayPlanExpander.swift BabyCareTests/BabyCareTests+DayPlan.swift
git commit -m "feat(dayplan): 시간표를 하루의 칸으로 펼치는 순수 함수"
```

---

## Task 3: Firestore Narrow Protocol 5단계

**Files:**
- Modify: `BabyCare/Utils/Constants.swift` (`FirestoreCollections` 에 한 줄)
- Create: `BabyCare/Services/FirestoreService+DayPlan.swift`
- Create: `BabyCareTests/MockDayPlanFirestore.swift`
- Test: `BabyCareTests/BabyCareTests+DayPlan.swift` (append)

**Interfaces:**
- Consumes: `DayPlan` (Task 1)
- Produces: `FirestoreCollections.dayPlans`, `DayPlanFirestoreProviding` (`fetchDayPlans(userId:)`, `saveDayPlan(_:userId:)`, `deleteDayPlan(_:userId:)`), `MockDayPlanFirestore`

- [ ] **Step 1: Mock 과 계약 테스트를 쓴다**

`BabyCareTests/MockDayPlanFirestore.swift`:

```swift
import Foundation
@testable import BabyCare

final class MockDayPlanFirestore: DayPlanFirestoreProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: [DayPlan]] = [:]

    var fetchCount = 0
    var saveCount = 0
    var deleteCount = 0
    var capturedUserIds: [String] = []
    var errorToThrow: Error?

    func seed(_ plans: [DayPlan], userId: String) {
        lock.lock(); defer { lock.unlock() }
        store[userId] = plans
    }

    func fetchDayPlans(userId: String) async throws -> [DayPlan] {
        lock.lock(); defer { lock.unlock() }
        fetchCount += 1
        capturedUserIds.append(userId)
        if let e = errorToThrow { throw e }
        return store[userId] ?? []
    }

    func saveDayPlan(_ plan: DayPlan, userId: String) async throws {
        lock.lock(); defer { lock.unlock() }
        saveCount += 1
        capturedUserIds.append(userId)
        if let e = errorToThrow { throw e }
        var list = store[userId] ?? []
        if let i = list.firstIndex(where: { $0.id == plan.id }) { list[i] = plan } else { list.append(plan) }
        store[userId] = list
    }

    func deleteDayPlan(_ planId: String, userId: String) async throws {
        lock.lock(); defer { lock.unlock() }
        deleteCount += 1
        capturedUserIds.append(userId)
        if let e = errorToThrow { throw e }
        store[userId] = (store[userId] ?? []).filter { $0.id != planId }
    }
}
```

`BabyCareTests+DayPlan.swift` 끝에 추가:

```swift
final class DayPlanStoreTests: XCTestCase {

    func testCollectionConstantIsStable() {
        XCTAssertEqual(FirestoreCollections.dayPlans, "dayPlans")
    }

    func testMockRoundTrip() async throws {
        let mock = MockDayPlanFirestore()
        let plan = DayPlan(id: "p1", name: "표")
        try await mock.saveDayPlan(plan, userId: "u1")
        let back = try await mock.fetchDayPlans(userId: "u1")
        XCTAssertEqual(back, [plan])
        try await mock.deleteDayPlan("p1", userId: "u1")
        let empty = try await mock.fetchDayPlans(userId: "u1")
        XCTAssertTrue(empty.isEmpty)
        XCTAssertEqual(mock.saveCount, 1)
        XCTAssertEqual(mock.deleteCount, 1)
    }

    func testMockIsolatesUsers() async throws {
        let mock = MockDayPlanFirestore()
        try await mock.saveDayPlan(DayPlan(id: "p1", name: "내 것"), userId: "u1")
        let other = try await mock.fetchDayPlans(userId: "u2")
        XCTAssertTrue(other.isEmpty)
    }
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests/DayPlanStoreTests 2>&1 | grep -E "error:|Executed"
```

기대: `cannot find type 'DayPlanFirestoreProviding'`.

- [ ] **Step 3: 상수 · 프로토콜 · 구현을 만든다**

`BabyCare/Utils/Constants.swift` 의 `FirestoreCollections` 안, `routines` 줄 아래에 추가:

```swift
    static let dayPlans = "dayPlans"
```

`BabyCare/Services/FirestoreService+DayPlan.swift`:

```swift
import Foundation
import FirebaseFirestore

/// 시간표 저장소 — VM 이 의존하는 좁은 면.
protocol DayPlanFirestoreProviding: Sendable {
    func fetchDayPlans(userId: String) async throws -> [DayPlan]
    func saveDayPlan(_ plan: DayPlan, userId: String) async throws
    func deleteDayPlan(_ planId: String, userId: String) async throws
}

extension FirestoreService {

    private func dayPlanCollection(_ userId: String) -> CollectionReference {
        db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.dayPlans)
    }

    func fetchDayPlans(userId: String) async throws -> [DayPlan] {
        let snapshot = try await dayPlanCollection(userId)
            .order(by: "createdAt", descending: false)
            .getDocuments()
        return decodeDocuments(snapshot.documents, as: DayPlan.self)
    }

    func saveDayPlan(_ plan: DayPlan, userId: String) async throws {
        try dayPlanCollection(userId).document(plan.id).setData(from: plan)
    }

    func deleteDayPlan(_ planId: String, userId: String) async throws {
        try await dayPlanCollection(userId).document(planId).delete()
    }
}

extension FirestoreService: DayPlanFirestoreProviding {}
```

> 🔑 실측 확인됨(2026-09-02): `FirestoreCollections.users == "users"` 이고, 경로 모양
> `users/{uid}/<컬렉션>` 은 `FirestoreService+Routine.swift:7-22` 와 동일하다.
> 디코딩은 그 파일이 쓰는 **`decodeDocuments(_:as:)` 헬퍼**를 그대로 쓴다(직접 `try?` 금지 — 집 패턴).

- [ ] **Step 4: 통과와 게이트를 확인한다**

```bash
cd /Users/roque/BabyCare
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests/DayPlanStoreTests 2>&1 | grep -E "error:|Executed"
bash scripts/arch_test.sh
```

기대: `Executed 3 tests, with 0 failures` · arch R1=R2=R3=R4=0.

- [ ] **Step 5: Firestore 규칙을 확인한다**

`firestore.rules` 에서 `users/{userId}/{document=**}` 와일드카드가 새 하위 컬렉션을 덮는지 눈으로 본다.
덮으면 규칙 변경 없음(이 경우가 대부분). **안 덮으면 규칙을 추가하고 PO 승인 후 배포한다** —
규칙 배포는 별도 게이트다.

- [ ] **Step 6: 커밋**

```bash
cd /Users/roque/BabyCare
git add BabyCare/Utils/Constants.swift BabyCare/Services/FirestoreService+DayPlan.swift \
        BabyCareTests/MockDayPlanFirestore.swift BabyCareTests/BabyCareTests+DayPlan.swift
git commit -m "feat(dayplan): dayPlans 컬렉션 — narrow protocol 5단계"
```

---

## Task 4: `DayPlanViewModel` — owner-path 로 읽고 쓴다

**Files:**
- Create: `BabyCare/ViewModels/DayPlanViewModel.swift`
- Test: `BabyCareTests/BabyCareTests+DayPlan.swift` (append)

**Interfaces:**
- Consumes: `DayPlan` (T1), `DayPlanFirestoreProviding`/`MockDayPlanFirestore` (T3)
- Produces: `DayPlanViewModel(provider:)`, `.plans`, `.load(userId:)`, `.save(_:userId:)`, `.delete(_:userId:)`, `.errorMessage`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`BabyCareTests+DayPlan.swift` 끝에 추가:

```swift
@MainActor
final class DayPlanViewModelTests: XCTestCase {

    func testLoadPopulatesPlans() async {
        let mock = MockDayPlanFirestore()
        mock.seed([DayPlan(id: "p1", name: "표")], userId: "owner")
        let vm = DayPlanViewModel(provider: mock)
        await vm.load(userId: "owner")
        XCTAssertEqual(vm.plans.map(\.id), ["p1"])
        XCTAssertNil(vm.errorMessage)
    }

    func testSaveWritesToOwnerPath() async {
        let mock = MockDayPlanFirestore()
        let vm = DayPlanViewModel(provider: mock)
        await vm.save(DayPlan(id: "p1", name: "표"), userId: "owner")
        XCTAssertEqual(mock.saveCount, 1)
        XCTAssertEqual(mock.capturedUserIds, ["owner"])
    }

    // 실패를 삼키지 않는다 — 조용한 실패가 이 프로젝트의 반복 결함이다
    func testSaveSurfacesError() async {
        let mock = MockDayPlanFirestore()
        mock.errorToThrow = NSError(domain: "test", code: 1)
        let vm = DayPlanViewModel(provider: mock)
        await vm.save(DayPlan(id: "p1", name: "표"), userId: "owner")
        XCTAssertNotNil(vm.errorMessage)
    }

    // 되돌리는 길도 재야 한다
    func testDeleteRemovesFromList() async {
        let mock = MockDayPlanFirestore()
        mock.seed([DayPlan(id: "p1", name: "표")], userId: "owner")
        let vm = DayPlanViewModel(provider: mock)
        await vm.load(userId: "owner")
        await vm.delete(DayPlan(id: "p1", name: "표"), userId: "owner")
        XCTAssertTrue(vm.plans.isEmpty)
        XCTAssertEqual(mock.deleteCount, 1)
    }
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests/DayPlanViewModelTests 2>&1 | grep -E "error:|Executed"
```

기대: `cannot find 'DayPlanViewModel' in scope`.

- [ ] **Step 3: VM 을 만든다**

`BabyCare/ViewModels/DayPlanViewModel.swift`:

```swift
import Foundation
import Observation

@MainActor
@Observable
final class DayPlanViewModel {

    private(set) var plans: [DayPlan] = []
    private(set) var isLoading = false
    var errorMessage: String?

    private let provider: DayPlanFirestoreProviding

    init(provider: DayPlanFirestoreProviding = FirestoreService.shared) {
        self.provider = provider
    }

    func load(userId: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            plans = try await provider.fetchDayPlans(userId: userId)
            errorMessage = nil
        } catch {
            errorMessage = "시간표를 불러오지 못했어요."
            logSilent("시간표 로드 실패", error: error, logger: AppLogger.firestore)
        }
    }

    func save(_ plan: DayPlan, userId: String) async {
        let previous = plans
        if let i = plans.firstIndex(where: { $0.id == plan.id }) { plans[i] = plan } else { plans.append(plan) }
        do {
            try await provider.saveDayPlan(plan, userId: userId)
            errorMessage = nil
        } catch {
            plans = previous
            errorMessage = "시간표를 저장하지 못했어요."
            logSilent("시간표 저장 실패", error: error, logger: AppLogger.firestore)
        }
    }

    func delete(_ plan: DayPlan, userId: String) async {
        let previous = plans
        plans.removeAll { $0.id == plan.id }
        do {
            try await provider.deleteDayPlan(plan.id, userId: userId)
            errorMessage = nil
        } catch {
            plans = previous
            errorMessage = "시간표를 지우지 못했어요."
            logSilent("시간표 삭제 실패", error: error, logger: AppLogger.firestore)
        }
    }
}
```

> ⚠️ `@Observable` · `logSilent` · `AppLogger` 의 실제 사용법은 이웃 VM
> (`BabyCare/ViewModels/RoutineViewModel.swift`)을 열어 그대로 따를 것.
> **`userId` 는 호출부가 owner-path(`dataUserId`)로 변환해 넘긴다** — VM 이 스스로 정하지 않는다.

- [ ] **Step 4: 통과를 확인한다**

Step 2 와 같은 명령. 기대: `Executed 4 tests, with 0 failures`.

- [ ] **Step 5: 커밋**

```bash
cd /Users/roque/BabyCare
git add BabyCare/ViewModels/DayPlanViewModel.swift BabyCareTests/BabyCareTests+DayPlan.swift
git commit -m "feat(dayplan): 시간표 VM — 저장 실패를 삼키지 않는다"
```

---

## Task 5: 「언제」 고르는 시트

시안 2페이지 오른쪽 artboard 가 정본이다.

**Files:**
- Create: `BabyCare/Views/DayPlan/PlanEntrySheet.swift`
- Test: `BabyCareTests/BabyCareTests+DayPlan.swift` (append)

**Interfaces:**
- Consumes: `DayPlan.Entry`, `PlanSchedule` (T1)
- Produces: `PlanEntryDraft` (순수 값 + `.isValid` + `.build()`), `PlanEntrySheet(draft:onSave:)`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

화면이 아니라 **화면이 쓰는 순수 값**을 잠근다.

```swift
final class PlanEntryDraftTests: XCTestCase {

    func testFixedTimesRequiresAtLeastOneTime() {
        var d = PlanEntryDraft(title: "목욕", kind: .fixedTimes)
        XCTAssertFalse(d.isValid)
        d.minutesOfDay = [19 * 60 + 30]
        XCTAssertTrue(d.isValid)
    }

    func testAfterFirstRequiresAnchorAndPositiveNumbers() {
        var d = PlanEntryDraft(title: "분유", kind: .afterFirst)
        XCTAssertFalse(d.isValid)
        d.anchorType = "feeding_bottle"
        d.everyMinutes = 180
        d.count = 6
        XCTAssertTrue(d.isValid)
        d.count = 0
        XCTAssertFalse(d.isValid)
    }

    func testAfterEntryRequiresPrecedingEntry() {
        var d = PlanEntryDraft(title: "잠자리", kind: .afterEntry)
        XCTAssertFalse(d.isValid)
        d.afterEntryId = "bath"
        d.offsetMinutes = 30
        XCTAssertTrue(d.isValid)
    }

    func testEmptyTitleIsInvalidForEveryKind() {
        var d = PlanEntryDraft(title: "  ", kind: .fixedTimes)
        d.minutesOfDay = [720]
        XCTAssertFalse(d.isValid)
    }

    func testBuildProducesMatchingSchedule() throws {
        var d = PlanEntryDraft(title: "분유", kind: .afterFirst)
        d.anchorType = "feeding_bottle"
        d.everyMinutes = 180
        d.count = 6
        d.lane = .baby
        let entry = try XCTUnwrap(d.build(order: 3))
        XCTAssertEqual(entry.schedule.kind, .afterFirst)
        XCTAssertEqual(entry.schedule.everyMinutes, 180)
        XCTAssertEqual(entry.order, 3)
        XCTAssertEqual(entry.title, "분유")
    }

    func testBuildReturnsNilWhenInvalid() {
        let d = PlanEntryDraft(title: "", kind: .fixedTimes)
        XCTAssertNil(d.build(order: 0))
    }
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests/PlanEntryDraftTests 2>&1 | grep -E "error:|Executed"
```

기대: `cannot find 'PlanEntryDraft' in scope`.

- [ ] **Step 3: 순수 값을 만든다**

`BabyCare/Views/DayPlan/PlanEntrySheet.swift` 상단:

```swift
import SwiftUI

/// 시트가 편집하는 값. 화면 상태가 아니라 **순수 값**이라 테스트로 잠근다.
struct PlanEntryDraft: Hashable {
    var title: String
    var kind: PlanSchedule.Kind
    var lane: DayPlan.Lane = .baby
    var activityType: String?

    var minutesOfDay: [Int] = []
    var anchorType: String?
    var everyMinutes: Int?
    var count: Int?
    var afterEntryId: String?
    var offsetMinutes: Int?

    var isValid: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch kind {
        case .fixedTimes:
            return !minutesOfDay.isEmpty && minutesOfDay.allSatisfy { (0..<1440).contains($0) }
        case .afterFirst:
            guard let a = anchorType, !a.isEmpty else { return false }
            return (everyMinutes ?? 0) > 0 && (count ?? 0) > 0
        case .afterEntry:
            guard let e = afterEntryId, !e.isEmpty else { return false }
            return (offsetMinutes ?? -1) >= 0
        }
    }

    func build(order: Int) -> DayPlan.Entry? {
        guard isValid else { return nil }
        let schedule: PlanSchedule
        switch kind {
        case .fixedTimes:
            schedule = .fixedTimes(minutesOfDay: minutesOfDay)
        case .afterFirst:
            schedule = .afterFirst(anchorType: anchorType ?? "", everyMinutes: everyMinutes ?? 0, count: count ?? 0)
        case .afterEntry:
            schedule = .afterEntry(entryId: afterEntryId ?? "", offsetMinutes: offsetMinutes ?? 0)
        }
        return DayPlan.Entry(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            activityType: activityType,
            lane: lane,
            schedule: schedule,
            order: order
        )
    }
}
```

- [ ] **Step 4: 통과를 확인한다**

Step 2 와 같은 명령. 기대: `Executed 6 tests, with 0 failures`.

- [ ] **Step 5: 시트 화면을 만든다**

같은 파일에 `PlanEntrySheet: View` 를 붙인다. 골격은 이렇고, 나머지는 시안(2페이지 오른쪽)을 따른다:

```swift
struct PlanEntrySheet: View {
    @State private var draft: PlanEntryDraft
    /// 「앞 일 뒤에」에서 고를 수 있는 앞 항목들(자기 자신 제외).
    let precedingEntries: [DayPlan.Entry]
    let onSave: (PlanEntryDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    init(draft: PlanEntryDraft, precedingEntries: [DayPlan.Entry], onSave: @escaping (PlanEntryDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.precedingEntries = precedingEntries
        self.onSave = onSave
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                header
                ForEach([PlanSchedule.Kind.afterFirst, .fixedTimes, .afterEntry], id: \.self) { kind in
                    kindCard(kind)          // 고른 것만 테두리 강조 · 안쪽에 그 방식의 입력
                }
                footnote                    // 「밑그림입니다」 안내
            }
            .padding(DS2.Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) { saveBar }   // 하단 고정(전 폼 관례)
    }

    private var saveBar: some View {
        Button {
            onSave(draft)
            dismiss()
        } label: {
            Text("시간표에 넣기").frame(maxWidth: .infinity)
        }
        .disabled(!draft.isValid)
        .buttonStyle(.borderedProminent)
        .padding(DS2.Spacing.lg)
    }

    /// 「첫 기록부터 주기」 미리보기 — 문구를 손으로 적지 말고 순수 함수에서 뽑는다.
    private func previewTimes(anchorHour: Int) -> [Date] {
        guard let entry = draft.build(order: 0) else { return [] }
        var cal = Calendar.current
        let day = cal.startOfDay(for: Date())
        let anchor = cal.date(byAdding: .minute, value: anchorHour * 60 + 20, to: day) ?? day
        let plan = DayPlan(id: "preview", name: "preview", entries: [entry])
        let anchors = DayAnchors(firstRecordByType: [draft.anchorType ?? "": anchor])
        return DayPlanExpander.slots(plan: plan, day: day, anchors: anchors, calendar: cal)
            .compactMap(\.plannedAt)
    }
}
```

나머지 규칙:

- 세 방식이 **카드 셋**으로 세로로 놓이고, 고른 것만 테두리가 강조된다
- 「첫 기록부터 주기」 카드는 **미리보기**를 보여준다 — 「첫 수유가 06:20이면 → 09:20 · 12:20 …」
  (`DayPlanExpander.slots` 를 예시 정박점으로 호출해 만든다. 문구를 손으로 적지 말 것)
- 맨 아래 안내: **「시간표는 밑그림입니다. 그 시각에 꼭 해야 하는 게 아니고, 늦었다고 알리지 않습니다.」**
- ⛔ 「지연」·「늦음」·「해야 합니다」류 낱말 금지
- 색은 `DS2.Color.*`, 간격은 `DS2.Spacing.*`, 반경은 `DS2.Radius.*` 만
- 저장 버튼은 `draft.isValid` 일 때만 활성

- [ ] **Step 6: 눈으로 본다**

```bash
cd /Users/roque/BabyCare
make build
```

빌드 후 시뮬레이터에 설치해 시트를 열어 본다.
🩸 **설치용 `.app` 은 방금 `make build` 가 쓴 DerivedData(`~/Library/Developer/Xcode/DerivedData`)에서 집을 것.**
repo 안 `build/DerivedData` 는 화석이다(`.claude/rules/build-gotchas.md`).

- [ ] **Step 7: 커밋**

```bash
cd /Users/roque/BabyCare
git add BabyCare/Views/DayPlan/PlanEntrySheet.swift BabyCareTests/BabyCareTests+DayPlan.swift
git commit -m "feat(dayplan): 「언제」 고르는 시트 — 세 방식"
```

---

## Task 6: 시간표 목록 화면 + 설정 진입점

**Files:**
- Create: `BabyCare/Views/DayPlan/DayPlanListView.swift`
- Modify: `BabyCare/Views/Settings/SettingsView.swift`
- Test: `BabyCareTests/BabyCareTests+DayPlan.swift` (append)

**Interfaces:**
- Consumes: `DayPlanViewModel` (T4), `PlanEntryDraft`/`PlanEntrySheet` (T5), `DayPlanExpander` (T2)
- Produces: `DayPlanListView()`, `PlanEntryGrouping.sections(for:)`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

화면의 **묶는 규칙**을 순수 함수로 잠근다(시안 2페이지 왼쪽 = 방식별 묶음).

```swift
final class PlanEntryGroupingTests: XCTestCase {

    private func entry(_ id: String, _ kind: PlanSchedule.Kind, order: Int) -> DayPlan.Entry {
        let s: PlanSchedule
        switch kind {
        case .fixedTimes: s = .fixedTimes(minutesOfDay: [720])
        case .afterFirst: s = .afterFirst(anchorType: "feeding_bottle", everyMinutes: 180, count: 6)
        case .afterEntry: s = .afterEntry(entryId: "x", offsetMinutes: 30)
        }
        return DayPlan.Entry(id: id, title: id, schedule: s, order: order)
    }

    func testGroupsByKindInFixedSectionOrder() {
        let plan = DayPlan(id: "p", name: "표", entries: [
            entry("bath", .fixedTimes, order: 2),
            entry("bed", .afterEntry, order: 3),
            entry("milk", .afterFirst, order: 1)
        ])
        let sections = PlanEntryGrouping.sections(for: plan)
        XCTAssertEqual(sections.map(\.kind), [.afterFirst, .fixedTimes, .afterEntry])
        XCTAssertEqual(sections[0].entries.map(\.id), ["milk"])
    }

    func testEmptyKindsAreOmitted() {
        let plan = DayPlan(id: "p", name: "표", entries: [entry("bath", .fixedTimes, order: 0)])
        let sections = PlanEntryGrouping.sections(for: plan)
        XCTAssertEqual(sections.map(\.kind), [.fixedTimes])
    }

    func testEntriesWithinSectionSortByOrder() {
        let plan = DayPlan(id: "p", name: "표", entries: [
            entry("b", .fixedTimes, order: 5),
            entry("a", .fixedTimes, order: 1)
        ])
        XCTAssertEqual(PlanEntryGrouping.sections(for: plan)[0].entries.map(\.id), ["a", "b"])
    }
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests/PlanEntryGroupingTests 2>&1 | grep -E "error:|Executed"
```

기대: `cannot find 'PlanEntryGrouping' in scope`.

- [ ] **Step 3: 묶는 규칙을 만든다**

`BabyCare/Views/DayPlan/DayPlanListView.swift` 상단:

```swift
import SwiftUI

enum PlanEntryGrouping {

    struct Section: Identifiable, Hashable {
        var id: PlanSchedule.Kind { kind }
        let kind: PlanSchedule.Kind
        let entries: [DayPlan.Entry]
    }

    /// 시안 순서 — 첫 기록부터 주기 · 고정 시각 · 앞 일 뒤에.
    private static let order: [PlanSchedule.Kind] = [.afterFirst, .fixedTimes, .afterEntry]

    static func sections(for plan: DayPlan) -> [Section] {
        order.compactMap { kind in
            let matched = plan.entries
                .filter { $0.schedule.kind == kind }
                .sorted { $0.order < $1.order }
            return matched.isEmpty ? nil : Section(kind: kind, entries: matched)
        }
    }
}
```

- [ ] **Step 4: 통과를 확인한다**

Step 2 와 같은 명령. 기대: `Executed 3 tests, with 0 failures`.

- [ ] **Step 5: 목록 화면과 진입점을 만든다**

같은 파일에 `DayPlanListView: View`. 골격은 이렇고, 나머지는 시안(2페이지 왼쪽)을 따른다:

```swift
struct DayPlanListView: View {
    @State private var vm = DayPlanViewModel()
    @Environment(AuthViewModel.self) private var authVM
    @State private var editing: PlanEntryDraft?

    /// ⛔ 여기서 NavigationStack 을 새로 열지 않는다 — 설정에서 push 된다.
    var body: some View {
        List {
            ForEach(vm.plans) { plan in
                ForEach(PlanEntryGrouping.sections(for: plan)) { section in
                    Section(sectionTitle(section.kind)) {
                        ForEach(section.entries) { entry in
                            PlanEntryRow(entry: entry)
                        }
                        .onDelete { offsets in
                            Task { await deleteEntries(offsets, in: section, of: plan) }
                        }
                    }
                }
            }
            addButtonRow
        }
        .navigationTitle("우리 하루")
        .task { await vm.load(userId: ownerUserId) }
        .sheet(item: $editing) { draft in
            PlanEntrySheet(draft: draft, precedingEntries: allEntries) { saved in
                Task { await appendEntry(saved) }
            }
        }
        .alert("문제가 생겼어요", isPresented: .constant(vm.errorMessage != nil)) {
            Button("확인") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    private func sectionTitle(_ kind: PlanSchedule.Kind) -> String {
        switch kind {
        case .afterFirst: "첫 기록부터 주기"
        case .fixedTimes: "고정 시각"
        case .afterEntry: "앞 일 뒤에 이어서"
        }
    }
}
```

> ⚠️ `ownerUserId` 는 이웃 화면이 쓰는 owner-path 변환(`dataUserId`)을 **그대로** 따른다.
> `authVM.currentUserId` 를 직접 쓰지 말 것 — 공유 아기에서 격리가 깨진다(#49 결함군).

나머지 규칙:

- 제목 「우리 하루」 · 부제 「서준이와 나의 하루를 짜 둡니다」
- 방식별 묶음. 묶음 머리말 색은 `afterFirst`=`DS2.Color.feeding`, `fixedTimes`=`DS2.Color.bath`,
  `afterEntry`=`DS2.Color.pumping` 계열의 **강조색 자산**(hex 하드코딩 금지)
- 각 줄: 아이콘 타일 + 제목 + 「첫 수유부터 3시간마다 · 하루 6번」 요약
- 맨 아래 점선 「시간표에 추가」 → `PlanEntrySheet`
- 스와이프 삭제 → `vm.delete(...)` · **되돌리는 길을 직접 눌러 볼 것**
- ⛔ 연속 일수·완료율 분수·배지 없음
- `NavigationStack` 중첩 금지 — 설정에서 `NavigationLink` 로 push 되므로 여기서 스택을 새로 열지 않는다

`SettingsView.swift` 에 진입점 한 줄(기존 row 패턴 그대로):

```swift
NavigationLink {
    DayPlanListView()
} label: {
    Label("우리 하루", systemImage: "calendar.day.timeline.left")
}
```

- [ ] **Step 6: 눈으로 본다**

```bash
cd /Users/roque/BabyCare
make build
```

설정 → 「우리 하루」 → 추가 → 저장 → 목록에 뜨는지 → **스와이프 삭제까지** 확인.
🩸 되돌리는 길(삭제·비우기)은 붙인 날부터 안 재지는 구역이다. 직접 눌러 볼 것.

- [ ] **Step 7: 전체 게이트**

```bash
cd /Users/roque/BabyCare
make verify
bash scripts/arch_test.sh
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests 2>&1 | grep -E "Executed|error:"
```

기대: `ALL CHECKS PASSED` · R1=R2=R3=R4=0 · 테스트 수가 **745 → 773**(신규 28 = 3+9+3+4+6+3) 로 **늘었는지 눈으로 확인**.
🩸 `make verify` 의 `make test` 는 `-quiet` 라 개수가 안 보인다. EXIT=0 만으로 초록을 말하지 말 것.

- [ ] **Step 8: 커밋**

```bash
cd /Users/roque/BabyCare
git add BabyCare/Views/DayPlan/DayPlanListView.swift BabyCare/Views/Settings/SettingsView.swift \
        BabyCareTests/BabyCareTests+DayPlan.swift
git commit -m "feat(dayplan): 시간표 목록 + 설정 진입점"
```

---

## 완료 기준

- [ ] `make verify` ALL CHECKS PASSED · arch R1–R4=0 · lint 0 err
- [ ] 테스트 **745 → 773** (신규 28 · 숫자를 눈으로 확인)
- [ ] 설정 → 「우리 하루」 에서 세 방식으로 항목을 넣고 · 목록에서 보고 · **지울 수 있다**
- [ ] 화면 어디에도 지연·재촉·연속 일수·완료율 분수가 **없다**
- [ ] 루틴(`Routine`·`RoutineView`)은 **한 줄도 안 바뀌었다**
- [ ] push·PR·머지는 **PO 승인 후**

## 범위 밖 (②③④단계)

「오늘 하루 시작하기」 · 기록↔칸 붙이기 · 아이 줄/내 줄 화면 · 잠금화면 Live Activity ·
다이나믹 아일랜드 · 8시간 이어붙이기 · 밤에 닫기
