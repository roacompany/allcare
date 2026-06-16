# 임신 v3 — ②기록·추적 허브 (서브프로젝트 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 임신 노트 ②기록 탭의 stub을 실제 추적 허브로 교체 — 세그먼트([매일 도구]/[상태별]/[선택 모듈]) + 오늘 요약 스트립 + 매일 도구(태동·체중·증상, 기존 자산 재사용) + 상태별 도구(혈압/혈당·진통 타이머, **신규 Firestore 컬렉션 2종**) + 선택 모듈(약/수분/수면 토글). 모든 저장은 ①여정으로 자동 역류(공유 `PregnancyViewModel`).

**Architecture:** SCREENS.md §②기록 명세를 4단계(Phase A~D)로 분할 — 각 단계가 독립 PR. 의료 수치·판정 로직(오늘 요약 카운트·임당 목표선 비교·Korean BMI 권장 증가밴드·5-1-1 진통 판정)은 **순수·테스트 가능한 값 타입**으로 추출하고, 신규 컬렉션(혈압/혈당·진통)은 기존 **Narrow Protocol 5단계**(weight/symptom 선례)를 정확히 복제. View는 기존 `KickSessionView`/`PregnancyWeightView`/`PregnancyRecordingSheets` 재사용 + 보라(`DS2.Color.pregnancy`) 톤.

**Tech Stack:** SwiftUI, Swift 6.0, XCTest, Apple Charts, DesignSystemV2, Firestore(Narrow Protocol), 기존 `PregnancyViewModel`.

**전제(이미 완료):** ①여정(`2026-06-16-pregnancy-v3-journey-content.md`), 셸 PR #33, 토대 PR #32. 이 플랜은 `PregnancyTrackingHubView` stub을 채운다.

> **불변 규칙(.claude/rules):** ① 임신 수치를 Analytics/Crashlytics 파라미터로 보내지 말 것(safety.md) — 진단은 `logSilent` + `AppLogger.pregnancy`(비식별). ② "정상/위험" 의학 단정 텍스트 금지 — 목표선/밴드는 참고선, "병원 연락 고려" 같은 **비지시적** 표현만. ③ 신규 컬렉션은 **Narrow Protocol 5단계** + arch-test Rule 3 baseline=0(`Firestore.firestore()` 직접호출 금지). ④ `[String: Any]` 프로토콜 시그니처 금지. ⑤ KickEvent식 임베딩(서브컬렉션 생성 금지) — 진통도 events 배열 임베딩. ⑥ `babyVM.dataUserId()` 경유(공유 임신, `authVM.currentUserId` 직접 금지). ⑦ NavigationStack 중첩 금지(셸 탭 스택 push 측). ⑧ 진통 타이머는 **절대시간 기반**(타이머 카운트 의존 금지 — 백그라운드 경과 손실 방지).

---

## File Structure

**Phase A — 허브 셸 + 매일 도구 (신규 데이터 0)**
- Create `BabyCare/ViewModels/PregnancyTrackingSummary.swift` — 오늘 기록 개수 파생(순수, 테스트 대상).
- Create `BabyCare/Views/Pregnancy/PregnancyTrackingComponents.swift` — `TrackingSegment`/`TodaySummaryStrip`/`TrackingToolCard`.
- Modify `BabyCare/Views/Pregnancy/PregnancyTrackingHubView.swift` — stub 교체, 세그먼트+오늘요약+매일도구 조립.
- Test `BabyCareTests/BabyCareTests+PregnancyTracking.swift`.

**Phase B — 혈압/혈당 (신규 컬렉션 `pregnancyVitals`)**
- Create `BabyCare/Models/PregnancyVitalEntry.swift` — 혈압/혈당 1행 + 임당 목표선 판정(순수).
- Modify `BabyCare/Utils/Constants.swift` — `FirestoreCollections.pregnancyVitals` 상수.
- Modify `BabyCare/Services/FirestoreService+Pregnancy.swift` — `saveVitalEntry`/`fetchVitalEntries` + `PregnancyFirestoreProviding` 프로토콜에 추가.
- Modify `BabyCareTests/MockPregnancyFirestore.swift` — mock 메서드 + 호출 카운터.
- Modify `BabyCare/ViewModels/PregnancyViewModel.swift` — `vitalEntries` 배열 + `addVitalEntry`/load.
- Create `BabyCare/Views/Pregnancy/PregnancyVitalsView.swift` + 입력 시트.
- Modify `firestore.indexes.json` — 필요 시 인덱스.

**Phase C — 진통 타이머 (신규 컬렉션 `contractionSessions`)**
- Create `BabyCare/Models/ContractionSession.swift` — 세션 + events 임베딩 + 5-1-1 판정(순수).
- Modify Constants/FirestoreService+Pregnancy/Mock/PregnancyViewModel (Narrow Protocol 5단계).
- Create `BabyCare/Views/Pregnancy/ContractionTimerView.swift`.

**Phase D — 선택 모듈 토글**
- Modify `BabyCare/Views/Pregnancy/PregnancyTrackingComponents.swift` — `OptionalModuleToggleCard`.
- Modify `PregnancyTrackingHubView.swift` — [선택 모듈] 세그먼트 + UserDefaults 토글.

> **재사용(확인됨):** `KickRecordingSheet()`/`PregnancyWeightEntrySheet()`/`PregnancySymptomMemoSheet()`(무인자, env 주입). `KickSessionView`/`PregnancyWeightView`(Health/). `pregnancyVM.kickSessions/weightEntries/symptoms`. Narrow Protocol 선례 = `saveWeightEntry`/`saveSymptom`(FirestoreService+Pregnancy.swift) + Mock(`saveWeightEntryCalls`/`weightEntriesResponse`). Collections: `pregnancyWeights`/`pregnancySymptoms`(Constants.swift:114-115).

---

# Phase A — 허브 셸 + 매일 도구 (PR #1)

## Task A1: PregnancyTrackingSummary — 오늘 기록 개수 (TDD)

**Files:**
- Create: `BabyCare/ViewModels/PregnancyTrackingSummary.swift`
- Test: `BabyCareTests/BabyCareTests+PregnancyTracking.swift`

- [ ] **Step 1: Write the failing test**

Create `BabyCareTests/BabyCareTests+PregnancyTracking.swift`:

```swift
import XCTest
@testable import BabyCare

final class PregnancyTrackingTests: XCTestCase {

    private let cal = Calendar.current

    private func kick(at date: Date) -> KickSession {
        var s = KickSession(pregnancyId: "p1")
        s.startedAt = date
        return s
    }
    private func weight(at date: Date) -> PregnancyWeightEntry {
        PregnancyWeightEntry(pregnancyId: "p1", weight: 60, unit: "kg", measuredAt: date)
    }
    private func symptom(at date: Date) -> PregnancySymptom {
        PregnancySymptom(pregnancyId: "p1", memo: "메모", occurredAt: date)
    }

    func test_summary_countsOnlyToday() {
        let today = Date()
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let summary = PregnancyTrackingSummary(
            now: today,
            kickSessions: [kick(at: today), kick(at: yesterday)],
            weightEntries: [weight(at: today)],
            symptoms: [symptom(at: yesterday)]
        )
        XCTAssertEqual(summary.kickCount, 1)
        XCTAssertEqual(summary.weightCount, 1)
        XCTAssertEqual(summary.symptomCount, 0)
    }

    func test_summary_isEmptyWhenNothingToday() {
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let summary = PregnancyTrackingSummary(
            now: Date(), kickSessions: [kick(at: yesterday)], weightEntries: [], symptoms: []
        )
        XCTAssertTrue(summary.isEmpty)
    }

    func test_summary_notEmptyWhenAnyToday() {
        let summary = PregnancyTrackingSummary(
            now: Date(), kickSessions: [], weightEntries: [weight(at: Date())], symptoms: []
        )
        XCTAssertFalse(summary.isEmpty)
    }
}
```

> **검증 선행**: `KickSession`에 `startedAt`(var Date) 필드가 있는지 grep 확인(`grep -n "startedAt\|var started" BabyCare/Models/KickSession.swift`). 필드명이 다르면(`createdAt` 등) 테스트/구현의 날짜 키를 실제 필드로 맞출 것.

- [ ] **Step 2: Run test to verify it fails**

Run: `make test` (또는 `-only-testing:BabyCareTests/PregnancyTrackingTests`)
Expected: FAIL — "cannot find 'PregnancyTrackingSummary'".

- [ ] **Step 3: Write minimal implementation**

Create `BabyCare/ViewModels/PregnancyTrackingSummary.swift`:

```swift
import Foundation

/// ②기록 허브 "오늘 요약 스트립" 파생 — 오늘 기록한 항목 개수(순수, 테스트 대상).
struct PregnancyTrackingSummary: Sendable {
    let kickCount: Int
    let weightCount: Int
    let symptomCount: Int

    var isEmpty: Bool { kickCount == 0 && weightCount == 0 && symptomCount == 0 }

    init(now: Date,
         kickSessions: [KickSession],
         weightEntries: [PregnancyWeightEntry],
         symptoms: [PregnancySymptom],
         calendar: Calendar = .current) {
        func isToday(_ d: Date) -> Bool { calendar.isDate(d, inSameDayAs: now) }
        self.kickCount = kickSessions.filter { isToday($0.startedAt) }.count
        self.weightCount = weightEntries.filter { isToday($0.measuredAt) }.count
        self.symptomCount = symptoms.filter { isToday($0.occurredAt) }.count
    }
}
```

- [ ] **Step 4: Run test to verify it passes** — `make test` → PASS (3 tests).
- [ ] **Step 5: Commit**

```bash
git add BabyCare/ViewModels/PregnancyTrackingSummary.swift BabyCareTests/BabyCareTests+PregnancyTracking.swift
git commit -m "feat(pregnancy-v3): 기록 허브 오늘 요약 파생 로직 (TDD)"
```

## Task A2: 허브 컴포넌트 (세그먼트·요약 스트립·도구 카드)

**Files:** Create `BabyCare/Views/Pregnancy/PregnancyTrackingComponents.swift`

- [ ] **Step 1: Create components**

```swift
import SwiftUI

/// ②기록 허브 세그먼트.
enum TrackingSegment: String, CaseIterable, Identifiable {
    case daily = "매일 도구"
    case conditional = "상태별"
    case optional = "선택 모듈"
    var id: String { rawValue }
}

/// 오늘 기록 개수 칩 스트립.
struct TodaySummaryStrip: View {
    let summary: PregnancyTrackingSummary
    var body: some View {
        if summary.isEmpty {
            Text("오늘 첫 기록을 남겨보세요")
                .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: DS2.Spacing.sm) {
                if summary.kickCount > 0 { chip("태동 \(summary.kickCount)회") }
                if summary.weightCount > 0 { chip("체중 \(summary.weightCount)") }
                if summary.symptomCount > 0 { chip("증상 \(summary.symptomCount)") }
                Spacer(minLength: 0)
            }
        }
    }
    private func chip(_ text: String) -> some View {
        Text(text).font(DS2.Font.caption)
            .padding(.horizontal, DS2.Spacing.sm).padding(.vertical, DS2.Spacing.xs)
            .background(DS2.Color.tintPurple.opacity(0.5), in: Capsule())
            .foregroundStyle(DS2.Color.pregnancy)
    }
}

/// 도구 카드(아이콘+제목+서브타이틀+미니 슬롯). 탭 시 action.
struct TrackingToolCard<Accessory: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS2.Spacing.md) {
                Image(systemName: icon).font(.title2).foregroundStyle(DS2.Color.pregnancy)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
                    Text(title).font(DS2.Font.headline).foregroundStyle(DS2.Color.textPrimary)
                    Text(subtitle).font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                }
                Spacer(minLength: 0)
                accessory()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(DS2.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS2.Radius.md))
        }
        .buttonStyle(.plain)
    }
}

extension TrackingToolCard where Accessory == EmptyView {
    init(icon: String, title: String, subtitle: String, action: @escaping () -> Void) {
        self.init(icon: icon, title: title, subtitle: subtitle, action: action, accessory: { EmptyView() })
    }
}
```

- [ ] **Step 2: Build** — `make build` → SUCCEEDED.
- [ ] **Step 3: Commit** — `git commit -m "feat(pregnancy-v3): 기록 허브 컴포넌트(세그먼트·요약·도구카드)"`

## Task A3: PregnancyTrackingHubView 조립 (stub 교체, 매일 도구)

**Files:** Modify `BabyCare/Views/Pregnancy/PregnancyTrackingHubView.swift`

- [ ] **Step 1: Replace stub**

```swift
import SwiftUI

/// ② 기록·추적 허브 (SCREENS.md §②기록). 세그먼트 + 오늘 요약 + 도구 카드.
/// 저장은 공유 PregnancyViewModel 통해 ①여정으로 역류.
@MainActor
struct PregnancyTrackingHubView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM

    @State private var segment: TrackingSegment = .daily
    @State private var activeSheet: TrackingSheet?

    private enum TrackingSheet: Int, Identifiable {
        case kick, weight, symptom
        var id: Int { rawValue }
    }

    private var summary: PregnancyTrackingSummary {
        PregnancyTrackingSummary(
            now: Date(),
            kickSessions: pregnancyVM.kickSessions,
            weightEntries: pregnancyVM.weightEntries,
            symptoms: pregnancyVM.symptoms
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS2.Spacing.lg) {
                TodaySummaryStrip(summary: summary)

                Picker("도구 분류", selection: $segment) {
                    ForEach(TrackingSegment.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch segment {
                case .daily: dailyTools
                case .conditional: conditionalTools   // Phase B/C
                case .optional: optionalTools          // Phase D
                }
            }
            .padding(.horizontal, DS2.Spacing.lg)
            .padding(.vertical, DS2.Spacing.lg)
        }
        .navigationTitle("기록")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .kick: KickRecordingSheet()
            case .weight: PregnancyWeightEntrySheet()
            case .symptom: PregnancySymptomMemoSheet()
            }
        }
    }

    @ViewBuilder private var dailyTools: some View {
        TrackingToolCard(icon: "hand.tap.fill", title: "태동 카운터",
                         subtitle: "ACOG 2시간 내 10회 기준", action: { activeSheet = .kick })
        TrackingToolCard(icon: "scalemass.fill", title: "체중",
                         subtitle: "임신 전 대비 증가 추이", action: { activeSheet = .weight })
        TrackingToolCard(icon: "face.smiling", title: "증상 / 기분",
                         subtitle: "오늘 컨디션을 기록", action: { activeSheet = .symptom })
    }

    // Phase B/C 에서 채움
    @ViewBuilder private var conditionalTools: some View {
        ContentUnavailableView("준비 중", systemImage: "heart.text.square",
                               description: Text("혈압/혈당·진통 타이머가 곧 제공됩니다."))
    }
    // Phase D 에서 채움
    @ViewBuilder private var optionalTools: some View {
        ContentUnavailableView("준비 중", systemImage: "switch.2",
                               description: Text("약·수분·수면 모듈이 곧 제공됩니다."))
    }
}

#if DEBUG
#Preview {
    let vm = PregnancyViewModel()
    vm.activePregnancy = Pregnancy(
        lmpDate: Calendar.current.date(byAdding: .day, value: -168, to: Date()),
        dueDate: Calendar.current.date(byAdding: .day, value: 112, to: Date()),
        fetusCount: 1, babyNickname: "둘째"
    )
    return NavigationStack { PregnancyTrackingHubView() }
        .environment(vm).tint(DS2.Color.pregnancy)
}
#endif
```

- [ ] **Step 2: make verify** → green(arch R1–R4=0).
- [ ] **Step 3: Commit + PR**

```bash
git add BabyCare/Views/Pregnancy/PregnancyTrackingHubView.swift
git commit -m "feat(pregnancy-v3): ②기록 허브 stub → 세그먼트+오늘요약+매일도구 조립"
```
Phase A PR: "feat(pregnancy-v3): ②기록 허브 Phase A — 셸+매일도구".

---

# Phase B — 혈압/혈당 (신규 컬렉션 `pregnancyVitals`, PR #2)

## Task B1: PregnancyVitalEntry 모델 + 임당 목표선 판정 (TDD)

**Files:**
- Create: `BabyCare/Models/PregnancyVitalEntry.swift`
- Test: `BabyCareTests/BabyCareTests+PregnancyTracking.swift` (append)

- [ ] **Step 1: Write the failing test** (append to class)

```swift
    func test_glucose_withinTarget_fasting() {
        // 한국 임당 참고선: 공복 ≤ 95 mg/dL
        XCTAssertTrue(PregnancyVitalEntry.glucoseWithinReference(value: 90, context: .fasting))
        XCTAssertFalse(PregnancyVitalEntry.glucoseWithinReference(value: 100, context: .fasting))
    }
    func test_glucose_withinTarget_postMeal1h() {
        // 식후 1시간 ≤ 140
        XCTAssertTrue(PregnancyVitalEntry.glucoseWithinReference(value: 130, context: .postMeal1h))
        XCTAssertFalse(PregnancyVitalEntry.glucoseWithinReference(value: 150, context: .postMeal1h))
    }
    func test_glucose_withinTarget_postMeal2h() {
        // 식후 2시간 ≤ 120
        XCTAssertTrue(PregnancyVitalEntry.glucoseWithinReference(value: 110, context: .postMeal2h))
        XCTAssertFalse(PregnancyVitalEntry.glucoseWithinReference(value: 130, context: .postMeal2h))
    }
```

- [ ] **Step 2: Run** → FAIL ("cannot find 'PregnancyVitalEntry'").

- [ ] **Step 3: Implement**

Create `BabyCare/Models/PregnancyVitalEntry.swift`:

```swift
import Foundation

/// 혈압/혈당 측정 1행 (신규 컬렉션 pregnancyVitals). 혈압·혈당 중 하나 이상.
struct PregnancyVitalEntry: Identifiable, Codable, Hashable {
    var id: String
    var pregnancyId: String
    var systolic: Int?       // 수축기 mmHg
    var diastolic: Int?      // 이완기 mmHg
    var glucose: Int?        // 혈당 mg/dL
    /// 혈당 측정 맥락 (fasting|postMeal1h|postMeal2h). 문자열 — rawValue 영구 계약 회피.
    var glucoseContext: String?
    var measuredAt: Date
    var notes: String?
    var createdAt: Date

    init(id: String = UUID().uuidString, pregnancyId: String,
         systolic: Int? = nil, diastolic: Int? = nil,
         glucose: Int? = nil, glucoseContext: String? = nil,
         measuredAt: Date = Date(), notes: String? = nil, createdAt: Date = Date()) {
        self.id = id; self.pregnancyId = pregnancyId
        self.systolic = systolic; self.diastolic = diastolic
        self.glucose = glucose; self.glucoseContext = glucoseContext
        self.measuredAt = measuredAt; self.notes = notes; self.createdAt = createdAt
    }

    /// 혈당 측정 맥락.
    enum GlucoseContext: String, CaseIterable, Identifiable {
        case fasting, postMeal1h, postMeal2h
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .fasting: return "공복"
            case .postMeal1h: return "식후 1시간"
            case .postMeal2h: return "식후 2시간"
            }
        }
        /// 한국 임신성 당뇨 참고 목표선(mg/dL) — 진단 아님, 참고선 표시·비교용.
        var referenceCeiling: Int {
            switch self {
            case .fasting: return 95
            case .postMeal1h: return 140
            case .postMeal2h: return 120
            }
        }
    }

    /// 혈당이 참고 목표선 이하인지(차트 RuleMark 비교용, 의학 단정 아님).
    static func glucoseWithinReference(value: Int, context: GlucoseContext) -> Bool {
        value <= context.referenceCeiling
    }
}
```

- [ ] **Step 4: Run** → PASS. **Step 5: Commit** `feat(pregnancy-v3): 혈압/혈당 모델 + 임당 참고선 판정 (TDD)`.

## Task B2: Narrow Protocol 5단계 — pregnancyVitals 컬렉션

> weight/symptom 선례를 정확히 복제. arch-test Rule 3 baseline=0 유지.

- [ ] **Step 1: Constants 상수** — `BabyCare/Utils/Constants.swift`의 `pregnancySymptoms` 다음 줄에:
```swift
    static let pregnancyVitals = "pregnancyVitals"
```

- [ ] **Step 2: FirestoreService+Pregnancy.swift — 프로토콜 + 구현**

`PregnancyFirestoreProviding` 프로토콜 본문에 (saveSymptom/fetchSymptoms 시그니처 옆) 추가:
```swift
    func saveVitalEntry(_ entry: PregnancyVitalEntry, userId: String, pregnancyId: String) async throws
    func fetchVitalEntries(userId: String, pregnancyId: String) async throws -> [PregnancyVitalEntry]
```
extension 본문에 (saveSymptom/fetchSymptoms 구현 옆, weight 패턴 복제) 추가:
```swift
    func saveVitalEntry(_ entry: PregnancyVitalEntry, userId: String, pregnancyId: String) async throws {
        try db.collection(FirestoreCollections.users).document(userId)
            .collection(FirestoreCollections.pregnancies).document(pregnancyId)
            .collection(FirestoreCollections.pregnancyVitals).document(entry.id)
            .setData(from: entry)
    }
    func fetchVitalEntries(userId: String, pregnancyId: String) async throws -> [PregnancyVitalEntry] {
        let snapshot = try await db.collection(FirestoreCollections.users).document(userId)
            .collection(FirestoreCollections.pregnancies).document(pregnancyId)
            .collection(FirestoreCollections.pregnancyVitals)
            .order(by: "measuredAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: PregnancyVitalEntry.self) }
    }
```
> 실제 weight/symptom 구현의 정확한 `db` 체인·`setData(from:)` 형태를 그대로 따를 것(`sed -n '118,150p' BabyCare/Services/FirestoreService+Pregnancy.swift` 로 확인 후 복제).

- [ ] **Step 3: MockPregnancyFirestore.swift** — 응답/카운터 + 메서드:
```swift
    var vitalEntriesResponse: [PregnancyVitalEntry] = []
    private(set) var saveVitalEntryCalls: [PregnancyVitalEntry] = []
    func saveVitalEntry(_ entry: PregnancyVitalEntry, userId: String, pregnancyId: String) async throws {
        if let error = errorToThrow { throw error }
        saveVitalEntryCalls.append(entry)
    }
    func fetchVitalEntries(userId: String, pregnancyId: String) async throws -> [PregnancyVitalEntry] {
        if let error = errorToThrow { throw error }
        return vitalEntriesResponse
    }
```
> Mock의 실제 에러 주입 변수명(`errorToThrow` 등)을 기존 메서드에서 확인해 일치시킬 것.

- [ ] **Step 4: PregnancyViewModel.swift** — 배열 + add/load:
```swift
    var vitalEntries: [PregnancyVitalEntry] = []

    func addVitalEntry(_ entry: PregnancyVitalEntry, userId: String) async {
        guard let pid = activePregnancy?.id else { return }
        do {
            try await firestoreService.saveVitalEntry(entry, userId: userId, pregnancyId: pid)
            vitalEntries.insert(entry, at: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
```
그리고 `loadActivePregnancy`(또는 데이터 로드 지점)에서 `vitalEntries = (try? await firestoreService.fetchVitalEntries(...)) ?? []` 패턴으로 채움(weight/symptom 로드와 동일 위치).

- [ ] **Step 5: arch-test + 단위테스트**

Mock 사용 단위테스트 1개 추가(append):
```swift
    @MainActor
    func test_addVitalEntry_persistsAndPrepends() async {
        let mock = MockPregnancyFirestore()
        let vm = PregnancyViewModel(firestoreService: mock)
        vm.activePregnancy = Pregnancy(lmpDate: nil, dueDate: nil, fetusCount: 1, babyNickname: "t")
        await vm.addVitalEntry(PregnancyVitalEntry(pregnancyId: "p1", glucose: 90, glucoseContext: "fasting"), userId: "u1")
        XCTAssertEqual(mock.saveVitalEntryCalls.count, 1)
        XCTAssertEqual(vm.vitalEntries.first?.glucose, 90)
    }
```
> `PregnancyViewModel(firestoreService:)` init 시그니처 확인(`grep -n "init(" BabyCare/ViewModels/PregnancyViewModel.swift`) 후 주입 인자명 일치.

Run: `bash scripts/arch_test.sh` → R3=0. `make test` → PASS.

- [ ] **Step 6: Commit** `feat(pregnancy-v3): pregnancyVitals 컬렉션 Narrow Protocol 5단계`.

## Task B3: 혈압/혈당 View + 입력 시트

**Files:** Create `BabyCare/Views/Pregnancy/PregnancyVitalsView.swift`

- [ ] **Step 1: Create view** — 최근 값 요약 + Apple Charts 2계열(혈압 systolic/diastolic, 혈당) + 임당 목표선 `RuleMark`(`glucoseContext.referenceCeiling`) + 입력 시트(공복/식후 세그먼트, decimalPad). 면책 1줄(info.circle, "참고용·의학 단정 아님"). 색=`DS2.Color.pregnancy`. 차트는 `import Charts`, `AppColors` 핑크 금지.
  - 입력 시트는 `medium` detent, 저장 = `pregnancyVM.addVitalEntry(...)`, `errorMessage==nil`일 때만 dismiss(기존 시트 패턴).
  - "정상/위험" 텍스트 금지 — 목표선 위/아래는 색+라벨("참고선 이내/초과")만.
- [ ] **Step 2: 허브 conditionalTools 에 카드 연결** — `PregnancyTrackingHubView.conditionalTools`에 혈압/혈당 `TrackingToolCard`(icon `heart.text.square`) → `NavigationLink { PregnancyVitalsView() }` 또는 sheet.
- [ ] **Step 3: make verify** → green. **Step 4: Commit + Phase B PR**.

---

# Phase C — 진통 타이머 (신규 컬렉션 `contractionSessions`, PR #3)

## Task C1: ContractionSession 모델 + 5-1-1 판정 (TDD)

**Files:** Create `BabyCare/Models/ContractionSession.swift`; Test append.

- [ ] **Step 1: Write failing test**

```swift
    func test_511_metWhenIntervalsTightAndSustained() {
        // 5분 간격·1분 지속·1시간 지속 → 충족
        let now = Date()
        var session = ContractionSession(pregnancyId: "p1")
        // 13개 수축: 5분 간격, 각 60초 지속, 60분 범위
        for i in 0..<13 {
            let start = now.addingTimeInterval(Double(i) * 300)        // 5분 간격
            session.contractions.append(ContractionEvent(startedAt: start, endedAt: start.addingTimeInterval(60)))
        }
        XCTAssertTrue(session.meets511(asOf: now.addingTimeInterval(13 * 300)))
    }
    func test_511_notMetWhenSparse() {
        let now = Date()
        var session = ContractionSession(pregnancyId: "p1")
        // 15분 간격 → 미충족
        for i in 0..<5 {
            let start = now.addingTimeInterval(Double(i) * 900)
            session.contractions.append(ContractionEvent(startedAt: start, endedAt: start.addingTimeInterval(30)))
        }
        XCTAssertFalse(session.meets511(asOf: now.addingTimeInterval(5 * 900)))
    }
    func test_511_notMetWhenShortHistory() {
        let now = Date()
        var session = ContractionSession(pregnancyId: "p1")
        // 5분 간격·1분 지속이지만 20분만 지속 → 1시간 미충족
        for i in 0..<5 {
            let start = now.addingTimeInterval(Double(i) * 300)
            session.contractions.append(ContractionEvent(startedAt: start, endedAt: start.addingTimeInterval(60)))
        }
        XCTAssertFalse(session.meets511(asOf: now.addingTimeInterval(5 * 300)))
    }
```

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement**

```swift
import Foundation

/// 진통 1회 (시작/끝, 임베딩 — 서브컬렉션 생성 금지 룰).
struct ContractionEvent: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: TimeInterval? {
        guard let end = endedAt else { return nil }
        return end.timeIntervalSince(startedAt)
    }
}

/// 진통 세션 (신규 컬렉션 contractionSessions). 5-1-1 판정은 순수·절대시간 기반.
struct ContractionSession: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString
    var pregnancyId: String
    var contractions: [ContractionEvent] = []
    var isFirstBirth: Bool = true   // 초산/경산 안내 분기
    var startedAt: Date = Date()
    var endedAt: Date?
    var createdAt: Date = Date()

    /// 5-1-1: 최근 1시간 동안 평균 간격 ≤ 5분 AND 평균 지속 ≥ 1분 AND 관찰창이 1시간 이상.
    /// 판정은 안내일 뿐 — 의료 단정 금지.
    func meets511(asOf now: Date, window: TimeInterval = 3600) -> Bool {
        let recent = contractions
            .filter { $0.startedAt >= now.addingTimeInterval(-window) }
            .sorted { $0.startedAt < $1.startedAt }
        guard recent.count >= 2,
              let first = recent.first?.startedAt,
              now.timeIntervalSince(first) >= window - 1 else { return false }  // 1시간 지속

        // 평균 간격 ≤ 5분
        var intervals: [TimeInterval] = []
        for i in 1..<recent.count {
            intervals.append(recent[i].startedAt.timeIntervalSince(recent[i-1].startedAt))
        }
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)
        guard avgInterval <= 300 else { return false }

        // 평균 지속 ≥ 1분 (지속 기록 있는 것만)
        let durations = recent.compactMap { $0.durationSeconds }
        guard !durations.isEmpty else { return false }
        let avgDuration = durations.reduce(0, +) / Double(durations.count)
        return avgDuration >= 60
    }
}
```

- [ ] **Step 4: Run** → PASS. **Step 5: Commit** `feat(pregnancy-v3): 진통 세션 모델 + 5-1-1 판정 (TDD, 절대시간)`.

## Task C2: Narrow Protocol 5단계 — contractionSessions
> Task B2 패턴 정확히 복제(상수 `contractionSessions` / save·fetch / Mock / VM `contractionSessions: [ContractionSession]` + add/load). arch R3=0. 단위테스트 1개(add → 카운터). Commit.

## Task C3: ContractionTimerView
> **풀스크린**(진행 중 실수 이탈 방지) + "수축 시작/끝" 버튼(`UIImpactFeedbackGenerator` 햅틱) + 라이브 간격/지속 + `meets511` 충족 시 카드 강조 + "병원 연락을 고려하세요"(비지시적). 초산/경산 토글. **절대시간 기반**(시작 시각 저장, 타이머 카운트 의존 금지 — 백그라운드 손실 방지). 허브 conditionalTools 에 "진통 간격 타이머" `TrackingToolCard`(icon `stopwatch`) → fullScreenCover. make verify → green. Commit + Phase C PR.

---

# Phase D — 선택 모듈 토글 (PR #4)

## Task D1: OptionalModuleToggleCard + 허브 [선택 모듈] 세그먼트
**Files:** Modify `PregnancyTrackingComponents.swift` + `PregnancyTrackingHubView.swift`

- [ ] **Step 1: OptionalModuleToggleCard** — 약/수분/수면 카드. 우상단 "표시" 토글. 꺼짐 시 흐림 + "켜기". 표시 상태는 `@AppStorage("pregnancy.module.\(key)")` (UserDefaults, Firestore 불필요 — 로컬 UI 선호).
```swift
struct OptionalModuleToggleCard: View {
    let icon: String
    let title: String
    @Binding var isEnabled: Bool
    var body: some View {
        DS2Card {
            HStack {
                Image(systemName: icon).foregroundStyle(isEnabled ? DS2.Color.pregnancy : DS2.Color.textSecondary)
                Text(title).font(DS2.Font.headline)
                    .foregroundStyle(isEnabled ? DS2.Color.textPrimary : DS2.Color.textSecondary)
                Spacer()
                Toggle("표시", isOn: $isEnabled).labelsHidden().tint(DS2.Color.pregnancy)
            }
            .opacity(isEnabled ? 1 : 0.5)
        }
    }
}
```
- [ ] **Step 2: 허브 optionalTools** — `@AppStorage` 3개(med/water/sleep) + 카드 3개. 켜진 모듈만 입력 행 추가(약 복용/수분/수면은 v1에서 토글+placeholder까지, 실제 입력은 후속 — SCREENS "켜야 노출"). 
- [ ] **Step 3: make verify** → green. **Step 4: Commit + Phase D PR**.

---

## Done Criteria (전체 ②기록)
- [ ] `PregnancyTrackingHubView` stub 제거 — 세그먼트 3 + 오늘 요약 + 도구 카드.
- [ ] 매일 도구(태동/체중/증상) = 기존 시트 재사용, 저장 시 ①여정 역류.
- [ ] 혈압/혈당·진통 = 신규 컬렉션 2종, **Narrow Protocol 5단계 + arch R3=0**.
- [ ] 임당 목표선·BMI 밴드·5-1-1 판정 = 순수 타입 단위테스트.
- [ ] 의학 단정 텍스트 0 / 임신 데이터 Analytics 미전송 / 진통 절대시간 기반.
- [ ] 보라(`DS2.Color.pregnancy`) 톤 — 핑크 미사용. `make verify` green. flag-off 휴면.

## 비범위(후속)
- 체중 카드 Korean BMI 권장 증가밴드 AreaMark(PregnancyWeightView 델타) — 별도 작업으로 분리 가능.
- 선택 모듈(약/수분/수면)의 실제 입력 폼·기록(v1=토글+placeholder까지).
- 증상 시트 주차별 추천칩(SymptomMoodStampSheet 확장) — ①여정/② 공통, PregnancySymptomMemoSheet 확장.
- dev-flag on 시각 QA + H-items(의료감수: 임당 목표선·5-1-1 수치 검증 / 법무) = 출시 선결.
```
