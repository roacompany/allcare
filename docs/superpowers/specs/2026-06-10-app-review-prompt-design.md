# 앱 평가 팝업 (App Review Prompt) — 설계

- 날짜: 2026-06-10
- 브랜치: `feat/app-review-prompt` (off `origin/main` `b73dae0`)
- 상태: 설계 승인됨(구두) → 적대적 리뷰 반영본. **PO 스펙 리뷰 대기.**

## 1. 목표

긍정적 성취 순간에 **Apple 시스템 평가 시트(`requestReview`)를 생애 1회** 띄워 자발적 별점/리뷰를 유도한다. 더불어 설정 화면에 **상시 "리뷰 남기기"** 버튼(App Store 작성 화면 딥링크)을 둔다. App Store ID = `6759935352`.

## 2. ⚠️ 승인안 대비 변경점 (PO 확인 필요)

적대적 스펙 리뷰(HIGH 3건) 결과, 승인된 설계에서 **두 가지를 의도적으로 변경**했다. PO가 원치 않으면 되돌린다.

| # | 승인안 | 변경본 | 이유 |
|---|--------|--------|------|
| A | 트리거 4종(배지·하이라이트·기록마일스톤·병원리포트) | **v1은 2종(기록 마일스톤 + 병원리포트)**. 배지·하이라이트는 **v1.1로 보류**(§12에 부활 요건 명시) | 배지: 누적 카운트 부재 + backfill 무더기 지급 → **앱 시작 시 스낵바 위 오발** 위험 + 오버레이 충돌. 하이라이트: 현재 RemoteConfig로 **꺼져 있음**(`highlight_enabled=false`/`ticker_pct=0`)이라 사실상 dark. 둘 다 위험·저효율 대비 구현비용 큼 |
| B | 설정 "리뷰 남기기" 누르면 자동팝업도 OFF | **설정 버튼은 자동팝업 1회와 독립**(서로 안 끔) | "리뷰 페이지 열기 ≠ 작성 완료". 딴짓하다 미작성한 사용자가 편한 인앱 시트까지 영영 못 받게 됨 |

그 외 승인안(시스템 시트·딥링크 버튼·UserDefaults 1플래그·컴파일 킬스위치·"먼저 도달한 트리거 1번만")은 유지.

## 3. UX 동작

- 사용자가 **기록 마일스톤** 또는 **병원리포트 생성 완료** 중 먼저 도달하는 순간 → 화면이 **안정적이고(다른 시트/스낵바 없음) scene이 활성**일 때 시스템 평가 시트를 1회 호출. 이후 자동 호출 영구 중단.
- 설정 → "리뷰 남기기" → App Store 작성 화면으로 직행(언제나, 자동 1회와 무관).

## 4. 트리거 (v1)

"먼저 자격 충족한 1개"가 이긴다(중복 호출 불가 — §5 원자적 게이트). 트리거는 자체로 충분한 참여 신호라 별도 engagement floor 불필요.

| 트리거 | 발화 지점(파일·심볼) | 조건 | 데이터 소스 |
|--------|----------------------|------|-------------|
| `recordsMilestone` | `ViewModels/ActivityViewModel+Save.swift` — 저장 완료(배지 평가 직후, 이미 stats 접근하는 경로) | 누적 기록 **총 ≥ 20** | `UserStats`(`Models/UserStats.swift`) 4필드 합: `(feedingCount ?? 0)+(sleepCount ?? 0)+(diaperCount ?? 0)+(growthRecordCount ?? 0)`. `users/{uid}/stats/lifetime`(`UserStats.lifetimeId`) |
| `hospitalReport` | `ViewModels/HospitalReportViewModel.swift` — `state = .done(report)` | 리포트 렌더 완료 **그리고** 공유/내보내기 시트가 닫힌 "깨끗한 순간" | 상태 전이 `.generating → .done` |

- **임계값 상수**는 서비스에 중앙화(`Trigger`별 상수). `≥ 20`은 *정확한 20번째 교차 감지 불필요* — 게이트가 멱등(§5)이라 20 이상 매 저장마다 호출해도 대기 신호는 1회만 세팅.
- **누적 카운트 읽기는 트리거 사이트(ViewModel)에서** 수행 — 배지 평가가 쓰는 동일 stats 재사용 또는 `FirestoreService.fetchStats`(단일 문서, 저렴). 서비스는 결과(`total ≥ 20` 여부)만 통지받아 **Firestore-free 유지**(arch Rule 3). 정확한 재사용 경로는 구현 단계 확정.
- 병원리포트는 **공유 시트가 떠 있는 동안 호출 금지**(시트 동시 표시 불가). 리포트 화면이 공유 시트 dismiss 후에 `noteTrigger` 호출.

## 5. 아키텍처

UI 부작용은 View, 상태·로직은 Service라는 기존 원칙을 따른다. `requestReview`는 `@Environment` 액션이라 View에서만 호출 가능 → ViewModel 트리거는 **대기 신호 → 단일 초크포인트 View**로 브리지한다.

### 5.1 `AppReviewPromptService` (신규, `Services/`)
순수 상태/결정 단위. **StoreKit/SwiftUI/Firestore import 없음** → 동기 유닛 테스트 가능. `ThemeManager.swift` 패턴(@MainActor @Observable + UserDefaults) 준용.

```swift
@MainActor @Observable final class AppReviewPromptService {
    static let shared = AppReviewPromptService()

    enum Trigger: String { case recordsMilestone, hospitalReport } // v1.1: badge, highlights

    static let recordsMilestoneThreshold = 20

    private let defaults: UserDefaults
    private let isEnabled: Bool   // 기본 = FeatureFlags.appReviewPromptEnabled (테스트에서 OFF 주입용)
    /// 의미: 자동 1회 호출을 이미 "소진"(=다시 자동호출 안 함). '사용자가 리뷰했음'이 아님.
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
        guard isEnabled else { return }              // 컴파일 킬스위치 early-guard (주입 가능)
        guard !isConsumed, pendingTrigger == nil else { return }
        pendingTrigger = trigger
    }

    /// 초크포인트 View가 requestReview() 호출 직후 호출. 원자적으로 소진 + 대기 해제.
    @discardableResult
    func consumePending() -> Trigger? {
        guard let t = pendingTrigger else { return nil }
        defaults.set(true, forKey: Self.consumedKey)   // 소진(read→write 사이 await 없음 = 원자적)
        pendingTrigger = nil
        return t
    }
}
```

- **레이스 방지**: `@MainActor` + `noteTrigger`/`consumePending`이 동기 check-and-set(중간 `await` 없음). 같은 런루프에 두 트리거가 겹쳐도(예: 20번째 저장이 배지도 지급) 대기는 1개, 소진은 1회.
- **Firestore 없음** → arch-test Rule 3 위반 없음, narrow protocol 불필요. (트리거 사이트가 이미 가진 stats를 읽어 임계값을 *계산*하고, 서비스엔 결과만 통지.)

### 5.2 초크포인트 View = `ContentView` (배지 스낵바 오버레이를 이미 호스팅)
`requestReview` + `scenePhase` + 오버레이 상태를 아는 **유일한** 곳.

```swift
@Environment(\.requestReview) private var requestReview
@Environment(\.scenePhase) private var scenePhase
private let reviewService = AppReviewPromptService.shared
// AppState.shared.badgePresenter 로 스낵바 상태 확인

private func presentAutoReviewIfClean() {
    guard reviewService.pendingTrigger != nil else { return }
    guard scenePhase == .active else { return }                 // 비활성 scene이면 소진 안 함 = 샷 보존
    let presenter = AppState.shared.badgePresenter
    guard presenter.current == nil, presenter.isQueueEmpty else { return } // 배지 스낵바에 양보
    Task { @MainActor in
        try? await Task.sleep(for: .milliseconds(700))          // 스낵바 트랜지션 정착 대기
        guard scenePhase == .active,
              presenter.current == nil, presenter.isQueueEmpty,
              reviewService.pendingTrigger != nil else { return }
        requestReview()                                          // @MainActor, View에서만
        if let t = reviewService.consumePending() {
            AnalyticsService.shared.trackEvent(.reviewPromptRequested,
                parameters: ["trigger": t.rawValue, "source": "auto"])
        }
    }
}
// .onChange(of: reviewService.pendingTrigger) / .onChange(of: scenePhase) / .onChange(of: presenter.current?.id) → presentAutoReviewIfClean()
```

- `badgePresenter`에 `isQueueEmpty` 류 read-only 노출이 없으면 추가(대기열 비었는지). 구현 단계 확정.

### 5.3 설정 "리뷰 남기기" 행 (`SettingsView.swift`)
"법적 고지" Section(개인정보/약관 `Link` 옆) 또는 "정보" Section에 추가. **자동 1회와 독립**.

```swift
Button {
    AnalyticsService.shared.trackEvent(.reviewPromptRequested, parameters: ["source": "settings"])
    openURL(Self.writeReviewURL)
} label: {
    Label("리뷰 남기기", systemImage: "star.bubble")
}
.accessibilityLabel("App Store에서 리뷰 남기기")
// writeReviewURL: itms-apps://apps.apple.com/app/id6759935352?action=write-review
//   (실패/미설치 fallback: https://apps.apple.com/app/id6759935352?action=write-review)
```

## 6. 영속 / 상태

- `UserDefaults` 키 1개: `autoReviewPromptConsumed: Bool`. 의미 = "자동 1회 호출을 소진했다"(리뷰 여부 아님).
- **기기별**(per-device). 가족공유/다기기 사용자는 **기기마다 1회** 가능 — Apple이 연 3회로 어차피 상한이라 비용 낮음. v1 수용(§14). 계정 단위가 필요해지면 추후 `users/{uid}` 불리언 또는 `NSUbiquitousKeyValueStore`로 이관.

## 7. 호출 정책 (once + 보호 가드)

- **1번만**: 첫 자격 트리거가 대기를 세우고, **scene 활성 + 오버레이 없음**의 첫 깨끗한 순간에 `requestReview()` 1회 → 즉시 소진, 영구 중단.
- **다른 트리거로 재무장(re-arm) 안 함** — PO의 "1번만" 준수. 단 **비활성 scene/오버레이 중에는 소진하지 않고 대기**(샷을 허공에 안 날림). 즉 "트리거 순간에 정확히" 발사가 아니라 "무장 후 첫 깨끗한 순간"에 발사.
- **Apple이 throttle/판단으로 시트를 안 띄워도 우리는 재시도 안 함**(HIG "반복 요청 금지" 준수, 콜백도 없음). 이 1회 신의성실 호출로 끝. → 트레이드오프 문서화: 단순·가이드라인 안전, 대신 그 1회를 Apple이 묵살하면 그 사용자에겐 자동팝업이 영영 안 뜸(설정 버튼은 항상 가능).

## 8. FeatureFlag / 비활성 동작

- `FeatureFlags.appReviewPromptEnabled: Bool = true` (컴파일 상수, 기존 `pregnancyModeEnabled`/`highlightsEnabled` 스타일). **`import FirebaseRemoteConfig` 금지**(safety.md) — RC 레이어 없음.
- OFF 시: `noteTrigger`가 early-guard로 즉시 반환(UserDefaults 쓰기·analytics 없음) **그리고** 설정 "리뷰 남기기" 행도 숨김(`if FeatureFlags.appReviewPromptEnabled`). 플래그 OFF = 기능 부재.

## 9. 분석 (Analytics)

- 신규 이벤트 `AnalyticsEvents.reviewPromptRequested`(예: `"review_prompt_requested"`), 파라미터 `{ trigger: recordsMilestone|hospitalReport, source: auto|settings }`. `requestReview()` 호출 시점(자동) / 딥링크 탭 시점(설정)에 1회.
- `AppLogger.analytics` 진단 병행. **아기/임신 식별자 등 건강정보 절대 미포함**(safety.md). `requestReview`는 콜백이 없어 이 이벤트가 유일한 관측 수단.

## 10. 접근성 / 로컬라이즈

- 설정 행 라벨은 기존 파일 컨벤션(한글 리터럴, 예: "개인정보 처리방침")과 통일 — 별도 Localizable 키 신설 안 함(앱 전반 1,631개 하드코딩 추출은 별도 백로그). `accessibilityLabel` + 버튼 trait 부여.
- `AccessibilityXXXL`에서 truncate 방지(H-8 선례) — 필요 시 `ViewThatFits`/`lineLimit`. SF Symbol `star.bubble`. URL 못 열면 무동작(crash 금지) — `openURL` completion/`canOpenURL` 가드.

## 11. 테스트 (`BabyCareTests/BabyCareTests.swift` append)

`AppReviewPromptService(defaults:)`에 인메모리 `UserDefaults`(고유 suiteName) 주입:

1. `noteTrigger` 첫 호출 → `pendingTrigger != nil`.
2. `consumePending()` → `isConsumed == true`, `pendingTrigger == nil`, 반환값 == 해당 트리거.
3. 소진 후 `noteTrigger` 재호출 → `pendingTrigger == nil`(재무장 없음).
4. `pendingTrigger` 이미 세팅 상태에서 다른 `noteTrigger` → 첫 트리거 유지(레이스/덮어쓰기 없음).
5. `AppReviewPromptService(defaults:, isEnabled: false)` → `noteTrigger` 무동작(`pendingTrigger == nil`).
6. 임계값 헬퍼: stats 합 19 → 미발화 / 20 → 발화(순수 계산 함수로 분리해 테스트).

`requestReview()` 자체는 시스템 콜·콜백 없음이라 유닛 불가 → **서비스 상태 로직만** 검증. 실제 시트 표출은 H-item(QA, StoreKit Testing/디버그 빌드에서 throttle 없이 매번 표시되는 점 활용).

## 12. 비범위 (v1 제외)

- **배지 트리거(v1.1)**: 부활 시 필수 — (a) 누적 earned-badge 카운트의 단일 진실원(예: `UserStats.earnedBadgeCount` 신설 또는 badges 컬렉션 count) 정의 + `firstRecord` 제외, (b) **backfill 지급분 제외**(`runBadgeBackfillIfNeeded` 경로에 플래그 전달 → backfill enqueue는 트리거 금지), (c) 스낵바 dismiss 후 발화(§5.2 오버레이 가드 재사용).
- **하이라이트 트리거(v1.1)**: RC `highlight_enabled` 켜질 때만 의미. 부활 시 **records ≥ 10 floor를 AND-게이트**(near-empty 계정 방지).
- 커스텀 별점 UI(Apple 금지) · 리뷰 여부 추적(불가) · 간격/총횟수>1 throttle · Firestore 동기화 · RemoteConfig 롤아웃 레이어.

## 13. 예상 파일 변경

- 신규: `BabyCare/Services/AppReviewPromptService.swift`
- 수정: `BabyCare/Utils/FeatureFlags.swift`(플래그) · `BabyCare/Views/Settings/SettingsView.swift`(행) · 초크포인트 View(`ContentView` 등, `requestReview`/`scenePhase`/`onChange`) · `ActivityViewModel+Save.swift`(records 트리거) · `HospitalReportViewModel.swift` 또는 그 표시 View(report 트리거) · `AnalyticsEvents`(이벤트 상수) · 필요 시 `BadgePresenter`(`isQueueEmpty` read-only)
- 테스트: `BabyCareTests/BabyCareTests.swift`(append)

## 14. 수용된 트레이드오프

- **per-device 1회**(계정 단위 아님) — Apple 연 3회 상한으로 비용 낮음. v1 수용.
- **Apple 묵살 시 무재시도** — 가이드라인 안전 우선. 설정 버튼이 안전망.
- **v1 트리거 2종** — 도달성·안전성 높은 것만. dark/위험 트리거는 v1.1.
