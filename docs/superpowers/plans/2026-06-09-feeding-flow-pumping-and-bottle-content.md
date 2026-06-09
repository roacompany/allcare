# 유축 기록하기 통합 + 병수유 내용물(분유/모유) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 유축을 기록하기(RecordingView) 수유 흐름에 노출하고, 유축한 모유를 먹인 섭취를 병수유 내용물(분유/모유) 구분으로 정확히 기록한다.

**Architecture:** 유축(`.feedingPumping`)은 category `.pumping`(생산, 섭취 제외) 유지. 병수유(`.feedingBottle`)에 옵셔널 `feedingContent`(분유/모유) 추가 — 둘 다 category `.feeding`(섭취 포함)이되, "formula 특정"(분유재고 차감·병원리포트 분유량)은 `isFormulaBottle` predicate로 분리. 화면 위치만 이동, 데이터 격리 불변.

**Tech Stack:** SwiftUI, Swift 6, iOS 17+, XCTest. 디자인토큰 `AppColors`.

**Spec:** `docs/superpowers/specs/2026-06-09-feeding-flow-pumping-and-bottle-content-design.md`

---

## File Structure

| 파일 | 책임 | 변경 |
|---|---|---|
| `BabyCare/Models/Activity.swift` | 모델 + 표시/집계 predicate | `FeedingContent` enum, `feedingContent` 필드, init, `isBreastMilkBottle`/`isFormulaBottle`/`displayLabel` |
| `BabyCare/ViewModels/ActivityViewModel.swift` | 입력 폼 상태 | `selectedFeedingContent` 상태 |
| `BabyCare/ViewModels/ActivityViewModel+Save.swift` | 저장 변환 | `applyTypeFields` bottle content + pumping 가드, `resetForm` |
| `BabyCare/Views/Recording/RecordingComponents.swift` | 수유 하위선택 칩 | `FeedingSubPicker` 유축 칩 + per-type 색 + ViewThatFits |
| `BabyCare/Views/Recording/FeedingRecordView.swift` | 수유 기록 폼 | 유축 섹션 + 병수유 내용물 토글 + 재고 게이트 |
| `BabyCare/Views/Dashboard/QuickInputSheet.swift` | 빠른기록 미니시트 | bottle 내용물 토글 + `buildActivity` |
| `BabyCare/Views/Dashboard/ActivityEditSheet.swift` | 기록 편집 | bottle 내용물 편집 |
| `BabyCare/Services/PDFReportService.swift` | 병원 리포트 | 분유량 = `isFormulaBottle`만 |
| `BabyCare/Views/Components/ActivityRow.swift` | 타임라인 행 | `displayLabel` 표시 |
| `BabyCareTests/BabyCareTests.swift` | 단위 테스트 | 모델/집계/buildActivity |

**테스트 철학(이 코드베이스 관행):** 로직은 모델 computed + ViewModel computed(`todayTotalMl` 등, `todayActivities` 직접 셋) + 순수 빌더(`QuickInputSheet.buildActivity`)로 단위 테스트. SwiftUI 뷰 자체(칩 레이아웃·폼 렌더)는 `make build` green + 시뮬레이터 시각 QA로 검증(saveActivity는 firestore 의존이라 기존에도 미단위테스트 — #20과 동일).

---

## Task 1: 모델 — FeedingContent + 집계 predicate

**Files:**
- Modify: `BabyCare/Models/Activity.swift` (필드 `:13` 인접 / init `:171` / enum `:141` 인접 / computeds)
- Test: `BabyCareTests/BabyCareTests.swift`

- [ ] **Step 1: 실패 테스트 작성** — `BabyCareTests/BabyCareTests.swift`의 유축 테스트 블록(`testCalendar_pumpingProducesNoDot` 뒤, `:173` 이후) 다음에 추가:

```swift
    // MARK: - 병수유 내용물 (분유/모유) — 2026-06-09

    func testFeedingContent_displayNameAndRawValue() {
        XCTAssertEqual(Activity.FeedingContent.formula.displayName, "분유")
        XCTAssertEqual(Activity.FeedingContent.breastMilk.displayName, "모유")
        XCTAssertEqual(Activity.FeedingContent.formula.rawValue, "formula")
        XCTAssertEqual(Activity.FeedingContent.breastMilk.rawValue, "breast_milk")
    }

    func testActivity_feedingContentDefaultsNil() {
        let a = Activity(babyId: "b1", type: .feedingBottle, startTime: Date(), amount: 100)
        XCTAssertNil(a.feedingContent, "기존 분유 레코드 하위호환 — 미지정은 nil(=분유)")
    }

    func testActivity_isFormulaBottle_andBreastMilkBottle() {
        let formulaNil = Activity(babyId: "b1", type: .feedingBottle, startTime: Date(), amount: 100)
        XCTAssertTrue(formulaNil.isFormulaBottle, "content nil = 분유 병수유로 취급")
        XCTAssertFalse(formulaNil.isBreastMilkBottle)

        var breast = Activity(babyId: "b1", type: .feedingBottle, startTime: Date(), amount: 100)
        breast.feedingContent = .breastMilk
        XCTAssertTrue(breast.isBreastMilkBottle, "유축한 모유 병수유")
        XCTAssertFalse(breast.isFormulaBottle, "모유 병수유는 분유(formula)로 세면 안 된다")

        let pump = Activity(babyId: "b1", type: .feedingPumping, startTime: Date(), amount: 200)
        XCTAssertFalse(pump.isFormulaBottle)
        XCTAssertFalse(pump.isBreastMilkBottle)
    }

    func testActivity_displayLabel_contentAware() {
        var breast = Activity(babyId: "b1", type: .feedingBottle, startTime: Date(), amount: 100)
        breast.feedingContent = .breastMilk
        XCTAssertEqual(breast.displayLabel, "모유(병)")
        let formula = Activity(babyId: "b1", type: .feedingBottle, startTime: Date(), amount: 100)
        XCTAssertEqual(formula.displayLabel, "분유")
        let pump = Activity(babyId: "b1", type: .feedingPumping, startTime: Date(), amount: 200)
        XCTAssertEqual(pump.displayLabel, "유축")
    }

    @MainActor
    func testBottle_breastMilkCountsAsIntake_pumpingDoesNot() {
        let vm = ActivityViewModel()
        let now = Date()
        var breastBottle = Activity(babyId: "b1", type: .feedingBottle, startTime: now, amount: 50)
        breastBottle.feedingContent = .breastMilk
        vm.todayActivities = [
            Activity(babyId: "b1", type: .feedingBottle, startTime: now, amount: 100), // 분유
            breastBottle,                                                              // 유축한 모유 병수유
            Activity(babyId: "b1", type: .feedingPumping, startTime: now, amount: 200) // 유축(생산)
        ]
        XCTAssertEqual(vm.todayTotalMl, 150, "병수유는 분유·모유 모두 섭취. 유축(생산)만 제외")
        XCTAssertEqual(vm.todayFeedingCount, 2, "병수유 2건은 섭취 횟수. 유축은 미포함")
    }
```

- [ ] **Step 2: 컴파일 실패 확인**

Run: `make build`
Expected: FAIL — `'FeedingContent' is not a member type of struct 'Activity'`, `value of type 'Activity' has no member 'feedingContent'/'isFormulaBottle'/...`

- [ ] **Step 3: 모델 구현** — `BabyCare/Models/Activity.swift`:

(a) 저장 프로퍼티 추가 — `var side: BreastSide?`(`:13`) 바로 아래:
```swift
    var feedingContent: FeedingContent?   // 병수유 내용물(분유/유축한 모유). nil=분유(하위호환). feedingBottle에서만 의미.
```

(b) init(`:171`)에 파라미터 추가 — `side: BreastSide? = nil,` 다음 줄:
```swift
        feedingContent: FeedingContent? = nil,
```
init 본문의 `self.side = side` 다음 줄:
```swift
        self.feedingContent = feedingContent
```

(c) 표시/집계 computed 추가 — 저장 프로퍼티 블록 뒤(struct 본문, init 앞 아무 곳):
```swift
    /// 유축한 모유 병수유 — 섭취(.feeding)지만 'formula' 아님. 분유재고·분유량 집계서 제외용.
    var isBreastMilkBottle: Bool { type == .feedingBottle && feedingContent == .breastMilk }
    /// 진짜 분유(formula) 병수유 — 분유재고 차감·병원리포트 '분유량' 집계 대상(nil=분유).
    var isFormulaBottle: Bool { type == .feedingBottle && feedingContent != .breastMilk }
    /// 타임라인/표시용 라벨 — 모유 병수유는 '모유(병)'로 구분.
    var displayLabel: String { isBreastMilkBottle ? "모유(병)" : type.displayName }
```

(d) `FeedingContent` enum 추가 — `enum BreastSide`(`:141`) 바로 앞:
```swift
    enum FeedingContent: String, Codable, CaseIterable {
        case formula = "formula"          // 분유 (rawValue = Firestore 영구계약)
        case breastMilk = "breast_milk"   // 유축한 모유
        var displayName: String {
            switch self {
            case .formula: "분유"
            case .breastMilk: "모유"
            }
        }
    }
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `make build && make test`
Expected: PASS (위 6개 신규 테스트 + 기존 유축 테스트 green)

- [ ] **Step 5: 커밋**

```bash
git add BabyCare/Models/Activity.swift BabyCareTests/BabyCareTests.swift
git commit -m "feat(model): FeedingContent(분유/모유) + isFormulaBottle/displayLabel — 병수유 내용물 분리 기반"
```

---

## Task 2: 저장 변환 — applyTypeFields + VM 상태

**Files:**
- Modify: `BabyCare/ViewModels/ActivityViewModel.swift` (`:16-20` 상태 인접)
- Modify: `BabyCare/ViewModels/ActivityViewModel+Save.swift` (`applyTypeFields :78`/`:120`, `resetForm :248`)

글루 코드(저장 변환) — saveActivity는 firestore 의존이라 단위테스트 미대상(코드베이스 관행). 값 영속은 Task 5(QuickInputSheet.buildActivity)·시각 QA로 검증. 본 태스크는 `make build` green이 게이트.

- [ ] **Step 1: VM 상태 추가** — `BabyCare/ViewModels/ActivityViewModel.swift`, `var amount: String = ""`(`:17`) 다음:
```swift
    var selectedFeedingContent: Activity.FeedingContent = .formula   // 병수유 내용물(분유 기본)
```

- [ ] **Step 2: resetForm 리셋** — `BabyCare/ViewModels/ActivityViewModel+Save.swift` `resetForm()`(`:248`)의 `selectedSide = .left` 다음:
```swift
        selectedFeedingContent = .formula
```

- [ ] **Step 3: applyTypeFields — bottle content 영속** — `.feedingBottle` case(`:78-86`)의 `activity.amount = Double(amount)` 다음:
```swift
            activity.feedingContent = selectedFeedingContent
```

- [ ] **Step 4: applyTypeFields — pumping 가드 + 주석** — `.feedingPumping` case(`:120-123`) 전체를 교체:
```swift
        case .feedingPumping:
            // 유축 = 생산(.pumping). 빠른기록 미니시트 + 기록하기 양 경로 공용.
            guard isAmountValid else {
                errorMessage = "유축량을 올바르게 입력해주세요. (1~500ml)"
                return false
            }
            activity.amount = Double(amount)
            activity.side = selectedSide
```

- [ ] **Step 5: 빌드 확인**

Run: `make build`
Expected: PASS (컴파일 green — `selectedFeedingContent`/가드 결선 완료)

- [ ] **Step 6: 커밋**

```bash
git add BabyCare/ViewModels/ActivityViewModel.swift BabyCare/ViewModels/ActivityViewModel+Save.swift
git commit -m "feat(save): 병수유 content 영속 + 유축 양 가드 (applyTypeFields)"
```

---

## Task 3: FeedingSubPicker — 유축 칩 + per-type 색 + a11y

**Files:**
- Modify: `BabyCare/Views/Recording/RecordingComponents.swift` (`FeedingSubPicker :70-114`)

SwiftUI 뷰 — `make build` + 시각 QA 게이트.

- [ ] **Step 1: FeedingSubPicker 교체** — `struct FeedingSubPicker`(`:70`) 본문 전체(`:74`의 `feedingTypes`부터 `:113` 닫는 `}` 직전까지)를 아래로 교체:

```swift
    let feedingTypes: [(Activity.ActivityType, String, String)] = [
        (.feedingBreast,  "모유수유", "figure.and.child.holdinghands"),
        (.feedingBottle,  "분유",     "cup.and.saucer.fill"),
        (.feedingSolid,   "이유식",   "fork.knife"),
        (.feedingSnack,   "간식",     "carrot.fill"),
        (.feedingPumping, "유축",     "drop.fill"),
    ]

    private func chipColor(_ type: Activity.ActivityType) -> Color {
        type == .feedingPumping ? AppColors.pumpingColor : .pink   // 유축=보라(생산 구분), 그 외 수유=핑크
    }

    var body: some View {
        // 평소엔 한 줄 5칸, 큰 Dynamic Type에서 잘리면 3+2 두 줄로 reflow (a11y)
        ViewThatFits(in: .horizontal) {
            chipRow(feedingTypes)
            VStack(spacing: 8) {
                chipRow(Array(feedingTypes.prefix(3)))
                chipRow(Array(feedingTypes.suffix(from: 3)))
            }
        }
    }

    @ViewBuilder
    private func chipRow(_ types: [(Activity.ActivityType, String, String)]) -> some View {
        HStack(spacing: 8) {
            ForEach(types, id: \.0) { (type, label, icon) in
                chip(type: type, label: label, icon: icon)
            }
        }
    }

    @ViewBuilder
    private func chip(type: Activity.ActivityType, label: String, icon: String) -> some View {
        let color = chipColor(type)
        Button {
            guard selected != type else { return }
            if activityVM.isTimerRunning { _ = activityVM.stopTimer() }
            withAnimation(.spring(duration: 0.25)) { selected = type }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.body)
                    .accessibilityHidden(true)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(selected == type ? color : color.opacity(0.08))
            .foregroundStyle(selected == type ? .white : color)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(selected == type ? [.isSelected] : [])
    }
```

- [ ] **Step 2: 빌드 확인**

Run: `make build`
Expected: PASS

- [ ] **Step 3: 시각 확인 (수동)** — 기록하기 → 수유: 칩 5개(유축=보라), 큰 글씨에서 2줄 reflow. 유축 탭 시 선택 보라.

- [ ] **Step 4: 커밋**

```bash
git add BabyCare/Views/Recording/RecordingComponents.swift
git commit -m "feat(recording): 수유 하위선택에 유축 칩 추가 (보라, ViewThatFits a11y)"
```

---

## Task 4: FeedingRecordView — 유축 섹션 + 병수유 내용물 + 재고 게이트

**Files:**
- Modify: `BabyCare/Views/Recording/FeedingRecordView.swift`

- [ ] **Step 1: accentColor에 유축** — `accentColor`(`:27-35`) switch에 `.feedingSnack` 다음 줄 추가:
```swift
        case .feedingPumping: AppColors.pumpingColor
```

- [ ] **Step 2: canSave에 유축** — `canSave`(`:19-24`)를 교체:
```swift
    private var canSave: Bool {
        if type == .feedingBottle { return (Int(activityVM.amount) ?? 0) > 0 }
        if type == .feedingPumping { return (Int(activityVM.amount) ?? 0) > 0 }
        return true
    }
```

- [ ] **Step 3: 병수유 내용물 토글** — `bottleAmountSection(vm:)`(`:163`) 내부 `VStack(alignment: .leading, spacing: 10) {`(`:165`) 바로 다음(즉 `Label("섭취량 (ml)"...)` 앞)에 추가:
```swift
                Picker("내용물", selection: Bindable(vm).selectedFeedingContent) {
                    Text("분유").tag(Activity.FeedingContent.formula)
                    Text("유축한 모유").tag(Activity.FeedingContent.breastMilk)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("병수유 내용물")
                .padding(.bottom, 4)

```

- [ ] **Step 4: 유축 섹션 추가** — `bottleAmountSection(vm:)` 함수 끝(`:193` 닫는 `}`) 다음에 신규 함수 추가:
```swift
    @ViewBuilder
    private func pumpingSection(vm: ActivityViewModel) -> some View {
        if type == .feedingPumping {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("유축량 (ml)", systemImage: "drop.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    HStack {
                        TextField("0", text: Bindable(vm).amount)
                            .keyboardType(.numberPad)
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                        Text("ml")
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    quickFillButtons
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label("유축 방향", systemImage: "arrow.left.arrow.right")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        ForEach(Activity.BreastSide.allCases, id: \.self) { side in
                            SideButton(
                                side: side,
                                isSelected: activityVM.selectedSide == side,
                                color: accentColor
                            ) {
                                activityVM.selectedSide = side
                            }
                        }
                    }
                }
                Text("유축 기록은 ‘짜낸 양’이에요. 아기가 실제로 먹은 양은 분유/모유 수유로 따로 기록해 주세요. 그래야 섭취량 통계와 병원 리포트가 정확해요.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(accentColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }
```

- [ ] **Step 5: body에 유축 섹션 결선** — body의 `bottleAmountSection(vm: vm)`(`:51`) 다음 줄:
```swift
                pumpingSection(vm: vm)
```

- [ ] **Step 6: onAppear 유축 방향 기본값** — `.onAppear`(`:62-73`) 블록의 닫는 `}` 직전(직수 if 블록 다음)에 추가:
```swift
            if type == .feedingPumping {
                activityVM.selectedSide = .both   // 유축 기본 방향
            }
```

- [ ] **Step 7: save() 재고 게이트** — `save()`(`:219`)의 재고 차감부(`:232-237`)를 교체:
```swift
            // 유축한 모유 병수유는 분유 재고를 차감하지 않는다 (모유 ≠ formula)
            let skipFormulaDeduction = (type == .feedingBottle && activityVM.selectedFeedingContent == .breastMilk)
            if !skipFormulaDeduction,
               let candidates = await productVM.deductStockForActivity(type, userId: currentUserId, recordedAmount: feedAmount) {
                productCandidates = candidates
            } else {
                isSaving = false
                onSaved?()
            }
```

- [ ] **Step 8: 빌드 확인**

Run: `make build`
Expected: PASS

- [ ] **Step 9: 시각 확인 (수동)** — 유축 칩 → 유축량/방향/카피 폼, 양 0이면 저장 비활성. 분유 칩 → 상단 [분유/유축한 모유] 토글.

- [ ] **Step 10: 커밋**

```bash
git add BabyCare/Views/Recording/FeedingRecordView.swift
git commit -m "feat(recording): 유축 폼(양·방향·카피) + 병수유 내용물 토글 + 모유는 분유재고 미차감"
```

---

## Task 5: QuickInputSheet — 병수유 내용물 (빠른기록 일관성)

**Files:**
- Modify: `BabyCare/Views/Dashboard/QuickInputSheet.swift` (`:22` 상태 / `bottleInput :210` / `buildActivity :259` / `save :295`)
- Test: `BabyCareTests/BabyCareTests.swift`

> 참고: 빠른기록 저장 경로(`DashboardView+Actions.quickSaveWithData`)는 분유 재고를 차감하지 않으므로 재고 게이트 불필요. content 영속만.

- [ ] **Step 1: 실패 테스트 작성** — `BabyCareTests/BabyCareTests.swift` 병수유 블록(Task 1)에 추가:
```swift
    func testQuickInput_bottle_persistsFeedingContent() {
        let breast = QuickInputSheet.buildActivity(
            babyId: "b1", type: .feedingBottle, recordTime: Date(),
            amount: "100", side: nil, feedingContent: .breastMilk,
            temperature: "", medicationName: "", medicationDosage: "", note: ""
        )
        XCTAssertEqual(breast.amount, 100)
        XCTAssertEqual(breast.feedingContent, .breastMilk, "병수유 내용물(모유) 영속")
        XCTAssertTrue(breast.isBreastMilkBottle)

        let formula = QuickInputSheet.buildActivity(
            babyId: "b1", type: .feedingBottle, recordTime: Date(),
            amount: "100", side: nil, feedingContent: .formula,
            temperature: "", medicationName: "", medicationDosage: "", note: ""
        )
        XCTAssertEqual(formula.feedingContent, .formula)
        XCTAssertTrue(formula.isFormulaBottle)
    }
```

- [ ] **Step 2: 컴파일 실패 확인**

Run: `make build`
Expected: FAIL — `buildActivity` 에 `feedingContent` 인자 없음

- [ ] **Step 3: 상태 + buildActivity + bottleInput 구현** — `BabyCare/Views/Dashboard/QuickInputSheet.swift`:

(a) 상태 추가 — `@State private var amount = ""`(`:22`) 다음:
```swift
    @State private var selectedFeedingContent: Activity.FeedingContent = .formula   // 병수유 내용물
```

(b) `buildActivity`(`:259`) 시그니처에 `side:` 다음 파라미터 추가(기본값 → 기존 호출 무영향):
```swift
        side: Activity.BreastSide?,
        feedingContent: Activity.FeedingContent = .formula,
```
그리고 `case .feedingBottle:`(`:279-280`) 본문 교체:
```swift
        case .feedingBottle:
            activity.amount = Double(amount)
            activity.feedingContent = feedingContent
```

(c) `save()`(`:298-308`)의 `buildActivity(...)` 호출에 `side:` 다음 줄 추가:
```swift
            feedingContent: selectedFeedingContent,
```

(d) `bottleInput`(`:210-225`) Section 내부, `HStack { Text("수유량") ... }` 앞에 토글 추가:
```swift
            Picker("내용물", selection: $selectedFeedingContent) {
                Text("분유").tag(Activity.FeedingContent.formula)
                Text("유축한 모유").tag(Activity.FeedingContent.breastMilk)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("병수유 내용물")
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `make build && make test`
Expected: PASS (신규 + 기존 `testQuickInput_pumping_persistsAmountAndSide` 도 green — feedingContent 기본값 덕분)

- [ ] **Step 5: 커밋**

```bash
git add BabyCare/Views/Dashboard/QuickInputSheet.swift BabyCareTests/BabyCareTests.swift
git commit -m "feat(quickinput): 병수유 내용물(분유/모유) 토글 + buildActivity content 영속"
```

---

## Task 6: ActivityEditSheet — 병수유 내용물 편집

**Files:**
- Modify: `BabyCare/Views/Dashboard/ActivityEditSheet.swift` (`:13` 상태 / `:34` init / `:94` 섹션 / `:232` save)

SwiftUI 뷰 — `make build` + 시각 QA.

- [ ] **Step 1: 편집 상태 추가** — `@State private var editedSide: Activity.BreastSide`(`:20`) 다음:
```swift
    @State private var editedFeedingContent: Activity.FeedingContent
```

- [ ] **Step 2: init 초기화** — `_editedAmount = State(...)`(`:34`) 다음:
```swift
        _editedFeedingContent = State(initialValue: activity.feedingContent ?? .formula)
```

- [ ] **Step 3: 편집 UI** — 분유 섹션(`:94` `if activity.type == .feedingBottle { Section("수유량 (ml)") {`) 내부, 수유량 입력 앞에 추가:
```swift
                        Picker("내용물", selection: $editedFeedingContent) {
                            Text("분유").tag(Activity.FeedingContent.formula)
                            Text("유축한 모유").tag(Activity.FeedingContent.breastMilk)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("병수유 내용물")
```

- [ ] **Step 4: save 반영** — save의 `if activity.type == .feedingBottle { updated.amount = Double(editedAmount) }`(`:231-232`)에 amount 다음 줄:
```swift
                            updated.feedingContent = editedFeedingContent
```

- [ ] **Step 5: 빌드 + 시각 확인**

Run: `make build`
Expected: PASS. 시각: 기존 분유 기록 편집 → [분유/모유] 토글, 모유 전환 저장 시 타임라인 "모유(병)"로 변경.

- [ ] **Step 6: 커밋**

```bash
git add BabyCare/Views/Dashboard/ActivityEditSheet.swift
git commit -m "feat(edit): 분유 기록 내용물(분유/모유) 편집"
```

---

## Task 7: 리포트·표시 결선 (formula-only / displayLabel)

**Files:**
- Modify: `BabyCare/Services/PDFReportService.swift` (`:194`, `:223`)
- Modify: `BabyCare/Views/Components/ActivityRow.swift` (`:18`)

predicate는 Task 1에서 단위테스트 완료(`isFormulaBottle`/`displayLabel`). 본 태스크는 결선 + 빌드 green.

- [ ] **Step 1: PDF 총 분유량 formula-only** — `PDFReportService.swift:194`를 교체:
```swift
            ("총 분유량", "\(Int(feedings.filter { $0.isFormulaBottle }.compactMap(\.amount).reduce(0, +)))ml"),
```

- [ ] **Step 2: PDF 일자별 분유량 formula-only** — `:223`를 교체:
```swift
                let bottleMl = Int(day.activities.filter { $0.isFormulaBottle }.compactMap(\.amount).reduce(0, +))
```

- [ ] **Step 3: 타임라인 라벨 content-aware** — `ActivityRow.swift:18`를 교체:
```swift
                Text(activity.displayLabel)
```

- [ ] **Step 4: 빌드 확인**

Run: `make build`
Expected: PASS

- [ ] **Step 5: 커밋**

```bash
git add BabyCare/Services/PDFReportService.swift BabyCare/Views/Components/ActivityRow.swift
git commit -m "fix(report): 병원리포트 분유량 = formula만 + 타임라인 모유(병) 라벨"
```

---

## Task 8: 전체 검증

**Files:** 없음 (게이트)

- [ ] **Step 1: 전체 verify**

Run: `make verify`
Expected: PASS — build + lint + arch(R1=R2=R3=R4=0) + test(신규 7 + 기존 유축 + 회귀) + design.

- [ ] **Step 2: 회귀 단언 재확인** — 아래 테스트가 모두 green인지 확인:
  - `testPumping_excludedFromTodayFeedingTotals` (유축 격리 유지)
  - `testBottle_breastMilkCountsAsIntake_pumpingDoesNot` (모유 병수유=섭취, 유축=제외)
  - `testActivity_isFormulaBottle_andBreastMilkBottle`
  - `testQuickInput_pumping_persistsAmountAndSide` + `testQuickInput_bottle_persistsFeedingContent`

- [ ] **Step 3: 시뮬레이터 시각 QA (수동)** — 기록하기 유축 칩→폼 / 분유 내용물 토글 / 타임라인 "유축"·"모유(병)" 구분 / 다크모드 보라 / VoiceOver(유축 방향·병수유 내용물 라벨) / 큰 글씨 칩 2줄 reflow.

---

## Task 9: 출시 (PO 게이트 — 승인 시에만)

**Files:** `project.yml`

> 현재 로컬 `project.yml` = v2.8.6 빌드87(미커밋, TestFlight 업로드됨). 본 작업은 빌드87 이후 → 빌드88.

- [ ] **Step 1: 빌드 번호 bump** (이번엔 정상 — 87이 소비 최대)

Run: `make bump`
Expected: `📦 빌드 번호: 87 → 88` (project.yml 4필드 중 CURRENT_PROJECT_VERSION 2곳 = 88)

- [ ] **Step 2: 릴리즈 커밋** (PO 승인 시)

```bash
git add project.yml
git commit -m "chore(release): v2.8.6 빌드88 — 유축 기록하기 통합 + 병수유 내용물"
```

- [ ] **Step 3: archive + TestFlight 업로드** (PO 승인 시)

Run: `make upload`
Expected: `UPLOAD SUCCEEDED`. 이후 ASC 재조회로 빌드88 VALID 확인.

---

## 자기검토 결과 (작성자)
- **스펙 커버리지**: Part1(유축 기록하기)=T3·T4 / Part2(병수유 내용물)=T1·T2·T5·T6 / 잔물결(재고·PDF·표시)=T4·T7 / 일관성(편집)=T6 / 격리 회귀=T1·T8. 갭 없음.
- **플레이스홀더**: 없음(모든 step 실제 코드/명령).
- **타입 일관성**: `FeedingContent`/`feedingContent`/`isFormulaBottle`/`isBreastMilkBottle`/`displayLabel`/`selectedFeedingContent` 명칭 전 태스크 일치. `buildActivity`는 `feedingContent: = .formula` 기본값으로 기존 호출 무파손.
- **스코프 메모**: QuickInputSheet 재고 게이트 불필요(consumer가 미차감) 확인 반영. 분유 재고 차감 게이트는 FeedingRecordView 한 곳.
