# AdMob Adaptive Banner 통합

> BabyCare iOS에 Google Mobile Ads SDK 13.2 기반 Adaptive Banner 추가. Non-personalized + Child-directed. Dashboard/Calendar/Health 탭 하단에 feature flag로 A(3탭)/B(1탭) 전환 가능.
> Mode: standard/autopilot

---

## Assumptions

> Decisions made autonomously without explicit user confirmation.

| Decision Point | Assumed Choice | Rationale | Source |
|---------------|---------------|-----------|--------|
| SDK 버전 | Google Mobile Ads SDK 13.2.0 | 2025-04 기준 최신 stable, Firebase 11.x 호환 | external-researcher |
| Representable 타입 | UIViewRepresentable | GADBannerView는 UIVC 불필요, 40줄 보일러플레이트 제거 | tradeoff-analyzer |
| Layer ownership | ContentView overlay에 통합 | 기존 FloatingTimerBanner/FloatingMiniPlayer와 같은 레이어 → 터치/Z-order 충돌 해결 | tradeoff-analyzer |
| Feature flag | `enum AdExperimentVariant { .allThreeTabs, .dashboardOnly }` | Set 대신 enum, 컴파일타임 타입 안전, 1줄 전환 | tradeoff-analyzer |
| Variant 기본값 | `.allThreeTabs` (A) | 사용자가 먼저 A를 테스트하고 싶다고 명시 | 사용자 지시 |
| Ad Unit ID | Google Test ID + `#if DEBUG` | crash 방지, 실제 ID는 DP-01 Option A | DP-01 |
| privacy.html IDFA 문구 | 유지 + AdMob 섹션 추가 | 기술적으로 정확 (child-directed + non-personalized는 IDFA 수집 안 함), 사용자 신뢰 보호 | DP-02 |
| v2.6.1(46) review 처리 | v2.6.2에 포함 (build 46 건드리지 않음) | 이미 v2.6.2 진행 중, 리스크 없음 | DP-03 |
| Personalized state API | `MobileAds.shared.requestConfiguration.publisherPrivacyPersonalizationState = .disabled` | GADExtras npa=1은 legacy, v13에서 deprecated | external-researcher |
| Adaptive banner API | `largeAnchoredAdaptiveBanner(width:)` | GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth v13 deprecated | external-researcher |
| BannerCoordinator 격리 | `@MainActor` | Swift 6 strict concurrency, 델리게이트 메인 스레드 강제 | external-researcher |
| iPad 노출 | 지원 (iPhone과 동일 정책) | TARGETED_DEVICE_FAMILY=1,2 기반, Adaptive Banner 자동 처리 | gap-analyzer |
| 첫 노출 조건 | 즉시 노출 | 사용자가 UX reviewer 권고(7일+10건)를 선택 안 함 | 사용자 지시 |

---

## Verification Summary

### Agent-Verifiable (A-items)
| ID | Criterion | Method | Related TODO |
|----|-----------|--------|-------------|
| A-1 | GoogleMobileAds SPM 패키지 추가 + xcodegen 성공 | `grep 'GoogleMobileAds' project.yml` + `make generate` | TODO 1 |
| A-2 | Info.plist에 GADApplicationIdentifier 존재 | `grep 'GADApplicationIdentifier' project.yml` | TODO 1 |
| A-3 | Info.plist에 SKAdNetworkItems 배열 존재 | `grep 'SKAdNetworkIdentifier' project.yml` | TODO 1 |
| A-4 | PrivacyInfo.xcprivacy 유효 | `plutil -lint BabyCare/PrivacyInfo.xcprivacy` | TODO 2 |
| A-5 | AppDelegate에 MobileAds.shared.start() + child-directed 설정 존재 | `grep 'tagForChildDirectedTreatment' BabyCare/App/AppDelegate.swift` | TODO 3 |
| A-6 | AdBannerView(UIViewRepresentable) 파일 존재 + BannerCoordinator @MainActor | `test -f` + grep | TODO 4 |
| A-7 | AdExperimentVariant enum 존재 + 기본값 .allThreeTabs | `grep 'AdExperimentVariant' BabyCare/Services/` | TODO 5 |
| A-8 | ContentView overlay에 banner 통합 코드 존재 | `grep 'AdBannerView' BabyCare/App/ContentView.swift` | TODO 6 |
| A-9 | Widget target에 GoogleMobileAds 없음 | project.yml BabyCareWidgetExtension dependencies 검증 | TODO 1 |
| A-10 | privacy.html에 Google AdMob 수탁업체 추가 + IDFA 문구 유지 | grep 양쪽 모두 | TODO 7 |
| A-11 | 신규 unit 테스트 통과 (enum variant 분기 + variant→tabs 매핑) | `make test` | TODO 8 |
| A-12 | `make verify` 전체 통과 (build + test + design-verify) | `make verify` | TODO Final |
| A-13 | `make build` 경고 0건 유지 | `make build 2>&1 | grep 'warning' | wc -l` == 0 | TODO Final |

### Human-Required (H-items)
| ID | Criterion | Reason | Review Material |
|----|-----------|--------|----------------|
| H-1 | 테스트 광고가 시뮬레이터에서 실제로 로드되어 배너에 표시되는지 | 네트워크 + SDK 런타임, 자동화 불가 | 시뮬레이터 Dashboard/Calendar/Health 확인 |
| H-2 | FloatingTimerBanner + AdBanner 동시 활성 시 레이어 충돌 없음 | 시각적 Z-order 검증 | 수유 타이머 시작 → 각 탭 방문 |
| H-3 | Calendar FAB이 banner에 가려지지 않음 | 시각적 검증 | Calendar 탭 FAB 위치 확인 |
| H-4 | Variant 전환 (A→B) 시 Dashboard만 배너 표시 | 수동 코드 변경 + 빌드 검증 | `.dashboardOnly`로 변경 후 재빌드 |
| H-5 | iPad 레이아웃에서 배너 정상 표시 | 디바이스별 렌더링 | iPad simulator 확인 |
| H-6 | 광고 내용 child-directed 분류 확인 (유아/가족 광고 위주) | AdMob 정책 준수 확인 | 실제 광고 내용 관찰 |

### Verification Gaps
- AdMob 런타임 광고 로드 자동화 불가 → 시뮬레이터 수동 검증으로 대체
- Tier 2-4 부재: 네이티브 iOS 프로젝트, sandbox/E2E 인프라 없음
- Child-directed 처리 검증: 실제 광고 송출 대상 관찰 외 자동 검증 방법 없음 (Google Ads Policy 준수 신뢰)

---

## External Dependencies Strategy

### Pre-work (user prepares before AI work)
| Dependency | Action | Command/Step | Blocking? |
|------------|--------|-------------|-----------|
| (none) | Test ID 사용으로 모든 pre-work 불필요 | - | - |

### During (AI work strategy)
| Dependency | Dev Strategy | Rationale |
|------------|-------------|-----------|
| Google Mobile Ads SDK 13.2.0 | SPM 추가, 테스트 광고 ID 사용 | crash 방지, 실제 ID는 launch 전 별도 작업 |
| Test App ID | `ca-app-pub-3940256099942544~1458002511` 하드코딩 (DEBUG) | Google 공식 테스트 ID, production 영향 없음 |
| Test Banner Unit ID | `ca-app-pub-3940256099942544/2435281174` 하드코딩 (DEBUG) | Google 공식 테스트 ID |
| AdMob 네트워크 런타임 | 테스트 광고로 폐쇄형 검증, unit 테스트는 순수 함수만 | 네트워크 의존 없는 테스트 유지 |

### Post-work (user actions after completion)
| Task | Related Dependency | Action | Command/Step |
|------|--------------------|--------|-------------|
| AdMob 계정 등록 | AdMob Console | 실제 앱 등록 후 production App ID + Banner Unit ID 발급 | https://apps.admob.com |
| Production ID 교체 | AdBannerView, Info.plist | `#if DEBUG/RELEASE` 분기에서 실제 ID로 교체 | 코드 수정 후 v2.6.3 빌드 |
| A/B 테스트 | AdExperimentVariant | 시뮬레이터에서 A 확인 후 `.dashboardOnly`로 전환 검증 | 코드 1줄 수정 |
| TestFlight 배포 | make deploy | v2.6.2 (build 50) 업로드 | `make deploy` |
| App Store 광고 정책 검토 | App Store Connect | 광고 설정, child-directed 선언 | ASC 웹 UI |

---

## Context

### Original Request
AdMob Banner 광고 추가 — 대시보드/캘린더/건강 탭 하단 3곳에 Adaptive Banner, Non-personalized only, 광고 제거 옵션 없음. Feature flag로 A/B 테스트 가능하게.

### Interview Summary
**Key Discussions**:
- 배치: **3탭 모두 (A안)** 기본값, **Dashboard만 (B안)**으로 1줄 전환 가능
- Personalized: **Non-personalized only** — ATT 프롬프트 없음, NSPrivacyTracking=false 유지
- 광고 제거 옵션: **없음** (구독 미도입)
- Child-directed: **필수** (COPPA 준수, 육아 앱)
- Ad Unit ID: **Google Test ID** (DEBUG) → Production ID는 별도 작업
- v2.6.1 심사 중 빌드는 건드리지 않고 **v2.6.2에 포함**

**Research Findings**:
- SDK 13.2.0가 최신 stable (Swift naming overhaul 완료, v11 GAD prefix 제거됨)
- `GADBannerView` → `BannerView`, `MobileAds.shared` API
- `publisherPrivacyPersonalizationState = .disabled`로 non-personalized 제어 (GADExtras npa=1은 legacy)
- `largeAnchoredAdaptiveBanner(width:)`로 adaptive banner (구 API deprecated)
- Firebase 11.x와 호환 문제 없음 (v11에서 GoogleAppMeasurement 의존성 제거됨)
- Swift 6 strict concurrency: BannerCoordinator `@MainActor` 필수

---

## Work Objectives

### Core Objective
BabyCare iOS에 Non-personalized Adaptive Banner를 기존 UX를 해치지 않으면서 통합. A(3탭)/B(1탭) 변형을 feature flag로 1줄 전환 가능하게 하여 사용자가 직접 테스트 후 결정.

### Concrete Deliverables
- `project.yml` — GoogleMobileAds SPM 패키지 + BabyCare target dependency + GADApplicationIdentifier + SKAdNetworkItems
- `BabyCare/PrivacyInfo.xcprivacy` — AdMob 데이터 수집 항목 추가
- `BabyCare/App/AppDelegate.swift` — MobileAds 초기화 + child-directed + non-personalized 설정
- `BabyCare/Services/AdExperimentVariant.swift` — enum (feature flag)
- `BabyCare/Views/Ads/AdBannerView.swift` — UIViewRepresentable + BannerCoordinator `@MainActor`
- `BabyCare/App/ContentView.swift` — overlay에 AdBannerView 통합 (조건부 표시)
- `privacy.html` — Google AdMob 수탁업체 추가 (IDFA 문구 유지)
- `BabyCareTests.swift` — AdExperimentVariant enum 테스트

### Definition of Done
- [ ] `make build` 성공 (경고 0건)
- [ ] `make test` 기존 38개 + 신규 테스트 통과
- [ ] `make verify` 성공
- [ ] 테스트 광고가 시뮬레이터에서 3개 탭 하단에 표시됨
- [ ] FloatingTimerBanner가 AdBanner에 가려지지 않음
- [ ] Calendar FAB이 AdBanner에 가려지지 않음
- [ ] `AdExperimentVariant.currentVariant`를 `.dashboardOnly`로 바꾸면 Dashboard만 배너 표시 (B안 검증)

### Must NOT Do (Guardrails)
- `NSPrivacyTracking`을 `true`로 변경 금지
- `NSUserTrackingUsageDescription` Info.plist 추가 금지 (ATT 프롬프트 유발)
- `tagForChildDirectedTreatment`를 `false`로 설정하거나 누락 금지 — COPPA 위반
- `BabyCareWidgetExtension` target에 GoogleMobileAds 의존성 추가 금지 — 빌드 실패
- Production Ad Unit ID를 현 단계에서 하드코딩 금지 — Google Test ID + `#if DEBUG` 유지
- `privacy.html`의 "IDFA 사용 안 함" 문구 삭제 금지 — child-directed + non-personalized 하에서 기술적으로 유효
- ScrollView 내부에 banner 삽입 금지 — sticky 하단 배치
- `UIViewControllerRepresentable` 사용 금지 — `UIViewRepresentable`로 충분
- 새 테스트 파일 생성 금지 — `BabyCareTests.swift`에 append
- `@preconcurrency import`로 Swift 6 경고 회피 금지 — `@MainActor`로 정식 처리
- `GADBannerView` / `GADRequest` / `GADExtras` / `GADCurrentOrientationAnchoredAdaptiveBanner...` 레거시 API 사용 금지 — SDK 13 신 API만
- 광고 로드 실패 시 앱 크래시 금지 — BannerViewDelegate failWithError 핸들링
- Firebase 버전 업그레이드 금지 — 11.0.0 고정 유지
- Do not run git commands

---

## Task Flow

```
TODO-1 (SPM + Info.plist) → TODO-2 (PrivacyInfo) ─┐
                                                    ├→ TODO-3 (AppDelegate init)
                                                    │
TODO-4 (AdBannerView) ←────────────────────────────┘
    ↓
TODO-5 (AdExperimentVariant)
    ↓
TODO-6 (ContentView integration)
    ↓
TODO-7 (privacy.html)
    ↓
TODO-8 (tests)
    ↓
TODO-Final (verification)
```

## Dependency Graph

| TODO | Requires (Inputs) | Produces (Outputs) | Type |
|------|-------------------|-------------------|------|
| 1 | - | `spm_added` (string) | work |
| 2 | - | `privacy_updated` (string) | work |
| 3 | `todo-1.spm_added` | `init_done` (string) | work |
| 4 | `todo-1.spm_added` | `banner_view_path` (file) | work |
| 5 | - | `variant_path` (file) | work |
| 6 | `todo-4.banner_view_path`, `todo-5.variant_path` | `integration_done` (string) | work |
| 7 | - | `privacy_html_updated` (string) | work |
| 8 | `todo-5.variant_path` | `tests_added` (string) | work |
| Final | all outputs | - | verification |

## Parallelization

| Group | TODOs | Reason |
|-------|-------|--------|
| A | TODO 1, 2, 5, 7 | 서로 독립, 동시 실행 가능 |
| B | TODO 3, 4 | TODO 1 완료 후 병렬 가능 |
| - | TODO 6, 8 | 앞 단계 완료 의존 |

## Commit Strategy

| After TODO | Message | Files | Condition |
|------------|---------|-------|-----------|
| 2 | `chore(deps): add Google Mobile Ads SDK + Info.plist + PrivacyInfo` | `project.yml`, `BabyCare/PrivacyInfo.xcprivacy` | always |
| 5 | `feat(ads): add AdMob banner wrapper + feature flag + init` | `BabyCare/App/AppDelegate.swift`, `BabyCare/Views/Ads/AdBannerView.swift`, `BabyCare/Services/AdExperimentVariant.swift` | always |
| 6 | `feat(ads): integrate banner into ContentView overlay with variant gating` | `BabyCare/App/ContentView.swift` | always |
| 7 | `docs(privacy): add Google AdMob to privacy policy` | `privacy.html` | always |
| 8 | `test(ads): unit tests for AdExperimentVariant` | `BabyCareTests/BabyCareTests.swift` | always |

## Error Handling

### Failure Categories
| Category | Examples | Detection Pattern |
|----------|----------|-------------------|
| `env_error` | SPM resolve 실패, xcodegen 에러 | `/error:\|fatal:\|xcodegen.*failed/i` |
| `code_error` | Swift 컴파일 에러, Swift 6 concurrency 경고 | `/error:\|warning:.*concurrency/i` |
| `scope_internal` | SDK API 차이 (v13 rename 이슈), 누락된 import | Worker `suggested_adaptation` present |
| `unknown` | 분류 불가 에러 | Default fallback |

### Failure Handling Flow
| Scenario | Action |
|----------|--------|
| work fails | Retry up to 2 times → Analyze → (see below) |
| verification fails | Analyze immediately (no retry) → (see below) |
| Worker times out | Halt and report |
| Missing Input | Skip dependent TODOs, halt |

### After Analyze
| Category | Action |
|----------|--------|
| `env_error` | Halt + log to `issues.md` |
| `code_error` | Create Fix Task (depth=1 limit) |
| `scope_internal` | Adapt → Dynamic TODO (depth=1) |
| `unknown` | Halt + log to `issues.md` |

## Runtime Contract

| Aspect | Specification |
|--------|---------------|
| Working Directory | `/Users/roque/BabyCare` |
| Network Access | Allowed (SPM resolve) |
| Package Install | Allowed (GoogleMobileAds via SPM) |
| File Access | Repository only |
| Max Execution Time | 5 minutes per TODO |
| Git Operations | Denied (Orchestrator handles) |

---

## TODOs

### [x] TODO 1: Add GoogleMobileAds SPM + Info.plist config

**Type**: work
**Required Tools**: `xcodegen`
**Inputs**: (none)
**Outputs**:
- `spm_added` (string): `done`

**Steps**:
- [ ] `project.yml`의 `packages:` 블록에 GoogleMobileAds 추가:
  ```yaml
  GoogleMobileAds:
    url: https://github.com/googleads/swift-package-manager-google-mobile-ads.git
    from: "13.2.0"
  ```
- [ ] `BabyCare` target의 `dependencies:`에 추가:
  ```yaml
  - package: GoogleMobileAds
    product: GoogleMobileAds
  ```
- [ ] `BabyCare` target의 `info.properties:`에 추가:
  ```yaml
  GADApplicationIdentifier: "ca-app-pub-3940256099942544~1458002511"  # Google Test App ID
  SKAdNetworkItems:
    - SKAdNetworkIdentifier: cstr6suwn9.skadnetwork
    - SKAdNetworkIdentifier: 4fzdc2evr5.skadnetwork
    - SKAdNetworkIdentifier: 2fnua5tdw4.skadnetwork
    - SKAdNetworkIdentifier: ydx93a7ass.skadnetwork
    - SKAdNetworkIdentifier: p78axxw29g.skadnetwork
    - SKAdNetworkIdentifier: v72qych5uu.skadnetwork
    - SKAdNetworkIdentifier: ludvb6z3bs.skadnetwork
    - SKAdNetworkIdentifier: cp8zw746q7.skadnetwork
    - SKAdNetworkIdentifier: 3sh42y64q3.skadnetwork
  ```
- [ ] `BabyCareWidgetExtension` target의 dependencies는 **절대 변경하지 않음** (GoogleMobileAds 추가 금지)
- [ ] `make generate` 실행 → xcodeproj 재생성
- [ ] `make build` → SPM resolve + 컴파일 성공 확인

**Must NOT do**:
- Widget target에 GoogleMobileAds 의존성 추가 금지
- Firebase 버전 변경 금지
- Production Ad Unit ID 하드코딩 금지
- Do not run git commands

**References**:
- `project.yml:22-44` — 기존 Firebase SPM 선언 패턴
- `project.yml:90-122` — Widget target (건드리지 말 것)
- `project.yml:61-88` — info.properties 위치

**Acceptance Criteria**:
*Functional:*
- [ ] `grep 'GoogleMobileAds' project.yml` → 존재
- [ ] `grep 'GADApplicationIdentifier' project.yml` → 존재
- [ ] `grep 'SKAdNetworkIdentifier' project.yml` → 9개 이상
- [ ] BabyCareWidgetExtension dependencies 섹션에 GoogleMobileAds 없음

*Static:*
- [ ] `make generate` → exit 0
- [ ] `make build` → exit 0 (경고 0건)

*Runtime:*
- [ ] `make test` → 기존 테스트 통과

**Verify**:
```yaml
commands:
  - run: "grep 'url: https://github.com/googleads/swift-package-manager-google-mobile-ads' project.yml"
    expect: "exit 0"
  - run: "grep 'GADApplicationIdentifier' project.yml"
    expect: "exit 0"
  - run: "grep -c 'SKAdNetworkIdentifier' project.yml"
    expect: ">= 9"
  - run: "make build"
    expect: "exit 0"
risk: MEDIUM
rollback: "project.yml에서 GoogleMobileAds 블록과 Info.plist 키 제거 → make generate"
```

---

### [x] TODO 2: Update PrivacyInfo.xcprivacy

**Type**: work
**Required Tools**: `plutil`
**Inputs**: (none)
**Outputs**:
- `privacy_updated` (string): `done`

**Steps**:
- [ ] `BabyCare/PrivacyInfo.xcprivacy`의 `NSPrivacyCollectedDataTypes` 배열에 다음 항목 **추가** (기존 4개 유지):
  - `NSPrivacyCollectedDataTypeAdvertisingData` (Linked: false, Tracking: false, Purpose: `NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising`)
  - Note: `AdvertiserID`(IDFA)는 추가하지 않음 — child-directed + non-personalized 설정으로 수집 안 함
- [ ] `NSPrivacyTracking`은 `false` 유지 (절대 변경하지 말 것)
- [ ] `NSPrivacyTrackingDomains`는 빈 배열 유지
- [ ] `plutil -lint BabyCare/PrivacyInfo.xcprivacy` 실행 → 문법 검증

**Must NOT do**:
- `NSPrivacyTracking`을 `true`로 변경 금지
- `NSPrivacyCollectedDataTypeAdvertiserID`(IDFA) 추가 금지 — 수집하지 않음
- 기존 4개 데이터 타입 제거 금지
- Do not run git commands

**References**:
- `BabyCare/PrivacyInfo.xcprivacy` — 현재 파일 (Firebase Analytics 4개 항목 + NSPrivacyTracking=false)

**Acceptance Criteria**:
*Functional:*
- [ ] `grep 'NSPrivacyCollectedDataTypeAdvertisingData' BabyCare/PrivacyInfo.xcprivacy` → 존재
- [ ] `NSPrivacyTracking` 여전히 `false`
- [ ] 기존 4개 데이터 타입(`ProductInteraction`, `DeviceID`, `CrashData`, `PerformanceData`) 유지
- [ ] `NSPrivacyCollectedDataTypeAdvertiserID` 없음

*Static:*
- [ ] `plutil -lint BabyCare/PrivacyInfo.xcprivacy` → exit 0

*Runtime:*
- [ ] `make build` → exit 0

**Verify**:
```yaml
commands:
  - run: "plutil -lint BabyCare/PrivacyInfo.xcprivacy"
    expect: "exit 0"
  - run: "grep 'NSPrivacyCollectedDataTypeAdvertisingData' BabyCare/PrivacyInfo.xcprivacy"
    expect: "exit 0"
  - run: "grep -A1 'NSPrivacyTracking' BabyCare/PrivacyInfo.xcprivacy | grep false"
    expect: "exit 0"
risk: MEDIUM
rollback: "git revert — PrivacyInfo.xcprivacy는 Firebase Analytics 상태로 복원"
```

---

### [x] TODO 3: AppDelegate MobileAds init with child-directed + non-personalized

**Type**: work
**Required Tools**: (none)
**Inputs**:
- `spm_added` (string): `${todo-1.outputs.spm_added}`

**Outputs**:
- `init_done` (string): `done`

**Steps**:
- [ ] `BabyCare/App/AppDelegate.swift`에 `import GoogleMobileAds` 추가
- [ ] `didFinishLaunchingWithOptions`에서 `FirebaseApp.configure()` 직후, `AnalyticsService.shared.configure()` 이전에 다음 코드 추가:
  ```swift
  // MobileAds: child-directed + non-personalized (must be set BEFORE start())
  MobileAds.shared.requestConfiguration.tagForChildDirectedTreatment = true
  MobileAds.shared.requestConfiguration.publisherPrivacyPersonalizationState = .disabled
  MobileAds.shared.start(completionHandler: nil)
  ```
- [ ] Swift 6 concurrency 경고 없이 빌드 확인 (`@MainActor` 이미 AppDelegate에서 적용되므로 추가 작업 불필요)

**Must NOT do**:
- `start()` **이전에** child-directed/personalization 설정 순서 유지 필수
- `tagForChildDirectedTreatment`를 false로 설정 금지
- `@preconcurrency` 사용 금지
- Do not run git commands

**References**:
- `BabyCare/App/AppDelegate.swift:8-26` — 기존 didFinishLaunchingWithOptions
- external-researcher: SDK 13 API는 `MobileAds.shared` (singleton), `start(completionHandler:)`

**Acceptance Criteria**:
*Functional:*
- [ ] `grep 'import GoogleMobileAds' BabyCare/App/AppDelegate.swift` → 존재
- [ ] `grep 'tagForChildDirectedTreatment = true' BabyCare/App/AppDelegate.swift` → 존재
- [ ] `grep 'publisherPrivacyPersonalizationState = .disabled' BabyCare/App/AppDelegate.swift` → 존재
- [ ] `grep 'MobileAds.shared.start' BabyCare/App/AppDelegate.swift` → 존재
- [ ] 순서: child-directed → publisherPrivacy → start()

*Static:*
- [ ] `make build` → exit 0 (경고 0건)

*Runtime:*
- [ ] `make test` → 기존 테스트 통과

**Verify**:
```yaml
commands:
  - run: "grep -q 'import GoogleMobileAds' BabyCare/App/AppDelegate.swift && grep -q 'tagForChildDirectedTreatment = true' BabyCare/App/AppDelegate.swift && grep -q 'publisherPrivacyPersonalizationState = .disabled' BabyCare/App/AppDelegate.swift"
    expect: "exit 0"
  - run: "make build 2>&1 | grep -c 'warning:'"
    expect: "0"
risk: MEDIUM
rollback: "AppDelegate에서 MobileAds 관련 3줄 제거 → make build"
```

---

### [x] TODO 4: Create AdBannerView (UIViewRepresentable) + BannerCoordinator

**Type**: work
**Required Tools**: (none)
**Inputs**:
- `spm_added` (string): `${todo-1.outputs.spm_added}`

**Outputs**:
- `banner_view_path` (file): `BabyCare/Views/Ads/AdBannerView.swift`

**Steps**:
- [ ] `BabyCare/Views/Ads/` 디렉토리 생성
- [ ] `BabyCare/Views/Ads/AdBannerView.swift` 생성:
  - `import GoogleMobileAds`, `import SwiftUI`, `import UIKit`
  - `struct AdBannerView: UIViewRepresentable` — UIViewRepresentable 사용 (NOT UIViewControllerRepresentable)
  - Adaptive banner 크기: `largeAnchoredAdaptiveBanner(width: UIScreen.main.bounds.width)`
  - `makeUIView`: BannerView 생성, `adUnitID` 설정 (`#if DEBUG` → test ID / `#else` → placeholder "REPLACE_ME"), `load(Request())`, delegate 설정
  - `updateUIView`: 빈 구현
  - `makeCoordinator()` → `BannerCoordinator`
  - `@MainActor final class BannerCoordinator: NSObject, BannerViewDelegate` 내부 타입
  - `bannerViewDidReceiveAd(_:)` / `bannerView(_:didFailToReceiveAdWithError:)` 구현 (OSLog)
  - Swift 6 concurrency 안전 (@MainActor)
- [ ] 배너 높이 계산 가능한 static helper: `static func currentAdSize() -> CGSize`
- [ ] `make build` 확인

**Must NOT do**:
- UIViewControllerRepresentable 사용 금지
- `GADBannerView`, `GADRequest`, `GADExtras` 등 v11 이전 레거시 API 사용 금지
- `GADCurrentOrientationAnchoredAdaptiveBannerAdSizeWithWidth` 사용 금지 (v13 deprecated)
- `rootViewController` 수동 설정 금지 (SDK 11+ 자동)
- Production Ad Unit ID 하드코딩 금지
- Do not run git commands

**References**:
- external-researcher: SDK 13 SwiftUI 패턴 (BannerViewContainer: UIViewRepresentable)
- `BabyCare/App/FloatingTimerBanner.swift` — 유사 floating 컴포넌트 패턴 참조
- `BabyCare/Utils/Constants.swift` — AppColors (banner 배경용)

**Acceptance Criteria**:
*Functional:*
- [ ] `test -f BabyCare/Views/Ads/AdBannerView.swift`
- [ ] `grep 'UIViewRepresentable' BabyCare/Views/Ads/AdBannerView.swift` → 존재
- [ ] `grep 'UIViewControllerRepresentable' BabyCare/Views/Ads/AdBannerView.swift` → **없음**
- [ ] `grep 'largeAnchoredAdaptiveBanner' BabyCare/Views/Ads/AdBannerView.swift` → 존재
- [ ] `grep '@MainActor' BabyCare/Views/Ads/AdBannerView.swift` → BannerCoordinator에 적용
- [ ] `grep 'BannerViewDelegate' BabyCare/Views/Ads/AdBannerView.swift` → 존재
- [ ] `grep '#if DEBUG' BabyCare/Views/Ads/AdBannerView.swift` → test ID 분기 존재
- [ ] `grep 'ca-app-pub-3940256099942544/2435281174' BabyCare/Views/Ads/AdBannerView.swift` → test unit ID

*Static:*
- [ ] `make build` → exit 0 (경고 0건, Swift 6 concurrency 포함)

*Runtime:*
- [ ] `make test` → 기존 테스트 통과

**Verify**:
```yaml
commands:
  - run: "test -f BabyCare/Views/Ads/AdBannerView.swift"
    expect: "exit 0"
  - run: "! grep -q 'UIViewControllerRepresentable' BabyCare/Views/Ads/AdBannerView.swift"
    expect: "exit 0"
  - run: "grep -q '@MainActor' BabyCare/Views/Ads/AdBannerView.swift"
    expect: "exit 0"
  - run: "make build 2>&1 | grep -c 'warning:'"
    expect: "0"
risk: MEDIUM
```

---

### [x] TODO 5: Create AdExperimentVariant enum (feature flag)

**Type**: work
**Required Tools**: (none)
**Inputs**: (none)
**Outputs**:
- `variant_path` (file): `BabyCare/Services/AdExperimentVariant.swift`

**Steps**:
- [ ] `BabyCare/Services/AdExperimentVariant.swift` 생성:
  ```swift
  import Foundation

  /// AdMob 배너 배치 실험 — A/B 테스트를 위한 feature flag
  /// 변경 시 한 줄 수정으로 전환 가능 (currentVariant)
  enum AdExperimentVariant {
      case allThreeTabs  // A: Dashboard + Calendar + Health
      case dashboardOnly // B: Dashboard 1개 탭만

      /// 현재 활성 변형. A/B 테스트 시 이 값만 변경.
      static let currentVariant: AdExperimentVariant = .allThreeTabs

      /// 주어진 탭 인덱스에서 배너를 표시해야 하는지 판단.
      /// TabView tag: 0=Dashboard, 1=Calendar, 3=Health (2는 기록+ 버튼, 4는 설정)
      func shouldShowBanner(forTab tag: Int) -> Bool {
          switch self {
          case .allThreeTabs:
              return tag == 0 || tag == 1 || tag == 3
          case .dashboardOnly:
              return tag == 0
          }
      }
  }
  ```
- [ ] `make build` 확인

**Must NOT do**:
- `Set<String>` 기반 구현 금지 — enum variant 사용
- ViewModel로 감싸기 금지 — 순수 enum
- UserDefaults/Remote Config 사용 금지 — 컴파일타임 상수
- Do not run git commands

**References**:
- tradeoff-analyzer: enum variant 패턴 추천 (Set 회피)
- `BabyCare/Utils/AdminConfig.swift` — 유사한 컴파일타임 상수 enum 패턴

**Acceptance Criteria**:
*Functional:*
- [ ] `test -f BabyCare/Services/AdExperimentVariant.swift`
- [ ] `grep 'enum AdExperimentVariant' BabyCare/Services/AdExperimentVariant.swift`
- [ ] `grep 'case allThreeTabs' + 'case dashboardOnly'`
- [ ] `grep 'currentVariant: AdExperimentVariant = .allThreeTabs'`
- [ ] `grep 'shouldShowBanner(forTab'`

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 기존 테스트 통과

**Verify**:
```yaml
commands:
  - run: "test -f BabyCare/Services/AdExperimentVariant.swift"
    expect: "exit 0"
  - run: "grep -q 'enum AdExperimentVariant' BabyCare/Services/AdExperimentVariant.swift"
    expect: "exit 0"
  - run: "grep -q 'currentVariant: AdExperimentVariant = .allThreeTabs' BabyCare/Services/AdExperimentVariant.swift"
    expect: "exit 0"
  - run: "make build"
    expect: "exit 0"
risk: LOW
```

---

### [x] TODO 6: Integrate AdBannerView into ContentView overlay

**Type**: work
**Required Tools**: (none)
**Inputs**:
- `banner_view_path` (file): `${todo-4.outputs.banner_view_path}`
- `variant_path` (file): `${todo-5.outputs.variant_path}`

**Outputs**:
- `integration_done` (string): `done`

**Steps**:
- [ ] `BabyCare/App/ContentView.swift`의 `mainTabView`에서 기존 overlay 블록 찾기 (`.overlay(alignment: .bottom)`)
- [ ] 기존 `VStack { FloatingTimerBanner; FloatingMiniPlayer }` 하단에 조건부 AdBannerView 추가:
  ```swift
  .overlay(alignment: .bottom) {
      VStack(spacing: 6) {
          FloatingTimerBanner { category in
              initialRecordingCategory = category
              showRecording = true
          }
          FloatingMiniPlayer()
          if AdExperimentVariant.currentVariant.shouldShowBanner(forTab: selectedTab) {
              AdBannerView()
                  .frame(height: AdBannerView.currentAdSize().height)
          }
      }
      .padding(.bottom, 52) // TabBar 위
  }
  ```
- [ ] Banner가 FloatingTimerBanner 위가 아닌 **아래**에 배치됨 (타이머 우선순위 유지, UX reviewer 경고 반영)
- [ ] Calendar FAB은 별도 수정 불필요 (배너가 탭바 위 overlay라 FAB 위치에 영향 없음)
- [ ] `make build` + 시뮬레이터에서 탭 전환 테스트 (Cmd+Shift+H 후 Dashboard 복귀 시 banner 유지)

**Must NOT do**:
- 각 탭 View 내부에 `.safeAreaInset(edge: .bottom)` 추가 금지 — ContentView overlay에만 추가
- FloatingTimerBanner 위에 banner 배치 금지 — 타이머 정지 버튼 접근성 유지
- Calendar FAB의 bottomTrailing 위치 변경 금지
- Do not run git commands

**References**:
- `BabyCare/App/ContentView.swift:264-267` — 기존 FloatingTimerBanner/FloatingMiniPlayer overlay 블록
- tradeoff-analyzer: ContentView overlay 통합 권고
- UX reviewer: FloatingTimerBanner 가림 금지

**Acceptance Criteria**:
*Functional:*
- [ ] `grep 'AdBannerView' BabyCare/App/ContentView.swift` → 존재
- [ ] `grep 'AdExperimentVariant.currentVariant.shouldShowBanner' BabyCare/App/ContentView.swift` → 존재
- [ ] AdBannerView가 VStack의 **마지막** 요소 (FloatingTimerBanner/FloatingMiniPlayer 아래)
- [ ] `.safeAreaInset` 수정 없음 (DashboardView/CalendarView/HealthView 파일 변경 없음)

*Static:*
- [ ] `make build` → exit 0 (경고 0건)

*Runtime:*
- [ ] `make test` → 기존 테스트 통과

**Verify**:
```yaml
commands:
  - run: "grep -q 'AdBannerView' BabyCare/App/ContentView.swift"
    expect: "exit 0"
  - run: "grep -q 'shouldShowBanner(forTab:' BabyCare/App/ContentView.swift"
    expect: "exit 0"
  - run: "! git diff BabyCare/Views/Dashboard/DashboardView.swift | grep -q safeAreaInset"
    expect: "exit 0"
  - run: "make build"
    expect: "exit 0"
risk: MEDIUM
rollback: "ContentView에서 AdBannerView 조건부 블록 제거"
```

---

### [x] TODO 7: Update privacy.html with Google AdMob

**Type**: work
**Required Tools**: (none)
**Inputs**: (none)
**Outputs**:
- `privacy_html_updated` (string): `done`

**Steps**:
- [ ] `privacy.html`의 "최종 수정" 날짜를 오늘(2026년 4월 10일)로 업데이트
- [ ] "5. 개인정보의 처리 위탁" 테이블에 행 추가:
  ```html
  <tr>
    <td>Google AdMob</td>
    <td>앱 내 비맞춤형 광고 표시 (IDFA 미사용, 아동 보호 처리 적용)</td>
    <td>미국</td>
  </tr>
  ```
- [ ] "2. 개인정보의 수집 및 이용 목적" 섹션에 항목 추가:
  ```html
  <li><strong>광고 표시:</strong> 앱 운영을 위해 Google AdMob을 통해 비맞춤형 광고를 표시합니다. 광고 추적 식별자(IDFA)는 사용하지 않으며, 아동 보호 처리(Child-directed treatment)가 적용되어 개인화되지 않은 광고만 송출됩니다.</li>
  ```
- [ ] 기존 "이 앱은 광고 추적(IDFA)을 사용하지 않습니다" 문구 **유지** (삭제 금지)

**Must NOT do**:
- 기존 IDFA 미사용 문구 삭제 금지
- 광고 수집 범위를 과장 또는 축소 금지
- Do not run git commands

**References**:
- `privacy.html` — 현재 파일 (5번 위탁 테이블 3행: Firebase, Apple, Anthropic)
- DP-02: IDFA 문구 유지 + AdMob 섹션 추가 전략

**Acceptance Criteria**:
*Functional:*
- [ ] `grep 'Google AdMob' privacy.html` → 존재
- [ ] `grep 'IDFA 미사용' privacy.html` → 존재 (기존 문구 유지)
- [ ] `grep '아동 보호' privacy.html` → 존재
- [ ] `grep '비맞춤형 광고' privacy.html` → 존재
- [ ] 최종 수정 날짜 2026-04-10으로 업데이트

*Static:*
- [ ] HTML 문법 유효 (수동 확인 — unclosed tag 없음)

*Runtime:*
- [ ] (해당 없음)

**Verify**:
```yaml
commands:
  - run: "grep -q 'Google AdMob' privacy.html"
    expect: "exit 0"
  - run: "grep -q '광고 추적(IDFA)을 사용하지 않습니다' privacy.html"
    expect: "exit 0"
  - run: "grep -q '아동 보호' privacy.html"
    expect: "exit 0"
risk: LOW
```

---

### [x] TODO 8: Unit tests for AdExperimentVariant

**Type**: work
**Required Tools**: (none)
**Inputs**:
- `variant_path` (file): `${todo-5.outputs.variant_path}`

**Outputs**:
- `tests_added` (string): `done`

**Steps**:
- [ ] `BabyCareTests/BabyCareTests.swift`에 append (새 파일 생성 금지):
  - `testAdExperimentVariant_allThreeTabs_showsOnDashboardCalendarHealth`
    - `.allThreeTabs`의 `shouldShowBanner(forTab: 0/1/3)` → true
    - `shouldShowBanner(forTab: 2/4)` → false (기록, 설정 제외)
  - `testAdExperimentVariant_dashboardOnly_showsOnDashboardOnly`
    - `.dashboardOnly`의 `shouldShowBanner(forTab: 0)` → true
    - `shouldShowBanner(forTab: 1/2/3/4)` → false
  - `testAdExperimentVariant_currentVariant_defaultsToAllThreeTabs`
    - `AdExperimentVariant.currentVariant == .allThreeTabs`
- [ ] `make test` 전체 통과 확인

**Must NOT do**:
- 새 테스트 파일 생성 금지 — `BabyCareTests.swift`에 append
- AdBannerView/MobileAds 런타임 테스트 금지 (네트워크 의존)
- Do not run git commands

**References**:
- `BabyCareTests/BabyCareTests.swift:283-` — 기존 Analytics/패턴분석 테스트 이후 append 지점

**Acceptance Criteria**:
*Functional:*
- [ ] `grep -c 'testAdExperimentVariant' BabyCareTests/BabyCareTests.swift` → ≥ 3
- [ ] 신규 테스트가 기존 38개 이후에 append됨

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 기존 38 + 신규 3 이상 모두 PASS

**Verify**:
```yaml
commands:
  - run: "grep -c 'testAdExperimentVariant' BabyCareTests/BabyCareTests.swift"
    expect: ">= 3"
  - run: "make test"
    expect: "exit 0"
risk: LOW
```

---

### [x] TODO Final: Verification

**Type**: verification
**Required Tools**: `xcodebuild`, `plutil`
**Inputs**:
- `spm_added`, `privacy_updated`, `init_done`, `banner_view_path`, `variant_path`, `integration_done`, `privacy_html_updated`, `tests_added`

**Outputs**: (none)

**Steps**:
- [ ] `make verify` 실행 (build + test + design-verify)
- [ ] `make build 2>&1 | grep -c warning` == 0 확인
- [ ] SPM 패키지 존재 확인
- [ ] Info.plist GADApplicationIdentifier + SKAdNetworkItems 확인
- [ ] PrivacyInfo.xcprivacy NSPrivacyTracking=false 유지 확인
- [ ] AppDelegate child-directed + non-personalized 설정 확인
- [ ] AdBannerView가 UIViewRepresentable 기반인지 확인
- [ ] AdExperimentVariant 기본값 .allThreeTabs 확인
- [ ] ContentView에 AdBannerView 통합 확인
- [ ] privacy.html Google AdMob 섹션 + IDFA 문구 유지 확인
- [ ] Widget target에 GoogleMobileAds 없음 확인
- [ ] 신규 테스트 3개 이상 통과

**Must NOT do**:
- Do not use Edit or Write tools (source code modification forbidden)
- Do not add new features or fix errors (report only)
- Do not run git commands
- Bash is allowed for: running tests, builds, type checks
- Do not modify repo files via Bash (no `sed -i`, `echo >`, etc.)

**Acceptance Criteria**:

*Functional:*
- [ ] `grep 'GoogleMobileAds' project.yml` → exit 0
- [ ] `grep 'GADApplicationIdentifier' project.yml` → exit 0
- [ ] `grep -c 'SKAdNetworkIdentifier' project.yml` → ≥ 9
- [ ] `grep 'NSPrivacyCollectedDataTypeAdvertisingData' BabyCare/PrivacyInfo.xcprivacy` → exit 0
- [ ] `grep -A1 NSPrivacyTracking BabyCare/PrivacyInfo.xcprivacy | grep false` → exit 0
- [ ] `grep 'tagForChildDirectedTreatment = true' BabyCare/App/AppDelegate.swift` → exit 0
- [ ] `grep 'publisherPrivacyPersonalizationState = .disabled' BabyCare/App/AppDelegate.swift` → exit 0
- [ ] `grep 'UIViewRepresentable' BabyCare/Views/Ads/AdBannerView.swift` → exit 0
- [ ] `! grep 'UIViewControllerRepresentable' BabyCare/Views/Ads/AdBannerView.swift` → exit 0
- [ ] `grep 'currentVariant: AdExperimentVariant = .allThreeTabs' BabyCare/Services/AdExperimentVariant.swift` → exit 0
- [ ] `grep 'AdBannerView' BabyCare/App/ContentView.swift` → exit 0
- [ ] `grep 'Google AdMob' privacy.html` → exit 0
- [ ] `grep '광고 추적(IDFA)을 사용하지 않습니다' privacy.html` → exit 0
- [ ] `grep -c 'testAdExperimentVariant' BabyCareTests/BabyCareTests.swift` → ≥ 3

*Static:*
- [ ] `make build` → exit 0
- [ ] `make build 2>&1 | grep -c 'warning:'` → 0
- [ ] `plutil -lint BabyCare/PrivacyInfo.xcprivacy` → exit 0

*Runtime:*
- [ ] `make test` → 모든 테스트 PASS (기존 38 + 신규 3 이상)
- [ ] `make verify` → exit 0

**Verify**:
```yaml
commands:
  - run: "make verify"
    expect: "exit 0"
  - run: "make build 2>&1 | grep -c 'warning:'"
    expect: "0"
risk: N/A
```
