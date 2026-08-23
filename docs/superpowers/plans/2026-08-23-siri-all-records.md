# 시리로 모든 기록 — 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기록 런처 12종 전부를 시리로 기록할 수 있게 한다 — 저장 규칙·데이터 모델은 손대지 않는다.

**Architecture:** 판정은 순수 함수(`SiriPromptPolicy` / `SiriRecordRequest` / `SiriRecordPlanner` / `SiriSleepPlanner`), 부수효과는 얇은 껍데기(`AppIntent` / `SiriRecordRecorder`). 저장 규칙의 유일한 주인은 기존 `ActivityDraftBuilder` 이고 이 계획은 그 파일을 **수정하지 않는다**. 수면은 새 개념을 만들지 않고 앱의 기존 타이머(`ActivityTimerManager`)를 App Group 으로 옮겨 시리와 공유한다.

**Tech Stack:** Swift 5.9+ / SwiftUI / AppIntents (iOS 17 배포 타깃) / XCTest / xcodegen / Firebase(Firestore·Auth)

**Spec:** `docs/superpowers/specs/2026-08-23-siri-all-records-design.md`

## Global Constraints

이 절의 값은 **모든 태스크의 요구사항에 포함된다.**

- **배포 타깃 iOS 17.0** (`project.yml:5`). iOS 18+ 전용 API 금지.
- **데이터 모델 변경 0 · 마이그레이션 0.** `Activity` 구조체와 Firestore 스키마를 건드리지 않는다.
- **`ActivityDraftBuilder.swift` 를 수정하지 않는다.** 저장 규칙(수유량 1~500ml, 체온 34.0~43.0°C, 수면 24h)의 유일한 주인.
- **App Group = `group.com.roacompany.allcare`** — 접근은 항상 `WidgetDataStore.defaults` 를 통해서(suite 이름 단일 소스).
- **시리가 읽는 사용자 범위 App Group 키는 전부 `siri_` 접두**를 쓴다. 지우는 목록을 만들지 않기 위한 규약.
- **용어(PO 확정, 어길 수 없음)**: 짜는 행위=**유축** · 짜둔 모유를 먹인 기록=**모유(병)** · 물질명=**유축한 모유**. **'짜기' 라는 말 전면 금지**, '짜둔 모유' 금지.
- **의학 단정 텍스트 금지**(`.claude/rules/safety.md`) — 시리 응답 문구에 진단·권고를 넣지 않는다.
- **`print()` 금지** — `AppLogger` 사용. **`[String: Any]` 시그니처 금지.** View→Service 직접 호출 금지(arch R1).
- **exhaustive switch**: 새 `enum` 의 `switch` 에 `default:` 를 쓰지 않는다(새 항목이 조용히 빠지는 것을 막는 레포 관례 — `.claude/rules/swift-conventions.md`).
- **테스트는 `BabyCareTests/BabyCareTests.swift` 의 첫 `BabyCareTests` 클래스 안**(현재 5~3604줄)에 넣는다. 파일 끝에 붙이면 `BadgeEvaluatorIntegrationTests` 것이 되어 `-only-testing:BabyCareTests/BabyCareTests` 가 **0개 실행하면서 통과**한다.
- **RED 확인 시 컴파일 에러는 RED 가 아니다** — 어느 클래스에 넣든 똑같이 깨지므로 이 실수를 못 잡는다. GREEN 에서 **실행 수가 늘었는지**(현재 704) 반드시 눈으로 확인한다.
- **새 파일은 폴더에 두고 `xcodegen generate`** — 이 레포는 `project.yml` 이 정본이고 `*.xcodeproj` 는 gitignore. **pbxproj 손수술 금지.**
- **commit author = `roquejp`** (이 레포 관례. parking24 의 `roacompany` 와 다르다).
- **push · PR · 머지 · TestFlight 업로드 · App Store 제출은 PO 승인 시에만.** 이 계획은 로컬 커밋까지만 한다.

---

## File Structure

| 파일 | 책임 |
|---|---|
| `BabyCare/Models/SiriRecordKind.swift` | 시리가 받는 기록 종류(11종) ↔ `RecordTile` 매핑 |
| `BabyCare/Models/SiriPromptPolicy.swift` | 이 종류는 무엇을 되물어야 하나 (단일 판정) |
| `BabyCare/Models/SiriRecordRequest.swift` | 시리 요청 → `ActivityDraft` (순수) |
| `BabyCare/Models/SiriRecordPlanner.swift` | 기록 판정: ready / needs / notReady / invalid |
| `BabyCare/Models/SleepSession.swift` | 자는 구간 — 시작시각·길이 (순수) |
| `BabyCare/Models/SiriSleepPlanner.swift` | 수면 시작·종료 판정 (순수) |
| `BabyCare/Services/SiriSharedStore.swift` | App Group 접두 규약 + 일괄 삭제 |
| `BabyCare/Services/RunningTimerStore.swift` | 도는 타이머 App Group 스냅샷 (앱·시리 공용) |
| `BabyCare/Services/SiriRecordRecorder.swift` | 저장 부수효과 (오프라인 큐 + 계측) |
| `BabyCare/Intents/RecordActivityIntent.swift` | 기록 인텐트 + AppShortcuts |
| `BabyCare/Intents/SleepIntents.swift` | 「잠들었어」 / 「깼어」 |

**삭제**: `SiriFeedingRequest.swift` · `SiriFeedingPlanner.swift` · `SiriFeedingRecorder.swift`
**축소**: `RecordFeedingIntent.swift` (한 판 유지 · 새 판정에 위임)

---

## Task 0: 작업 브랜치

**Files:** 없음

- [ ] **Step 1: 지금 브랜치와 상태를 확인한다**

```bash
cd /Users/roque/BabyCare
git branch --show-current && git status --short
```

기대: `main` · untracked `.superpowers/`·`scripts/__pycache__/` 만(무해).
⚠️ `main` 이 아니거나 커밋되지 않은 남의 변경이 있으면 **여기서 멈추고 보고**한다.

- [ ] **Step 2: 브랜치를 만든다**

```bash
git checkout -b feat/siri-all-records
git branch --show-current   # feat/siri-all-records 여야 한다
```

---

## Task 1: 되묻기 판정 하나로 (`SiriPromptPolicy`) + 죽은 판정 정리

전 종류로 넓히려면 "이 기록은 무엇을 되물어야 하나"가 필요하다. 지금 그 성격의 판정이 다섯 군데 있고 둘은 죽었다. 새 판정 하나를 세우고, **저장 검증과 어긋나면 게이트가 빨강**이 되게 한다.

**Files:**
- Create: `BabyCare/Models/SiriRecordKind.swift`
- Create: `BabyCare/Models/SiriPromptPolicy.swift`
- Modify: `BabyCare/Models/Activity.swift` (죽은 `needsAmount` · `needsQuickInput` 제거)
- Test: `BabyCareTests/BabyCareTests.swift` (첫 클래스 안)

**Interfaces:**
- Consumes: `RecordTile`(기존) · `Activity.ActivityType`(기존) · `Activity.FeedingContent`(기존)
- Produces:
  - `enum SiriRecordKind: String, CaseIterable, Sendable` — 11 케이스, `var tile: RecordTile`
  - `enum SiriPromptPolicy` — `enum Prompt: String { amountMl, temperatureCelsius, medicationName }`, `Prompt.isRequired: Bool`, `static func prompt(for: SiriRecordKind) -> Prompt?`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`BabyCareTests/BabyCareTests.swift` 의 3603줄(첫 클래스의 닫는 `}` 바로 앞)에 넣는다.

```swift
    // MARK: - 시리 전 종류 — 되묻기 판정 ↔ 저장 검증 일치

    /// 🔑 이 테스트가 이 트랙의 안전줄이다.
    /// "안 물어도 된다"고 판정한 종류는 값 없이 저장이 통과해야 하고,
    /// "물어야 한다"고 판정한 종류는 값 없이 **거절**돼야 한다.
    /// 둘이 어긋나면 시리가 조용히 실패하거나 쓸데없이 되묻는다.
    func testSiriPromptPolicy_matchesDraftBuilderForEveryKind() {
        for kind in SiriRecordKind.allCases {
            let draft = SiriRecordRequest(kind: kind).draft(babyId: "baby-1", at: Date())
            let built = ActivityDraftBuilder.build(draft)
            let mustAsk = SiriPromptPolicy.prompt(for: kind)?.isRequired ?? false

            switch built {
            case .success:
                XCTAssertFalse(mustAsk, "\(kind.rawValue): 값 없이 저장되는데 되묻고 있다")
            case .failure:
                XCTAssertTrue(mustAsk, "\(kind.rawValue): 값 없이는 거절되는데 안 되묻는다")
            }
        }
    }

    /// 투약은 예외 — 앱도 약 이름 없이 저장된다. 물어보되 못 들으면 그냥 저장한다.
    func testSiriPromptPolicy_medicationAsksButIsNotRequired() {
        XCTAssertEqual(SiriPromptPolicy.prompt(for: .medication), .medicationName)
        XCTAssertFalse(SiriPromptPolicy.Prompt.medicationName.isRequired)
    }

    /// 값이 꼭 필요한 것 셋 — 없으면 저장이 안 되므로 반드시 되물어야 한다.
    func testSiriPromptPolicy_requiredPrompts() {
        XCTAssertEqual(SiriPromptPolicy.prompt(for: .bottleFormula), .amountMl)
        XCTAssertEqual(SiriPromptPolicy.prompt(for: .bottleBreastMilk), .amountMl)
        XCTAssertEqual(SiriPromptPolicy.prompt(for: .pumping), .amountMl)
        XCTAssertEqual(SiriPromptPolicy.prompt(for: .temperature), .temperatureCelsius)
        XCTAssertTrue(SiriPromptPolicy.Prompt.amountMl.isRequired)
        XCTAssertTrue(SiriPromptPolicy.Prompt.temperatureCelsius.isRequired)
    }

    /// 값을 안 물어도 되는 것 — 말 한마디로 저장된다.
    func testSiriPromptPolicy_instantKindsAskNothing() {
        for kind in [SiriRecordKind.breast, .solid, .snack, .diaperWet, .diaperDirty, .bath] {
            XCTAssertNil(SiriPromptPolicy.prompt(for: kind), "\(kind.rawValue) 는 되물을 게 없어야 한다")
        }
    }
```

> ⚠️ 이 테스트는 Task 2 의 `SiriRecordRequest` 를 쓴다. Task 1 에서는 **컴파일이 안 되는 상태로 두지 말고**, Task 2 를 먼저 읽고 `SiriRecordRequest` 의 최소 형태(케이스 하나에 `draft` 만)를 Task 1 에서 같이 만든다. 아래 Step 3 이 그렇게 되어 있다.

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination 'platform=iOS Simulator,arch=arm64,id=E8CF2728-092B-485D-BEF7-E959ED6B9435' \
  -only-testing:BabyCareTests/BabyCareTests 2>&1 | tail -30
```

기대: `cannot find 'SiriRecordKind' in scope` 등 컴파일 실패.
⚠️ 컴파일 실패는 아직 RED 가 아니다 — Step 4 에서 **실행 수 증가**를 확인해야 진짜 GREEN 이다.

- [ ] **Step 3: 최소 구현**

`BabyCare/Models/SiriRecordKind.swift` 새 파일:

```swift
import Foundation

/// 시리가 받는 기록 종류 — 기록 런처 타일(`RecordTile`)과 1:1 로 맞춘다.
///
/// 수면은 여기 없다: 「잠들었어」/「깼어」 두 동작이라 별도 인텐트가 맡는다(`SleepIntents`).
/// 소변+대변(`diaperBoth`)도 없다 — 런처에서 이미 뺀 타일이고 옛 기록 표시용 enum 만 남아 있다.
///
/// ⚠️ `rawValue` 는 **손님이 단축어 앱에 만들어 둔 것에 저장된다.** 바꾸면 그 단축어가 깨진다.
enum SiriRecordKind: String, CaseIterable, Sendable {
    case breast = "breast"                        // 모유
    case bottleFormula = "bottle_formula"         // 분유
    case bottleBreastMilk = "bottle_breast_milk"  // 모유(병) — 유축한 모유를 병으로 먹인 기록
    case pumping = "pumping"                      // 유축 (생산)
    case solid = "solid"                          // 이유식
    case snack = "snack"                          // 간식
    case diaperWet = "diaper_wet"                 // 소변
    case diaperDirty = "diaper_dirty"             // 대변
    case bath = "bath"                            // 목욕
    case temperature = "temperature"              // 체온
    case medication = "medication"                // 투약

    /// 런처 타일과 같은 것을 가리킨다 — 라벨·색·아이콘·저장 타입의 단일 소스.
    /// default: 없이 exhaustive 유지 — 새 종류가 조용히 빠지지 않도록.
    var tile: RecordTile {
        switch self {
        case .breast: RecordTile(.feedingBreast)
        case .bottleFormula: RecordTile(.feedingBottle, content: .formula)
        case .bottleBreastMilk: RecordTile(.feedingBottle, content: .breastMilk)
        case .pumping: RecordTile(.feedingPumping)
        case .solid: RecordTile(.feedingSolid)
        case .snack: RecordTile(.feedingSnack)
        case .diaperWet: RecordTile(.diaperWet)
        case .diaperDirty: RecordTile(.diaperDirty)
        case .bath: RecordTile(.bath)
        case .temperature: RecordTile(.temperature)
        case .medication: RecordTile(.medication)
        }
    }

    /// 시리가 말할 때 쓰는 이름 — 런처 라벨과 같은 것을 쓴다(화면과 말이 갈라지지 않게).
    var displayName: String { tile.label }
}
```

`BabyCare/Models/SiriPromptPolicy.swift` 새 파일:

```swift
import Foundation

/// 이 기록은 시리가 무엇을 되물어야 하나 — **단일 판정**.
///
/// 저장 규칙 자체는 `ActivityDraftBuilder` 가 갖고 있다. 여기는 "값이 없으면 저장이 안 되는가"를
/// 시리 쪽에서 미리 아는 자리일 뿐이고, 둘이 어긋나면
/// `testSiriPromptPolicy_matchesDraftBuilderForEveryKind` 가 빨강으로 잡는다.
enum SiriPromptPolicy {
    /// 시리가 되물을 값.
    enum Prompt: String, Equatable, Sendable {
        case amountMl
        case temperatureCelsius
        case medicationName

        /// 값이 없으면 `ActivityDraftBuilder` 가 **거절하는가**.
        /// false = 물어는 보되, 못 들으면 그냥 저장한다(조용히 실패시키지 않는다).
        var isRequired: Bool {
            switch self {
            case .amountMl, .temperatureCelsius: true
            case .medicationName: false   // 앱도 약 이름 없이 저장된다
            }
        }

        /// 시리가 되물을 때 하는 말.
        var requestDialog: String {
            switch self {
            case .amountMl: "몇 ml 인가요?"
            case .temperatureCelsius: "몇 도인가요?"
            case .medicationName: "어떤 약인가요?"
            }
        }
    }

    /// default: 없이 exhaustive 유지 — 새 종류가 조용히 "안 물어봄"으로 떨어지지 않도록.
    static func prompt(for kind: SiriRecordKind) -> Prompt? {
        switch kind {
        case .breast, .solid, .snack, .diaperWet, .diaperDirty, .bath:
            return nil
        case .bottleFormula, .bottleBreastMilk, .pumping:
            return .amountMl
        case .temperature:
            return .temperatureCelsius
        case .medication:
            return .medicationName
        }
    }
}
```

`BabyCare/Models/SiriRecordRequest.swift` 새 파일 (Task 2 에서 문구·테스트가 더 붙는다):

```swift
import Foundation

/// 시리로 받은 기록 요청 → 기존 저장 판정(`ActivityDraftBuilder`)이 그대로 먹는 순수 스냅샷.
///
/// 저장 규칙을 여기서 다시 쓰지 않는다 — **판정은 하나**.
struct SiriRecordRequest: Sendable {
    let kind: SiriRecordKind
    let amountMl: Int?
    let temperatureCelsius: Double?
    let medicationName: String?

    init(kind: SiriRecordKind,
         amountMl: Int? = nil,
         temperatureCelsius: Double? = nil,
         medicationName: String? = nil) {
        self.kind = kind
        self.amountMl = amountMl
        self.temperatureCelsius = temperatureCelsius
        self.medicationName = medicationName
    }

    /// 되물어야 할 값이 아직 없으면 그 Prompt 를 돌려준다(없으면 nil = 바로 저장 가능).
    var missingRequiredPrompt: SiriPromptPolicy.Prompt? {
        guard let prompt = SiriPromptPolicy.prompt(for: kind), prompt.isRequired else { return nil }
        switch prompt {
        case .amountMl: return amountMl == nil ? prompt : nil
        case .temperatureCelsius: return temperatureCelsius == nil ? prompt : nil
        case .medicationName: return nil   // 필수가 아니다
        }
    }

    /// default: 없이 exhaustive 유지 — 새 종류가 조용히 "아무 값도 안 실림"으로 떨어지지 않도록.
    func draft(babyId: String, at date: Date) -> ActivityDraft {
        var d = ActivityDraft(babyId: babyId, type: kind.tile.type, startTime: date)
        d.source = .siri   // 진입점이 스스로 선언한다 — 호출부가 적지 않는다

        switch kind {
        case .breast, .solid, .snack, .diaperWet, .diaperDirty, .bath:
            break
        case .bottleFormula, .bottleBreastMilk:
            d.feedingContent = kind.tile.contentPreset ?? .formula
            if let amountMl { d.amountText = String(amountMl) }
        case .pumping:
            if let amountMl { d.amountText = String(amountMl) }
        case .temperature:
            if let temperatureCelsius { d.temperatureText = String(temperatureCelsius) }
        case .medication:
            if let medicationName, !medicationName.trimmingCharacters(in: .whitespaces).isEmpty {
                d.medicationName = medicationName
            }
        }
        return d
    }
}
```

`BabyCare/Models/Activity.swift` — 죽은 판정 2개를 지운다. `var needsAmount: Bool { ... }` 블록 전체와 `var needsQuickInput: Bool { ... }` 블록 전체를 삭제한다(프로덕션 호출 0 · `RecordEntryRule` 이 대체함). `needsTimer` 는 뷰가 쓰고 있으므로 **남긴다**.

`BabyCareTests/BabyCareTests.swift` — 지운 판정을 못박은 옛 단언도 같이 지운다:
- 76~77줄 `XCTAssertTrue(Activity.ActivityType.feedingPumping.needsAmount, ...)`
- 78~79줄 `XCTAssertTrue(Activity.ActivityType.feedingPumping.needsQuickInput, ...)`
- 172줄 `XCTAssertFalse(Activity.ActivityType.unknown.needsAmount)`
- 173줄 `XCTAssertFalse(Activity.ActivityType.unknown.needsQuickInput)`

⚠️ 지우기 전에 반드시 재확인한다(새로 생겼을 수 있다):

```bash
cd /Users/roque/BabyCare && grep -rn "needsAmount\|needsQuickInput" --include="*.swift" BabyCare/ BabyCareTests/
```

- [ ] **Step 4: 프로젝트 재생성 + 테스트 통과 확인**

```bash
cd /Users/roque/BabyCare && xcodegen generate && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination 'platform=iOS Simulator,arch=arm64,id=E8CF2728-092B-485D-BEF7-E959ED6B9435' \
  -only-testing:BabyCareTests/BabyCareTests 2>&1 | tail -20
```

기대: PASS. **Executed 수가 704 보다 커야 한다** — 눈으로 확인한다. 같거나 작으면 테스트가 엉뚱한 클래스에 들어간 것이다.

- [ ] **Step 5: 커밋**

```bash
cd /Users/roque/BabyCare && git add \
  BabyCare/Models/SiriRecordKind.swift \
  BabyCare/Models/SiriPromptPolicy.swift \
  BabyCare/Models/SiriRecordRequest.swift \
  BabyCare/Models/Activity.swift \
  BabyCareTests/BabyCareTests.swift
git commit -m "feat(siri): 되묻기 판정을 하나로 — SiriPromptPolicy + 죽은 needs* 2종 정리"
```

---

## Task 2: 종류 누락 방지 — 런처에 있으면 시리에도 있어야 한다

이름을 열거하면 새 것이 조용히 빠진다(같은 결함 3회). 종류 목록을 **대조로** 잠근다.

**Files:**
- Test: `BabyCareTests/BabyCareTests.swift` (첫 클래스 안)

**Interfaces:**
- Consumes: `SiriRecordKind`(Task 1) · `RecordTile.launcherSections`(기존)
- Produces: 없음 (게이트 전용)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```swift
    /// 🩸 이름을 열거하면 새 것이 조용히 빠진다 — 대조로 잠근다.
    /// 기록 런처에 타일을 하나 추가하면 이 테스트가 빨강이 되어 시리에도 넣게 만든다.
    func testSiriRecordKind_coversEveryLauncherTileExceptSleep() {
        let launcher = Set(RecordTile.launcherSections.flatMap(\.tiles).map(\.id))
        let siri = Set(SiriRecordKind.allCases.map(\.tile.id))
        let sleep = RecordTile(.sleep).id   // 수면은 「잠들었어」/「깼어」 전용 인텐트가 맡는다

        XCTAssertEqual(launcher.subtracting(siri), [sleep],
                       "런처에 있는데 시리로 못 하는 기록이 있다 — SiriRecordKind 에 추가할 것")
        XCTAssertTrue(siri.subtracting(launcher).isEmpty,
                      "시리에만 있고 런처에 없는 기록이 있다 — 손님이 화면에서 못 찾는다")
    }

    /// 시리가 말하는 이름은 화면 라벨과 같아야 한다(용어가 갈라지지 않게).
    func testSiriRecordKind_displayNameMatchesLauncherLabel() {
        XCTAssertEqual(SiriRecordKind.bottleBreastMilk.displayName, "모유(병)")
        XCTAssertEqual(SiriRecordKind.bottleFormula.displayName, "분유")
        XCTAssertEqual(SiriRecordKind.pumping.displayName, "유축")
        XCTAssertEqual(SiriRecordKind.diaperWet.displayName, "소변")
    }
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination 'platform=iOS Simulator,arch=arm64,id=E8CF2728-092B-485D-BEF7-E959ED6B9435' \
  -only-testing:BabyCareTests/BabyCareTests/testSiriRecordKind_coversEveryLauncherTileExceptSleep 2>&1 | tail -15
```

기대: PASS **또는** 어떤 타일이 빠졌다는 실패. 실패하면 Task 1 의 `SiriRecordKind` 에 그 종류를 추가한다(11 케이스가 맞는지 여기서 확정된다).

- [ ] **Step 3: 통과할 때까지 `SiriRecordKind` 를 맞춘다**

`launcher.subtracting(siri)` 가 수면 하나만 남을 때까지 케이스를 더한다. 반대 방향(`siri.subtracting(launcher)`)이 비지 않으면 런처에 없는 종류를 넣은 것이니 뺀다.

- [ ] **Step 4: 전체 테스트 통과 확인**

```bash
cd /Users/roque/BabyCare && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination 'platform=iOS Simulator,arch=arm64,id=E8CF2728-092B-485D-BEF7-E959ED6B9435' \
  -only-testing:BabyCareTests/BabyCareTests 2>&1 | tail -20
```

기대: PASS · Executed 수 증가.

- [ ] **Step 5: 커밋**

```bash
cd /Users/roque/BabyCare && git add BabyCare/Models/SiriRecordKind.swift BabyCareTests/BabyCareTests.swift
git commit -m "test(siri): 런처 타일이 시리 종류에 빠지면 빨강이 되게 — 이름 열거 대신 대조"
```

---

## Task 3: 기록 판정 (`SiriRecordPlanner`)

`SiriFeedingPlanner` 를 전 종류용으로 다시 세운다. 부수효과 없음.

**Files:**
- Create: `BabyCare/Models/SiriRecordPlanner.swift`
- Delete: `BabyCare/Models/SiriFeedingPlanner.swift` · `BabyCare/Models/SiriFeedingRequest.swift`
- Test: `BabyCareTests/BabyCareTests.swift`

**Interfaces:**
- Consumes: `SiriRecordContext`(기존) · `SiriRecordRequest`(Task 1) · `SiriPromptPolicy`(Task 1) · `ActivityDraftBuilder`(기존) · `FirestoreCollections.babyChildPath(userId:babyId:collection:)`(기존)
- Produces:
  - `struct SiriRecordPlanner.Plan: Equatable { let activity: Activity; let collectionPath: String; let dialog: String }`
  - `enum SiriRecordPlanner.Outcome: Equatable { case ready(Plan), needs(SiriPromptPolicy.Prompt), notReady(SiriRecordContext.Reason), invalid(String) }`
  - `static func plan(context:request:now:) -> Outcome`
  - `static func dialog(kind:amountMl:temperatureCelsius:babyName:) -> String`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

기존 `testSiriFeeding_*` 테스트 5개(3291~3336줄 부근)를 **지우고** 아래로 교체한다. 지우기 전에 위치를 확인한다:

```bash
cd /Users/roque/BabyCare && grep -n "func testSiriFeeding_" BabyCareTests/BabyCareTests.swift
```

```swift
    // MARK: - 시리 전 종류 — 판정

    /// 값이 필요 없는 종류는 한마디로 저장된다.
    func testSiriRecordPlanner_instantKindIsReady() {
        let out = SiriRecordPlanner.plan(
            context: .ready(ownerUserId: "owner-1", babyId: "baby-1", babyName: "서준"),
            request: SiriRecordRequest(kind: .diaperWet),
            now: Date()
        )
        guard case .ready(let plan) = out else { return XCTFail("소변은 값 없이 기록되어야 한다") }
        XCTAssertEqual(plan.activity.type, .diaperWet)
        XCTAssertEqual(plan.activity.source, .siri)
        XCTAssertEqual(plan.collectionPath, "users/owner-1/babies/baby-1/activities")
        XCTAssertEqual(plan.dialog, "서준의 소변을 기록했어요")
    }

    /// 유축은 양이 있어야 저장된다 → 시리가 되물어야 한다.
    func testSiriRecordPlanner_pumpingWithoutAmountAsks() {
        let out = SiriRecordPlanner.plan(
            context: .ready(ownerUserId: "o", babyId: "b", babyName: nil),
            request: SiriRecordRequest(kind: .pumping),
            now: Date()
        )
        XCTAssertEqual(out, .needs(.amountMl))
    }

    func testSiriRecordPlanner_pumpingWithAmountIsReady() {
        let out = SiriRecordPlanner.plan(
            context: .ready(ownerUserId: "o", babyId: "b", babyName: nil),
            request: SiriRecordRequest(kind: .pumping, amountMl: 90),
            now: Date()
        )
        guard case .ready(let plan) = out else { return XCTFail("양이 있는 유축은 기록되어야 한다") }
        XCTAssertEqual(plan.activity.amount, 90)
        XCTAssertEqual(plan.activity.type, .feedingPumping)
        XCTAssertEqual(plan.dialog, "유축 90ml를 기록했어요")
    }

    /// 체온도 되묻는다. 범위 밖이면 **폼과 같은 문구**로 거절한다.
    func testSiriRecordPlanner_temperatureAsksThenValidates() {
        let ctx = SiriRecordContext.ready(ownerUserId: "o", babyId: "b", babyName: nil)
        XCTAssertEqual(SiriRecordPlanner.plan(context: ctx,
                                              request: SiriRecordRequest(kind: .temperature),
                                              now: Date()),
                       .needs(.temperatureCelsius))

        let tooHigh = SiriRecordPlanner.plan(context: ctx,
                                             request: SiriRecordRequest(kind: .temperature, temperatureCelsius: 50),
                                             now: Date())
        XCTAssertEqual(tooHigh, .invalid(RecordValidationError.invalidTemperature.message))

        guard case .ready(let plan) = SiriRecordPlanner.plan(
            context: ctx,
            request: SiriRecordRequest(kind: .temperature, temperatureCelsius: 37.5),
            now: Date()
        ) else { return XCTFail("정상 체온은 기록되어야 한다") }
        XCTAssertEqual(plan.activity.temperature, 37.5)
    }

    /// 투약은 이름을 못 들어도 저장된다 — 조용히 실패시키지 않는다.
    func testSiriRecordPlanner_medicationSavesWithoutName() {
        guard case .ready(let plan) = SiriRecordPlanner.plan(
            context: .ready(ownerUserId: "o", babyId: "b", babyName: nil),
            request: SiriRecordRequest(kind: .medication),
            now: Date()
        ) else { return XCTFail("약 이름이 없어도 투약은 기록되어야 한다") }
        XCTAssertEqual(plan.activity.type, .medication)
        XCTAssertNil(plan.activity.medicationName)
    }

    /// 병수유 양이 범위 밖이면 폼과 같은 문구로 거절한다.
    func testSiriRecordPlanner_bottleAmountOutOfRangeIsRejected() {
        let out = SiriRecordPlanner.plan(
            context: .ready(ownerUserId: "o", babyId: "b", babyName: nil),
            request: SiriRecordRequest(kind: .bottleFormula, amountMl: 900),
            now: Date()
        )
        XCTAssertEqual(out, .invalid(RecordValidationError.invalidAmount(isPumping: false).message))
    }

    /// 로그인·아기 선택이 안 됐으면 무엇을 해야 하는지 알려준다.
    func testSiriRecordPlanner_notReadyPassesReasonThrough() {
        XCTAssertEqual(SiriRecordPlanner.plan(context: .notReady(.noAccount),
                                              request: SiriRecordRequest(kind: .bath),
                                              now: Date()),
                       .notReady(.noAccount))
        XCTAssertEqual(SiriRecordPlanner.plan(context: .notReady(.noBaby),
                                              request: SiriRecordRequest(kind: .bath),
                                              now: Date()),
                       .notReady(.noBaby))
    }

    /// 아기 이름이 없으면 이름 없이 말한다(기록은 된다).
    func testSiriRecordPlanner_dialogWithoutBabyName() {
        XCTAssertEqual(SiriRecordPlanner.dialog(kind: .bath, amountMl: nil,
                                                temperatureCelsius: nil, babyName: nil),
                       "목욕을 기록했어요")
    }

    /// 용어 한 벌 — 유축한 모유를 먹인 기록의 이름은 '모유(병)'.
    func testSiriRecordPlanner_breastMilkBottleKeepsTerm() {
        guard case .ready(let plan) = SiriRecordPlanner.plan(
            context: .ready(ownerUserId: "o", babyId: "b", babyName: nil),
            request: SiriRecordRequest(kind: .bottleBreastMilk, amountMl: 100),
            now: Date()
        ) else { return XCTFail("모유(병)은 기록되어야 한다") }
        XCTAssertTrue(plan.activity.isBreastMilkBottle)
        XCTAssertEqual(plan.activity.displayLabel, "모유(병)")
        XCTAssertEqual(plan.dialog, "모유(병) 100ml를 기록했어요")
    }
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination 'platform=iOS Simulator,arch=arm64,id=E8CF2728-092B-485D-BEF7-E959ED6B9435' \
  -only-testing:BabyCareTests/BabyCareTests 2>&1 | tail -20
```

기대: `cannot find 'SiriRecordPlanner' in scope`.

- [ ] **Step 3: 구현**

`BabyCare/Models/SiriRecordPlanner.swift` 새 파일:

```swift
import Foundation

/// 시리 기록의 **판정** — 부수효과 없음(저장은 호출부가 한다).
///
/// 저장 규칙(양 범위·체온 범위·타입별 필드)은 `ActivityDraftBuilder` 를 그대로 쓴다.
/// 시리가 폼과 다른 규칙을 갖게 되면 두 경로가 갈라진다 — **판정은 하나**.
enum SiriRecordPlanner {
    struct Plan: Equatable {
        let activity: Activity
        /// 소유자 경로 — 가족 공유 아기면 소유자 uid 아래에 쓴다.
        let collectionPath: String
        /// 시리가 말할 문구.
        let dialog: String
    }

    enum Outcome: Equatable {
        case ready(Plan)
        /// 값이 있어야 저장되는데 안 말했다 → 시리가 되물어야 한다.
        case needs(SiriPromptPolicy.Prompt)
        /// 로그인/아기 선택이 안 돼 기록할 곳이 없다.
        case notReady(SiriRecordContext.Reason)
        /// 기존 저장 판정이 거절 — 문구는 폼과 같은 것을 쓴다.
        case invalid(String)
    }

    static func plan(context: SiriRecordContext, request: SiriRecordRequest, now: Date) -> Outcome {
        switch context {
        case .notReady(let reason):
            return .notReady(reason)

        case .ready(let ownerUserId, let babyId, let babyName):
            if let missing = request.missingRequiredPrompt { return .needs(missing) }

            switch ActivityDraftBuilder.build(request.draft(babyId: babyId, at: now)) {
            case .failure(let error):
                return .invalid(error.message)
            case .success(let activity):
                return .ready(Plan(
                    activity: activity,
                    collectionPath: FirestoreCollections.babyChildPath(
                        userId: ownerUserId,
                        babyId: babyId,
                        collection: FirestoreCollections.activities
                    ),
                    dialog: dialog(kind: request.kind,
                                   amountMl: request.amountMl,
                                   temperatureCelsius: request.temperatureCelsius,
                                   babyName: babyName)
                ))
            }
        }
    }

    /// 조사 문제를 피해 "…의 …를 기록했어요" 로 고정한다(이름이 무엇이든 자연스럽다).
    /// default: 없이 exhaustive 유지.
    static func dialog(kind: SiriRecordKind,
                       amountMl: Int?,
                       temperatureCelsius: Double?,
                       babyName: String?) -> String {
        let label: String
        switch kind {
        case .breast:
            label = "모유 수유"
        case .bottleFormula, .bottleBreastMilk, .pumping:
            label = "\(kind.displayName) \(amountMl ?? 0)ml"
        case .temperature:
            label = "체온 \(Self.formatted(temperatureCelsius ?? 0))도"
        case .solid, .snack, .diaperWet, .diaperDirty, .bath, .medication:
            label = kind.displayName
        }
        let prefix = babyName.map { "\($0)의 " } ?? ""
        return "\(prefix)\(label)를 기록했어요"
    }

    /// 37.0 은 "37", 37.5 는 "37.5" 로 읽는다.
    private static func formatted(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(value)
    }
}
```

기존 `BabyCare/Models/SiriFeedingPlanner.swift` 와 `BabyCare/Models/SiriFeedingRequest.swift` 를 삭제한다:

```bash
cd /Users/roque/BabyCare && git rm BabyCare/Models/SiriFeedingPlanner.swift BabyCare/Models/SiriFeedingRequest.swift
```

⚠️ 삭제하면 `RecordFeedingIntent.swift` 와 `SiriFeedingRecorder.swift` 가 깨진다 — Task 7·8 에서 고친다. **이 태스크의 GREEN 은 Task 8 이후에 확정된다.** Step 4 에서 컴파일이 깨지면 정상이며, Task 7·8 을 이어서 한다.

- [ ] **Step 4: 컴파일 상태 확인 (아직 빨강일 수 있다)**

```bash
cd /Users/roque/BabyCare && xcodegen generate && xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare \
  -destination 'platform=iOS Simulator,arch=arm64,id=E8CF2728-092B-485D-BEF7-E959ED6B9435' 2>&1 | grep -E "error:" | head -10
```

기대: `RecordFeedingIntent.swift` / `SiriFeedingRecorder.swift` 의 에러만. 다른 파일 에러가 있으면 멈추고 원인을 본다.

- [ ] **Step 5: 커밋하지 않는다**

Task 7·8 로 이어간다(중간 커밋하면 빌드가 깨진 커밋이 남는다).

---

## Task 4: App Group 접두 규약 (`SiriSharedStore`)

로그아웃 정리가 "지울 것을 이름으로 나열"하는 자리라, 항목을 더하면 나중에 조용히 빠진다. **접두로 싹 지우는** 방식으로 바꿔 목록 자체를 없앤다.

**Files:**
- Create: `BabyCare/Services/SiriSharedStore.swift`
- Modify: `BabyCare/App/AppState.swift` (`SiriRecordContextStore.clear()` → `SiriSharedStore.clearAll()`)
- Test: `BabyCareTests/BabyCareTests.swift`

**Interfaces:**
- Consumes: `WidgetDataStore.defaults`(기존)
- Produces: `enum SiriSharedStore` — `static let userScopedPrefix = "siri_"`, `static func clearAll()`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```swift
    // MARK: - 시리 App Group — 접두 규약으로 일괄 삭제

    /// 🩸 지울 것을 이름으로 나열하면 나중에 생긴 것이 조용히 빠진다(같은 결함 3회).
    /// 접두가 붙은 키는 **이름을 몰라도** 지워져야 한다.
    func testSiriSharedStore_clearsAnyPrefixedKeyEvenUnknownOnes() {
        let unknownKey = "siri_future_thing_nobody_listed"
        WidgetDataStore.defaults.set("x", forKey: unknownKey)

        SiriSharedStore.clearAll()

        XCTAssertNil(WidgetDataStore.defaults.object(forKey: unknownKey),
                     "siri_ 접두 키는 목록에 없어도 지워져야 한다")
    }

    /// 접두가 없는 값(위젯 데이터 등)은 건드리지 않는다.
    func testSiriSharedStore_leavesNonPrefixedKeysAlone() {
        let widgetKey = "widget_last_feeding_placeholder_test"
        WidgetDataStore.defaults.set("keep", forKey: widgetKey)

        SiriSharedStore.clearAll()

        XCTAssertEqual(WidgetDataStore.defaults.string(forKey: widgetKey), "keep")
        WidgetDataStore.defaults.removeObject(forKey: widgetKey)
    }

    /// 🔒 기존 계약 유지 — 로그아웃 뒤 시리가 이전 계정 경로에 쓰면 안 된다.
    func testSiriSharedStore_clearAllAlsoClearsRecordContext() {
        SiriRecordContextStore.update(ownerUserId: "owner-9", babyId: "baby-9", babyName: "하윤")
        SiriSharedStore.clearAll()
        XCTAssertEqual(SiriRecordContextStore.current(), .notReady(.noAccount))
    }
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination 'platform=iOS Simulator,arch=arm64,id=E8CF2728-092B-485D-BEF7-E959ED6B9435' \
  -only-testing:BabyCareTests/BabyCareTests 2>&1 | grep -E "error:|cannot find" | head -5
```

기대: `cannot find 'SiriSharedStore' in scope`.

- [ ] **Step 3: 구현**

`BabyCare/Services/SiriSharedStore.swift` 새 파일:

```swift
import Foundation

/// 시리(App Intents)가 앱과 나눠 쓰는 App Group 값의 **정리 담당**.
///
/// 🩸 지울 것을 이름으로 나열하지 않는다. `AppState.resetUserScopedState` 처럼 목록을 적는 자리는
///    나중에 생긴 항목이 조용히 빠진다(같은 결함을 세 번 겪었다).
///    대신 **접두 규약**을 쓴다 — 시리가 읽는 사용자 범위 값은 전부 `siri_` 로 시작하고,
///    여기서는 접두가 붙은 키를 전부 지운다. 새 키가 생겨도 이 파일은 안 고쳐도 된다.
///
/// ⚠️ 새 시리 공유 값을 만들 때는 **반드시 `siri_` 로 시작하는 키**를 쓸 것.
enum SiriSharedStore {
    static let userScopedPrefix = "siri_"

    /// 로그아웃·계정 전환에서 호출 (`AppState.resetUserScopedState`).
    static func clearAll() {
        let defaults = WidgetDataStore.defaults
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(userScopedPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
```

`BabyCare/App/AppState.swift` — 마지막 줄을 교체한다(**목록에 항목을 더하지 않는다**):

```swift
        OfflineQueue.shared.clear()
        // 시리(App Intents)가 App Group 에 남긴 사용자 범위 값 일괄 삭제.
        // 안 지우면 로그아웃 뒤에도 시리가 이전 계정 경로에 계속 쓴다(큐를 비우는 것만으로는 못 막는다).
        // 🔑 여기에 항목을 나열하지 않는다 — 새 시리 값은 `siri_` 접두를 쓰면 자동으로 지워진다.
        SiriSharedStore.clearAll()
```

- [ ] **Step 4: 통과 확인**

```bash
cd /Users/roque/BabyCare && xcodegen generate && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination 'platform=iOS Simulator,arch=arm64,id=E8CF2728-092B-485D-BEF7-E959ED6B9435' \
  -only-testing:BabyCareTests/BabyCareTests 2>&1 | tail -20
```

기대: 새 3개 PASS. (Task 3 때문에 다른 곳이 아직 빨강일 수 있다 — Task 8 에서 해소된다.)

- [ ] **Step 5: 커밋하지 않는다** — Task 8 이후 한 번에 커밋한다.

---

## Task 5: 도는 타이머를 앱·시리가 같이 본다 (`RunningTimerStore`)

지금 타이머 상태는 `UserDefaults.standard` 에 있고 시리 컨텍스트는 App Group 에 있다. 저장소가 둘이라 시리가 수면 타이머를 못 본다. **App Group 으로 옮기고 1회 이관**한다.

**Files:**
- Create: `BabyCare/Models/SleepSession.swift`
- Create: `BabyCare/Services/RunningTimerStore.swift`
- Modify: `BabyCare/Services/ActivityTimerManager.swift:22-23, 36-38, 71-73, 84-103`
- Test: `BabyCareTests/BabyCareTests.swift`

**Interfaces:**
- Consumes: `WidgetDataStore.defaults`(기존) · `Activity.ActivityType.known(rawValue:)`(기존) · `AppConstants.secondsPerDay`(기존, 86_400)
- Produces:
  - `struct RunningTimer: Equatable, Sendable { let type: Activity.ActivityType; let startedAt: Date }`
  - `enum RunningTimerStore` — `static func current() -> RunningTimer?`, `static func start(type:at:)`, `static func clear()`, `static func migrateFromStandardDefaultsIfNeeded()`
  - `struct SleepSession: Equatable, Sendable { let startedAt: Date; func duration(now: Date) -> TimeInterval }`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```swift
    // MARK: - 도는 타이머 — 앱과 시리가 같은 것을 본다

    func testRunningTimerStore_roundTrip() {
        RunningTimerStore.clear()
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        RunningTimerStore.start(type: .sleep, at: started)

        XCTAssertEqual(RunningTimerStore.current(), RunningTimer(type: .sleep, startedAt: started))
        RunningTimerStore.clear()
        XCTAssertNil(RunningTimerStore.current())
    }

    /// forward-compat 센티넬은 타이머로 되살리지 않는다(영속 금지와 같은 원칙).
    func testRunningTimerStore_rejectsUnknownType() {
        RunningTimerStore.clear()
        WidgetDataStore.defaults.set(Date().timeIntervalSince1970, forKey: "siri_timer_start")
        WidgetDataStore.defaults.set("unknown", forKey: "siri_timer_type")
        XCTAssertNil(RunningTimerStore.current())
        RunningTimerStore.clear()
    }

    /// 🩸 업데이트 순간 자고 있던 아기의 타이머를 잃지 않는다 — 옛 자리에서 한 번 옮겨 온다.
    func testRunningTimerStore_migratesFromStandardDefaultsOnce() {
        RunningTimerStore.clear()
        let started = Date().addingTimeInterval(-3600)
        UserDefaults.standard.set(started.timeIntervalSince1970, forKey: "babycare_timer_start")
        UserDefaults.standard.set(Activity.ActivityType.sleep.rawValue, forKey: "babycare_timer_type")

        RunningTimerStore.migrateFromStandardDefaultsIfNeeded()

        XCTAssertEqual(RunningTimerStore.current()?.type, .sleep)
        XCTAssertNil(UserDefaults.standard.object(forKey: "babycare_timer_start"),
                     "옮긴 뒤 옛 자리는 비워야 두 곳이 갈라지지 않는다")
        RunningTimerStore.clear()
    }

    /// 🔒 로그아웃하면 타이머 상태도 사라져야 한다 — 접두 규약 덕에 저절로 된다.
    func testRunningTimerStore_clearedByClearAll() {
        RunningTimerStore.start(type: .sleep, at: Date())
        SiriSharedStore.clearAll()
        XCTAssertNil(RunningTimerStore.current())
    }

    // MARK: - 자는 구간

    func testSleepSession_durationIsElapsedTime() {
        let started = Date(timeIntervalSince1970: 1_700_000_000)
        let session = SleepSession(startedAt: started)
        XCTAssertEqual(session.duration(now: started.addingTimeInterval(3600)), 3600, accuracy: 0.001)
    }
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination 'platform=iOS Simulator,arch=arm64,id=E8CF2728-092B-485D-BEF7-E959ED6B9435' \
  -only-testing:BabyCareTests/BabyCareTests 2>&1 | grep -E "cannot find" | head -5
```

기대: `cannot find 'RunningTimerStore' in scope` · `cannot find 'SleepSession' in scope`.

- [ ] **Step 3: 구현**

`BabyCare/Models/SleepSession.swift` 새 파일:

```swift
import Foundation

/// 자고 있는 구간 — 시작만 있고 아직 안 끝난 상태.
/// 끝나는 순간 `ActivityDraftBuilder` 가 24시간 초과를 거절하므로 여기서 규칙을 다시 쓰지 않는다.
struct SleepSession: Equatable, Sendable {
    let startedAt: Date

    func duration(now: Date) -> TimeInterval { now.timeIntervalSince(startedAt) }
}
```

`BabyCare/Services/RunningTimerStore.swift` 새 파일:

```swift
import Foundation

/// 지금 도는 타이머 — 앱(`ActivityTimerManager`)과 시리(App Intents)가 **같은 것을 본다**.
///
/// 앱 안에만 있던 상태를 App Group 으로 옮긴 이유: 시리는 앱 화면 없이 도는 별도 진입점이라
/// ViewModel 을 못 본다. 두 곳에 따로 두면 「잠들었어」와 앱 배너가 갈라진다 — **판정은 하나**.
///
/// 키는 `siri_` 접두 규약을 따른다 → 로그아웃 시 `SiriSharedStore.clearAll()` 이 저절로 지운다.
struct RunningTimer: Equatable, Sendable {
    let type: Activity.ActivityType
    let startedAt: Date
}

enum RunningTimerStore {
    private enum Keys {
        static let start = "siri_timer_start"
        static let type = "siri_timer_type"
    }

    /// 옮겨오기 전 자리(앱 전용이던 시절). 이관 뒤에는 쓰지 않는다.
    private enum LegacyKeys {
        static let start = "babycare_timer_start"
        static let type = "babycare_timer_type"
    }

    private static var defaults: UserDefaults { WidgetDataStore.defaults }

    static func current() -> RunningTimer? {
        let interval = defaults.double(forKey: Keys.start)
        guard interval > 0,
              let raw = defaults.string(forKey: Keys.type),
              let type = Activity.ActivityType.known(rawValue: raw) else { return nil }
        return RunningTimer(type: type, startedAt: Date(timeIntervalSince1970: interval))
    }

    static func start(type: Activity.ActivityType, at date: Date) {
        guard type != .unknown else { return }
        defaults.set(date.timeIntervalSince1970, forKey: Keys.start)
        defaults.set(type.rawValue, forKey: Keys.type)
    }

    static func clear() {
        defaults.removeObject(forKey: Keys.start)
        defaults.removeObject(forKey: Keys.type)
    }

    /// 🩸 업데이트 순간 타이머가 돌고 있었다면 잃지 않도록 옛 자리에서 한 번 옮겨 온다.
    /// 옮긴 뒤 옛 자리를 비워 두 곳이 갈라지지 않게 한다.
    static func migrateFromStandardDefaultsIfNeeded() {
        let legacyInterval = UserDefaults.standard.double(forKey: LegacyKeys.start)
        guard legacyInterval > 0 else { return }
        defer {
            UserDefaults.standard.removeObject(forKey: LegacyKeys.start)
            UserDefaults.standard.removeObject(forKey: LegacyKeys.type)
        }
        guard defaults.double(forKey: Keys.start) == 0,
              let raw = UserDefaults.standard.string(forKey: LegacyKeys.type),
              let type = Activity.ActivityType.known(rawValue: raw) else { return }
        start(type: type, at: Date(timeIntervalSince1970: legacyInterval))
    }
}
```

`BabyCare/Services/ActivityTimerManager.swift` 수정 — 저장소를 `RunningTimerStore` 로 바꾼다:

1. 22~23줄의 `timerStartKey` / `timerTypeKey` 상수 2개를 **삭제**한다.
2. `startTimer(type:)` 안 36~38줄의 `UserDefaults.standard.set(...)` 두 줄을 아래로 바꾼다:

```swift
        // 앱과 시리가 같은 것을 본다(App Group) — 앱 강제 종료 후 복구용이기도 하다.
        RunningTimerStore.start(type: type, at: startTime)
```

3. `stopTimer()` 안 71~73줄의 `removeObject` 두 줄을 아래로 바꾼다:

```swift
        RunningTimerStore.clear()
```

4. `resumeTimerIfNeeded()` 의 84~103줄 앞부분을 아래로 바꾼다(24시간 가드·Live Activity 정리는 그대로 유지):

```swift
    @discardableResult
    func resumeTimerIfNeeded() -> (type: Activity.ActivityType, startTime: Date)? {
        RunningTimerStore.migrateFromStandardDefaultsIfNeeded()

        guard let running = RunningTimerStore.current() else {
            // 복구할 타이머 없음 — 시스템에 leftover Live Activity가 있으면 정리
            LiveActivityManager.shared.reconcileWithRunningTimer(isTimerRunning: false)
            return nil
        }

        let startTime = running.startedAt
        let type = running.type
        let elapsed = Date().timeIntervalSince(startTime)

        // 24시간 이상 지난 타이머는 복구하지 않음 (비정상 상태)
        guard elapsed < AppConstants.secondsPerDay else {
            RunningTimerStore.clear()
            LiveActivityManager.shared.reconcileWithRunningTimer(isTimerRunning: false)
            return nil
        }
```

(그 아래 `isTimerRunning = true` 부터 끝까지는 **그대로 둔다**.)

- [ ] **Step 4: 통과 확인**

```bash
cd /Users/roque/BabyCare && xcodegen generate && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination 'platform=iOS Simulator,arch=arm64,id=E8CF2728-092B-485D-BEF7-E959ED6B9435' \
  -only-testing:BabyCareTests/BabyCareTests 2>&1 | tail -20
```

옛 키가 코드에 남지 않았는지 확인한다:

```bash
cd /Users/roque/BabyCare && grep -rn "babycare_timer_" --include="*.swift" BabyCare/
```

기대: `RunningTimerStore.swift` 의 `LegacyKeys` 두 줄만.

- [ ] **Step 5: 커밋하지 않는다** — Task 8 이후 한 번에.

---

## Task 6: 수면 판정 (`SiriSleepPlanner`)

**Files:**
- Create: `BabyCare/Models/SiriSleepPlanner.swift`
- Test: `BabyCareTests/BabyCareTests.swift`

**Interfaces:**
- Consumes: `SiriRecordContext`(기존) · `RunningTimer`(Task 5) · `SleepSession`(Task 5) · `ActivityDraftBuilder`(기존) · `SiriRecordPlanner.Plan`(Task 3)
- Produces:
  - `enum SiriSleepPlanner.Outcome: Equatable { case start(dialog: String), alreadySleeping(dialog: String), busy(dialog: String), save(SiriRecordPlanner.Plan), notSleeping(dialog: String), notReady(SiriRecordContext.Reason), invalid(String) }`
  - `static func planStart(context:running:now:) -> Outcome`
  - `static func planStop(context:running:now:) -> Outcome`

- [ ] **Step 1: 실패하는 테스트를 쓴다**

```swift
    // MARK: - 시리 수면 — 「잠들었어」 / 「깼어」

    private var sleepCtx: SiriRecordContext {
        .ready(ownerUserId: "owner-1", babyId: "baby-1", babyName: "서준")
    }

    func testSiriSleep_startWhenNothingRunning() {
        let out = SiriSleepPlanner.planStart(context: sleepCtx, running: nil, now: Date())
        XCTAssertEqual(out, .start(dialog: "서준이 자기 시작한 걸로 기록했어요"))
    }

    /// 이미 자는 중이면 덮어쓰지 않는다 — 덮어쓰면 앞의 잠이 통째로 사라진다.
    func testSiriSleep_startWhenAlreadySleepingDoesNotOverwrite() {
        let now = Date()
        let running = RunningTimer(type: .sleep, startedAt: now.addingTimeInterval(-3 * 3600))
        let out = SiriSleepPlanner.planStart(context: sleepCtx, running: running, now: now)
        XCTAssertEqual(out, .alreadySleeping(dialog: "이미 자고 있다고 기록돼 있어요. 3시간째예요"))
    }

    /// 남의 타이머(수유 등)를 끄지 않는다.
    func testSiriSleep_startWhileOtherTimerRunningIsRefused() {
        let now = Date()
        let running = RunningTimer(type: .feedingBreast, startedAt: now.addingTimeInterval(-600))
        let out = SiriSleepPlanner.planStart(context: sleepCtx, running: running, now: now)
        XCTAssertEqual(out, .busy(dialog: "지금 모유 타이머가 돌고 있어요"))
    }

    func testSiriSleep_stopSavesWithDuration() {
        let now = Date()
        let running = RunningTimer(type: .sleep, startedAt: now.addingTimeInterval(-(3 * 3600 + 20 * 60)))
        guard case .save(let plan) = SiriSleepPlanner.planStop(context: sleepCtx, running: running, now: now) else {
            return XCTFail("자던 중 「깼어」는 저장되어야 한다")
        }
        XCTAssertEqual(plan.activity.type, .sleep)
        XCTAssertEqual(plan.activity.source, .siri)
        XCTAssertEqual(plan.activity.duration ?? 0, 3 * 3600 + 20 * 60, accuracy: 1)
        XCTAssertNotNil(plan.activity.endTime, "수면은 종료 시각이 있어야 캘린더·통계가 자정을 넘겨 붙는다")
        XCTAssertEqual(plan.dialog, "서준이 3시간 20분 잤어요")
    }

    func testSiriSleep_stopWhenNotSleeping() {
        let out = SiriSleepPlanner.planStop(context: sleepCtx, running: nil, now: Date())
        XCTAssertEqual(out, .notSleeping(dialog: "자고 있다고 기록된 게 없어요"))
    }

    /// 다른 타이머가 돌 때 「깼어」는 그 타이머를 건드리지 않는다.
    func testSiriSleep_stopWhileOtherTimerRunning() {
        let running = RunningTimer(type: .feedingBreast, startedAt: Date())
        let out = SiriSleepPlanner.planStop(context: sleepCtx, running: running, now: Date())
        XCTAssertEqual(out, .notSleeping(dialog: "자고 있다고 기록된 게 없어요"))
    }

    /// 24시간을 넘기면 폼과 같은 문구로 거절한다 — 시간을 앱에서 고치게.
    func testSiriSleep_stopRejectsOver24Hours() {
        let now = Date()
        let running = RunningTimer(type: .sleep, startedAt: now.addingTimeInterval(-(25 * 3600)))
        let out = SiriSleepPlanner.planStop(context: sleepCtx, running: running, now: now)
        XCTAssertEqual(out, .invalid(RecordValidationError.sleepTooLong.message))
    }

    func testSiriSleep_notReadyPassesReasonThrough() {
        XCTAssertEqual(SiriSleepPlanner.planStart(context: .notReady(.noBaby), running: nil, now: Date()),
                       .notReady(.noBaby))
        XCTAssertEqual(SiriSleepPlanner.planStop(context: .notReady(.noAccount), running: nil, now: Date()),
                       .notReady(.noAccount))
    }

    /// 1시간 미만은 "분"만 말한다.
    func testSiriSleep_dialogUnderOneHour() {
        let now = Date()
        let running = RunningTimer(type: .sleep, startedAt: now.addingTimeInterval(-(45 * 60)))
        guard case .save(let plan) = SiriSleepPlanner.planStop(context: sleepCtx, running: running, now: now) else {
            return XCTFail("45분 수면도 저장되어야 한다")
        }
        XCTAssertEqual(plan.dialog, "서준이 45분 잤어요")
    }
```

- [ ] **Step 2: 실패를 확인한다**

```bash
cd /Users/roque/BabyCare && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination 'platform=iOS Simulator,arch=arm64,id=E8CF2728-092B-485D-BEF7-E959ED6B9435' \
  -only-testing:BabyCareTests/BabyCareTests 2>&1 | grep -E "cannot find" | head -5
```

기대: `cannot find 'SiriSleepPlanner' in scope`.

- [ ] **Step 3: 구현**

`BabyCare/Models/SiriSleepPlanner.swift` 새 파일:

```swift
import Foundation

/// 시리 수면 기록의 **판정** — 부수효과 없음.
///
/// 새 개념을 만들지 않는다: 앱에 이미 있는 타이머(`RunningTimerStore`)를 시리가 만지는 것뿐이다.
/// 저장 규칙(24시간 초과 거절)은 `ActivityDraftBuilder` 가 갖고 있다 — 여기서 다시 쓰지 않는다.
enum SiriSleepPlanner {
    enum Outcome: Equatable {
        /// 타이머를 시작해도 된다.
        case start(dialog: String)
        /// 이미 자는 중 — 덮어쓰지 않는다(앞의 잠이 사라진다).
        case alreadySleeping(dialog: String)
        /// 다른 타이머가 도는 중 — 남의 것을 끄지 않는다.
        case busy(dialog: String)
        /// 타이머를 멈추고 이 기록을 저장한다.
        case save(SiriRecordPlanner.Plan)
        /// 자고 있다고 기록된 게 없다.
        case notSleeping(dialog: String)
        case notReady(SiriRecordContext.Reason)
        /// 기존 저장 판정이 거절 — 문구는 폼과 같은 것을 쓴다.
        case invalid(String)
    }

    /// `SiriRecordPlanner.plan` 과 같은 모양으로 쓴다 — 컨텍스트 해석이 두 벌이 되지 않게.
    static func planStart(context: SiriRecordContext, running: RunningTimer?, now: Date) -> Outcome {
        switch context {
        case .notReady(let reason):
            return .notReady(reason)

        case .ready(_, _, let babyName):
            if let running {
                if running.type == .sleep {
                    let elapsed = SleepSession(startedAt: running.startedAt).duration(now: now)
                    return .alreadySleeping(dialog: "이미 자고 있다고 기록돼 있어요. \(spoken(elapsed))째예요")
                }
                // 남의 타이머를 끄지 않는다 — 수유 중이던 기록이 사라진다.
                return .busy(dialog: "지금 \(running.type.displayName) 타이머가 돌고 있어요")
            }

            let prefix = babyName.map { "\($0)이 " } ?? ""
            return .start(dialog: "\(prefix)자기 시작한 걸로 기록했어요")
        }
    }

    static func planStop(context: SiriRecordContext, running: RunningTimer?, now: Date) -> Outcome {
        let ownerUserId: String, babyId: String, babyName: String?
        switch context {
        case .notReady(let reason):
            return .notReady(reason)
        case .ready(let owner, let baby, let name):
            (ownerUserId, babyId, babyName) = (owner, baby, name)
        }

        guard let running, running.type == .sleep else {
            return .notSleeping(dialog: "자고 있다고 기록된 게 없어요")
        }

        let session = SleepSession(startedAt: running.startedAt)
        let duration = session.duration(now: now)

        var draft = ActivityDraft(babyId: babyId, type: .sleep, startTime: session.startedAt)
        draft.source = .siri
        draft.endTime = now
        draft.duration = duration

        switch ActivityDraftBuilder.build(draft) {
        case .failure(let error):
            return .invalid(error.message)
        case .success(let activity):
            let prefix = babyName.map { "\($0)이 " } ?? ""
            return .save(SiriRecordPlanner.Plan(
                activity: activity,
                collectionPath: FirestoreCollections.babyChildPath(
                    userId: ownerUserId,
                    babyId: babyId,
                    collection: FirestoreCollections.activities
                ),
                dialog: "\(prefix)\(spoken(duration)) 잤어요"
            ))
        }
    }

    /// "3시간 20분" · "45분" · "2시간" — 0분은 말하지 않는다.
    static func spoken(_ duration: TimeInterval) -> String {
        let totalMinutes = max(0, Int(duration / 60))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes)분" }
        if minutes == 0 { return "\(hours)시간" }
        return "\(hours)시간 \(minutes)분"
    }
}
```

- [ ] **Step 4: 통과 확인**

```bash
cd /Users/roque/BabyCare && xcodegen generate && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination 'platform=iOS Simulator,arch=arm64,id=E8CF2728-092B-485D-BEF7-E959ED6B9435' \
  -only-testing:BabyCareTests/BabyCareTests 2>&1 | tail -20
```

기대: 수면 테스트 9개 PASS.

- [ ] **Step 5: 커밋하지 않는다** — Task 8 이후 한 번에.

---

## Task 7: 저장 부수효과 (`SiriRecordRecorder`)

**Files:**
- Create: `BabyCare/Services/SiriRecordRecorder.swift`
- Delete: `BabyCare/Services/SiriFeedingRecorder.swift`

**Interfaces:**
- Consumes: `SiriRecordPlanner.Plan`(Task 3) · `OfflineQueue.shared.enqueueSave(_:collectionPath:documentId:)`(기존, `-> Bool`) · `AnalyticsService.shared.logRecordSaved(_:)`(기존) · `AppLogger.firestore`(기존)
- Produces: `enum SiriRecordRecorder` — `@MainActor static func record(_ plan: SiriRecordPlanner.Plan) async`

- [ ] **Step 1: 구현** (부수효과 껍데기 — 판정은 이미 테스트로 잠겨 있다)

`BabyCare/Services/SiriRecordRecorder.swift` 새 파일:

```swift
import FirebaseAuth
import Foundation

/// 시리 기록의 **부수효과** — 판정은 `SiriRecordPlanner` / `SiriSleepPlanner` 가 이미 끝냈다.
///
/// 오프라인 큐에 적는 것을 저장 성공으로 본다(앱의 기존 계약과 동일 — `persist` 도 큐잉을 성공으로 돌려준다).
///
/// ⚠️ **로그인 안 된 상태에서는 `flush()` 를 부르지 않는다.** 큐는 5회 실패하면 항목을 버리는데,
///    백그라운드 실행이라 인증이 아직 복원되지 않았을 때 flush 하면 시리를 몇 번 쓰는 것만으로
///    먼저 쌓인 기록이 재시도를 소진하고 조용히 사라진다.
@MainActor
enum SiriRecordRecorder {
    static func record(_ plan: SiriRecordPlanner.Plan) async {
        let queued = OfflineQueue.shared.enqueueSave(
            plan.activity,
            collectionPath: plan.collectionPath,
            documentId: plan.activity.id
        )
        guard queued else {
            AppLogger.firestore.error("시리 기록 인코딩 실패 — activity \(plan.activity.id) 큐잉 누락")
            return
        }
        // 큐 적재 = 이 앱의 저장 성공 계약(앱 경로 persist 와 동일) → 같은 이벤트를 낸다.
        AnalyticsService.shared.logRecordSaved(plan.activity)   // 출처=siri

        // 인증이 살아 있을 때만 즉시 전송 시도. 아니면 앱이 다음에 뜰 때/연결 복구 때 나간다.
        guard Auth.auth().currentUser != nil else { return }
        await OfflineQueue.shared.flush()
    }
}
```

```bash
cd /Users/roque/BabyCare && git rm BabyCare/Services/SiriFeedingRecorder.swift
```

- [ ] **Step 2: 커밋하지 않는다** — Task 8 이후 한 번에.

---

## Task 8: 시리 명령 (`RecordActivityIntent` · `SleepIntents` · AppShortcuts)

**Files:**
- Create: `BabyCare/Intents/RecordActivityIntent.swift`
- Create: `BabyCare/Intents/SleepIntents.swift`
- Modify: `BabyCare/Intents/RecordFeedingIntent.swift` (위임으로 축소 · `BabyCareAppShortcuts` 는 여기서 제거)

**Interfaces:**
- Consumes: 앞선 모든 태스크
- Produces: `enum SiriRecordKindOption: String, AppEnum` · `struct RecordActivityIntent: AppIntent` · `struct StartSleepIntent` · `struct StopSleepIntent` · `struct BabyCareAppShortcuts: AppShortcutsProvider`

- [ ] **Step 1: 기록 인텐트를 만든다**

`BabyCare/Intents/RecordActivityIntent.swift` 새 파일:

```swift
import AppIntents
import Foundation

/// 시리 문구에 들어가는 기록 종류 — 「베이비케어에 ⟨소변⟩ 기록」의 ⟨…⟩ 자리.
///
/// `AppEnum` 이라 시리가 말 속에서 값을 바로 집어낸다(되묻기 없음).
/// ⚠️ `rawValue` 는 손님이 단축어 앱에 만들어 둔 것에 저장된다 — 바꾸면 그 단축어가 깨진다.
enum SiriRecordKindOption: String, AppEnum {
    case breast, bottleFormula, bottleBreastMilk, pumping, solid, snack
    case diaperWet, diaperDirty, bath, temperature, medication

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "기록 종류"

    /// 화면 라벨과 같은 말을 쓴다 — 손님이 앱에서 본 낱말 그대로 부를 수 있어야 한다.
    static let caseDisplayRepresentations: [SiriRecordKindOption: DisplayRepresentation] = [
        .breast: "모유",
        .bottleFormula: "분유",
        .bottleBreastMilk: "모유(병)",
        .pumping: "유축",
        .solid: "이유식",
        .snack: "간식",
        .diaperWet: "소변",
        .diaperDirty: "대변",
        .bath: "목욕",
        .temperature: "체온",
        .medication: "투약"
    ]

    /// default: 없이 exhaustive 유지 — 새 종류가 조용히 빠지지 않도록.
    var kind: SiriRecordKind {
        switch self {
        case .breast: .breast
        case .bottleFormula: .bottleFormula
        case .bottleBreastMilk: .bottleBreastMilk
        case .pumping: .pumping
        case .solid: .solid
        case .snack: .snack
        case .diaperWet: .diaperWet
        case .diaperDirty: .diaperDirty
        case .bath: .bath
        case .temperature: .temperature
        case .medication: .medication
        }
    }
}

/// "시리야, 베이비케어에 소변 기록해줘" — 앱을 열지 않고 한 손으로 기록한다.
///
/// 판정은 전부 `SiriRecordPlanner`(순수)가 하고, 여기서는 되묻기와 응답만 한다.
struct RecordActivityIntent: AppIntent {
    static let title: LocalizedStringResource = "기록"
    static let description = IntentDescription("아기의 기록을 남깁니다.")
    /// 한 손으로 끝나야 하므로 앱을 띄우지 않는다.
    static let openAppWhenRun = false

    @Parameter(title: "기록 종류")
    var kindOption: SiriRecordKindOption

    @Parameter(title: "양 (ml)", requestValueDialog: "몇 ml 인가요?")
    var amountMl: Int?

    @Parameter(title: "체온 (°C)", requestValueDialog: "몇 도인가요?")
    var temperatureCelsius: Double?

    @Parameter(title: "약 이름", requestValueDialog: "어떤 약인가요?")
    var medicationName: String?

    init() {}

    init(kindOption: SiriRecordKindOption) {
        self.kindOption = kindOption
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        var outcome = plan()

        // 값이 있어야 저장되는 종류인데 안 말했으면 되묻는다 — 조용히 실패시키지 않는다.
        if case .needs(let prompt) = outcome {
            switch prompt {
            case .amountMl: amountMl = try await $amountMl.requestValue()
            case .temperatureCelsius: temperatureCelsius = try await $temperatureCelsius.requestValue()
            case .medicationName: medicationName = try await $medicationName.requestValue()
            }
            outcome = plan()
        }

        switch outcome {
        case .ready(let ready):
            await SiriRecordRecorder.record(ready)
            return .result(dialog: IntentDialog(stringLiteral: ready.dialog))
        case .needs(let prompt):
            return .result(dialog: IntentDialog(stringLiteral: prompt.requestDialog))
        case .notReady(let reason):
            return .result(dialog: IntentDialog(stringLiteral: reason.siriMessage))
        case .invalid(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
    }

    private func plan() -> SiriRecordPlanner.Outcome {
        SiriRecordPlanner.plan(
            context: SiriRecordContextStore.current(),
            request: SiriRecordRequest(kind: kindOption.kind,
                                       amountMl: amountMl,
                                       temperatureCelsius: temperatureCelsius,
                                       medicationName: medicationName),
            now: Date()
        )
    }
}
```

- [ ] **Step 2: 수면 인텐트를 만든다**

`BabyCare/Intents/SleepIntents.swift` 새 파일:

```swift
import AppIntents
import Foundation

/// "시리야, 베이비케어에 잠들었어" — 앱의 수면 타이머를 시작한다.
///
/// 새 개념을 만들지 않는다. `RunningTimerStore` 는 앱 배너·잠금화면이 보는 그 자리다.
struct StartSleepIntent: AppIntent {
    static let title: LocalizedStringResource = "수면 시작"
    static let description = IntentDescription("아기가 자기 시작했다고 기록합니다.")
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let now = Date()
        let outcome = SiriSleepPlanner.planStart(
            context: SiriRecordContextStore.current(),
            running: RunningTimerStore.current(),
            now: now
        )

        switch outcome {
        case .start(let dialog):
            RunningTimerStore.start(type: .sleep, at: now)
            return .result(dialog: IntentDialog(stringLiteral: dialog))
        case .alreadySleeping(let dialog), .busy(let dialog), .notSleeping(let dialog):
            return .result(dialog: IntentDialog(stringLiteral: dialog))
        case .notReady(let reason):
            return .result(dialog: IntentDialog(stringLiteral: reason.siriMessage))
        case .invalid(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .save:
            // planStart 는 저장하지 않는다 — 도달 불가.
            return .result(dialog: "기록하지 못했어요")
        }
    }
}

/// "시리야, 베이비케어에 깼어" — 타이머를 멈추고 잔 시간과 함께 저장한다.
struct StopSleepIntent: AppIntent {
    static let title: LocalizedStringResource = "수면 종료"
    static let description = IntentDescription("아기가 깼다고 기록합니다.")
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let outcome = SiriSleepPlanner.planStop(
            context: SiriRecordContextStore.current(),
            running: RunningTimerStore.current(),
            now: Date()
        )

        switch outcome {
        case .save(let plan):
            RunningTimerStore.clear()
            await SiriRecordRecorder.record(plan)
            return .result(dialog: IntentDialog(stringLiteral: plan.dialog))
        case .invalid(let message):
            // ⚠️ 타이머를 지우지 않는다 — 앱에서 시간을 고쳐 저장할 수 있게 남긴다.
            return .result(dialog: IntentDialog(stringLiteral: message))
        case .notSleeping(let dialog), .alreadySleeping(let dialog), .busy(let dialog), .start(let dialog):
            return .result(dialog: IntentDialog(stringLiteral: dialog))
        case .notReady(let reason):
            return .result(dialog: IntentDialog(stringLiteral: reason.siriMessage))
        }
    }
}

/// 설치만 하면 바로 쓰이는 시리 명령 — 손님이 단축어 앱에서 따로 만들 필요가 없다.
/// (베이비타임 등 구형 Siri Shortcuts 방식은 손님이 4단계를 직접 설정해야 한다.)
///
/// ⚠️ **App Shortcut 은 앱당 10개까지**(애플 제한). 지금 8개 — 늘릴 때 이 주석을 확인할 것.
///    자주 쓰는 5종만 프리셋으로 두고, 나머지는 마지막의 **종류 변수 문구**가 전부 받는다.
struct BabyCareAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordActivityIntent(kindOption: .breast),
            phrases: [
                "\(.applicationName)에 모유 수유 기록",
                "\(.applicationName) 모유 수유 기록해줘",
                "Record breast feeding in \(.applicationName)"
            ],
            shortTitle: "모유 수유 기록",
            systemImageName: "figure.and.child.holdinghands"
        )
        AppShortcut(
            intent: RecordActivityIntent(kindOption: .bottleFormula),
            phrases: [
                "\(.applicationName)에 분유 기록",
                "\(.applicationName) 분유 먹였어",
                "Record formula feeding in \(.applicationName)"
            ],
            shortTitle: "분유 기록",
            systemImageName: "waterbottle.fill"
        )
        AppShortcut(
            intent: RecordActivityIntent(kindOption: .bottleBreastMilk),
            phrases: [
                "\(.applicationName)에 모유 병수유 기록",
                "\(.applicationName) 유축한 모유 먹였어",
                "Record pumped milk feeding in \(.applicationName)"
            ],
            shortTitle: "모유(병) 기록",
            systemImageName: "drop.circle.fill"
        )
        AppShortcut(
            intent: RecordActivityIntent(kindOption: .diaperWet),
            phrases: [
                "\(.applicationName)에 소변 기록",
                "\(.applicationName) 쉬했어",
                "Record a wet diaper in \(.applicationName)"
            ],
            shortTitle: "소변 기록",
            systemImageName: "drop.fill"
        )
        AppShortcut(
            intent: RecordActivityIntent(kindOption: .diaperDirty),
            phrases: [
                "\(.applicationName)에 대변 기록",
                "\(.applicationName) 응가했어",
                "Record a dirty diaper in \(.applicationName)"
            ],
            shortTitle: "대변 기록",
            systemImageName: "humidity.fill"
        )
        AppShortcut(
            intent: StartSleepIntent(),
            phrases: [
                "\(.applicationName)에 잠들었어",
                "\(.applicationName) 자기 시작했어",
                "Start sleep in \(.applicationName)"
            ],
            shortTitle: "수면 시작",
            systemImageName: "moon.zzz.fill"
        )
        AppShortcut(
            intent: StopSleepIntent(),
            phrases: [
                "\(.applicationName)에 깼어",
                "\(.applicationName) 일어났어",
                "Stop sleep in \(.applicationName)"
            ],
            shortTitle: "수면 종료",
            systemImageName: "sun.max.fill"
        )
        // 나머지 전 종류(유축·이유식·간식·목욕·체온·투약)를 이 한 자리가 받는다.
        AppShortcut(
            intent: RecordActivityIntent(),
            phrases: [
                "\(.applicationName)에 \(\.$kindOption) 기록",
                "\(.applicationName) \(\.$kindOption) 기록해줘",
                "Record \(\.$kindOption) in \(.applicationName)"
            ],
            shortTitle: "기록",
            systemImageName: "square.and.pencil"
        )
    }
}
```

- [ ] **Step 3: 옛 인텐트를 위임으로 축소한다**

`BabyCare/Intents/RecordFeedingIntent.swift` 전체를 아래로 교체한다. **지우지 않는 이유**: 지우면 손님이 단축어 앱에 만들어 둔 것이 깨진다(v2.8.9 로 이미 나갔다). 문은 둘이지만 **판정은 하나**다.

```swift
import AppIntents
import Foundation

/// v2.8.9 에서 나간 수유 전용 인텐트 — **한 판(v2.8.10) 동안만 남긴다.**
///
/// 지우면 손님이 단축어 앱에 만들어 둔 것이 깨지므로 남기되, 판정은 전부
/// `RecordActivityIntent` 와 같은 자리(`SiriRecordPlanner`)를 쓴다 — 두 문이 갈라지지 않게.
/// App Shortcut 노출은 새 인텐트만 한다(`BabyCareAppShortcuts` 는 `SleepIntents.swift` 로 옮겼다).
enum SiriFeedingKindOption: String, AppEnum {
    case breast
    case bottleFormula
    case bottleBreastMilk

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "수유 종류"
    static let caseDisplayRepresentations: [SiriFeedingKindOption: DisplayRepresentation] = [
        .breast: "모유",
        .bottleFormula: "분유",
        .bottleBreastMilk: "모유(병)"
    ]

    var kind: SiriRecordKind {
        switch self {
        case .breast: .breast
        case .bottleFormula: .bottleFormula
        case .bottleBreastMilk: .bottleBreastMilk
        }
    }
}

struct RecordFeedingIntent: AppIntent {
    static let title: LocalizedStringResource = "수유 기록"
    static let description = IntentDescription("아기의 수유를 기록합니다.")
    static let openAppWhenRun = false

    @Parameter(title: "수유 종류")
    var kindOption: SiriFeedingKindOption

    @Parameter(title: "수유량 (ml)", requestValueDialog: "몇 ml 먹였나요?")
    var amountMl: Int?

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        var outcome = plan()

        if case .needs(.amountMl) = outcome {
            amountMl = try await $amountMl.requestValue()
            outcome = plan()
        }

        switch outcome {
        case .ready(let ready):
            await SiriRecordRecorder.record(ready)
            return .result(dialog: IntentDialog(stringLiteral: ready.dialog))
        case .needs(let prompt):
            return .result(dialog: IntentDialog(stringLiteral: prompt.requestDialog))
        case .notReady(let reason):
            return .result(dialog: IntentDialog(stringLiteral: reason.siriMessage))
        case .invalid(let message):
            return .result(dialog: IntentDialog(stringLiteral: message))
        }
    }

    private func plan() -> SiriRecordPlanner.Outcome {
        SiriRecordPlanner.plan(
            context: SiriRecordContextStore.current(),
            request: SiriRecordRequest(kind: kindOption.kind, amountMl: amountMl),
            now: Date()
        )
    }
}
```

- [ ] **Step 4: 빌드 + 전체 테스트 통과 확인**

```bash
cd /Users/roque/BabyCare && xcodegen generate && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare \
  -destination 'platform=iOS Simulator,arch=arm64,id=E8CF2728-092B-485D-BEF7-E959ED6B9435' \
  -only-testing:BabyCareTests 2>&1 | tail -25
```

기대: 전 클래스 PASS · 실패 0. **Executed 수를 눈으로 확인**한다(704 → 약 735 이상).

옛 이름이 남지 않았는지 확인한다:

```bash
cd /Users/roque/BabyCare && grep -rn "SiriFeedingRequest\|SiriFeedingPlanner\|SiriFeedingRecorder" --include="*.swift" BabyCare/ BabyCareTests/
```

기대: 0건 (`SiriFeedingKindOption` 은 남아 있어야 한다 — 옛 단축어 호환).

- [ ] **Step 5: 커밋** (Task 3~8 을 한 번에)

```bash
cd /Users/roque/BabyCare && git add \
  BabyCare/Models/SiriRecordPlanner.swift \
  BabyCare/Models/SleepSession.swift \
  BabyCare/Models/SiriSleepPlanner.swift \
  BabyCare/Services/SiriSharedStore.swift \
  BabyCare/Services/RunningTimerStore.swift \
  BabyCare/Services/SiriRecordRecorder.swift \
  BabyCare/Services/ActivityTimerManager.swift \
  BabyCare/Intents/RecordActivityIntent.swift \
  BabyCare/Intents/SleepIntents.swift \
  BabyCare/Intents/RecordFeedingIntent.swift \
  BabyCare/App/AppState.swift \
  BabyCareTests/BabyCareTests.swift
git add -u BabyCare/Models/SiriFeedingRequest.swift BabyCare/Models/SiriFeedingPlanner.swift BabyCare/Services/SiriFeedingRecorder.swift
git commit -m "feat(siri): 기록 12종 전부 시리로 — 전 종류 판정 + 수면 타이머 공유"
```

⚠️ **`git add -A` 금지** — 다른 세션의 미커밋 변경이 섞인다. 위처럼 파일 이름으로만 담는다.

---

## Task 9: 게이트 + 문서

**Files:**
- Modify: `CHANGELOG.md` · `CLAUDE.md`
- Modify: `project.yml:16-17, 128-129` (버전 올림)

- [ ] **Step 1: 구조 게이트**

```bash
cd /Users/roque/BabyCare && bash scripts/arch_test.sh; echo "EXIT=$?"
```

기대: `✅ Architecture test PASSED (R1=0 R2=0 R3=0 R4=0)` · EXIT=0.
🩸 백그라운드로 돌리면 종료코드가 `echo` 것이 된다 — 위처럼 `EXIT=$?` 를 찍어 눈으로 읽는다.

- [ ] **Step 2: 전체 게이트**

```bash
cd /Users/roque/BabyCare && make verify 2>&1 | tail -30; echo "EXIT=$?"
```

기대: `ALL CHECKS PASSED`. (~10분)

- [ ] **Step 3: 버전을 올린다**

2.8.9 train 이 닫혔으므로 **`MARKETING_VERSION` 도 손으로** 올린다. `make bump` 은 빌드번호만 올린다.

```bash
cd /Users/roque/BabyCare && sed -i '' 's/MARKETING_VERSION: "2.8.9"/MARKETING_VERSION: "2.8.10"/g; s/CURRENT_PROJECT_VERSION: "105"/CURRENT_PROJECT_VERSION: "106"/g' project.yml
grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" project.yml
```

기대: **두 곳**(base 16~17줄 + Widget 128~129줄) 모두 `2.8.10` / `106`.

ASC 최고 빌드가 정말 105 인지 다시 잰다(기대값을 적어 두지 않는다 — 실측이 정본):

```bash
cd /Users/roque/BabyCare && python3 -c "
import sys; sys.path.insert(0,'scripts')
from asc_status import *
cfg=load_config(); tok=make_token(cfg)
d=http_get('https://api.appstoreconnect.apple.com/v1/builds?filter[app]=6759935352&sort=-uploadedDate&limit=3&fields[builds]=version,processingState', tok)
[print(b['attributes']['version'], b['attributes']['processingState']) for b in d['data']]"
```

새 빌드번호는 **여기서 나온 최고값 + 1** 이어야 한다.

- [ ] **Step 4: CHANGELOG 를 쓴다**

`CHANGELOG.md` 5줄(`## [2.8.9]` 바로 위)에 새 절을 넣는다. **#76 이 아직 어느 릴리스에도 안 적혀 있으므로 같이 적는다.**

```markdown
## [2.8.10] - 2026-08-23 (TestFlight 빌드 106)

> **빌드 106 = 시리로 모든 기록.** v2.8.9(빌드 105)는 수유 3종만 시리로 됐다 — 기록 런처 12종 중 9종이 막혀 있었다.
> 이 판은 그 9종을 열고, 같은 판에 **#76(기록 출처)** 이 처음으로 손님에게 나간다.
> ⚠️ v2.8.9 출시로 train 이 닫혀 2.8.10 으로 올렸다. App Store 제출은 PO 결정.

### Added — 시리로 모든 기록 (빌드 106, 2026-08-23)

- **기록 12종 전부 시리로**: 소변·대변·목욕·이유식·간식은 **말 한마디로** 저장(앱에서도 원탭인 것들) · 유축·체온은 값을 되묻고 · 투약은 약 이름을 묻되 못 들으면 이름 없이 저장
- **수면 = 「잠들었어」/「깼어」**: 새 개념을 만들지 않고 앱의 기존 수면 타이머를 시리와 공유한다(`RunningTimerStore` — 타이머 상태를 App Group 으로 이관 + 옛 자리에서 1회 마이그레이션). 이미 자는 중이면 덮어쓰지 않고, 다른 타이머가 돌면 그것을 끄지 않는다
- **문구에 종류를 변수로**(`\(\.$kindOption)`): App Shortcut 은 앱당 10개 제한이라 12종을 하나씩 넣을 수 없다 → 자주 쓰는 5종 프리셋 + 수면 2 + **종류 변수 1** = 8자리로 전 종류를 덮는다
- **되묻기 판정을 하나로**(`SiriPromptPolicy`): 이 종류가 무엇을 물어야 하는지가 한 자리에만 있고, `ActivityDraftBuilder` 와 어긋나면 게이트가 빨강이 된다(전 종류 순회 대조)
- Fixed(예방): 로그아웃 정리를 **접두 규약**으로 바꿨다(`SiriSharedStore.clearAll()` — `siri_` 로 시작하는 App Group 키를 전부 지운다). 지울 것을 이름으로 나열하던 자리라 새 시리 값이 조용히 빠질 구조였다
- Removed: 죽은 판정 2종(`ActivityType.needsAmount` · `needsQuickInput`) — 프로덕션 호출 0, `RecordEntryRule` 이 대체함
- 종류 누락 방지: 기록 런처에 타일을 더하면 시리에 빠졌을 때 게이트가 빨강이 된다(이름 열거 대신 대조)
- 옛 인텐트(`RecordFeedingIntent`)는 **한 판 남긴다** — 지우면 손님이 단축어 앱에 만들어 둔 것이 깨진다. 판정은 새 것과 같은 자리를 쓴다
- ⚠️ 아기가 여럿이면 **앱에서 고른 아기**에만 기록된다(현행 제약 유지) · 성장·일기·접종은 범위 밖

### Added — 기록 출처 (#76, 2026-08-22 머지 · 이 판으로 처음 출시)

- `Activity.source`(`app`/`siri`) + telemetry `record_saved {record_type, source}` — 앱·시리 양쪽 저장 꼬리에서 발화
- 🔑 **v2.8.9 까지 시리 기록은 분석에 한 건도 안 잡혔다**(기록 이벤트가 화면 안에서만 발화했다). 이 판이 나가야 시리 채택률을 처음 잰다 — 그전 수치의 0 은 「안 쓴다」가 아니다
- `nil` 을 `app` 으로 세지 않는다 — 「모르는 것」과 「앱에서 온 것」은 다르다
```

- [ ] **Step 5: CLAUDE.md 를 실측대로 고친다**

268~281줄 `## Current Status` 에서:
- **Version**: `v2.8.9 ... 심사 중(WAITING_FOR_REVIEW)` → **`v2.8.10 (빌드 106) 개발 중 · v2.8.9 = 2026-08-22 READY_FOR_SALE(라이브)`**
- **App Store** 목록의 v2.8.9 줄을 `WAITING_FOR_REVIEW` → `READY_FOR_SALE (출시 2026-08-22 · v2.8.8 을 교체 · train closed)`
- **TestFlight** 줄에 빌드 106 추가
- **테스트** 줄의 개수를 Step 2 에서 실제로 본 숫자로 고친다(⛔ 추정 금지)

- [ ] **Step 6: 커밋**

```bash
cd /Users/roque/BabyCare && git add CHANGELOG.md CLAUDE.md project.yml
git commit -m "chore(release): v2.8.10 빌드 106 bump + CHANGELOG — 시리로 모든 기록 · 기록 출처(#76)"
```

- [ ] **Step 7: PO 보고 — 여기서 멈춘다**

**push · PR · 머지 · `make upload` · App Store 제출은 하지 않는다.** PO 승인 대기.

보고할 것:
- `make verify` 결과와 **실제 테스트 개수**
- 기기 QA 항목(설계 §8) — 시뮬레이터로 못 재는 구간이 무엇인지
- ⚠️ 미확인으로 남는 것: **백그라운드에서 수면 Live Activity(잠금화면)가 뜨는지** — 코드로도 시뮬레이터로도 못 잰다

---

## 자가 점검 결과

| 설계 절 | 태스크 |
|---|---|
| §4.1 뼈대 일반화 | Task 1·3·7 |
| §4.2 시리 명령 표면(8자리·파라미터 문구) | Task 8 |
| §4.3 종류별 처리 | Task 1·3 |
| §4.4 수면 = 타이머 (App Group 이관·예외 4종·마이그레이션) | Task 5·6·8 |
| §4.5 저장 경로 무변경 | Task 7 |
| §4.6 계측 | Task 7 (기존 `logRecordSaved` 재사용) · Task 9 (CHANGELOG) |
| §5 보안·격리 (접두 규약) | Task 4 |
| §1.3 죽은 판정 정리 | Task 1 |
| §7 테스트 (대조 게이트 포함) | Task 1·2·3·4·5·6·8 |
| §11 배포 (버전·PO 승인) | Task 9 |

**미해결로 남기는 것**: Live Activity 가 백그라운드 실행에서 뜨는지는 기기 QA 전까지 알 수 없다. 안 뜨더라도 기록·타이머 상태는 남게 설계했다(Task 8 Step 2 의 `StartSleepIntent` 는 Live Activity 를 부르지 않는다 — 앱이 다음에 열릴 때 `resumeTimerIfNeeded()` 가 붙인다).
