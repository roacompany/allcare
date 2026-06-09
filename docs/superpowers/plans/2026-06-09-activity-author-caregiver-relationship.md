# 활동 작성자(createdBy) + 보호자 관계 라벨 (Track A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Steps use `- [ ]`. BabyCare 게이트: `make verify` (build+lint+arch+test+design).

**Goal:** 활동 기록에 **작성자(uid)** 를 남기고, 보호자(소유자+공유멤버)에 **관계 라벨(엄마/아빠/…)** 을 붙여, 향후 어드민에서 "엄마 vs 아빠 기록 비중"(Track C)을 집계할 연료를 쌓는다. **효과는 본 변경이 출시(v2.8.7+)된 이후 기록부터** — 과거 기록은 소급 불가.

**Architecture:** 신규 컬렉션 없음, 기존 구조에 **optional 필드 추가**만. `Activity.createdBy`(작성자 uid, v1은 activities 한정) + `SharedBabyAccess.relationship`(공유멤버 관계) + `Baby.ownerRelationship`(소유자 관계) + `CaregiverRelationship` enum(forward-compat). 작성자는 이미 저장 경로에 흐르는 `currentUserId`를 주입. 관계는 가족공유 수락/관리 UI에서 선택.

**Tech Stack:** Swift 6, SwiftUI, Firestore(필드 추가만 → rules 변경 불필요), 기존 `FirestoreService+Activity/Family/Baby`.

**확정(브레인스토밍 (2) 선택):** mother/father/grandmother/grandfather/other(+unknown). v1 작성자=activities만. 관계 미설정 허용(→ 비중에서 "미지정").

---

## File Structure
- Create: `BabyCare/Models/CaregiverRelationship.swift` (enum)
- Modify: `BabyCare/Models/Activity.swift` (+`createdBy`), `BabyCare/Models/Baby.swift` (+`ownerRelationship`), `BabyCare/Models/FamilyInvite.swift` (SharedBabyAccess +`relationship`)
- Modify: `BabyCare/ViewModels/ActivityViewModel+Save.swift` (createdBy 주입 3곳)
- Modify: `BabyCare/ViewModels/FamilySharingViewModel.swift` (`joinFamily` +relationship), `BabyCare/Views/Settings/FamilySharingView.swift` (수락 시 관계 picker + 소유자 "내 역할" picker)
- Create: `BabyCareTests/BabyCareTests+CaregiverAttribution.swift` (도메인 분리 테스트, 선례 따름)

**불변 규칙 준수:** 신규 필드는 optional / 모델 Identifiable·Codable·Hashable / enum rawValue 영구계약·`unknown` 센티넬(ActivityType 선례) / `Firestore.firestore()` 직접호출 금지(기존 FirestoreService 메서드만) / `print()` 금지(AppLogger) / `make verify` green.

---

## Task 1: CaregiverRelationship enum (TDD)

**Files:** Create `BabyCare/Models/CaregiverRelationship.swift`, Test `BabyCareTests/BabyCareTests+CaregiverAttribution.swift`

- [ ] **Step 1: 실패 테스트 작성** (`BabyCareTests+CaregiverAttribution.swift` 신규)

```swift
import XCTest
@testable import BabyCare

final class CaregiverAttributionTests: XCTestCase {
    func test_relationship_rawValues_areStableContract() {
        XCTAssertEqual(CaregiverRelationship.mother.rawValue, "mother")
        XCTAssertEqual(CaregiverRelationship.father.rawValue, "father")
        XCTAssertEqual(CaregiverRelationship.grandmother.rawValue, "grandmother")
        XCTAssertEqual(CaregiverRelationship.grandfather.rawValue, "grandfather")
        XCTAssertEqual(CaregiverRelationship.other.rawValue, "other")
    }

    func test_relationship_displayName_korean() {
        XCTAssertEqual(CaregiverRelationship.mother.displayName, "엄마")
        XCTAssertEqual(CaregiverRelationship.father.displayName, "아빠")
    }

    func test_relationship_unknownDecode_fallback() {
        // 미래 버전이 추가한 rawValue → unknown 으로 관용 디코드
        XCTAssertEqual(CaregiverRelationship.known(rawValue: "aunt"), CaregiverRelationship.unknown)
        XCTAssertEqual(CaregiverRelationship.known(rawValue: "mother"), CaregiverRelationship.mother)
    }

    func test_selectableCases_excludeUnknown() {
        XCTAssertFalse(CaregiverRelationship.selectable.contains(.unknown))
        XCTAssertEqual(CaregiverRelationship.selectable.count, 5)
    }
}
```

- [ ] **Step 2: 실패 확인** — `make build` 또는 테스트 컴파일 실패(타입 없음).

- [ ] **Step 3: 구현**

```swift
// BabyCare/Models/CaregiverRelationship.swift
import Foundation

/// 보호자–아기 관계 라벨. rawValue 는 영구 계약(저장값) — 절대 변경/재사용 금지.
/// `unknown` 은 미래 버전이 추가한 미지의 rawValue 를 관용 디코드하기 위한 read-only 센티넬
/// (ActivityType.unknown 선례). 새 쓰기 경로는 `selectable` 만 사용.
enum CaregiverRelationship: String, Codable, Hashable, CaseIterable {
    case mother
    case father
    case grandmother
    case grandfather
    case other
    case unknown   // read-only 폴백 — UI 선택지/저장 대상 아님

    /// UI 선택지 (unknown 제외).
    static let selectable: [CaregiverRelationship] = [.mother, .father, .grandmother, .grandfather, .other]

    /// 미지 rawValue 는 unknown 으로 폴백 (init?(rawValue:) 의 nil 회피).
    static func known(rawValue: String) -> CaregiverRelationship {
        CaregiverRelationship(rawValue: rawValue) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .mother: return "엄마"
        case .father: return "아빠"
        case .grandmother: return "할머니"
        case .grandfather: return "할아버지"
        case .other: return "기타"
        case .unknown: return "미지정"
        }
    }
}
```

- [ ] **Step 4: 통과 확인** — `make build` + 테스트 PASS.
- [ ] **Step 5: 커밋** — `git add BabyCare/Models/CaregiverRelationship.swift BabyCareTests/BabyCareTests+CaregiverAttribution.swift && git commit -m "feat(caregiver): CaregiverRelationship enum (forward-compat)"`

---

## Task 2: 모델 필드 추가 (Codable 라운드트립 TDD)

**Files:** Modify `Activity.swift`, `Baby.swift`, `FamilyInvite.swift`; append tests.

- [ ] **Step 1: 실패 테스트 추가** (`BabyCareTests+CaregiverAttribution.swift`)

```swift
extension CaregiverAttributionTests {
    func test_activity_createdBy_codableRoundTrip() throws {
        var a = Activity(babyId: "b1", type: .feedingBottle)
        a.createdBy = "uid_dad"
        let data = try JSONEncoder().encode(a)
        let decoded = try JSONDecoder().decode(Activity.self, from: data)
        XCTAssertEqual(decoded.createdBy, "uid_dad")
    }

    func test_activity_createdBy_defaultsNil_backwardCompat() throws {
        // createdBy 없는 과거 문서도 디코드되어야 (optional)
        let json = #"{"id":"x","babyId":"b1","type":"sleep","startTime":0,"createdAt":0}"#.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(Activity.self, from: json)
        XCTAssertNil(decoded.createdBy)
    }

    func test_sharedAccess_relationship_roundTrip() throws {
        var s = SharedBabyAccess(ownerUserId: "o", babyId: "b", babyName: "아기")
        s.relationship = CaregiverRelationship.father.rawValue
        let decoded = try JSONDecoder().decode(SharedBabyAccess.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(decoded.relationship, "father")
    }

    func test_baby_ownerRelationship_roundTrip() throws {
        var b = Baby(id: "b", name: "아기", birthDate: Date(timeIntervalSince1970: 0), gender: .male, createdAt: Date(timeIntervalSince1970: 0), updatedAt: Date(timeIntervalSince1970: 0))
        b.ownerRelationship = CaregiverRelationship.mother.rawValue
        let decoded = try JSONDecoder().decode(Baby.self, from: JSONEncoder().encode(b))
        XCTAssertEqual(decoded.ownerRelationship, "mother")
    }
}
```

> 주: `Activity`/`Baby` init 시그니처는 기존 그대로 — 신규 필드는 모두 optional 이라 호출부 영향 없음. 위 테스트의 `Baby(...)` init 인자는 실제 시그니처에 맞게 확인(구현 시 `Baby.swift` 의 memberwise/custom init 참조).

- [ ] **Step 2: 실패 확인** — 컴파일 실패(필드 없음).

- [ ] **Step 3: 구현 — 필드 추가 (모두 optional, 영속)**
  - `Activity.swift`: `var createdBy: String?` 추가 (다른 optional 필드 옆, 예: photoURL 근처). **주의:** Activity 는 커스텀 `Codable`(ActivityType.unknown 처리) 일 수 있음 — `init(from:)`/`encode(to:)` 가 커스텀이면 `createdBy` 도 디코드/인코드에 추가. memberwise/synthesized 면 자동.
  - `Baby.swift`: `var ownerRelationship: String?` 추가 (`ownerUserId` 아래).
  - `FamilyInvite.swift` `SharedBabyAccess`: `var relationship: String?` 추가 + init 에 `relationship: String? = nil` 파라미터 추가(기본 nil → 기존 호출부 영향 없음).

- [ ] **Step 4: 통과 확인** — `make build` + 테스트 PASS. (Activity 가 커스텀 Codable 이면 createdBy 누락 시 round-trip 테스트가 잡아줌.)
- [ ] **Step 5: 커밋** — `git add -A && git commit -m "feat(caregiver): Activity.createdBy + Baby.ownerRelationship + SharedBabyAccess.relationship"`

---

## Task 3: createdBy 주입 (저장 경로 3곳)

**Files:** Modify `BabyCare/ViewModels/ActivityViewModel+Save.swift`

> 작성자 = 호출자 `currentUserId`(이미 시그니처에 존재). 저장 직전 activity 에 주입. activities 한정(v1). 오프라인 큐도 activity 에 이미 세팅돼 보존됨.

- [ ] **Step 1: 3곳 주입**
  - `performSaveActivity` (`var activity = Activity(...)` 직후, save 전): `activity.createdBy = currentUserId`
  - `quickSave` (`var activity = Activity(...)` 직후): `activity.createdBy = currentUserId`
  - `savePrebuiltActivity` (param `activity: Activity` 는 let → 가변 복사): 함수 본문에서 `var act = activity; act.createdBy = currentUserId` 후 이후 `activity` 참조를 `act` 로 교체(insert/save/rollback 모두). 또는 시그니처를 받은 즉시 `var activity = activity` shadowing.

- [ ] **Step 2: 검증** — `make build` 통과. (단위 테스트는 activity mock 부재로 생략 — 1줄 주입은 코드리뷰로 검증. Task 2 의 Codable 테스트가 필드 영속을 보장.)
- [ ] **Step 3: 커밋** — `git add -A && git commit -m "feat(caregiver): 활동 저장 시 createdBy(currentUserId) 주입"`

---

## Task 4: 공유 수락 시 관계 선택 (멤버)

**Files:** Modify `FamilySharingViewModel.swift`, `FamilySharingView.swift`

- [ ] **Step 1: VM — joinFamily 에 relationship 추가**
  `func joinFamily(code: String, userId: String, relationship: CaregiverRelationship) async throws -> SharedBabyAccess` — `SharedBabyAccess(ownerUserId:, babyId:, babyName:, relationship: relationship.rawValue)` 로 생성. (SharedBabyAccess init 에 relationship 파라미터는 Task 2에서 추가됨.)

- [ ] **Step 2: View — 수락 시트에 관계 Picker**
  `FamilySharingView` 의 join 시트(코드 입력 + "참여" 버튼, `joinFamily()` private func ~L211 영역)에 **관계 선택 Picker** 추가:
  - `@State private var relationship: CaregiverRelationship = .mother`
  - "참여" 버튼 위에 `Picker("나의 관계", selection: $relationship) { ForEach(CaregiverRelationship.selectable, id: \.self) { Text($0.displayName).tag($0) } }` (기존 디자인 톤; ViewThatFits/segmented 등 주변 스타일 따름)
  - `joinFamily()` private func → `vm.joinFamily(code: code, userId: userId, relationship: relationship)`
  - **a11y**: 라벨 길이 대비 ViewThatFits 고려(선례: AddBabyView 임신 진입점).

- [ ] **Step 3: 검증 + 커밋** — `make build` 통과. `git add -A && git commit -m "feat(caregiver): 가족 공유 수락 시 관계 라벨 선택(멤버)"`

---

## Task 5: 소유자 "내 역할" 설정

**Files:** Modify `FamilySharingView.swift` (+ 필요 시 BabyViewModel)

- [ ] **Step 1: 소유자 관계 Picker + 저장**
  `FamilySharingView` 의 소유자 공유 관리 화면(초대코드 생성/공유멤버 목록이 보이는 메인 영역)에 **"내 역할" Picker** 추가:
  - 현재 baby 의 `ownerRelationship` 로 초기화(미설정 시 기본 .mother 또는 미선택 placeholder).
  - 변경 시 `var updated = baby; updated.ownerRelationship = selected.rawValue; updated.updatedAt = Date()` 후 `FirestoreService.shared.updateBaby(updated, userId:)` (기존 메서드, L26). VM 경유가 있으면 VM 메서드로(직접 `Firestore.firestore()` 금지). 실패 시 AppLogger.logSilent.
  - dataUserId: 소유자 자신의 baby 이므로 `authVM.currentUserId` 경로(공유받은 baby 면 소유자만 역할 설정 가능하도록 노출 제한 — 본인 소유 baby 에서만 picker 표시).

- [ ] **Step 2: 검증 + 커밋** — `make build` 통과. `git add -A && git commit -m "feat(caregiver): 소유자 '내 역할' 설정"`

---

## Task 6: 전체 검증 (make verify)

- [ ] **Step 1: `make verify`** — 빌드 + SwiftLint + arch-test(R1~R4 baseline 0 유지: 신규 `Firestore.firestore()` 직접호출 0) + 단위테스트(신규 CaregiverAttribution 포함) + design 토큰. 모두 green.
- [ ] **Step 2: (선택) smoke-test** — 시뮬레이터 런치 크래시 없음.
- [ ] **Step 3: 최종 커밋(있으면) + PR**

---

## Self-Review (작성자 확인)
- 스펙 §5 매핑: createdBy(Task3) · 관계 enum(Task1) · 멤버 관계(Task4) · 소유자 관계(Task5) · 필드(Task2). 전부 커버.
- 불변규칙: optional 필드 / enum unknown 센티넬 / FirestoreService 경유(arch R3) / AppLogger / make verify.
- **하위호환:** 모든 신규 필드 optional → 과거 문서·기존 호출부 안전. SharedBabyAccess init relationship 기본 nil.
- **테스트 범위:** enum + Codable 라운드트립(단위). VM createdBy 주입은 activity mock 부재로 단위테스트 생략(1줄, 코드리뷰 검증) — 필요 시 ActivityFirestoreProviding narrow protocol 도입은 후속(스코프 외).
- **Activity 커스텀 Codable 리스크:** Activity 가 `init(from:)`/`encode(to:)` 커스텀이면 createdBy 를 양쪽에 추가해야 영속됨 — Task2 round-trip 테스트가 누락을 잡음. 구현 시 `Activity.swift` Codable 구현부 반드시 확인.

## 출시 / 후속
- 본 변경은 **다음 BabyCare 릴리즈(v2.8.7+)** 탑승. 출시 후 기록부터 createdBy/relationship 누적.
- **Track C(어드민 엄마/아빠 비중)** 는 데이터 수 주 누적 후: activities.createdBy → uid별 카운트 → uid→관계(소유자=baby.ownerRelationship / 멤버=sharedAccess.relationship) 매핑 → 관계별 합산. (어드민도 인덱스-free `.get()` 스캔 가능.)
- v1 작성자=activities만. growth/diary 등 확장은 동일 패턴 후속.
