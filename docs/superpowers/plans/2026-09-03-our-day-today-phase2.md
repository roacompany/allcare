# 우리 하루 ② — 오늘 하루 열기 · 칸 채우기 · 닫기 · 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 부모가 짜 둔 시간표(①단계)를 **오늘**로 펼쳐서, 「오늘 하루 시작하기」로 열고 · 기록이 들어올 때마다 칸이 채워지고 · 밤에 「오늘도 잘 지났어요」로 닫는다.

**Architecture:** 새 컬렉션 `dayRuns`(하루 한 문서, 문서 id = 로컬 날짜 `yyyy-MM-dd`)가 「열림/닫힘」만 갖는다. **칸의 상태는 저장하지 않는다** — 시간표(`dayPlans`) + 그날 기록(`activities`)에서 **매번 순수 함수로 다시 계산**한다. 저장하면 기록을 고칠 때마다 갈라진다. 화면은 대시보드 카드 하나(`TodayBandCard`)로 들어간다.

**Tech Stack:** Swift 6 / iOS 17+ · SwiftUI · Firestore(supabase 아님) · `@MainActor @Observable` MVVM · XCTest

**Spec:** `docs/superpowers/specs/2026-09-02-our-day-timetable-design.md`
**앞 단계:** `docs/superpowers/plans/2026-09-02-our-day-timetable-phase1.md` (머지 완료 · main `a936ffa`)
**시안(정본):** https://claude.ai/code/artifact/71582316-c272-4718-8cac-c30ee888658a

---

## Global Constraints

①단계와 **동일**. 아래는 전문(全文) — 각 Task 의 요구사항에 암묵적으로 포함된다.

- 모델은 `Identifiable, Codable, Hashable` 채택 · **신규 필드는 전부 optional**
- Firestore 컬렉션명은 **`FirestoreCollections.*` 상수만** — 하드코딩 금지
- 신규 컬렉션 = **Narrow Protocol 5단계** 필수 · `arch_test.sh` **R1=R2=R3=R4=0**
- `Firestore.firestore()` 직접 호출은 `Services/FirestoreService*.swift` 밖에서 금지
- 프로토콜 시그니처에 **`[String: Any]` 금지**(Swift 6 Sendable)
- `print()` 금지 = `AppLogger` · non-fatal 은 `logSilent(_:error:logger:)`
- View → Service 직접 호출 금지(R1) · `NavigationStack` 중첩 금지
- 저장 userId 는 **owner-path**(`dataUserId`) · `@AppStorage` 에 사용자 데이터 금지
  - 🔴 `dataUserId` 는 `currentUserId` 가 nil 이어도 공유 아기의 소유자 uid 를 돌려준다 → **`currentUserId` 를 먼저 확인**
- Firestore 에 저장되는 **rawValue 는 영구 계약** — 바꾸면 기존 문서가 깨진다
- 색은 **DS2 토큰만**(`DS2.Color.*` · `DS2.Spacing.*` · `DS2.Radius.*`) — hex 하드코딩 금지
- 100% SF Symbols
- 용어: **'짜기' 금지** — 유축(생산) / 모유(병)(섭취)
- **의학 단정 금지** — 「이제 먹일 때예요」류 문구 금지. 시각은 **부모가 정한 것**으로만 표현
- ⛔ **지연·재촉·경고 문구 금지** · ⛔ **연속 일수·완료율 분수·배지 금지**(설계 §5)
- ⛔ `FeedingPredictionService` 사용 금지 — 예측이 아니라 부모가 짠 것(설계 결정 4)
- ⛔ `Routine`·`RoutineView` 는 **한 줄도 건드리지 않는다**
- 테스트는 **`BabyCareTests/BabyCareTests+DayPlan.swift`** 에 append(①단계 선례 · 클래스 신규 추가)
- 임신 v3 는 flag-off 휴면 — 건드리지 않는다
- push · PR · 머지 · 업로드 · 제출 = **PO 승인 시만**

### ⚠️ 이 단계의 함정 — 하루 귀속 (`.claude/rules/day-attribution.md`)

🔴 **`activityVM.todayActivities` 는 「오늘 시작한 것」 + 「오늘 끝난 것」을 합쳐 갖고 있다.**
어젯밤 22시에 시작해 오늘 아침 7시에 끝난 잠이 **오늘 목록에도** 들어 있다.

→ 「오늘 그 종류의 **첫 기록**」(`afterFirst` 정박점)을 그대로 뽑으면 **어젯밤 잠이 오늘의 정박점이 된다.**
→ **반드시 `ActivityDayAttribution.startedOn(_:day:)` 로 거른 뒤** 쓴다. 칸 채우기도 같다.

---

## 이번 단계에서 하지 않는 것 (범위)

| | 왜 미루나 |
|---|---|
| **내 줄(부모 줄)** — lane 고르기 · 「아무 때나」 방식 · 수동 완료 · 「셋 중 둘」 요약 | ②-B 로 분리. 새 `PlanSchedule.Kind`(「아무 때나」)와 시트 변경이 따라와서 이 단계와 독립적으로 리뷰될 수 있다. 아이 줄만으로도 「오늘」은 **혼자 동작한다** |
| 잠금화면 Live Activity · 다이나믹 아일랜드 · 8시간 이어붙이기 | ③단계 |
| 아침 알림(「오늘 하루 시작할까요?」) | ③단계 (`NotificationService` 배선) |

⚠️ **PO 결정 대기 — ②-B 착수 전에 물을 것:** 시안 밤 화면의 **「셋 중 둘을 했어요」**는
설계 §5 의 **「못 한 것은 세지 않는다 · 완료율 분수 금지」**와 충돌한다. 둘 중 무엇이 이기나.
(이 단계 범위 밖이라 지금은 막지 않는다 — 아이 줄 요약은 「일곱 번 먹고 세 번 잤어요」로 **한 것만** 말한다.)

---

## File Structure

| 파일 | 책임 |
|---|---|
| `BabyCare/Models/DayRun.swift` (신규) | 「오늘을 열었나/닫았나」만 갖는 저장 모델. 칸 상태는 **안 갖는다** |
| `BabyCare/Models/DayAnchorsBuilder.swift` (신규) | **순수 함수** — 그날 기록 → `DayAnchors`(`firstRecordByType`) |
| `BabyCare/Models/DaySlotFiller.swift` (신규) | **순수 함수** — 칸 + 그날 기록 → 채워진 칸 + 끼어든 칸 |
| `BabyCare/Models/DaySummary.swift` (신규) | **순수 함수** — 그날 기록 → 밤 요약 문장 조각 |
| `BabyCare/Utils/Constants.swift` (수정) | `FirestoreCollections.dayRuns` 추가 |
| `BabyCare/Services/FirestoreService+DayRun.swift` (신규) | `DayRunFirestoreProviding` + 구현 |
| `BabyCareTests/MockDayRunFirestore.swift` (신규) | in-memory + 호출 카운터 + 에러 주입 |
| `BabyCare/ViewModels/TodayViewModel.swift` (신규) | 열기·닫기 · 시간표+기록 → 오늘의 칸 |
| `BabyCare/Views/DayPlan/TodayBandCard.swift` (신규) | 대시보드 카드 — 하루 띠 · 시작 · 닫기 · 밤 요약 |
| `BabyCare/Views/Dashboard/DashboardView.swift` (수정) | 카드 한 줄 배치 |
| `BabyCareTests/BabyCareTests+DayPlan.swift` (수정) | 전 태스크 테스트 append |

**의존 방향:** `DayAnchorsBuilder` → `DayPlanExpander`(①단계) → `DaySlotFiller` → `TodayViewModel` → `TodayBandCard`.
순수 함수 셋은 서로를 모른다 — `TodayViewModel` 이 이어 붙인다.

---

## Task 1: 「오늘을 열었나」 저장 모델 `DayRun`

**Files:**
- Create: `BabyCare/Models/DayRun.swift`
- Test: `BabyCareTests/BabyCareTests+DayPlan.swift` (append)

**Interfaces:**
- Produces: `DayRun(id:planId:startedAt:closedAt:)` · `DayRun.documentId(for:calendar:) -> String` · `var isOpen: Bool`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

파일 **끝**에 새 클래스로 append 한다(①단계 선례 — 기존 클래스 안에 넣지 않는다).

```swift
// MARK: - Task 1 · 오늘을 열었나

final class DayRunTests: XCTestCase {

    /// 문서 id = 로컬 날짜. 하루에 한 문서만 생기고, 같은 날 다시 눌러도 덮어쓴다(멱등).
    func testDocumentIdIsLocalCalendarDate() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let day = cal.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 23, minute: 50))!
        XCTAssertEqual(DayRun.documentId(for: day, calendar: cal), "2026-09-03")
    }

    /// 🩸 자정 직전/직후가 다른 날이어야 한다 — 같은 id 면 어제 하루를 덮어쓴다.
    func testDocumentIdChangesAcrossMidnight() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Seoul")!
        let before = cal.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: 23, minute: 59))!
        let after = cal.date(from: DateComponents(year: 2026, month: 9, day: 4, hour: 0, minute: 1))!
        XCTAssertNotEqual(DayRun.documentId(for: before, calendar: cal),
                          DayRun.documentId(for: after, calendar: cal))
    }

    func testOpenUntilClosed() {
        var run = DayRun(id: "2026-09-03", planId: "p", startedAt: Date())
        XCTAssertTrue(run.isOpen)
        run.closedAt = Date()
        XCTAssertFalse(run.isOpen)
    }

    func testRoundTripsThroughJSON() throws {
        let run = DayRun(id: "2026-09-03", planId: "p", startedAt: Date(timeIntervalSince1970: 1_000_000))
        let data = try JSONEncoder().encode(run)
        let back = try JSONDecoder().decode(DayRun.self, from: data)
        XCTAssertEqual(back, run)
    }

    /// 신규 필드는 전부 optional — 옛 문서(planId·closedAt 없음)가 들어와도 살아야 한다.
    func testDecodesDocumentWithoutOptionalFields() throws {
        let json = #"{"id":"2026-09-03","startedAt":0}"#.data(using: .utf8)!
        let back = try JSONDecoder().decode(DayRun.self, from: json)
        XCTAssertEqual(back.id, "2026-09-03")
        XCTAssertNil(back.planId)
        XCTAssertTrue(back.isOpen)
    }
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare
make generate
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests/DayRunTests 2>&1 | grep -E "error:|Executed"
```

기대: `cannot find 'DayRun' in scope`.

🩸 **새 테스트 클래스를 만든 뒤에는 반드시 `make generate` 를 먼저 돌린다** — 안 그러면
`Executed 0 tests` 인데 `TEST SUCCEEDED` 가 나온다(①단계에서 실제로 밟았다).
**실행 수가 0 이면 빨강으로 취급할 것.**

- [ ] **Step 3: 모델을 만든다**

`BabyCare/Models/DayRun.swift`:

```swift
import Foundation

/// 「오늘 하루」를 열었나 · 닫았나. **하루에 한 문서**(id = 로컬 날짜).
///
/// ⛔ 칸의 상태(무엇이 채워졌나)는 여기 저장하지 않는다 —
///    시간표 + 그날 기록에서 매번 다시 계산한다. 저장하면 기록을 고칠 때마다 갈라진다.
///
/// 왜 「시작」이 있나: 시작이 있으면 **안 한 날과 못 한 날이 갈린다.**
/// 시작 안 한 날은 실패가 아니다(설계 §2.2).
struct DayRun: Identifiable, Codable, Hashable {
    /// 로컬 날짜 `yyyy-MM-dd`. Firestore 문서 id 와 같다 — 같은 날 다시 열어도 덮어쓴다(멱등).
    var id: String
    /// 이 하루가 어느 시간표로 열렸나. nil = 시간표 없이 연 날(하위호환).
    var planId: String?
    var startedAt: Date
    /// nil = 아직 진행 중.
    var closedAt: Date?

    var isOpen: Bool { closedAt == nil }

    init(id: String, planId: String? = nil, startedAt: Date, closedAt: Date? = nil) {
        self.id = id
        self.planId = planId
        self.startedAt = startedAt
        self.closedAt = closedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        planId = try c.decodeIfPresent(String.self, forKey: .planId)
        startedAt = try c.decode(Date.self, forKey: .startedAt)
        closedAt = try c.decodeIfPresent(Date.self, forKey: .closedAt)
    }

    /// 로컬 달력 기준 날짜 문자열. **시간대를 타므로 달력을 받는다**(테스트가 고정할 수 있게).
    static func documentId(for day: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
```

- [ ] **Step 4: 통과를 확인한다**

Step 2 와 같은 명령. 기대: `Executed 5 tests, with 0 failures`.

- [ ] **Step 5: 커밋**

```bash
cd /Users/roque/BabyCare
git add BabyCare/Models/DayRun.swift BabyCareTests/BabyCareTests+DayPlan.swift
git commit -m "feat(dayplan): 오늘을 열었나 — DayRun 저장 모델"
```

---

## Task 2: 정박점을 뽑는 순수 함수 `DayAnchorsBuilder`

**Files:**
- Create: `BabyCare/Models/DayAnchorsBuilder.swift`
- Test: `BabyCareTests/BabyCareTests+DayPlan.swift` (append)

**Interfaces:**
- Consumes: `DayAnchors`(①단계 `DayPlanExpander.swift`) · `ActivityDayAttribution.startedOn(_:day:calendar:)`
- Produces: `DayAnchorsBuilder.anchors(from activities: [Activity], on day: Date, calendar: Calendar) -> DayAnchors`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```swift
// MARK: - Task 2 · 그날의 정박점

final class DayAnchorsBuilderTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func at(_ h: Int, _ m: Int = 0, day: Int = 3) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: day, hour: h, minute: m))!
    }

    private func activity(_ type: Activity.ActivityType, _ start: Date, end: Date? = nil) -> Activity {
        Activity(id: UUID().uuidString, babyId: "b", type: type,
                 startTime: start, endTime: end, createdAt: start)
    }

    func testFirstRecordPerTypeIsTheEarliestOfThatType() {
        let acts = [
            activity(.feedingBottle, at(9)),
            activity(.feedingBottle, at(6, 20)),
            activity(.diaperWet, at(7))
        ]
        let a = DayAnchorsBuilder.anchors(from: acts, on: at(12), calendar: cal)
        XCTAssertEqual(a.firstRecordByType["feeding_bottle"], at(6, 20))
        XCTAssertEqual(a.firstRecordByType["diaper_wet"], at(7))
    }

    /// 🔴 이 단계에서 제일 비싼 함정 —
    /// `todayActivities` 는 「오늘 끝난 것」도 갖고 있어서, **어젯밤 22시에 시작한 잠**이 섞여 있다.
    /// 그걸 오늘의 첫 기록으로 삼으면 하루 전체가 어제 시각에 정박한다.
    func testYesterdaysSleepThatEndedThisMorningIsNotTodaysAnchor() {
        let overnight = activity(.sleep, at(22, 0, day: 2), end: at(7, 0, day: 3))
        let todayNap = activity(.sleep, at(13))
        let a = DayAnchorsBuilder.anchors(from: [overnight, todayNap], on: at(12), calendar: cal)
        XCTAssertEqual(a.firstRecordByType["sleep"], at(13), "어젯밤 잠이 오늘의 정박점이 됐다")
    }

    func testUnknownTypeIsNeverAnAnchor() {
        // .unknown 은 read-only 센티넬 — 정박점으로 쓰면 알 수 없는 종류가 하루를 정한다.
        var a = activity(.feedingBottle, at(8))
        a.type = .unknown
        let out = DayAnchorsBuilder.anchors(from: [a], on: at(12), calendar: cal)
        XCTAssertTrue(out.firstRecordByType.isEmpty)
    }

    func testEmptyDayHasNoAnchors() {
        XCTAssertTrue(DayAnchorsBuilder.anchors(from: [], on: at(12), calendar: cal).firstRecordByType.isEmpty)
    }
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare
make generate
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests/DayAnchorsBuilderTests 2>&1 | grep -E "error:|Executed"
```

기대: `cannot find 'DayAnchorsBuilder' in scope`.

- [ ] **Step 3: 순수 함수를 만든다**

`BabyCare/Models/DayAnchorsBuilder.swift`:

```swift
import Foundation

/// 그날 기록 → `DayPlanExpander` 가 쓰는 정박점.
/// **순수 함수만** — `Date()` 도, 저장소도 만지지 않는다.
enum DayAnchorsBuilder {

    /// 🔴 `activities` 는 **하루 목록 그대로** 넘겨도 된다 — 여기서 `startedOn` 으로 거른다.
    ///    (`fetchActivities(date:)` 는 「그날 끝난 것」도 합쳐 주므로, 안 거르면
    ///     어젯밤 잠이 오늘의 첫 기록이 된다 — `.claude/rules/day-attribution.md`)
    static func anchors(
        from activities: [Activity],
        on day: Date,
        calendar: Calendar = .current
    ) -> DayAnchors {
        let started = ActivityDayAttribution.startedOn(activities, day: day, calendar: calendar)
        var first: [String: Date] = [:]
        for a in started where a.type != .unknown {
            let key = a.type.rawValue
            if let existing = first[key], existing <= a.startTime { continue }
            first[key] = a.startTime
        }
        // `completedByEntry`(앞 일 뒤에)는 ②-B 이후 — 지금은 비운다.
        // 비워 두면 `afterEntry` 칸은 「미정」으로 남는다(설계대로: 자리는 있고 시각만 없다).
        return DayAnchors(firstRecordByType: first)
    }
}
```

- [ ] **Step 4: 통과를 확인한다**

Step 2 와 같은 명령. 기대: `Executed 4 tests, with 0 failures`.

- [ ] **Step 5: 커밋**

```bash
cd /Users/roque/BabyCare
git add BabyCare/Models/DayAnchorsBuilder.swift BabyCareTests/BabyCareTests+DayPlan.swift
git commit -m "feat(dayplan): 그날의 정박점 — 어젯밤 잠을 오늘 첫 기록으로 세지 않는다"
```

---

## Task 3: 기록이 칸을 채우는 규칙 `DaySlotFiller`

**Files:**
- Create: `BabyCare/Models/DaySlotFiller.swift`
- Test: `BabyCareTests/BabyCareTests+DayPlan.swift` (append)

**Interfaces:**
- Consumes: `DayPlanExpander.Slot`(①단계) · `ActivityDayAttribution.startedOn`
- Produces: `DaySlotFiller.fill(slots:activities:on:calendar:) -> [DayCell]` · `DayCell` · `DayCell.Kind`

### 규칙 (설계 §3.3 의 미결을 여기서 정한다)

설계는 **「같은 종류의 가장 가까운 빈 칸을 채운다」**를 출발점으로 두고, **「얼마나 벗어나면 새 칸인가」**를
구현 단계로 미뤘다. **답: 거리 문턱을 두지 않는다.**

- 같은 종류끼리 **가까운 짝부터 1:1로** 붙인다(가장 가까운 쌍을 먼저 확정하는 그리디).
- 짝을 못 찾은 **기록**은 **끼어든 칸**(`.extra`)이 된다 — 시안 「예정에 없던 수유가 하나 더」.
- 짝을 못 찾은 **칸**은 **빈 채로** 남는다(`.planned`). **세지 않고, 빨갛게 하지 않는다.**
- 채워진 칸의 **표시 시각은 기록의 실제 시각**이다 — 「시간표는 밑그림이고 실제가 덮어쓴다」(결정 5).

🔑 **왜 문턱이 없나:** 문턱은 지어낸 숫자다(「30분 넘으면 새 칸」에 근거가 없다). 대신 **개수**가 답한다 —
칸보다 기록이 많으면 그만큼 늘어나고, 적으면 그만큼 빈다. 시안의 「8칸 계획 + 1개 더 = 오늘은 아홉 칸」이 정확히 이 규칙이다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```swift
// MARK: - Task 3 · 기록이 칸을 채운다

final class DaySlotFillerTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func at(_ h: Int, _ m: Int = 0, day: Int = 3) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: day, hour: h, minute: m))!
    }

    private func activity(_ type: Activity.ActivityType, _ start: Date, end: Date? = nil) -> Activity {
        Activity(id: "a-\(type.rawValue)-\(start.timeIntervalSince1970)", babyId: "b", type: type,
                 startTime: start, endTime: end, createdAt: start)
    }

    private func slot(_ id: String, _ type: Activity.ActivityType?, at plannedAt: Date?, order: Int = 0) -> DayPlanExpander.Slot {
        DayPlanExpander.Slot(id: id, entryId: id, title: id, activityType: type?.rawValue,
                             lane: .baby, plannedAt: plannedAt, order: order)
    }

    func testRecordFillsTheNearestSlotOfTheSameType() {
        let slots = [slot("s1", .feedingBottle, at: at(9)), slot("s2", .feedingBottle, at: at(12))]
        let acts = [activity(.feedingBottle, at(12, 10))]
        let cells = DaySlotFiller.fill(slots: slots, activities: acts, on: at(13), calendar: cal)
        XCTAssertEqual(cells.first(where: { $0.slotId == "s2" })?.kind, .done)
        XCTAssertEqual(cells.first(where: { $0.slotId == "s1" })?.kind, .planned)
    }

    /// 채워진 칸은 **실제 시각**으로 보인다 — 밑그림을 실제가 덮어쓴다(결정 5).
    func testFilledCellShowsTheActualTimeNotThePlannedTime() {
        let slots = [slot("s1", .bath, at: at(19, 30))]
        let cells = DaySlotFiller.fill(slots: slots, activities: [activity(.bath, at(8))], on: at(20), calendar: cal)
        XCTAssertEqual(cells[0].at, at(8))
    }

    /// 시안 「② 낮」 — 8칸 계획에 9번째 기록이 오면 **칸이 하나 늘어난다**.
    func testUnmatchedRecordBecomesAnExtraCell() {
        let slots = [slot("s1", .feedingBottle, at: at(9))]
        let acts = [activity(.feedingBottle, at(9, 5)), activity(.feedingBottle, at(15))]
        let cells = DaySlotFiller.fill(slots: slots, activities: acts, on: at(16), calendar: cal)
        XCTAssertEqual(cells.count, 2)
        XCTAssertEqual(cells.filter { $0.kind == .extra }.count, 1)
        XCTAssertEqual(cells.first(where: { $0.kind == .extra })?.at, at(15))
    }

    /// 종류가 다르면 절대 안 붙는다 — 목욕 기록이 수유 칸을 채우면 하루가 거짓이 된다.
    func testDifferentTypeNeverFillsASlot() {
        let slots = [slot("s1", .feedingBottle, at: at(9))]
        let cells = DaySlotFiller.fill(slots: slots, activities: [activity(.bath, at(9))], on: at(10), calendar: cal)
        XCTAssertEqual(cells.first(where: { $0.slotId == "s1" })?.kind, .planned)
        XCTAssertEqual(cells.filter { $0.kind == .extra }.count, 1)
    }

    /// 기록 종류가 없는 항목(내 밥·샤워)은 기록으로 채워지지 않는다 — 빈 채로 남는다.
    func testSlotWithoutActivityTypeStaysPlanned() {
        let slots = [slot("s1", nil, at: at(12))]
        let cells = DaySlotFiller.fill(slots: slots, activities: [activity(.feedingBottle, at(12))], on: at(13), calendar: cal)
        XCTAssertEqual(cells.first(where: { $0.slotId == "s1" })?.kind, .planned)
    }

    /// 정박 전(plannedAt=nil) 칸도 짝을 받는다 — 「첫 수유를 기다리는 중」이 채워지는 순간.
    func testUnscheduledSlotCanBeFilled() {
        let slots = [slot("s1", .feedingBottle, at: nil)]
        let cells = DaySlotFiller.fill(slots: slots, activities: [activity(.feedingBottle, at(6, 30))], on: at(9), calendar: cal)
        XCTAssertEqual(cells[0].kind, .done)
        XCTAssertEqual(cells[0].at, at(6, 30))
    }

    /// 🔴 어젯밤 잠이 오늘 칸을 채우면 안 된다(`todayActivities` 는 그것도 갖고 있다).
    func testActivityThatStartedYesterdayDoesNotFillTodaysSlot() {
        let slots = [slot("s1", .sleep, at: at(13))]
        let overnight = activity(.sleep, at(22, 0, day: 2), end: at(7, 0, day: 3))
        let cells = DaySlotFiller.fill(slots: slots, activities: [overnight], on: at(14), calendar: cal)
        XCTAssertEqual(cells.first(where: { $0.slotId == "s1" })?.kind, .planned)
        XCTAssertTrue(cells.allSatisfy { $0.kind != .extra }, "어젯밤 잠이 오늘 칸으로 끼어들었다")
    }

    /// 가까운 쌍부터 붙는다 — 순서에 따라 답이 달라지면 안 된다.
    func testClosestPairWinsRegardlessOfInputOrder() {
        let slots = [slot("s1", .feedingBottle, at: at(9)), slot("s2", .feedingBottle, at: at(15))]
        let acts = [activity(.feedingBottle, at(14, 50)), activity(.feedingBottle, at(9, 10))]
        let forward = DaySlotFiller.fill(slots: slots, activities: acts, on: at(16), calendar: cal)
        let reversed = DaySlotFiller.fill(slots: slots.reversed(), activities: acts.reversed(), on: at(16), calendar: cal)
        XCTAssertEqual(forward.first(where: { $0.slotId == "s1" })?.at, at(9, 10))
        XCTAssertEqual(reversed.first(where: { $0.slotId == "s1" })?.at, at(9, 10))
    }

    /// 띠는 시간 순이다. 시각 미정(정박 전)은 맨 앞 — 하루가 거기서 시작하기를 기다리는 자리다.
    func testCellsSortUnscheduledFirstThenByTime() {
        let slots = [slot("s2", .feedingBottle, at: at(12)), slot("s1", .feedingSolid, at: nil)]
        let cells = DaySlotFiller.fill(slots: slots, activities: [], on: at(13), calendar: cal)
        XCTAssertEqual(cells.map(\.slotId), ["s1", "s2"])
    }
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare
make generate
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests/DaySlotFillerTests 2>&1 | grep -E "error:|Executed"
```

기대: `cannot find 'DaySlotFiller' in scope`.

- [ ] **Step 3: 순수 함수를 만든다**

`BabyCare/Models/DaySlotFiller.swift`:

```swift
import Foundation

/// 하루 띠의 한 칸.
struct DayCell: Identifiable, Hashable {
    enum Kind: Hashable {
        /// 짜 뒀고 아직 안 왔다 — **세지 않는다. 빨갛게 하지 않는다.**
        case planned
        /// 짜 뒀고 기록이 왔다.
        case done
        /// 짜 두지 않았는데 왔다 — 칸이 하나 늘어난 것(시안 「끼어든 칸」).
        case extra
    }

    var id: String
    /// 계획된 칸이면 그 칸의 id, 끼어든 칸이면 nil.
    var slotId: String?
    var title: String
    var activityType: String?
    var lane: DayPlan.Lane
    var kind: Kind
    /// 채워졌으면 **기록의 실제 시각**, 아니면 계획된 시각. 정박 전이면 nil.
    var at: Date?
    var order: Int
}

/// 칸 + 그날 기록 → 하루 띠.
/// **순수 함수만** — `Date()` 도, 저장소도 만지지 않는다.
///
/// 규칙(설계 §3.3 의 미결을 여기서 정했다):
/// - 같은 종류끼리 **가까운 짝부터 1:1**로 붙인다. **거리 문턱은 없다** — 지어낸 숫자가 되기 때문이다.
/// - 짝 없는 기록 = 끼어든 칸 · 짝 없는 칸 = 빈 칸(그냥 남는다).
/// - 채워진 칸은 **기록의 실제 시각**으로 보인다 — 밑그림을 실제가 덮어쓴다(결정 5).
enum DaySlotFiller {

    static func fill(
        slots: [DayPlanExpander.Slot],
        activities: [Activity],
        on day: Date,
        calendar: Calendar = .current
    ) -> [DayCell] {
        // 🔴 하루 목록에는 「어제 시작해 오늘 끝난 것」이 섞여 있다 — 오늘 시작한 것만 센다.
        let todays = ActivityDayAttribution.startedOn(activities, day: day, calendar: calendar)
            .filter { $0.type != .unknown }

        // 가까운 쌍부터 확정한다(그리디). 입력 순서가 답을 바꾸지 않도록 결정적으로 정렬한다.
        struct Pair { let slotIndex: Int; let actIndex: Int; let distance: TimeInterval }
        var pairs: [Pair] = []
        for (si, s) in slots.enumerated() {
            guard let type = s.activityType else { continue }   // 기록 종류 없는 항목은 안 채워진다
            for (ai, a) in todays.enumerated() where a.type.rawValue == type {
                // 정박 전(plannedAt=nil) 칸은 거리를 0 으로 봐서 같은 종류 기록을 받아들인다.
                let d = s.plannedAt.map { abs($0.timeIntervalSince(a.startTime)) } ?? 0
                pairs.append(Pair(slotIndex: si, actIndex: ai, distance: d))
            }
        }
        pairs.sort {
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            if $0.slotIndex != $1.slotIndex { return $0.slotIndex < $1.slotIndex }
            return $0.actIndex < $1.actIndex
        }

        var slotToAct: [Int: Int] = [:]
        var usedActs = Set<Int>()
        for p in pairs where slotToAct[p.slotIndex] == nil && !usedActs.contains(p.actIndex) {
            slotToAct[p.slotIndex] = p.actIndex
            usedActs.insert(p.actIndex)
        }

        var cells: [DayCell] = slots.enumerated().map { si, s in
            if let ai = slotToAct[si] {
                return DayCell(id: s.id, slotId: s.id, title: s.title, activityType: s.activityType,
                               lane: s.lane, kind: .done, at: todays[ai].startTime, order: s.order)
            }
            return DayCell(id: s.id, slotId: s.id, title: s.title, activityType: s.activityType,
                           lane: s.lane, kind: .planned, at: s.plannedAt, order: s.order)
        }

        // 짝을 못 찾은 기록 = 끼어든 칸. order 는 계획 칸보다 뒤에 둬서 동시각 정렬을 안정시킨다.
        for (ai, a) in todays.enumerated() where !usedActs.contains(ai) {
            cells.append(DayCell(id: "extra-\(a.id)", slotId: nil, title: a.type.displayName,
                                 activityType: a.type.rawValue, lane: .baby, kind: .extra,
                                 at: a.startTime, order: Int.max))
        }

        // 미정(nil)은 맨 앞 — 하루가 거기서 시작하기를 기다리는 자리다(①단계 Expander 와 같은 규칙).
        return cells.sorted { l, r in
            let lt = l.at ?? .distantPast
            let rt = r.at ?? .distantPast
            if lt != rt { return lt < rt }
            if l.order != r.order { return l.order < r.order }
            return l.id < r.id
        }
    }
}
```

- [ ] **Step 4: 통과를 확인한다**

Step 2 와 같은 명령. 기대: `Executed 9 tests, with 0 failures`.

- [ ] **Step 5: 커밋**

```bash
cd /Users/roque/BabyCare
git add BabyCare/Models/DaySlotFiller.swift BabyCareTests/BabyCareTests+DayPlan.swift
git commit -m "feat(dayplan): 기록이 칸을 채운다 — 가까운 짝부터 1:1, 남으면 칸이 늘어난다"
```

---

## Task 4: 밤 요약 `DaySummary` — 한 것만 말한다

**Files:**
- Create: `BabyCare/Models/DaySummary.swift`
- Test: `BabyCareTests/BabyCareTests+DayPlan.swift` (append)

**Interfaces:**
- Consumes: `DayCell`(T3)
- Produces: `DaySummary.babyLine(cells:babyName:) -> String?`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```swift
// MARK: - Task 4 · 밤 요약

final class DaySummaryTests: XCTestCase {

    private func cell(_ type: Activity.ActivityType, _ kind: DayCell.Kind) -> DayCell {
        DayCell(id: UUID().uuidString, slotId: nil, title: type.displayName,
                activityType: type.rawValue, lane: .baby, kind: kind, at: Date(), order: 0)
    }

    /// 시안 밤 화면 — 「서준이 일곱 번 먹고 세 번 잤어요」.
    func testCountsWhatHappened() {
        let cells = Array(repeating: cell(.feedingBottle, .done), count: 6)
            + [cell(.feedingBreast, .done)]
            + Array(repeating: cell(.sleep, .done), count: 3)
        let line = DaySummary.babyLine(cells: cells, babyName: "서준")
        XCTAssertEqual(line, "서준이 일곱 번 먹고 세 번 잤어요")
    }

    /// 🔴 설계 §5 — **못 한 것은 세지 않는다.** 빈 칸이 문장에 나타나면 안 된다.
    func testNeverCountsWhatDidNotHappen() {
        let cells = [cell(.feedingBottle, .done)] + Array(repeating: cell(.feedingBottle, .planned), count: 5)
        let line = DaySummary.babyLine(cells: cells, babyName: "서준")
        XCTAssertEqual(line, "서준이 한 번 먹었어요")
        XCTAssertFalse(line?.contains("5") ?? false)
        XCTAssertFalse(line?.contains("못") ?? false)
    }

    /// 끼어든 칸도 **한 것**이다 — 계획 밖이라고 빼면 실제보다 적게 말하게 된다.
    func testExtraCellsCountToo() {
        XCTAssertEqual(DaySummary.babyLine(cells: [cell(.feedingBottle, .extra)], babyName: "서준"),
                       "서준이 한 번 먹었어요")
    }

    /// 아무것도 안 한 날엔 **아무 말도 하지 않는다** — 「0번 먹었어요」는 비난이다.
    func testSaysNothingWhenNothingHappened() {
        XCTAssertNil(DaySummary.babyLine(cells: [cell(.sleep, .planned)], babyName: "서준"))
    }

    /// 🩸 받침 — 「서아가」가 아니라 이름 뒤 주격은 이/가 규칙을 탄다.
    func testNameParticleFollowsFinalConsonant() {
        XCTAssertEqual(DaySummary.babyLine(cells: [cell(.sleep, .done)], babyName: "서아"),
                       "서아가 한 번 잤어요")
    }
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare
make generate
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests/DaySummaryTests 2>&1 | grep -E "error:|Executed"
```

기대: `cannot find 'DaySummary' in scope`.

- [ ] **Step 3: 순수 함수를 만든다**

`BabyCare/Models/DaySummary.swift`:

```swift
import Foundation

/// 밤에 하루를 닫으며 하는 말.
/// 🔴 **한 것만 말하고 못 한 것은 세지 않는다**(설계 §5). 분수·연속 일수·배지 없음.
/// 아무것도 없는 날엔 **아무 말도 하지 않는다** — 「0번」은 격려가 아니라 비난이다.
enum DaySummary {

    private static let korean = ["한", "두", "세", "네", "다섯", "여섯", "일곱", "여덟", "아홉", "열"]

    /// 「서준이 일곱 번 먹고 세 번 잤어요」. 셀 것이 없으면 nil.
    static func babyLine(cells: [DayCell], babyName: String) -> String? {
        let happened = cells.filter { $0.kind != .planned }
        let feeds = happened.filter { isFeeding($0.activityType) }.count
        let sleeps = happened.filter { $0.activityType == Activity.ActivityType.sleep.rawValue }.count
        guard feeds > 0 || sleeps > 0 else { return nil }

        let subject = "\(babyName)\(KoreanParticle.subject(after: babyName))"
        if feeds > 0 && sleeps > 0 {
            return "\(subject) \(count(feeds)) 번 먹고 \(count(sleeps)) 번 잤어요"
        }
        if feeds > 0 { return "\(subject) \(count(feeds)) 번 먹었어요" }
        return "\(subject) \(count(sleeps)) 번 잤어요"
    }

    /// 섭취만 센다 — **유축(생산)은 먹은 것이 아니다**(용어 규칙).
    private static func isFeeding(_ rawValue: String?) -> Bool {
        guard let raw = rawValue, let type = Activity.ActivityType.known(rawValue: raw) else { return false }
        switch type {
        case .feedingBreast, .feedingBottle, .feedingSolid, .feedingSnack: return true
        default: return false
        }
    }

    private static func count(_ n: Int) -> String {
        n >= 1 && n <= korean.count ? korean[n - 1] : "\(n)"
    }
}
```

⚠️ 문구는 **띄어쓰기까지** 테스트가 못박는다(`"서준이 일곱 번 먹고 세 번 잤어요"`). 구현이 문자열을
조립하는 방식이 바뀌면 테스트가 먼저 빨개진다 — 그게 목적이다.

- [ ] **Step 4: 통과를 확인한다**

Step 2 와 같은 명령. 기대: `Executed 5 tests, with 0 failures`.

- [ ] **Step 5: 커밋**

```bash
cd /Users/roque/BabyCare
git add BabyCare/Models/DaySummary.swift BabyCareTests/BabyCareTests+DayPlan.swift
git commit -m "feat(dayplan): 밤 요약 — 한 것만 말한다"
```

---

## Task 5: Firestore Narrow Protocol 5단계 (`dayRuns`)

**Files:**
- Modify: `BabyCare/Utils/Constants.swift` (`FirestoreCollections` 에 한 줄)
- Create: `BabyCare/Services/FirestoreService+DayRun.swift`
- Create: `BabyCareTests/MockDayRunFirestore.swift`
- Modify: `firestore.rules`
- Test: `BabyCareTests/BabyCareTests+DayPlan.swift` (append)

**Interfaces:**
- Produces: `DayRunFirestoreProviding` — `fetchDayRun(userId:documentId:) async throws -> DayRun?` ·
  `saveDayRun(_:userId:) async throws` · `FirestoreCollections.dayRuns`

- [ ] **Step 1: Mock 과 계약 테스트를 쓴다**

`BabyCareTests/MockDayRunFirestore.swift` (신규):

```swift
import Foundation
@testable import BabyCare

final class MockDayRunFirestore: DayRunFirestoreProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var store: [String: [String: DayRun]] = [:]   // userId → docId → DayRun

    private(set) var fetchCount = 0
    private(set) var saveCount = 0
    var fetchError: Error?
    var saveError: Error?

    func seed(_ run: DayRun, userId: String) {
        lock.lock(); defer { lock.unlock() }
        store[userId, default: [:]][run.id] = run
    }

    func fetchDayRun(userId: String, documentId: String) async throws -> DayRun? {
        lock.lock(); defer { lock.unlock() }
        fetchCount += 1
        if let e = fetchError { throw e }
        return store[userId]?[documentId]
    }

    func saveDayRun(_ run: DayRun, userId: String) async throws {
        lock.lock(); defer { lock.unlock() }
        saveCount += 1
        if let e = saveError { throw e }
        store[userId, default: [:]][run.id] = run
    }
}
```

계약 테스트 (`BabyCareTests+DayPlan.swift` 에 append):

```swift
// MARK: - Task 5 · dayRuns 저장소 계약

final class DayRunStoreTests: XCTestCase {

    func testCollectionConstantIsStable() {
        XCTAssertEqual(FirestoreCollections.dayRuns, "dayRuns")
    }

    func testMockRoundTrip() async throws {
        let mock = MockDayRunFirestore()
        let run = DayRun(id: "2026-09-03", planId: "p", startedAt: Date())
        try await mock.saveDayRun(run, userId: "u1")
        let back = try await mock.fetchDayRun(userId: "u1", documentId: "2026-09-03")
        XCTAssertEqual(back, run)
        XCTAssertEqual(mock.saveCount, 1)
        XCTAssertEqual(mock.fetchCount, 1)
    }

    /// owner-path 격리 — 다른 사용자의 하루가 보이면 안 된다(#49 결함군).
    func testMockIsolatesUsers() async throws {
        let mock = MockDayRunFirestore()
        try await mock.saveDayRun(DayRun(id: "2026-09-03", startedAt: Date()), userId: "u1")
        let other = try await mock.fetchDayRun(userId: "u2", documentId: "2026-09-03")
        XCTAssertNil(other)
    }

    func testMissingDayReturnsNilNotError() async throws {
        let mock = MockDayRunFirestore()
        XCTAssertNil(try await mock.fetchDayRun(userId: "u1", documentId: "2026-01-01"))
    }
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare
make generate
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests/DayRunStoreTests 2>&1 | grep -E "error:|Executed"
```

기대: `cannot find type 'DayRunFirestoreProviding' in scope`.

- [ ] **Step 3: 상수 · 프로토콜 · 구현을 만든다**

`BabyCare/Utils/Constants.swift` — `dayPlans` 바로 아래에 한 줄:

```swift
    static let dayRuns = "dayRuns"
```

`BabyCare/Services/FirestoreService+DayRun.swift` (신규):

```swift
import Foundation
import FirebaseFirestore

/// VM 이 의존하는 것만 — 하루를 읽고 쓴다.
protocol DayRunFirestoreProviding: Sendable {
    func fetchDayRun(userId: String, documentId: String) async throws -> DayRun?
    func saveDayRun(_ run: DayRun, userId: String) async throws
}

extension FirestoreService {

    private func dayRunsRef(userId: String) -> CollectionReference {
        db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.dayRuns)
    }

    /// 하루 한 문서 — 문서 id 가 곧 날짜라 목록을 훑지 않는다.
    /// 🔑 이 레포 다른 곳은 `try? snapshot.data(as:)` 를 쓰지만 **여기선 던진다** —
    ///    `nil` 이 「아직 안 열었다」를 뜻하는 자리라, 디코드 실패를 nil 로 삼키면
    ///    **열려 있는 하루를 못 읽고 새로 덮어쓴다**(fail-open).
    func fetchDayRun(userId: String, documentId: String) async throws -> DayRun? {
        let snapshot = try await dayRunsRef(userId: userId).document(documentId).getDocument()
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: DayRun.self)
    }

    /// 같은 날 다시 열어도 덮어쓴다(멱등) — 문서 id 가 날짜이기 때문이다.
    func saveDayRun(_ run: DayRun, userId: String) async throws {
        try dayRunsRef(userId: userId).document(run.id).setData(from: run)
    }
}

extension FirestoreService: DayRunFirestoreProviding {}
```

🔑 `FirestoreCollections.users` = `"users"` **실측 확인 완료**(2026-09-03). 경로 만드는 방식은
①단계 `FirestoreService+DayPlan.swift` 의 `dayPlanCollection(_:)` 과 **같다**(`users/{uid}/dayRuns/{날짜}`).

- [ ] **Step 4: Firestore 규칙을 넣는다**

`firestore.rules` — `dayPlans` 블록 **바로 아래**에:

```
      match /dayRuns/{docId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
```

🔴 **규칙은 코드와 따로 배포된다.** 안 올리면 손님이 하루를 열 때 permission-denied 로 실패한다.
배포는 **PO 승인 후** `make deploy-rules`(idempotent).
🔑 올리기 전에 **라이브를 읽어 대조**할 것 — 레포 파일이 낡았으면 그대로 올릴 때 라이브를 되돌린다:

```bash
TOKEN=$(gcloud auth application-default print-access-token)
REL=$(curl -s -H "Authorization: Bearer $TOKEN" \
  "https://firebaserules.googleapis.com/v1/projects/babycare-allcare/releases/cloud.firestore")
RS=$(echo "$REL" | python3 -c "import sys,json; print(json.load(sys.stdin)['rulesetName'])")
curl -s -H "Authorization: Bearer $TOKEN" "https://firebaserules.googleapis.com/v1/$RS" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['source']['files'][0]['content'])" > /tmp/live.rules
diff -u /tmp/live.rules firestore.rules   # 차이가 **추가하는 블록뿐**이어야 한다
```

- [ ] **Step 5: 통과와 게이트를 확인한다**

```bash
cd /Users/roque/BabyCare
make generate
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests/DayRunStoreTests 2>&1 | grep -E "error:|Executed"
bash scripts/arch_test.sh
```

기대: `Executed 4 tests, with 0 failures` · `R1=0 R2=0 R3=0 R4=0`.

- [ ] **Step 6: 커밋**

```bash
cd /Users/roque/BabyCare
git add BabyCare/Services/FirestoreService+DayRun.swift BabyCare/Utils/Constants.swift \
        BabyCareTests/MockDayRunFirestore.swift BabyCareTests/BabyCareTests+DayPlan.swift firestore.rules
git commit -m "feat(dayplan): dayRuns 컬렉션 — narrow protocol 5단계"
```

---

## Task 6: `TodayViewModel` — 열고 · 이어 붙이고 · 닫는다

**Files:**
- Create: `BabyCare/ViewModels/TodayViewModel.swift`
- Test: `BabyCareTests/BabyCareTests+DayPlan.swift` (append)

**Interfaces:**
- Consumes: `DayRunFirestoreProviding`(T5) · `DayPlanFirestoreProviding`(①단계) · `DayAnchorsBuilder`(T2) ·
  `DayPlanExpander`(①단계) · `DaySlotFiller`(T3) · `DaySummary`(T4)
- Produces: `TodayViewModel(dayRunProvider:planProvider:)` · `load(userId:day:activities:)` ·
  `startToday(userId:day:)` · `closeToday(userId:)` · `var cells: [DayCell]` · `var run: DayRun?` ·
  `var errorMessage: String?` · `var isLoading: Bool`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```swift
// MARK: - Task 6 · 오늘 VM

@MainActor
final class TodayViewModelTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Seoul")!
        return c
    }()

    private func at(_ h: Int, _ m: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: 3, hour: h, minute: m))!
    }

    private func makeVM(runs: MockDayRunFirestore = .init(),
                        plans: MockDayPlanFirestore = .init()) -> TodayViewModel {
        TodayViewModel(dayRunProvider: runs, planProvider: plans, calendar: cal)
    }

    private var planWithOneBottle: DayPlan {
        DayPlan(id: "p", name: "우리 하루", entries: [
            DayPlan.Entry(id: "milk", title: "분유", activityType: "feeding_bottle",
                          schedule: .fixedTimes(minutesOfDay: [12 * 60]), order: 0)
        ])
    }

    func testStartTodayWritesOneDocumentPerDay() async {
        let runs = MockDayRunFirestore()
        let vm = makeVM(runs: runs)
        await vm.startToday(userId: "u1", day: at(7))
        XCTAssertEqual(vm.run?.id, "2026-09-03")
        XCTAssertTrue(vm.run?.isOpen == true)
        XCTAssertEqual(runs.saveCount, 1)
    }

    /// 같은 날 두 번 눌러도 하루는 하나다 — 시작 시각이 리셋되면 안 된다.
    func testStartingTwiceKeepsTheFirstStartTime() async {
        let runs = MockDayRunFirestore()
        let vm = makeVM(runs: runs)
        await vm.startToday(userId: "u1", day: at(7))
        let first = vm.run?.startedAt
        await vm.startToday(userId: "u1", day: at(9))
        XCTAssertEqual(vm.run?.startedAt, first)
    }

    func testCloseTodayMarksItClosed() async {
        let vm = makeVM()
        await vm.startToday(userId: "u1", day: at(7))
        await vm.closeToday(userId: "u1")
        XCTAssertFalse(vm.run?.isOpen ?? true)
    }

    /// 시간표 + 기록 → 칸. VM 은 이어 붙이기만 하고 규칙은 순수 함수가 갖는다.
    func testCellsComeFromPlanAndActivities() async {
        let plans = MockDayPlanFirestore()
        plans.seed([planWithOneBottle], userId: "u1")
        let vm = makeVM(plans: plans)
        let act = Activity(id: "a1", babyId: "b", type: .feedingBottle,
                           startTime: at(12, 10), createdAt: at(12, 10))
        await vm.load(userId: "u1", day: at(13), activities: [act])
        XCTAssertEqual(vm.cells.count, 1)
        XCTAssertEqual(vm.cells[0].kind, .done)
        XCTAssertEqual(vm.cells[0].at, at(12, 10))
    }

    /// 🔙 불러오기 실패를 삼키지 않는다 — 「없는 하루」와 「못 읽은 하루」는 다르다.
    func testLoadSurfacesError() async {
        let runs = MockDayRunFirestore()
        runs.fetchError = NSError(domain: "t", code: 1)
        let vm = makeVM(runs: runs)
        await vm.load(userId: "u1", day: at(13), activities: [])
        XCTAssertNotNil(vm.errorMessage)
    }

    /// 시작 실패도 삼키지 않는다 — 눌렀는데 아무 일도 안 일어나면 손님은 다시 누른다.
    func testStartSurfacesErrorAndDoesNotClaimSuccess() async {
        let runs = MockDayRunFirestore()
        runs.saveError = NSError(domain: "t", code: 1)
        let vm = makeVM(runs: runs)
        await vm.startToday(userId: "u1", day: at(7))
        XCTAssertNil(vm.run, "저장이 실패했는데 열린 것처럼 보인다")
        XCTAssertNotNil(vm.errorMessage)
    }

    func testSummaryIsNilWhileNothingHappened() async {
        let vm = makeVM()
        await vm.load(userId: "u1", day: at(13), activities: [])
        XCTAssertNil(vm.summaryLine(babyName: "서준"))
    }
}
```

🔑 `MockDayPlanFirestore.seed(_ plans: [DayPlan], userId:)` 는 **배열을 받는다**(①단계 실측) — 그대로 쓴다.

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare
make generate
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests/TodayViewModelTests 2>&1 | grep -E "error:|Executed"
```

기대: `cannot find 'TodayViewModel' in scope`.

- [ ] **Step 3: VM 을 만든다**

`BabyCare/ViewModels/TodayViewModel.swift`:

```swift
import Foundation

/// 「오늘 하루」 — 열고 · 시간표와 기록을 이어 붙이고 · 닫는다.
///
/// `userId` 는 호출부가 owner-path(`dataUserId`)로 변환해 넘긴다 — VM 이 스스로 정하지 않는다.
/// ⛔ 칸의 상태는 저장하지 않는다. 시간표 + 기록에서 **매번 다시 계산**한다.
@MainActor @Observable
final class TodayViewModel: LoadingStateful {

    private(set) var run: DayRun?
    private(set) var cells: [DayCell] = []
    private(set) var plan: DayPlan?
    var isLoading = false
    var errorMessage: String?

    private let dayRunProvider: DayRunFirestoreProviding
    private let planProvider: DayPlanFirestoreProviding
    private let calendar: Calendar

    init(
        dayRunProvider: DayRunFirestoreProviding = FirestoreService.shared,
        planProvider: DayPlanFirestoreProviding = FirestoreService.shared,
        calendar: Calendar = .current
    ) {
        self.dayRunProvider = dayRunProvider
        self.planProvider = planProvider
        self.calendar = calendar
    }

    // MARK: - Load

    /// `activities` 는 **하루 목록 그대로** 넘겨도 된다 — 순수 함수들이 `startedOn` 으로 거른다.
    func load(userId: String, day: Date, activities: [Activity]) async {
        await withLoading {
            do {
                let docId = DayRun.documentId(for: day, calendar: calendar)
                async let fetchedRun = dayRunProvider.fetchDayRun(userId: userId, documentId: docId)
                async let fetchedPlans = planProvider.fetchDayPlans(userId: userId)
                run = try await fetchedRun
                plan = try await fetchedPlans.first
                recompute(day: day, activities: activities)
                errorMessage = nil
            } catch {
                errorMessage = "오늘 하루를 불러오지 못했어요."
                logSilent("오늘 하루 로드 실패", error: error, logger: AppLogger.firestore)
            }
        }
    }

    /// 기록이 바뀔 때마다 화면이 부르는 자리 — 저장소를 다시 안 두드린다.
    func refreshCells(day: Date, activities: [Activity]) {
        recompute(day: day, activities: activities)
    }

    private func recompute(day: Date, activities: [Activity]) {
        guard let plan else { cells = []; return }
        let anchors = DayAnchorsBuilder.anchors(from: activities, on: day, calendar: calendar)
        let slots = DayPlanExpander.slots(plan: plan, day: day, anchors: anchors, calendar: calendar)
        cells = DaySlotFiller.fill(slots: slots, activities: activities, on: day, calendar: calendar)
    }

    // MARK: - 열기 · 닫기

    /// 같은 날 다시 눌러도 **시작 시각은 그대로**다(문서 id 가 날짜라 덮어쓰기가 멱등).
    func startToday(userId: String, day: Date) async {
        if let existing = run, existing.id == DayRun.documentId(for: day, calendar: calendar) { return }
        let new = DayRun(id: DayRun.documentId(for: day, calendar: calendar),
                         planId: plan?.id, startedAt: Date())
        do {
            try await dayRunProvider.saveDayRun(new, userId: userId)
            run = new
            errorMessage = nil
        } catch {
            // ⛔ 저장이 실패했으면 열린 것처럼 보이지 않는다 — 손님이 닫을 수 없는 하루가 생긴다.
            errorMessage = "오늘 하루를 시작하지 못했어요."
            logSilent("하루 시작 실패", error: error, logger: AppLogger.firestore)
        }
    }

    func closeToday(userId: String) async {
        guard var current = run, current.isOpen else { return }
        current.closedAt = Date()
        do {
            try await dayRunProvider.saveDayRun(current, userId: userId)
            run = current
            errorMessage = nil
        } catch {
            errorMessage = "오늘 하루를 닫지 못했어요."
            logSilent("하루 닫기 실패", error: error, logger: AppLogger.firestore)
        }
    }

    // MARK: - 밤 요약

    func summaryLine(babyName: String) -> String? {
        DaySummary.babyLine(cells: cells, babyName: babyName)
    }
}
```

- [ ] **Step 4: 통과를 확인한다**

Step 2 와 같은 명령. 기대: `Executed 7 tests, with 0 failures`.

- [ ] **Step 5: 커밋**

```bash
cd /Users/roque/BabyCare
git add BabyCare/ViewModels/TodayViewModel.swift BabyCareTests/BabyCareTests+DayPlan.swift \
        BabyCareTests/MockDayPlanFirestore.swift
git commit -m "feat(dayplan): 오늘 VM — 열고 이어 붙이고 닫는다"
```

---

## Task 7: 하루 띠 카드 `TodayBandCard` + 대시보드 배치

**Files:**
- Create: `BabyCare/Views/DayPlan/TodayBandCard.swift`
- Modify: `BabyCare/Views/Dashboard/DashboardView.swift` (`quickActionsSection` 바로 **아래** 한 줄)
- Test: `BabyCareTests/BabyCareTests+DayPlan.swift` (append) · `BabyCareUITests/DayPlanFlowTests.swift` (append)

**Interfaces:**
- Consumes: `TodayViewModel`(T6) · `DayCell`(T3)
- Produces: `TodayBandCard()` · `TodayBandCopy.headline(run:cells:) -> String`

### 시안 (정본) — 이 카드가 그리는 네 상태

| 상태 | 언제 | 문구 |
|---|---|---|
| 시작 전 | `run == nil` | 「오늘 하루 시작하기」 버튼 |
| 아침 | 열림 · 채워진 칸 0 | 「첫 수유를 기다리는 중」 / 「먹이면 오늘 수유 시간이 정해져요」 |
| 낮 | 열림 · 하나 이상 채워짐 | 띠 + 「여섯 칸 지남」 · 끼어든 칸이 있으면 「오늘은 아홉 칸이 됐어요」 |
| 밤 | 닫힘 | 「오늘 이렇게 지났어요」 + 요약 + 「오늘도 잘 지났어요」 |

띠: **채워진 점**(지나가고 기록된 것) · **큰 고리**(지금) · **빈 점**(아직 안 온 것) ·
**끼어든 칸은 테두리**로 구분. ⛔ 빨간색은 어디에도 없다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

화면에서 떼어 낸 **문구 규칙**만 잠근다(껍데기는 눈으로 본다).

```swift
// MARK: - Task 7 · 띠 카드 문구

final class TodayBandCopyTests: XCTestCase {

    private func cell(_ kind: DayCell.Kind) -> DayCell {
        DayCell(id: UUID().uuidString, slotId: kind == .extra ? nil : "s", title: "분유",
                activityType: "feeding_bottle", lane: .baby, kind: kind, at: Date(), order: 0)
    }

    private var openRun: DayRun { DayRun(id: "2026-09-03", startedAt: Date()) }
    private var closedRun: DayRun {
        var r = openRun; r.closedAt = Date(); return r
    }

    func testBeforeStartInvitesToStart() {
        XCTAssertEqual(TodayBandCopy.headline(run: nil, cells: []), "오늘 하루 시작하기")
    }

    func testMorningWaitsForTheFirstRecord() {
        XCTAssertEqual(TodayBandCopy.headline(run: openRun, cells: [cell(.planned)]),
                       "첫 기록을 기다리는 중")
    }

    func testDaytimeCountsWhatPassed() {
        let cells = [cell(.done), cell(.done), cell(.planned)]
        XCTAssertEqual(TodayBandCopy.headline(run: openRun, cells: cells), "두 칸 지났어요")
    }

    /// 시안 「② 낮」 — 끼어든 칸이 있으면 **오늘의 칸 수**를 말한다.
    func testExtraCellsAnnounceTheNewTotal() {
        let cells = [cell(.done), cell(.extra), cell(.planned)]
        XCTAssertEqual(TodayBandCopy.headline(run: openRun, cells: cells), "오늘은 세 칸이 됐어요")
    }

    func testClosedDayIsKind() {
        XCTAssertEqual(TodayBandCopy.headline(run: closedRun, cells: [cell(.done)]), "오늘도 잘 지났어요")
    }

    /// 🔴 설계 §2 결정 6 · §5 — 재촉·지연·분수는 어떤 상태에서도 나오지 않는다.
    func testNeverNagsInAnyState() {
        let states: [(DayRun?, [DayCell])] = [
            (nil, []), (openRun, [cell(.planned)]),
            (openRun, [cell(.done), cell(.planned)]), (closedRun, [cell(.done), cell(.planned)])
        ]
        for (run, cells) in states {
            let text = TodayBandCopy.headline(run: run, cells: cells)
            for banned in ["지연", "늦", "밀렸", "못 한", "/", "연속"] {
                XCTAssertFalse(text.contains(banned), "「\(banned)」가 문구에 있다: \(text)")
            }
        }
    }
}
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare
make generate
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests/TodayBandCopyTests 2>&1 | grep -E "error:|Executed"
```

기대: `cannot find 'TodayBandCopy' in scope`.

- [ ] **Step 3: 문구 규칙을 만든다**

`BabyCare/Views/DayPlan/TodayBandCard.swift` 상단:

```swift
import SwiftUI

/// 띠 카드가 하는 말. 화면에서 떼어 내 테스트로 잠근다.
/// ⛔ 지연·재촉·완료율 분수·연속 일수는 **어떤 상태에서도** 나오지 않는다(설계 §2 결정 6 · §5).
enum TodayBandCopy {

    private static let korean = ["한", "두", "세", "네", "다섯", "여섯", "일곱", "여덟", "아홉", "열"]

    static func headline(run: DayRun?, cells: [DayCell]) -> String {
        guard let run else { return "오늘 하루 시작하기" }
        if !run.isOpen { return "오늘도 잘 지났어요" }
        if cells.contains(where: { $0.kind == .extra }) {
            return "오늘은 \(count(cells.count)) 칸이 됐어요"
        }
        let done = cells.filter { $0.kind == .done }.count
        return done == 0 ? "첫 기록을 기다리는 중" : "\(count(done)) 칸 지났어요"
    }

    static func count(_ n: Int) -> String {
        n >= 1 && n <= korean.count ? korean[n - 1] : "\(n)"
    }
}
```

- [ ] **Step 4: 통과를 확인한다**

Step 2 와 같은 명령. 기대: `Executed 6 tests, with 0 failures`.

- [ ] **Step 5: 카드 화면을 만든다**

같은 파일에 `TodayBandCard: View`. 골격은 이렇고, 나머지는 시안(「앱 안」 페이지)을 따른다:

```swift
struct TodayBandCard: View {
    @Environment(AuthViewModel.self) private var authVM
    @Environment(BabyViewModel.self) private var babyVM
    @Environment(ActivityViewModel.self) private var activityVM

    @State private var vm = TodayViewModel()

    /// 🔴 `currentUserId` 를 **먼저** — `dataUserId` 는 로그아웃 뒤에도 소유자 uid 를 돌려준다(#49).
    private var ownerUserId: String? {
        guard let current = authVM.currentUserId else { return nil }
        return babyVM.dataUserId(currentUserId: current) ?? current
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.md) {
            Text(TodayBandCopy.headline(run: vm.run, cells: vm.cells))
                .font(DS2.Font.headline)
                .foregroundStyle(DS2.Color.textPrimary)

            if vm.run == nil {
                startButton
            } else {
                DayBandStrip(cells: vm.cells)
                if vm.run?.isOpen == false, let name = babyVM.selectedBaby?.name,
                   let line = vm.summaryLine(babyName: name) {
                    Text(line)
                        .font(DS2.Font.callout)
                        .foregroundStyle(DS2.Color.textSecondary)
                }
                if vm.run?.isOpen == true { closeButton }
            }
        }
        .padding(DS2.Spacing.lg)
        .background(DS2.Color.surfaceSecondary, in: RoundedRectangle(cornerRadius: DS2.Radius.md))
        .ds2Shadow(.sm)
        .task {
            guard let userId = ownerUserId else { return }
            await vm.load(userId: userId, day: Date(), activities: activityVM.todayActivities)
        }
        // 기록이 들어오면 칸이 채워진다 — 저장소를 다시 두드리지 않는다.
        .onChange(of: activityVM.todayActivities) { _, new in
            vm.refreshCells(day: Date(), activities: new)
        }
    }
    private var startButton: some View {
        Button {
            Task {
                guard let userId = ownerUserId else { return }
                await vm.startToday(userId: userId, day: Date())
            }
        } label: {
            Text("오늘 하루 시작하기")
                .font(DS2.Font.callout)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS2.Spacing.sm)
                // 🩸 `.buttonStyle` 을 바꾸면 **글자 자리만** 눌린다 — ①단계에서 두 곳이 그랬다.
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .tint(DS2.Color.accent)
        .accessibilityHint("눌러서 오늘 하루를 엽니다")
    }

    private var closeButton: some View {
        Button {
            Task {
                guard let userId = ownerUserId else { return }
                await vm.closeToday(userId: userId)
            }
        } label: {
            Text("오늘도 잘 지났어요")
                .font(DS2.Font.callout)
                .foregroundStyle(DS2.Color.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS2.Spacing.xs)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("눌러서 오늘 하루를 닫습니다")
    }
}
```

`DayBandStrip` — 같은 파일에:

```swift
/// 하루 띠. 채워진 점 · 지금 고리 · 빈 점 · 끼어든 칸(테두리).
/// ⛔ 빨간색·경고 아이콘 없음 — 안 온 칸은 **그냥 빈 점**이다.
private struct DayBandStrip: View {
    let cells: [DayCell]

    /// 지금에 가장 가까운 **시각이 있는** 칸 — 여기에만 큰 고리를 두른다.
    private var nowCellId: String? {
        let now = Date()
        return cells
            .filter { $0.at != nil }
            .min { abs($0.at!.timeIntervalSince(now)) < abs($1.at!.timeIntervalSince(now)) }?
            .id
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS2.Spacing.md) {
                ForEach(cells) { cell in
                    VStack(spacing: DS2.Spacing.xs) {
                        dot(cell)
                            .frame(width: 20, height: 20)
                            .padding(4)
                            .overlay {
                                if cell.id == nowCellId {
                                    Circle().strokeBorder(DS2.Color.accent, lineWidth: 2)
                                }
                            }
                        Text(cell.at.map { PlanEntrySummary.timeLabel(minutesOfDay($0)) } ?? "미정")
                            .font(DS2.Font.caption2)
                            .foregroundStyle(DS2.Color.textSecondary)
                        Text(cell.title)
                            .font(DS2.Font.caption2)
                            .foregroundStyle(DS2.Color.textSecondary)
                            .lineLimit(1)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(label(cell))
                }
            }
            .padding(.vertical, DS2.Spacing.xs)
        }
    }

    @ViewBuilder
    private func dot(_ cell: DayCell) -> some View {
        switch cell.kind {
        case .done:
            Circle().fill(tint(cell.activityType))
        case .planned:
            Circle().fill(DS2.Color.textSecondary.opacity(0.25))
        case .extra:
            // 시안 「끼어든 칸」 — 계획에 없던 것은 테두리로 구분한다.
            Circle().strokeBorder(tint(cell.activityType), lineWidth: 2)
        }
    }

    /// 활동 색 자산만 쓴다 — hex 하드코딩 금지.
    /// ⚠️ `default:` 를 쓰지 않는다 — 새 분류가 생기면 **여기가 컴파일 에러**로 걸린다(swift-conventions.md).
    private func tint(_ rawValue: String?) -> Color {
        guard let raw = rawValue, let type = Activity.ActivityType.known(rawValue: raw) else {
            return DS2.Color.accent
        }
        switch type.category {
        case .feeding: return DS2.Color.feeding
        case .sleep: return DS2.Color.sleep
        case .diaper: return DS2.Color.diaper
        case .health: return DS2.Color.bath        // 목욕·체온·투약이 한 버킷(기존 앱 분류 그대로)
        case .pumping: return DS2.Color.pumping
        case .unknown: return DS2.Color.accent     // 센티넬 — 색을 지어내지 않는다
        }
    }

    private func minutesOfDay(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// 🩸 보인다 ≠ 읽힌다 — 점만 있으면 VoiceOver 에겐 빈 화면이다.
    private func label(_ cell: DayCell) -> String {
        let time = cell.at.map { PlanEntrySummary.timeLabel(minutesOfDay($0)) } ?? "시각 미정"
        switch cell.kind {
        case .done: return "\(cell.title) \(time) 기록됨"
        case .planned: return "\(cell.title) \(time) 예정"
        case .extra: return "\(cell.title) \(time) 계획에 없던 기록"
        }
    }
}
```

🔑 위 이름들은 **실측 확인 완료**(2026-09-03): `DS2.Color.{feeding,sleep,diaper,bath,pumping}` 존재 ·
`ActivityType.category` = `.feeding` / `.sleep` / `.diaper` / `.health`(목욕·체온·투약) / `.pumping` / `.unknown`.

나머지 규칙:

- ⛔ 빨간색·경고 아이콘 없음 · ⛔ 「N/M」 표기 없음 · ⛔ 「지연」 배지 없음
- 시각 형식은 `PlanEntrySummary.timeLabel` 을 **재사용**한다(①단계) — 두 자리에 적으면 갈라진다

`DashboardView.swift` — `quickActionsSection` **바로 아래** 한 줄:

```swift
        TodayBandCard()
```

- [ ] **Step 6: 눈으로 본다 (반드시 실제로 눌러 볼 것)**

```bash
cd /Users/roque/BabyCare
make build
```

시뮬레이터에 **방금 게이트가 쓴 DerivedData 의 .app** 을 설치한다(레포 `build/` 는 화석):

```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData/BabyCare-*/Build/Products/Debug-iphonesimulator \
  -maxdepth 1 -name "BabyCare.app" | head -1)
python3 -c "
data=open('$APP/BabyCare.debug.dylib','rb').read()
print('새 문구 포함:', '오늘 하루 시작하기'.encode() in data)"   # ⚠️ 코드는 .debug.dylib 에 있다
DEST_ID=$(grep -m1 '^DEST ?=' Makefile | grep -oE '[0-9A-F-]{36}')
xcrun simctl install "$DEST_ID" "$APP" && xcrun simctl launch "$DEST_ID" com.roacompany.allcare
```

홈에서 확인: 시작 전 → **시작** → 기록 하나 넣기 → **칸이 채워지는지** → **닫기**.
🩸 **되돌리는 길**(닫은 뒤 화면)도 직접 볼 것.

XCUITest 에도 한 흐름 추가(`BabyCareUITests/DayPlanFlowTests.swift`):

```swift
    @MainActor
    func testDashboardShowsTodayBandCard() throws {
        let app = XCUIApplication()
        app.launchArguments = ["UI_TESTING", "UI_TESTING_TAB=0"]
        app.launch()
        dismissDialogs(app)
        Thread.sleep(forTimeInterval: 2.5)
        XCTAssertTrue(app.staticTexts["오늘 하루 시작하기"].waitForExistence(timeout: 6),
                      "홈에 「오늘 하루」 카드가 없다")
        capture(app, "13_today_band_card")
        app.terminate()
    }
```

⚠️ `UI_TESTING` 은 인증을 흉내만 내서 Firestore 가 막힌다 — **닿는지·그려지는지**만 잰다.
넣고 채우고 닫는 **왕복은 로그인된 기기 QA**로만 확인된다.

- [ ] **Step 7: 전체 게이트**

```bash
cd /Users/roque/BabyCare
make verify
bash scripts/arch_test.sh
eval "$(grep -m1 '^DEST ?=' Makefile | sed 's/ ?= */=/')"
xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination $DEST -only-testing:BabyCareTests 2>&1 | grep -E "Executed [0-9]+ tests|error:"
```

기대: `ALL CHECKS PASSED` · `R1=R2=R3=R4=0` · 테스트 수가 **803 → 843**(신규 40 = 5+4+9+5+4+7+6) 로
**늘었는지 눈으로 확인**.
🩸 `make verify` 의 `make test` 는 `-quiet` 라 개수가 안 보인다. **EXIT=0 만으로 초록을 말하지 말 것.**

- [ ] **Step 8: 커밋**

```bash
cd /Users/roque/BabyCare
git add BabyCare/Views/DayPlan/TodayBandCard.swift BabyCare/Views/Dashboard/DashboardView.swift \
        BabyCareTests/BabyCareTests+DayPlan.swift BabyCareUITests/DayPlanFlowTests.swift
git commit -m "feat(dayplan): 하루 띠 카드 — 열고 채워지고 닫힌다"
```

---

## 완료 기준

- [ ] `make verify` ALL CHECKS PASSED · arch R1–R4=0 · lint 0 err
- [ ] 테스트 **803 → 843**(신규 40 · 숫자를 눈으로 확인)
- [ ] 홈에서 **오늘을 열고 · 기록이 칸을 채우고 · 닫을 수 있다**(시뮬레이터에서 직접 눌러 확인)
- [ ] 어젯밤 잠이 **오늘의 첫 기록으로도, 오늘의 칸으로도** 세어지지 않는다(테스트로 잠김)
- [ ] 화면 어디에도 **지연·재촉·연속 일수·완료율 분수·빨간색**이 없다
- [ ] 루틴(`Routine`·`RoutineView`)은 **한 줄도 안 바뀌었다**
- [ ] `firestore.rules` 의 `dayRuns` 가 **라이브와 대조 후** 배포됐다(PO 승인)
- [ ] push·PR·머지는 **PO 승인 후**

## 범위 밖 (②-B · ③단계)

내 줄(lane 고르기 · 「아무 때나」 · 수동 완료 · 「셋 중 둘」) · `afterEntry` 의 `completedByEntry` 정박 ·
잠금화면 Live Activity · 다이나믹 아일랜드 · 8시간 이어붙이기 · 아침 알림
