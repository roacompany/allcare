# 임신 v3 — ①여정 콘텐츠 (서브프로젝트 3) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 임신 노트 ①여정 탭의 stub(`DS2EmptyState`)을 실제 주차 타임라인 척추 화면으로 교체한다 — sticky 헤더(NN주N일·D-day·40주 진행바) + "오늘" 섹션(데일리팁·아기 크기 비교·QuickLogStrip·동적 승격 카드·미완 체크리스트 top-3) + 미래 주차 검진 마일스톤 핀 + 의료 면책 배너.

**Architecture:** 콘텐츠 선택/파생 로직(주차→fruitSize/tip 매칭, 동적 승격 카드 우선순위, 체크리스트 top-3, 한국 산전검진 마일스톤 핀)을 **순수·테스트 가능한 값 타입 2종**(`PregnancyWeekContentStore`, `PregnancyJourneyContent`)으로 추출하고, View는 이를 렌더만 하는 얇은 층으로 둔다. 기존 `DashboardPregnancyView`의 카드 7종(dDay/주차진행/체크리스트/검진/출산CTA/면책/다태)을 보라/라일락(`DS2.Color.pregnancy`) 톤으로 승격·재배치한다. flag-off 휴면이라 사용자 노출 0 — 검증은 `make verify`(빌드+단위테스트) + 차후 dev-flag 시각 QA.

**Tech Stack:** SwiftUI, Swift 6.0, XCTest, DesignSystemV2(DS2), `pregnancy-weeks.json`(4~40주), 기존 `PregnancyViewModel`/`Pregnancy` 모델.

**비범위(이 플랜 밖, 후속 플랜):** ②기록 허브(혈압/혈당·진통 = 신규 Firestore 컬렉션 + Narrow Protocol 5단계 ×2), 과거 주차 응집 카드의 초음파/일기 썸네일(D 정서기록 의존), 진통 타이머 화면 실제 구현. 이 플랜은 ①여정의 **오늘·미래·헤더**까지를 완결한다.

---

## File Structure

- **Create** `BabyCare/Models/PregnancyWeekContent.swift` — `PregnancyWeekContent`(Codable 1행) + `PregnancyWeekContentStore`(번들 로더 + 주차 매칭 순수 로직). 책임: pregnancy-weeks.json 디코드 & "현재 주차 이하 가장 가까운 항목" 선택.
- **Create** `BabyCare/ViewModels/PregnancyJourneyContent.swift` — `JourneyPromotedCard`/`PrenatalMilestone`/`PregnancyJourneyContent`. 책임: 오늘 섹션 동적 승격 카드 우선순위, 미완 체크리스트 top-3, 한국 산전검진 미래 마일스톤 핀을 순수 함수로 파생. MainActor/Firestore 무의존.
- **Create** `BabyCare/Views/Pregnancy/PregnancyJourneyComponents.swift` — 여정 전용 서브뷰(`JourneyStickyHeader`/`DailyTipCard`/`BabySizeCompareCard`/`JourneyQuickLogStrip`/`JourneyPromotedCardView`/`ChecklistPreviewCard`/`VisitMilestoneList`/`JourneyDisclaimerBanner`). 보라 토큰.
- **Modify** `BabyCare/Views/Pregnancy/PregnancyJourneyView.swift` — stub 제거, 위 컴포넌트 조립.
- **Create** `BabyCareTests/BabyCareTests+PregnancyJourney.swift` — 모델 2종 단위테스트(도메인 분리 선례: BabyCareTests+Pregnancy.swift).

> **재사용 사실(확인됨)**: `pregnancyVM.currentWeekAndDay -> (weeks,days)?`, `pregnancyVM.dDay -> Int?`, `pregnancyVM.checklistItems: [PregnancyChecklistItem]`, `pregnancyVM.prenatalVisits: [PrenatalVisit]`. `PrenatalVisit`: `isDueSoon: Bool`, `daysUntilScheduled: Int`, `hospitalName: String?`, `scheduledAt: Date`. `PregnancyChecklistItem`: `isCompleted: Bool`, `title: String`, `order: Int?`, `targetWeek: Int?`. pregnancy-weeks.json 행: `{week, fruitSize, milestone, tip, disclaimerKey?}`. `DS2.Color.pregnancy`(#B56FD1), `DS2.Color.tintPurple`, `DS2.Spacing.*`, `DS2.Font.*`. 컴포넌트: `DS2Card(tint:content:)`, `DS2Section(_:subtitle:content:)`, `DS2Button(_:icon:style:action:)`.

> **불변 규칙(.claude/rules 준수):** 임신 데이터를 Analytics/Crashlytics 파라미터로 보내지 말 것(safety.md). 의학적 "정상/위험" 단정 텍스트 금지. `print()`/`Firestore.firestore()` 직접 호출 금지. NavigationStack 중첩 금지(여정은 셸 탭 스택의 push 측 — body root에 NavigationStack 두지 않음). `AppColors` 핑크(primaryAccent) 대신 `DS2.Color.pregnancy` 사용.

---

## Task 1: PregnancyWeekContent 모델 + 주차 매칭 로직

**Files:**
- Create: `BabyCare/Models/PregnancyWeekContent.swift`
- Test: `BabyCareTests/BabyCareTests+PregnancyJourney.swift`

- [ ] **Step 1: Write the failing test**

Create `BabyCareTests/BabyCareTests+PregnancyJourney.swift`:

```swift
import XCTest
@testable import BabyCare

final class PregnancyJourneyTests: XCTestCase {

    // MARK: - PregnancyWeekContentStore

    private func fixtureStore() -> PregnancyWeekContentStore {
        PregnancyWeekContentStore(entries: [
            PregnancyWeekContent(week: 4, fruitSize: "양귀비 씨", milestone: "착상", tip: "엽산", disclaimerKey: nil),
            PregnancyWeekContent(week: 8, fruitSize: "라즈베리", milestone: "심장", tip: "수분", disclaimerKey: nil),
            PregnancyWeekContent(week: 24, fruitSize: "옥수수", milestone: "청각", tip: "태담", disclaimerKey: nil),
            PregnancyWeekContent(week: 40, fruitSize: "수박", milestone: "만삭", tip: "출산가방", disclaimerKey: nil)
        ])
    }

    func test_content_exactWeekMatch() {
        let store = fixtureStore()
        XCTAssertEqual(store.content(forWeek: 8)?.fruitSize, "라즈베리")
    }

    func test_content_betweenWeeks_picksNearestBelow() {
        let store = fixtureStore()
        // 10주는 8주 항목으로 폴백(현재 주차 이하 가장 가까운 항목)
        XCTAssertEqual(store.content(forWeek: 10)?.week, 8)
    }

    func test_content_belowFirst_picksFirst() {
        let store = fixtureStore()
        // 3주(4주 미만)는 첫 항목으로 폴백
        XCTAssertEqual(store.content(forWeek: 3)?.week, 4)
    }

    func test_content_aboveLast_picksLast() {
        let store = fixtureStore()
        XCTAssertEqual(store.content(forWeek: 50)?.week, 40)
    }

    func test_content_emptyStore_returnsNil() {
        let store = PregnancyWeekContentStore(entries: [])
        XCTAssertNil(store.content(forWeek: 12))
    }

    func test_loadBundled_decodesRealJSON() {
        let store = PregnancyWeekContentStore.loadBundled()
        // pregnancy-weeks.json 은 4~40주 연속 — 비어있지 않고 4주 항목 존재
        XCTAssertFalse(store.entries.isEmpty)
        XCTAssertEqual(store.content(forWeek: 4)?.week, 4)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme BabyCare -only-testing:BabyCareTests/PregnancyJourneyTests/test_content_exactWeekMatch` (또는 `make test`)
Expected: FAIL — "cannot find 'PregnancyWeekContentStore' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `BabyCare/Models/PregnancyWeekContent.swift`:

```swift
import Foundation

/// 주차별 임신 콘텐츠 1행 (pregnancy-weeks.json 스키마, 4~40주).
struct PregnancyWeekContent: Codable, Hashable, Sendable {
    let week: Int
    let fruitSize: String
    let milestone: String
    let tip: String
    let disclaimerKey: String?
}

/// 주차 콘텐츠 저장소 — 번들 JSON 로드 + "현재 주차 이하 가장 가까운 항목" 매칭.
/// DashboardPregnancyView.currentWeekInfo 로직 계승(순수·테스트 가능하게 추출).
struct PregnancyWeekContentStore: Sendable {
    let entries: [PregnancyWeekContent]

    /// 현재 주차보다 작거나 같은 가장 가까운 항목. 없으면(주차가 첫 항목 미만) 첫 항목. entries 빈 경우 nil.
    func content(forWeek week: Int) -> PregnancyWeekContent? {
        entries.last(where: { $0.week <= week }) ?? entries.first
    }

    /// 번들 pregnancy-weeks.json 디코드. 실패 시 빈 저장소(렌더는 옵셔널 가드로 안전).
    static func loadBundled() -> PregnancyWeekContentStore {
        guard let url = Bundle.main.url(forResource: "pregnancy-weeks", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let infos = try? JSONDecoder().decode([PregnancyWeekContent].self, from: data) else {
            return PregnancyWeekContentStore(entries: [])
        }
        return PregnancyWeekContentStore(entries: infos)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test` (또는 위 only-testing 전체 `PregnancyJourneyTests`)
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add BabyCare/Models/PregnancyWeekContent.swift BabyCareTests/BabyCareTests+PregnancyJourney.swift
git commit -m "feat(pregnancy-v3): 여정 주차 콘텐츠 저장소 + 매칭 로직 (TDD)"
```

---

## Task 2: PregnancyJourneyContent — 오늘 섹션 파생 로직

**Files:**
- Create: `BabyCare/ViewModels/PregnancyJourneyContent.swift`
- Test: `BabyCareTests/BabyCareTests+PregnancyJourney.swift` (append)

- [ ] **Step 1: Write the failing test**

Append to `BabyCareTests/BabyCareTests+PregnancyJourney.swift` (within the class):

```swift
    // MARK: - PregnancyJourneyContent

    private func visit(daysUntil: Int, hospital: String? = "행복산부인과") -> PrenatalVisit {
        let date = Calendar.current.date(byAdding: .day, value: daysUntil, to: Date())!
        return PrenatalVisit(
            id: "v\(daysUntil)", pregnancyId: "p1", scheduledAt: date, visitedAt: nil,
            hospitalName: hospital, doctorName: nil, visitType: nil, notes: nil,
            isCompleted: false, reminderEnabled: nil, createdAt: Date(), updatedAt: Date()
        )
    }

    private func checklist(_ title: String, completed: Bool, order: Int?) -> PregnancyChecklistItem {
        PregnancyChecklistItem(
            id: title, pregnancyId: "p1", title: title, itemDescription: nil,
            category: "test", isCompleted: completed, completedAt: nil,
            targetWeek: nil, source: "test", order: order, createdAt: Date()
        )
    }

    func test_promotedCards_laborTimerShownAt37WeeksFirst() {
        let content = PregnancyJourneyContent(
            currentWeek: 38,
            checklistItems: [],
            prenatalVisits: [visit(daysUntil: 1)]  // 임박 검진도 있음
        )
        // 37주+ 진통 타이머가 최우선 정렬
        XCTAssertEqual(content.promotedCards.first, .laborTimer)
        XCTAssertEqual(content.promotedCards.count, 2)  // labor + visit
    }

    func test_promotedCards_noLaborBefore37() {
        let content = PregnancyJourneyContent(
            currentWeek: 30,
            checklistItems: [],
            prenatalVisits: [visit(daysUntil: 1)]
        )
        XCTAssertEqual(content.promotedCards, [.upcomingVisit(daysUntil: 1, hospitalName: "행복산부인과")])
    }

    func test_promotedCards_onlyDueSoonVisitsCount() {
        let content = PregnancyJourneyContent(
            currentWeek: 20,
            checklistItems: [],
            prenatalVisits: [visit(daysUntil: 30)]  // isDueSoon=false (멀음)
        )
        XCTAssertTrue(content.promotedCards.isEmpty)
    }

    func test_promotedCards_cappedAtTwo() {
        let content = PregnancyJourneyContent(
            currentWeek: 38,
            checklistItems: [],
            prenatalVisits: [visit(daysUntil: 0), visit(daysUntil: 2)]
        )
        XCTAssertEqual(content.promotedCards.count, 2)
    }

    func test_topIncompleteChecklist_max3_sortedByOrder() {
        let items = [
            checklist("C", completed: false, order: 3),
            checklist("A", completed: false, order: 1),
            checklist("done", completed: true, order: 0),
            checklist("B", completed: false, order: 2),
            checklist("D", completed: false, order: 4)
        ]
        let content = PregnancyJourneyContent(currentWeek: 12, checklistItems: items, prenatalVisits: [])
        XCTAssertEqual(content.topIncompleteChecklist.map(\.title), ["A", "B", "C"])
    }

    func test_futureMilestones_filtersPastByUpperBound() {
        // 25주: NT(11~13)·정밀초음파(15~20) 지남, 임당(24~28)만 현재/미래
        let content = PregnancyJourneyContent(currentWeek: 25, checklistItems: [], prenatalVisits: [])
        XCTAssertEqual(content.futureMilestones.count, 1)
        XCTAssertEqual(content.futureMilestones.first?.weekRange, 24...28)
    }

    func test_futureMilestones_earlyWeekShowsAll() {
        let content = PregnancyJourneyContent(currentWeek: 9, checklistItems: [], prenatalVisits: [])
        XCTAssertEqual(content.futureMilestones.count, 3)
    }

    func test_nilWeek_noLaborNoMilestones() {
        let content = PregnancyJourneyContent(currentWeek: nil, checklistItems: [], prenatalVisits: [visit(daysUntil: 1)])
        XCTAssertFalse(content.promotedCards.contains(.laborTimer))
        XCTAssertTrue(content.futureMilestones.isEmpty)
        // 주차 미상이어도 임박 검진은 노출
        XCTAssertEqual(content.promotedCards, [.upcomingVisit(daysUntil: 1, hospitalName: "행복산부인과")])
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `make test`
Expected: FAIL — "cannot find 'PregnancyJourneyContent' in scope".

- [ ] **Step 3: Write minimal implementation**

Create `BabyCare/ViewModels/PregnancyJourneyContent.swift`:

```swift
import Foundation

/// 여정 "오늘" 섹션의 동적 승격 카드 종류 (SCREENS.md §①여정 2-d).
enum JourneyPromotedCard: Equatable, Sendable {
    /// 임박 산전검진 (isDueSoon). daysUntil = 0 이면 "오늘".
    case upcomingVisit(daysUntil: Int, hospitalName: String?)
    /// 37주+ 진통 타이머 진입 (5-1-1).
    case laborTimer
}

/// 한국 산전검진 마일스톤 (미래 주차 핀, SCREENS.md §①여정 4 / 한국 디테일).
struct PrenatalMilestone: Equatable, Sendable, Identifiable {
    let weekRange: ClosedRange<Int>
    let title: String
    let symbol: String
    var id: Int { weekRange.lowerBound }
}

/// 여정 "오늘"/"미래" 섹션 파생 — 순수(MainActor/Firestore 무의존), 단위 테스트 대상.
struct PregnancyJourneyContent: Sendable {
    let promotedCards: [JourneyPromotedCard]
    let topIncompleteChecklist: [PregnancyChecklistItem]
    let futureMilestones: [PrenatalMilestone]

    /// 한국 표준 산전검진 일정 (주차 범위 → 항목).
    static let koreanPrenatalSchedule: [PrenatalMilestone] = [
        PrenatalMilestone(weekRange: 11...13, title: "1차 기형아 검사 · 목투명대(NT)", symbol: "stethoscope"),
        PrenatalMilestone(weekRange: 15...20, title: "정밀 초음파", symbol: "waveform.path.ecg"),
        PrenatalMilestone(weekRange: 24...28, title: "임신성 당뇨 검사(GTT)", symbol: "drop.fill")
    ]

    private static let laborTimerWeek = 37

    init(currentWeek: Int?,
         checklistItems: [PregnancyChecklistItem],
         prenatalVisits: [PrenatalVisit]) {

        // 동적 승격 카드: 37주+ 진통 타이머가 최우선, 그 다음 임박 검진. 최대 2.
        var cards: [JourneyPromotedCard] = []
        if let week = currentWeek, week >= Self.laborTimerWeek {
            cards.append(.laborTimer)
        }
        let dueSoonVisits = prenatalVisits
            .filter { $0.isDueSoon }
            .sorted { $0.scheduledAt < $1.scheduledAt }
        for visit in dueSoonVisits {
            cards.append(.upcomingVisit(daysUntil: visit.daysUntilScheduled,
                                        hospitalName: visit.hospitalName))
        }
        self.promotedCards = Array(cards.prefix(2))

        // 미완 체크리스트 top-3 (order 오름차순, nil 은 뒤로).
        self.topIncompleteChecklist = checklistItems
            .filter { !$0.isCompleted }
            .sorted { ($0.order ?? Int.max) < ($1.order ?? Int.max) }
            .prefix(3)
            .map { $0 }

        // 미래 검진 마일스톤: 현재 주차가 범위를 완전히 지나지 않은 것만(upperBound >= currentWeek).
        if let week = currentWeek {
            self.futureMilestones = Self.koreanPrenatalSchedule.filter { $0.weekRange.upperBound >= week }
        } else {
            self.futureMilestones = []
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `make test`
Expected: PASS (Task1 6 + Task2 8 = 14 tests).

- [ ] **Step 5: Commit**

```bash
git add BabyCare/ViewModels/PregnancyJourneyContent.swift BabyCareTests/BabyCareTests+PregnancyJourney.swift
git commit -m "feat(pregnancy-v3): 여정 오늘/미래 섹션 파생 로직 — 승격카드·체크리스트·검진마일스톤 (TDD)"
```

---

## Task 3: 여정 서브뷰 컴포넌트 (보라 토큰)

**Files:**
- Create: `BabyCare/Views/Pregnancy/PregnancyJourneyComponents.swift`

> View 단위는 이 프로젝트에서 단위테스트 대상이 아님 — 게이트는 `make verify`(빌드+린트+arch+기존 테스트). 색은 `DS2.Color.pregnancy`(핑크 primaryAccent 금지). 모든 카드 `.regularMaterial` + `DS2.Radius`.

- [ ] **Step 1: Create components file**

Create `BabyCare/Views/Pregnancy/PregnancyJourneyComponents.swift`:

```swift
import SwiftUI

// MARK: - Sticky 헤더

/// NN주N일 · D-day · 40주 진행바 (SCREENS.md §①여정 1).
struct JourneyStickyHeader: View {
    let weekAndDay: (weeks: Int, days: Int)?
    let dDay: Int?

    private var progress: Double {
        guard let w = weekAndDay?.weeks else { return 0 }
        return min(Double(w) / 40.0, 1.0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS2.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                if let wd = weekAndDay {
                    Text("임신 \(wd.weeks)주 \(wd.days)일")
                        .font(DS2.Font.title3)
                        .foregroundStyle(DS2.Color.textPrimary)
                } else {
                    Text("임신 중")
                        .font(DS2.Font.title3)
                        .foregroundStyle(DS2.Color.textPrimary)
                }
                Spacer()
                dDayLabel
            }
            ProgressView(value: progress)
                .tint(DS2.Color.pregnancy)
        }
        .padding(DS2.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }

    @ViewBuilder private var dDayLabel: some View {
        if let dDay {
            if dDay > 0 {
                Text("D-\(dDay)").font(DS2.Font.headline).foregroundStyle(DS2.Color.pregnancy)
            } else if dDay == 0 {
                Text("오늘이 예정일").font(DS2.Font.subheadline).foregroundStyle(DS2.Color.pregnancy)
            } else {
                Text("+\(-dDay)일 경과").font(DS2.Font.subheadline).foregroundStyle(DS2.Color.warning)
            }
        } else {
            Text("예정일 미설정").font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
        }
    }
}

// MARK: - 데일리팁

struct DailyTipCard: View {
    let tip: String
    var body: some View {
        DS2Card(tint: DS2.Color.pregnancy) {
            HStack(alignment: .top, spacing: DS2.Spacing.sm) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(DS2.Color.pregnancy)
                Text(tip)
                    .font(DS2.Font.subheadline)
                    .foregroundStyle(DS2.Color.textPrimary)
            }
        }
    }
}

// MARK: - 아기 크기 비교

struct BabySizeCompareCard: View {
    let week: Int
    let fruitSize: String
    let milestone: String
    var body: some View {
        DS2Card {
            HStack(spacing: DS2.Spacing.md) {
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundStyle(DS2.Color.pregnancy)
                VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
                    Text("\(week)주차 · \(fruitSize) 크기")
                        .font(DS2.Font.headline)
                        .foregroundStyle(DS2.Color.textPrimary)
                    Text(milestone)
                        .font(DS2.Font.caption)
                        .foregroundStyle(DS2.Color.textSecondary)
                }
                Spacer()
            }
        }
    }
}

// MARK: - QuickLogStrip (태동/증상/체중)

/// 1탭 시 해당 기록 시트를 여는 가로 칩 3개. 동작은 부모(여정)가 클로저로 주입.
struct JourneyQuickLogStrip: View {
    let onKick: () -> Void
    let onSymptom: () -> Void
    let onWeight: () -> Void

    var body: some View {
        ViewThatFits {
            HStack(spacing: DS2.Spacing.sm) { chips }
            VStack(spacing: DS2.Spacing.sm) { chips }  // a11y XXXL 폴백
        }
    }

    @ViewBuilder private var chips: some View {
        quickChip("태동", "hand.tap.fill", onKick)
        quickChip("증상", "note.text", onSymptom)
        quickChip("체중", "scalemass.fill", onWeight)
    }

    private func quickChip(_ title: String, _ icon: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DS2.Spacing.xs) {
                Image(systemName: icon)
                Text(title).font(DS2.Font.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS2.Spacing.md)
            .background(DS2.Color.tintPurple.opacity(0.5), in: RoundedRectangle(cornerRadius: DS2.Radius.sm))
            .foregroundStyle(DS2.Color.pregnancy)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) 기록하기")
    }
}

// MARK: - 동적 승격 카드

struct JourneyPromotedCardView: View {
    let card: JourneyPromotedCard
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS2.Spacing.md) {
                Image(systemName: symbol).font(.title2).foregroundStyle(DS2.Color.pregnancy)
                VStack(alignment: .leading, spacing: DS2.Spacing.xs) {
                    Text(title).font(DS2.Font.headline).foregroundStyle(DS2.Color.textPrimary)
                    Text(subtitle).font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(DS2.Spacing.lg)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DS2.Radius.md))
        }
        .buttonStyle(.plain)
    }

    private var symbol: String {
        switch card {
        case .upcomingVisit: return "stethoscope"
        case .laborTimer: return "timer"
        }
    }
    private var title: String {
        switch card {
        case .upcomingVisit: return "다가오는 산전검진"
        case .laborTimer: return "진통 간격 타이머"
        }
    }
    private var subtitle: String {
        switch card {
        case let .upcomingVisit(days, hospital):
            let d = days == 0 ? "오늘" : "D-\(days)"
            return [hospital, d].compactMap { $0 }.joined(separator: " · ")
        case .laborTimer:
            return "5-1-1 규칙으로 진통 간격을 기록하세요"
        }
    }
}

// MARK: - 미완 체크리스트 top-3

struct ChecklistPreviewCard: View {
    let items: [PregnancyChecklistItem]
    let onSeeAll: () -> Void

    var body: some View {
        DS2Card {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                HStack {
                    Label("산전 체크리스트", systemImage: "checklist")
                        .font(DS2.Font.headline)
                        .foregroundStyle(DS2.Color.textPrimary)
                    Spacer()
                    Button("전체보기", action: onSeeAll)
                        .font(DS2.Font.caption)
                        .foregroundStyle(DS2.Color.pregnancy)
                }
                ForEach(items) { item in
                    HStack(spacing: DS2.Spacing.sm) {
                        Image(systemName: "circle").foregroundStyle(DS2.Color.pregnancy.opacity(0.5))
                        Text(item.title).font(DS2.Font.subheadline).foregroundStyle(DS2.Color.textPrimary)
                    }
                }
            }
        }
    }
}

// MARK: - 미래 검진 마일스톤

struct VisitMilestoneList: View {
    let milestones: [PrenatalMilestone]
    var body: some View {
        DS2Card {
            VStack(alignment: .leading, spacing: DS2.Spacing.md) {
                Label("다가올 산전검진", systemImage: "calendar")
                    .font(DS2.Font.headline)
                    .foregroundStyle(DS2.Color.textPrimary)
                ForEach(milestones) { m in
                    HStack(spacing: DS2.Spacing.sm) {
                        Image(systemName: m.symbol).foregroundStyle(DS2.Color.pregnancy)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.title).font(DS2.Font.subheadline).foregroundStyle(DS2.Color.textPrimary)
                            Text("\(m.weekRange.lowerBound)~\(m.weekRange.upperBound)주")
                                .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 의료 면책

struct JourneyDisclaimerBanner: View {
    let multiFetus: Bool
    var body: some View {
        VStack(spacing: DS2.Spacing.sm) {
            banner(icon: "info.circle.fill", tint: DS2.Color.warning,
                   text: "이 정보는 일반적인 참고 자료이며 의학적 진단을 대체하지 않습니다.")
            if multiFetus {
                banner(icon: "exclamationmark.triangle.fill", tint: DS2.Color.pregnancy,
                       text: "단태아 기준 정보입니다. 다태임신은 담당 의료진과 상의하세요.")
            }
        }
    }
    private func banner(icon: String, tint: Color, text: String) -> some View {
        HStack(spacing: DS2.Spacing.sm) {
            Image(systemName: icon).foregroundStyle(tint)
            Text(text).font(DS2.Font.caption).foregroundStyle(DS2.Color.textPrimary)
        }
        .padding(DS2.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: DS2.Radius.sm))
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `make build`
Expected: BUILD SUCCEEDED (컴포넌트는 아직 미사용 — Task 4에서 조립).

- [ ] **Step 3: Commit**

```bash
git add BabyCare/Views/Pregnancy/PregnancyJourneyComponents.swift
git commit -m "feat(pregnancy-v3): 여정 서브뷰 컴포넌트 8종 (보라 토큰)"
```

---

## Task 4: PregnancyJourneyView 조립 (stub 교체)

**Files:**
- Modify: `BabyCare/Views/Pregnancy/PregnancyJourneyView.swift` (전체 교체)

> 기존 stub의 `comingSoonList`/`DS2EmptyState` 제거. QuickLog/체크리스트/검진/출산 동작은 기존 시트·뷰로 연결: 태동=`KickRecordingSheet`, 체중=`PregnancyWeightEntrySheet`, 증상=`PregnancySymptomMemoSheet`(모두 `PregnancyRecordingSheets.swift`), 체크리스트 전체보기=`PregnancyChecklistView`, 출산 CTA=`PregnancyTransitionSheet`. NavigationStack 중첩 금지(셸 탭 스택의 push 측이므로 자체 NavigationStack 두지 않음).

- [ ] **Step 1: Replace the stub with assembled view**

Replace entire `BabyCare/Views/Pregnancy/PregnancyJourneyView.swift`:

```swift
import SwiftUI

/// ① 여정 탭 루트 — 주차 타임라인 척추 (SCREENS.md §①여정).
/// "오늘" 섹션(데일리팁·크기비교·QuickLog·동적승격·체크리스트) + 미래 검진 마일스톤 + 면책.
/// 과거 주차 응집 카드(초음파/일기)는 후속 플랜(정서기록 의존).
@MainActor
struct PregnancyJourneyView: View {
    @Environment(PregnancyViewModel.self) private var pregnancyVM
    @Environment(AuthViewModel.self) private var authVM

    private let weekStore = PregnancyWeekContentStore.loadBundled()

    @State private var activeSheet: JourneySheet?
    @State private var showTransitionSheet = false

    private enum JourneySheet: Identifiable {
        case kick, weight, symptom
        var id: Int { hashValue }
    }

    private var content: PregnancyJourneyContent {
        PregnancyJourneyContent(
            currentWeek: pregnancyVM.currentWeekAndDay?.weeks,
            checklistItems: pregnancyVM.checklistItems,
            prenatalVisits: pregnancyVM.prenatalVisits
        )
    }

    private var weekContent: PregnancyWeekContent? {
        guard let week = pregnancyVM.currentWeekAndDay?.weeks else { return nil }
        return weekStore.content(forWeek: week)
    }

    private var isMultiFetus: Bool {
        (pregnancyVM.activePregnancy?.fetusCount ?? 1) > 1
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: DS2.Spacing.lg, pinnedViews: [.sectionHeaders]) {
                Section {
                    todaySection
                    futureSection
                    JourneyDisclaimerBanner(multiFetus: isMultiFetus)
                } header: {
                    JourneyStickyHeader(
                        weekAndDay: pregnancyVM.currentWeekAndDay,
                        dDay: pregnancyVM.dDay
                    )
                }
            }
            .padding(.horizontal, DS2.Spacing.lg)
            .padding(.bottom, DS2.Spacing.xl)
        }
        .navigationTitle("여정")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .kick: KickRecordingSheet()
            case .weight: PregnancyWeightEntrySheet()
            case .symptom: PregnancySymptomMemoSheet()
            }
        }
        .sheet(isPresented: $showTransitionSheet) {
            if let pregnancy = pregnancyVM.activePregnancy {
                PregnancyTransitionSheet(pregnancy: pregnancy)
            }
        }
    }

    // MARK: - 오늘 섹션

    @ViewBuilder private var todaySection: some View {
        if let wc = weekContent {
            DailyTipCard(tip: wc.tip)
            BabySizeCompareCard(week: wc.week, fruitSize: wc.fruitSize, milestone: wc.milestone)
        }

        JourneyQuickLogStrip(
            onKick: { activeSheet = .kick },
            onSymptom: { activeSheet = .symptom },
            onWeight: { activeSheet = .weight }
        )

        ForEach(Array(content.promotedCards.enumerated()), id: \.offset) { _, card in
            JourneyPromotedCardView(card: card, action: { /* Task: 검진/진통 화면 라우팅은 후속 */ })
        }

        if !content.topIncompleteChecklist.isEmpty {
            ChecklistPreviewCard(items: content.topIncompleteChecklist, onSeeAll: { /* 체크리스트 push는 후속 */ })
        }

        if pregnancyVM.dDay != nil {
            birthCTABanner
        }
    }

    // MARK: - 미래 섹션

    @ViewBuilder private var futureSection: some View {
        if !content.futureMilestones.isEmpty {
            VisitMilestoneList(milestones: content.futureMilestones)
        }
    }

    // MARK: - 출산 CTA

    private var birthCTABanner: some View {
        Button { showTransitionSheet = true } label: {
            HStack(spacing: DS2.Spacing.md) {
                Image(systemName: "heart.circle.fill").font(.title2).foregroundStyle(DS2.Color.pregnancy)
                VStack(alignment: .leading, spacing: 2) {
                    Text("출산했어요!").font(DS2.Font.headline).foregroundStyle(DS2.Color.textPrimary)
                    Text("아기 정보를 등록하고 육아 모드로 전환하세요.")
                        .font(DS2.Font.caption).foregroundStyle(DS2.Color.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.subheadline).foregroundStyle(.tertiary)
            }
            .padding(DS2.Spacing.lg)
            .background(DS2.Color.pregnancy.opacity(0.12), in: RoundedRectangle(cornerRadius: DS2.Radius.md))
        }
        .buttonStyle(.plain)
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
    return NavigationStack { PregnancyJourneyView() }
        .environment(vm)
        .environment(AuthViewModel())
        .tint(DS2.Color.pregnancy)
}
#endif
```

- [ ] **Step 2: Verify the sheet/view names exist**

Run: `grep -n "struct KickRecordingSheet\|struct PregnancyWeightEntrySheet\|struct PregnancySymptomMemoSheet" BabyCare/Views/Pregnancy/PregnancyRecordingSheets.swift`
Expected: 세 시트 모두 존재. (없으면 해당 시트의 실제 init 시그니처에 맞춰 호출부 조정 — 일부는 파라미터가 필요할 수 있음.)

- [ ] **Step 3: Build + full verify**

Run: `make verify`
Expected: BUILD SUCCEEDED · lint 0 error · arch R1–R4=0 · 기존+신규 테스트 PASS · design 통과.

- [ ] **Step 4: Commit**

```bash
git add BabyCare/Views/Pregnancy/PregnancyJourneyView.swift
git commit -m "feat(pregnancy-v3): ①여정 stub → 주차 타임라인 척추 조립 (오늘/미래/헤더)"
```

---

## Task 5: 검진·체크리스트 라우팅 연결 + 셸 동작 확인

**Files:**
- Modify: `BabyCare/Views/Pregnancy/PregnancyJourneyView.swift`

> Task 4의 `/* 후속 */` 플레이스홀더 2곳(체크리스트 전체보기, 동적 승격 카드 탭)을 NavigationLink/탭 점프로 연결.

- [ ] **Step 1: Wire checklist "전체보기" to NavigationLink**

`PregnancyJourneyView` 의 `ChecklistPreviewCard(... onSeeAll:)` 자리를 `NavigationLink` 기반으로 교체 — `onSeeAll` 클로저 대신 `ChecklistPreviewCard`를 `NavigationLink { PregnancyChecklistView() } label: { ... }` 로 감싸거나, `ChecklistPreviewCard`에 `@State private var showChecklist`를 두고 `.navigationDestination(isPresented:)` 사용. 셸 탭의 NavigationStack을 사용하므로 push 안전(중첩 아님):

```swift
        if !content.topIncompleteChecklist.isEmpty {
            ChecklistPreviewCard(items: content.topIncompleteChecklist, onSeeAll: { showChecklist = true })
        }
```
그리고 body 에 추가:
```swift
        .navigationDestination(isPresented: $showChecklist) { PregnancyChecklistView() }
```
+ `@State private var showChecklist = false` 선언.

- [ ] **Step 2: Build + verify**

Run: `make verify`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add BabyCare/Views/Pregnancy/PregnancyJourneyView.swift
git commit -m "feat(pregnancy-v3): 여정 체크리스트 전체보기 라우팅 연결"
```

---

## Done Criteria

- [ ] `PregnancyJourneyView` stub 제거 — sticky 헤더 + 오늘 섹션 + 미래 마일스톤 + 면책 렌더.
- [ ] 콘텐츠 파생 로직(주차 매칭·승격카드·체크리스트·마일스톤)이 순수 타입으로 단위테스트됨(14+ tests).
- [ ] 보라/라일락(`DS2.Color.pregnancy`) 톤 — 핑크(primaryAccent) 미사용.
- [ ] `make verify` green (arch R1–R4=0).
- [ ] flag-off 휴면 유지(사용자 노출 0) — 셸 자체는 PR #33에서 배선됨.

## Follow-on (이 플랜 밖)
- **②기록 허브** = 별도 플랜 (혈압/혈당·진통 신규 Firestore 컬렉션 + Narrow Protocol 5단계 ×2, 태동/체중/증상 카드, 세그먼트, 오늘 요약 스트립).
- 과거 주차 응집 카드(초음파/일기 썸네일) = D 정서기록 콘텐츠 의존.
- 진통 타이머(ContractionTimerView)·검진 화면(③ PrenatalCareView 콘텐츠) 실제 구현.
- dev-flag on 시각 QA + H-items(의료감수·법무) — 출시 선결.
