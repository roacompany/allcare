# 앱 평가 팝업 (App Review Prompt) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 긍정적 성취(기록 20개 / 병원리포트 완료) 중 먼저 도달한 1개에서 Apple 시스템 평가 시트를 생애 1회 띄우고, 설정에 상시 "리뷰 남기기" 딥링크 버튼을 둔다.

**Architecture:** 순수 `AppReviewPromptService`(@MainActor @Observable, UserDefaults 1플래그·StoreKit/Firestore 무의존)가 one-shot 상태와 대기 신호를 보유. ViewModel 트리거는 `noteTrigger`로 대기만 세우고, 유일한 초크포인트 `ContentView`가 scene 활성 + 배지 스낵바 없음일 때 `@Environment(\.requestReview)`를 호출하며 원자적으로 소진. 설정 버튼은 자동 1회와 독립.

**Tech Stack:** Swift 6 / SwiftUI iOS 17+ / `@Environment(\.requestReview)` (StoreKit, iOS 16+) / XCTest / UserDefaults.

**Spec:** `docs/superpowers/specs/2026-06-10-app-review-prompt-design.md`

**Branch:** `feat/app-review-prompt` (이미 생성됨, off `origin/main`)

---

## File Structure

| 파일 | 책임 | 작업 |
|------|------|------|
| `BabyCare/Services/AppReviewPromptService.swift` | one-shot 상태 + 대기 신호 + 임계값 헬퍼 (순수) | **신규** |
| `BabyCare/Utils/FeatureFlags.swift` | `appReviewPromptEnabled` 컴파일 킬스위치 | 수정 |
| `BabyCare/Services/AnalyticsEvents.swift` | `reviewPromptRequested` 이벤트 + `trigger` 파라미터 키 | 수정 |
| `BabyCare/Services/ActivityFirestoreProviding.swift` | `fetchStats` narrow protocol 메서드 추가 | 수정 |
| `BabyCareTests/MockActivityFirestore.swift` | `fetchStats` 스텁 | 수정 |
| `BabyCare/ViewModels/ActivityViewModel+Save.swift` | 기록 마일스톤 트리거 배선 | 수정 |
| `BabyCare/App/ContentView.swift` | 초크포인트(requestReview + scene/overlay 가드) | 수정 |
| `BabyCare/Views/Health/HospitalVisitComponents.swift` | 병원리포트 완료 트리거 배선 | 수정 |
| `BabyCare/Views/Settings/SettingsView.swift` | "리뷰 남기기" 딥링크 행 | 수정 |
| `BabyCareTests/BabyCareTests.swift` | AppReviewPromptService 단위 테스트 | 수정 |

**불변 규칙(스펙 §2/§7):** 유축·임신 무관. requestReview는 **View에서만** 호출(서비스는 UI 무의존). `.unknown` 무관. 자동 1회와 설정 버튼은 **독립**. per-device 1회 수용.

---

### Task 1: AppReviewPromptService + FeatureFlag + 단위 테스트 (TDD)

**Files:**
- Create: `BabyCare/Services/AppReviewPromptService.swift`
- Modify: `BabyCare/Utils/FeatureFlags.swift` (line 29 뒤에 추가)
- Test: `BabyCareTests/BabyCareTests.swift` (append)

- [ ] **Step 1: 실패하는 테스트 작성** — `BabyCareTests/BabyCareTests.swift` 끝(마지막 `}` 직전)에 추가:

```swift
    // MARK: - App Review Prompt Tests

    private func makeEphemeralReviewDefaults() -> UserDefaults {
        let name = "test.appReview.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @MainActor
    func testReviewPrompt_firstTrigger_setsPending() {
        let svc = AppReviewPromptService(defaults: makeEphemeralReviewDefaults(), isEnabled: true)
        svc.noteTrigger(.recordsMilestone)
        XCTAssertEqual(svc.pendingTrigger, .recordsMilestone)
        XCTAssertFalse(svc.isConsumed)
    }

    @MainActor
    func testReviewPrompt_consume_marksConsumedAndClears() {
        let svc = AppReviewPromptService(defaults: makeEphemeralReviewDefaults(), isEnabled: true)
        svc.noteTrigger(.hospitalReport)
        let consumed = svc.consumePending()
        XCTAssertEqual(consumed, .hospitalReport)
        XCTAssertTrue(svc.isConsumed)
        XCTAssertNil(svc.pendingTrigger)
    }

    @MainActor
    func testReviewPrompt_afterConsume_noRearm() {
        let defaults = makeEphemeralReviewDefaults()
        let svc = AppReviewPromptService(defaults: defaults, isEnabled: true)
        svc.noteTrigger(.recordsMilestone)
        _ = svc.consumePending()
        svc.noteTrigger(.hospitalReport)
        XCTAssertNil(svc.pendingTrigger)
    }

    @MainActor
    func testReviewPrompt_secondTriggerIgnoredWhilePending() {
        let svc = AppReviewPromptService(defaults: makeEphemeralReviewDefaults(), isEnabled: true)
        svc.noteTrigger(.recordsMilestone)
        svc.noteTrigger(.hospitalReport)
        XCTAssertEqual(svc.pendingTrigger, .recordsMilestone)
    }

    @MainActor
    func testReviewPrompt_disabled_noPending() {
        let svc = AppReviewPromptService(defaults: makeEphemeralReviewDefaults(), isEnabled: false)
        svc.noteTrigger(.recordsMilestone)
        XCTAssertNil(svc.pendingTrigger)
    }

    @MainActor
    func testReviewPrompt_consumedFlagPersistsAcrossInstances() {
        let defaults = makeEphemeralReviewDefaults()
        let first = AppReviewPromptService(defaults: defaults, isEnabled: true)
        first.noteTrigger(.recordsMilestone)
        _ = first.consumePending()

        let second = AppReviewPromptService(defaults: defaults, isEnabled: true)
        second.noteTrigger(.hospitalReport)
        XCTAssertTrue(second.isConsumed)
        XCTAssertNil(second.pendingTrigger)
    }

    func testReviewPrompt_coreActivityTotal() {
        XCTAssertEqual(AppReviewPromptService.coreActivityTotal(nil), 0)
        var stats = UserStats.empty()
        stats.feedingCount = 7
        stats.sleepCount = 5
        stats.diaperCount = 6
        stats.growthRecordCount = 2
        XCTAssertEqual(AppReviewPromptService.coreActivityTotal(stats), 20)
    }
```

- [ ] **Step 2: 빌드해서 실패 확인**

Run: `make build`
Expected: FAIL — `cannot find 'AppReviewPromptService' in scope`

- [ ] **Step 3: FeatureFlag 추가** — `BabyCare/Utils/FeatureFlags.swift`에서 `designSystemV2Preview` 줄(line 29) 다음, `enum` 닫는 `}` 직전에 추가:

```swift

    /// 앱 평가(App Store 리뷰) 팝업 compile-time kill switch.
    /// true = 활성. 긍정적 성취(기록 20개 / 병원리포트 완료) 중 먼저 도달한 1개에서
    /// 시스템 평가 시트를 생애 1회 호출(AppReviewPromptService). RemoteConfig 미연결
    /// (FirebaseRemoteConfig import 금지, A-18). false 시 자동 팝업 + 설정 "리뷰 남기기" 행 모두 비활성.
    static let appReviewPromptEnabled: Bool = true
```

- [ ] **Step 4: 서비스 구현** — `BabyCare/Services/AppReviewPromptService.swift` 생성:

```swift
import Foundation

/// 앱 평가(App Store 리뷰) 팝업 one-shot 게이트.
///
/// 순수 상태/결정 단위 — StoreKit/SwiftUI/Firestore 무의존(동기 단위 테스트 가능).
/// 트리거 사이트가 `noteTrigger`로 대기만 세우고, 초크포인트 View(`ContentView`)가
/// scene 활성 + 배지 스낵바 없음일 때 `@Environment(\.requestReview)`를 호출하고
/// `consumePending()`으로 원자적으로 소진한다.
///
/// `autoReviewPromptConsumed`(UserDefaults)의 의미 = "자동 1회 호출을 이미 소진(=다시
/// 자동호출 안 함)". '사용자가 리뷰했음'이 아님 — requestReview는 콜백/결과가 없다.
/// per-device(가족 다기기는 기기마다 1회 — Apple 연 3회 상한이라 수용).
@MainActor
@Observable
final class AppReviewPromptService {
    static let shared = AppReviewPromptService()

    /// 자동 팝업 후보 트리거. 먼저 도달한 1개가 이긴다. (v1.1: badge, highlights)
    enum Trigger: String { case recordsMilestone, hospitalReport }

    /// 누적 핵심 활동(수유+수면+기저귀+성장) 기록 마일스톤 임계값.
    static let recordsMilestoneThreshold = 20

    private let defaults: UserDefaults
    private let isEnabled: Bool
    private static let consumedKey = "autoReviewPromptConsumed"

    /// 트리거가 자격 충족 시 세우는 대기 신호. 초크포인트 View가 관찰. (아직 소진 아님)
    private(set) var pendingTrigger: Trigger?

    init(defaults: UserDefaults = .standard,
         isEnabled: Bool = FeatureFlags.appReviewPromptEnabled) {
        self.defaults = defaults
        self.isEnabled = isEnabled
    }

    var isConsumed: Bool { defaults.bool(forKey: Self.consumedKey) }

    /// 트리거 사이트가 "깨끗한 순간"에 호출. 자격(플래그 on + 미소진 + 미대기) 시 대기만 세움.
    func noteTrigger(_ trigger: Trigger) {
        guard isEnabled else { return }
        guard !isConsumed, pendingTrigger == nil else { return }
        pendingTrigger = trigger
    }

    /// 초크포인트 View가 requestReview() 직전에 호출. 원자적으로 소진 + 대기 해제.
    /// read→write 사이 await 없음 → MainActor에서 분리 불가(레이스 방지).
    @discardableResult
    func consumePending() -> Trigger? {
        guard let trigger = pendingTrigger else { return nil }
        defaults.set(true, forKey: Self.consumedKey)
        pendingTrigger = nil
        return trigger
    }

    /// 누적 핵심 활동 기록 수(수유+수면+기저귀+성장). nil은 0.
    nonisolated static func coreActivityTotal(_ stats: UserStats?) -> Int {
        (stats?.feedingCount ?? 0) + (stats?.sleepCount ?? 0)
            + (stats?.diaperCount ?? 0) + (stats?.growthRecordCount ?? 0)
    }
}
```

- [ ] **Step 5: 빌드 + 테스트 통과 확인**

Run: `make build && make test`
Expected: 빌드 성공 + 신규 7개 테스트(`testReviewPrompt_*`) PASS, 기존 테스트 회귀 0.

- [ ] **Step 6: 커밋**

```bash
git add BabyCare/Services/AppReviewPromptService.swift BabyCare/Utils/FeatureFlags.swift BabyCareTests/BabyCareTests.swift
git commit -m "feat(review-prompt): AppReviewPromptService one-shot 게이트 + 단위 테스트"
```

---

### Task 2: Analytics 이벤트 상수

**Files:**
- Modify: `BabyCare/Services/AnalyticsEvents.swift`

- [ ] **Step 1: 이벤트 + 파라미터 키 추가** — `AnalyticsEvents` enum의 마지막 멤버(`highlightCardTapped`, line 68) 다음 줄에 추가:

```swift

    // App Review — 시스템 평가 시트/딥링크 요청 시점 (requestReview는 콜백 없음 → 유일한 계측).
    static let reviewPromptRequested = "review_prompt_requested"
```

그리고 `AnalyticsParams` enum의 `source`(line 77) 다음 줄에 추가:

```swift
    static let trigger = "trigger"
```

- [ ] **Step 2: 빌드 확인**

Run: `make build`
Expected: PASS

- [ ] **Step 3: 커밋**

```bash
git add BabyCare/Services/AnalyticsEvents.swift
git commit -m "feat(review-prompt): review_prompt_requested analytics 이벤트 상수"
```

---

### Task 3: 기록 마일스톤 트리거 배선 (provider fetchStats + 저장 경로)

**Files:**
- Modify: `BabyCare/Services/ActivityFirestoreProviding.swift`
- Modify: `BabyCareTests/MockActivityFirestore.swift`
- Modify: `BabyCare/ViewModels/ActivityViewModel+Save.swift`

- [ ] **Step 1: narrow protocol에 fetchStats 추가** — `ActivityFirestoreProviding`(line 11 `saveWeeklyMetricSnapshot...` 다음, 닫는 `}` 직전)에 추가:

```swift
    func fetchStats(userId: String) async throws -> UserStats?
```

(`extension FirestoreService: ActivityFirestoreProviding {}`는 이미 `FirestoreService+Stats.swift`의 `fetchStats`로 자동 충족 — 추가 구현 불필요.)

- [ ] **Step 2: Mock에 fetchStats 스텁 추가** — `BabyCareTests/MockActivityFirestore.swift`의 `saveWeeklyMetricSnapshot(...)` 메서드 다음, 클래스 닫는 `}` 직전에 추가. 그리고 stub 프로퍼티를 `weeklyMetricSnapshotsResponse` 선언부 근처에 추가:

```swift
    // (프로퍼티 — 기존 var ...Response 들과 함께)
    var statsResponse: UserStats?

    // (메서드 — 클래스 끝)
    func fetchStats(userId: String) async throws -> UserStats? {
        statsResponse
    }
```

- [ ] **Step 3: 저장 경로에 records 트리거 배선** — `BabyCare/ViewModels/ActivityViewModel+Save.swift`의 `evaluateBadgesIfNeeded`(line 238-243)를 아래로 교체하고, 바로 밑에 헬퍼 추가:

```swift
    private func evaluateBadgesIfNeeded(type: Activity.ActivityType, babyId: String, currentUserId: String, at date: Date) async {
        guard let kind = BadgeEvaluator.eventKind(for: type) else { return }
        let event = BadgeEvaluator.Event(kind: kind, babyId: babyId, at: date)
        let earned = await BadgeEvaluator().evaluate(event: event, userId: currentUserId)
        AppState.shared.badgePresenter.enqueue(earned)
        await noteRecordsMilestoneIfEligible(currentUserId: currentUserId)
    }

    /// 누적 핵심 활동 기록이 임계값(20)을 넘으면 앱 평가 대기 신호. 이미 소진됐으면 stats fetch도 생략.
    private func noteRecordsMilestoneIfEligible(currentUserId: String) async {
        guard !AppReviewPromptService.shared.isConsumed else { return }
        let stats = try? await firestoreService.fetchStats(userId: currentUserId)
        guard AppReviewPromptService.coreActivityTotal(stats) >= AppReviewPromptService.recordsMilestoneThreshold else { return }
        AppReviewPromptService.shared.noteTrigger(.recordsMilestone)
    }
```

- [ ] **Step 4: 빌드 + 테스트**

Run: `make build && make test`
Expected: PASS (MockActivityFirestore 프로토콜 충족, 기존 ActivityViewModel 테스트 회귀 0).

- [ ] **Step 5: 커밋**

```bash
git add BabyCare/Services/ActivityFirestoreProviding.swift BabyCareTests/MockActivityFirestore.swift BabyCare/ViewModels/ActivityViewModel+Save.swift
git commit -m "feat(review-prompt): 누적 기록 20개 마일스톤 트리거 배선 (fetchStats narrow protocol)"
```

---

### Task 4: ContentView 초크포인트 (requestReview + scene/overlay 가드)

**Files:**
- Modify: `BabyCare/App/ContentView.swift`

- [ ] **Step 1: 환경값 + 서비스 참조 추가** — line 22 `@Environment(\.scenePhase) private var scenePhase` 다음에 추가:

```swift
    @Environment(\.requestReview) private var requestReview
    private let reviewService = AppReviewPromptService.shared
```

- [ ] **Step 2: scenePhase onChange에 호출 추가** — 기존 `.onChange(of: scenePhase)`(line 129-140) 블록의 `if newPhase == .active {` 내부 첫 줄에 추가:

```swift
                presentAutoReviewIfClean()
```

- [ ] **Step 3: 대기/스낵바 onChange 추가** — `.onChange(of: scenePhase) { ... }`(line 140의 닫는 `}`) 바로 다음에 두 modifier 추가:

```swift
        .onChange(of: reviewService.pendingTrigger) { _, _ in
            presentAutoReviewIfClean()
        }
        .onChange(of: AppState.shared.badgePresenter.current == nil) { _, _ in
            presentAutoReviewIfClean()
        }
```

- [ ] **Step 4: 초크포인트 헬퍼 추가** — `// MARK: - Badge Backfill` 주석(line 158) 바로 앞에 추가:

```swift
    // MARK: - App Review Prompt (초크포인트)

    /// 대기 트리거가 있고 scene 활성 + 배지 스낵바 없음일 때만, 정착 지연 후 시스템 평가 시트 1회.
    /// scene 비활성/스낵바 표시 중에는 소진하지 않고 대기(그 1샷을 허공에 날리지 않음).
    private func presentAutoReviewIfClean() {
        guard reviewService.pendingTrigger != nil else { return }
        guard scenePhase == .active else { return }
        let presenter = AppState.shared.badgePresenter
        guard presenter.current == nil, presenter.pending.isEmpty else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(700)) // 스낵바 트랜지션 정착
            guard presenter.current == nil, presenter.pending.isEmpty else { return }
            guard let trigger = reviewService.consumePending() else { return }
            requestReview()
            AnalyticsService.shared.trackEvent(
                AnalyticsEvents.reviewPromptRequested,
                parameters: [AnalyticsParams.trigger: trigger.rawValue, AnalyticsParams.source: "auto"]
            )
        }
    }
```

- [ ] **Step 5: 빌드 + 테스트**

Run: `make build && make test`
Expected: PASS. (`@Environment(\.requestReview)`는 SwiftUI 제공 — StoreKit import 불필요.)

- [ ] **Step 6: 커밋**

```bash
git add BabyCare/App/ContentView.swift
git commit -m "feat(review-prompt): ContentView 초크포인트 — scene/스낵바 가드 후 requestReview 1회"
```

---

### Task 5: 병원리포트 완료 트리거

**Files:**
- Modify: `BabyCare/Views/Health/HospitalVisitComponents.swift`

- [ ] **Step 1: HospitalReportSheet에 onChange 추가** — `HospitalReportSheet.body`의 `Group { switch reportVM.state { ... } }` 닫는 `}` 다음(즉 `Group` 바로 뒤)에 modifier 추가:

```swift
        .onChange(of: reportVM.cachedReport != nil) { _, hasReport in
            if hasReport { AppReviewPromptService.shared.noteTrigger(.hospitalReport) }
        }
```

(`cachedReport`는 `.done`/캐시히트 시 set됨 → false→true 전이에서 1회 발화. 실제 시트는 `ContentView` 초크포인트가 scene/스낵바 가드 후 표시.)

- [ ] **Step 2: 빌드**

Run: `make build`
Expected: PASS

- [ ] **Step 3: 커밋**

```bash
git add BabyCare/Views/Health/HospitalVisitComponents.swift
git commit -m "feat(review-prompt): 병원리포트 생성 완료 트리거"
```

---

### Task 6: 설정 "리뷰 남기기" 딥링크 행

**Files:**
- Modify: `BabyCare/Views/Settings/SettingsView.swift`

- [ ] **Step 1: openURL 환경값 추가** — line 8 `@Environment(PregnancyViewModel.self) private var pregnancyVM` 다음에 추가:

```swift
    @Environment(\.openURL) private var openURL
```

- [ ] **Step 2: "정보" Section에 버튼 추가** — `Section("정보") {`(line 263) 바로 다음 줄(버전 `HStack` 앞)에 추가:

```swift
                    if FeatureFlags.appReviewPromptEnabled {
                        Button {
                            AnalyticsService.shared.trackEvent(
                                AnalyticsEvents.reviewPromptRequested,
                                parameters: [AnalyticsParams.source: "settings"]
                            )
                            if let url = URL(string: "itms-apps://apps.apple.com/app/id6759935352?action=write-review") {
                                openURL(url)
                            }
                        } label: {
                            Label("리뷰 남기기", systemImage: "star.bubble")
                        }
                        .accessibilityLabel("App Store에서 리뷰 남기기")
                    }
```

- [ ] **Step 3: 빌드**

Run: `make build`
Expected: PASS

- [ ] **Step 4: 커밋**

```bash
git add BabyCare/Views/Settings/SettingsView.swift
git commit -m "feat(review-prompt): 설정 '리뷰 남기기' App Store 딥링크 행 (자동 1회와 독립)"
```

---

### Task 7: 전체 검증 + arch/lint/design

**Files:** (없음 — 게이트 통과 확인)

- [ ] **Step 1: arch-test (Rule 3 = Firestore 직접호출 0 확인)**

Run: `bash scripts/arch_test.sh`
Expected: `✅ R1=0 R2=0 R3=0 R4=0` (AppReviewPromptService는 Firestore 무의존 → Rule 3 위반 없음).

- [ ] **Step 2: 전체 verify**

Run: `make verify`
Expected: 빌드 + lint(신규 경고 0) + arch(R1-4=0) + test(신규 7 포함 전체 PASS) + design(100%) 모두 통과.

- [ ] **Step 3: 잔여 정리 커밋(있으면)**

```bash
git status --short
# lint/format 변경이 있으면:
git add -A && git commit -m "chore(review-prompt): make verify 정리"
```

---

## H-items (사람 QA — TestFlight, 코드 완료 후)

- **자동 팝업**: 새 계정으로 핵심 기록(수유/수면/기저귀/성장) 20개 누적 → 다음 저장 직후 평가 시트 1회 노출(스낵바와 안 겹침). 닫은 뒤 추가 저장에도 재노출 없음. (디버그 빌드는 throttle 없어 매번 뜰 수 있음 — 정상.)
- **병원리포트**: 리포트 생성 완료 화면에서 ~0.7s 후 평가 시트(기록 트리거 전 미소진 상태일 때). 공유 시트 사용 중엔 안 뜸/소진 안 함 확인.
- **설정 버튼**: 설정 → 정보 → "리뷰 남기기" → 실기기에서 App Store 작성 화면 직행. 자동 1회 소진과 무관(독립) 확인.
- **a11y/다크모드**: AccessibilityXXXL에서 행 truncate 없는지, VoiceOver 라벨("App Store에서 리뷰 남기기").
- **킬스위치**: `FeatureFlags.appReviewPromptEnabled = false` 빌드 → 자동 팝업 + 설정 행 모두 사라짐.

---

## Self-Review (스펙 대조)

| 스펙 요구 | 커버 Task |
|-----------|-----------|
| §3 자동 1회 + 설정 버튼 | Task 1(서비스)·4(초크포인트)·6(버튼) |
| §4 트리거 2종(기록20·병원리포트) | Task 3·5 |
| §5.1 순수 서비스(Firestore-free, @MainActor 원자 게이트) | Task 1 |
| §5.2 초크포인트 ContentView(scene+스낵바 가드) | Task 4 |
| §5.3 설정 버튼 독립(자동 1회 안 끔) | Task 6 (markConsumed 없음 — 버튼은 openURL+analytics만) |
| §6 UserDefaults 1플래그 per-device | Task 1 (`consumedKey`) |
| §7 once + scene-active 가드(샷 보존) + 무재시도 | Task 4 (`presentAutoReviewIfClean`) |
| §8 컴파일 킬스위치 + OFF 시 버튼 숨김 | Task 1(flag)·6(`if FeatureFlags...`) |
| §9 analytics 이벤트(건강정보 미포함) | Task 2·4·6 (trigger/source만) |
| §10 a11y/딥링크 fallback | Task 6 (accessibilityLabel, itms-apps URL) |
| §11 단위 테스트 | Task 1 (7개) |
| §12 비범위(배지·하이라이트 v1.1) | 미포함(의도) |

**Placeholder 스캔:** 없음 — 모든 코드 블록은 실제 삽입 내용. **타입 일관성:** `Trigger`/`recordsMilestoneThreshold`/`coreActivityTotal`/`pendingTrigger`/`consumePending`/`noteTrigger`/`isConsumed`가 Task 1 정의와 Task 3·4·5 사용처에서 일치.
