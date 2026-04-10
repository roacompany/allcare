# Firebase Analytics 성과측정 시스템

> BabyCare iOS 앱에 Firebase Analytics를 추가하여 핵심 10개 뷰의 페이지 뷰, 버튼 클릭, 사용자 속성을 트래킹하는 성과측정 시스템 구축

---

## Verification Summary

### Agent-Verifiable (A-items)
| ID | Criterion | Method | Related TODO |
|----|-----------|--------|-------------|
| A-1 | project.yml에 FirebaseAnalytics product 존재 | `grep 'FirebaseAnalytics' project.yml` | TODO 1 |
| A-2 | xcodegen generate 성공 | `make generate` exit 0 | TODO 1 |
| A-3 | AnalyticsService.swift 파일 존재 | `test -f BabyCare/Services/AnalyticsService.swift` | TODO 2 |
| A-4 | AnalyticsEvents.swift 파일 존재 | `test -f BabyCare/Services/AnalyticsEvents.swift` | TODO 2 |
| A-5 | AnalyticsServiceProtocol 정의 존재 | `grep 'protocol AnalyticsTracking' BabyCare/Services/AnalyticsService.swift` | TODO 2 |
| A-6 | make build 성공 (컴파일 오류 0) | `make build` exit 0 | TODO 2, 3, 4, 5 |
| A-7 | 기존 25개 테스트 통과 | `make test` exit 0 | TODO Final |
| A-8 | Analytics 관련 신규 테스트 통과 | `make test` — 25개 이상 PASS | TODO Final |
| A-9 | 핵심 10개 뷰에 이벤트 로깅 코드 존재 | `grep -r 'AnalyticsService\|trackEvent\|trackScreen' BabyCare/Views --include='*.swift' \| wc -l` ≥ 10 | TODO 3, 4 |
| A-10 | 옵트아웃 토글 코드 존재 | `grep -r 'isAnalyticsEnabled\|analyticsEnabled' BabyCare/ --include='*.swift'` | TODO 5 |
| A-11 | PrivacyInfo.xcprivacy 문법 유효 | `plutil -lint BabyCare/PrivacyInfo.xcprivacy` exit 0 | TODO 6 |
| A-12 | NSPrivacyCollectedDataTypes 비어있지 않음 | `grep 'NSPrivacyCollectedDataTypes' BabyCare/PrivacyInfo.xcprivacy` | TODO 6 |
| A-13 | Preview 환경 가드 존재 | `grep 'XCODE_RUNNING_FOR_PREVIEWS' BabyCare/Services/AnalyticsService.swift` | TODO 2 |
| A-14 | make verify 전체 통과 | `make verify` exit 0 | TODO Final |

### Human-Required (H-items)
| ID | Criterion | Reason | Review Material |
|----|-----------|--------|----------------|
| H-1 | Firebase DebugView에서 이벤트 수신 확인 | 실기기/시뮬레이터에서만 확인 가능 | Xcode console + Firebase Console > DebugView |
| H-2 | 옵트아웃 토글 OFF 시 이벤트 전송 실제 차단 | SDK 내부 동작은 런타임에서만 확인 | 시뮬레이터에서 토글 전환 후 DebugView 확인 |
| H-3 | User Properties Firebase Console 반영 | 24~48시간 후 확인 필요 | Firebase Console > Analytics > User Properties |
| H-4 | 이벤트 명칭/파라미터 설계 적절성 | 분석 목적에 맞는지 판단 필요 | AnalyticsEvents.swift 코드 리뷰 |
| H-5 | PrivacyInfo.xcprivacy App Store 심사 적합성 | Apple 심사 기준 주관적 판단 | firebase-ios-sdk 공식 manifest 대조 결과 |
| H-6 | 10개 뷰 이벤트 커버리지 코드 리뷰 | 각 버튼에 올바른 이벤트가 연결되었는지 | PR diff 리뷰 |
| H-7 | Settings 토글 UI 위치/문구 적절성 | UX 판단 필요 | `make screenshots` 결과물 |

### Verification Gaps
- Firebase SDK 런타임 검증 불가 → AnalyticsServiceProtocol + MockAnalyticsService로 unit test 보완
- Tier 4 (Agent Sandbox) 없음 — iOS native 앱, docker-compose/BDD 미지원
- Firebase Console 데이터 반영 24~48시간 소요 — 즉시 확인 불가

---

## External Dependencies Strategy

### Pre-work (user prepares before AI work)
| Dependency | Action | Command/Step | Blocking? |
|------------|--------|-------------|-----------|
| Firebase Console | Analytics 활성화 여부 확인 (Google Analytics 연동) | Firebase Console > Project Settings > Analytics | No |

### During (AI work strategy)
| Dependency | Dev Strategy | Rationale |
|------------|-------------|-----------|
| FirebaseAnalytics SDK | project.yml에 product 추가, SPM 자동 해결 | Firebase 11.0.0 이미 설치, 동일 버전 |
| UserDefaults | 기존 패턴 그대로 사용 (ThemeManager 참조) | 옵트아웃 플래그 저장 |
| PrivacyInfo.xcprivacy | firebase-ios-sdk GitHub에서 공식 privacy manifest 참조 | App Store 심사 정합성 |

### Post-work (user actions after completion)
| Task | Related Dependency | Action | Command/Step |
|------|--------------------|--------|-------------|
| Firebase DebugView 확인 | Firebase Console | 시뮬레이터에서 이벤트 수신 확인 | `-FIRDebugEnabled` launch argument 추가 후 실행 |
| App Store 재제출 | PrivacyInfo.xcprivacy | 빌드 47+ 제출 시 xcprivacy 변경 반영 | `make deploy` |
| 개인정보처리방침 업데이트 | Privacy Policy | 웹페이지 내용 업데이트 | `roacompany.github.io/allcare/privacy.html` 수정 |

---

## Context

### Original Request
BabyCare 앱의 버튼, 페이지, 사용자 등 성과측정 — Firebase Analytics 기반

### Interview Summary
**Key Discussions**:
- 이벤트 범위: 전체 버튼 → 분석 후 핵심 10개 뷰 우선 적용 (HIGH 리스크 완화)
- User Property: 상세 속성 6종 (아기 수, 앱 버전, 온보딩 완료, 주 사용 기능, 가족 공유, 테마)
- Privacy: Firebase SDK 공식 manifest 기준으로 xcprivacy 업데이트, NSPrivacyTracking=false 유지
- ATT/IDFA: 사용 안 함 — 앱 런치 시 동의 다이얼로그 없음

**Research Findings**:
- Firebase 11.0.0 이미 설치 → FirebaseAnalytics product만 추가
- PrivacyInfo.xcprivacy NSPrivacyCollectedDataTypes 빈 배열 → 반드시 업데이트
- FirebaseApp.configure() 이중 호출 패턴 (AppDelegate + BabyCareApp.init) — Analytics 초기화는 AppDelegate에서
- AnalyticsService 동시성: Analytics.logEvent()는 내부적으로 백그라운드 dispatch → nonisolated 또는 Sendable 패턴 권장

---

## Work Objectives

### Core Objective
Firebase Analytics를 BabyCare 앱에 통합하여 핵심 10개 뷰의 페이지 뷰/버튼 클릭 트래킹 + 상세 사용자 속성 + 옵트아웃 기능을 구현

### Concrete Deliverables
- `project.yml` — FirebaseAnalytics product 추가
- `BabyCare/Services/AnalyticsService.swift` — 이벤트 로깅 중앙 서비스 (Protocol 포함)
- `BabyCare/Services/AnalyticsEvents.swift` — 이벤트/파라미터 이름 상수
- `BabyCare/App/ContentView.swift` — 탭 전환 페이지 뷰 트래킹
- 핵심 10개 뷰 파일 — 버튼 이벤트 트래킹 추가
- `BabyCare/Views/Settings/SettingsView.swift` — 옵트아웃 토글
- `BabyCare/PrivacyInfo.xcprivacy` — NSPrivacyCollectedDataTypes 업데이트
- `BabyCareTests/BabyCareTests.swift` — Analytics 관련 테스트 추가

### Definition of Done
- [ ] `make build` 성공
- [ ] `make test` 기존 25개 + 신규 테스트 통과
- [ ] 핵심 10개 뷰에 이벤트 로깅 코드 존재
- [ ] Settings에 옵트아웃 토글 동작
- [ ] PrivacyInfo.xcprivacy 유효하고 데이터 수집 항목 선언됨
- [ ] `make verify` 성공

### Must NOT Do (Guardrails)
- ATT(App Tracking Transparency) 프롬프트 추가 금지
- `NSUserTrackingUsageDescription` Info.plist 추가 금지
- `NSPrivacyTracking`을 `true`로 변경 금지
- 앱 런치 시 동의 다이얼로그 표시 금지
- 아기 이름, 건강 기록 등 개인 데이터를 이벤트 파라미터로 전송 금지
- Widget Extension 타겟에 FirebaseAnalytics 링크 금지
- AnalyticsService 파일을 여러 파일로 분할 금지 (단일 파일)
- 기존 155개 Button을 커스텀 컴포넌트로 전수 교체 금지
- SwiftUI Preview에서 Analytics 이벤트 전송 금지 (환경 가드 필수)
- 이벤트 파라미터 과다 금지 (이벤트당 최대 5개 파라미터)
- `AIGuardrailService` 수정 금지
- 외부 분석 라이브러리 추가 금지

---

## Task Flow

```
TODO-1 (project.yml) → TODO-2 (AnalyticsService) → TODO-3 (페이지뷰) ─┐
                                                   → TODO-4 (버튼)    ─┤→ TODO-6 (Privacy) → TODO-Final
                                                   → TODO-5 (옵트아웃) ─┘
```

## Dependency Graph

| TODO | Requires (Inputs) | Produces (Outputs) | Type |
|------|-------------------|-------------------|------|
| 1 | - | `project_updated` (string) | work |
| 2 | `todo-1.project_updated` | `analytics_service` (file), `analytics_events` (file) | work |
| 3 | `todo-2.analytics_service`, `todo-2.analytics_events` | `page_tracking_done` (string) | work |
| 4 | `todo-2.analytics_service`, `todo-2.analytics_events` | `button_tracking_done` (string) | work |
| 5 | `todo-2.analytics_service` | `optout_done` (string) | work |
| 6 | - | `privacy_updated` (string) | work |
| Final | all outputs | - | verification |

## Parallelization

| Group | TODOs | Reason |
|-------|-------|--------|
| A | TODO 3, 4, 5 | 모두 AnalyticsService에만 의존, 서로 독립적 |
| B | TODO 6 | 다른 TODO와 독립적, 언제든 실행 가능 |

## Commit Strategy

| After TODO | Message | Files | Condition |
|------------|---------|-------|-----------|
| 1 | `chore(deps): add FirebaseAnalytics to project.yml` | `project.yml` | always |
| 2 | `feat(analytics): add AnalyticsService and event constants` | `BabyCare/Services/AnalyticsService.swift`, `BabyCare/Services/AnalyticsEvents.swift`, `BabyCareTests/BabyCareTests.swift` | always |
| 3+4+5 | `feat(analytics): add page view, button tracking, and opt-out toggle` | `BabyCare/App/ContentView.swift`, `BabyCare/Views/**/*.swift`, `BabyCare/Views/Settings/SettingsView.swift` | always |
| 6 | `chore(privacy): update PrivacyInfo.xcprivacy for Analytics` | `BabyCare/PrivacyInfo.xcprivacy` | always |

## Error Handling

### Failure Categories

| Category | Examples | Detection Pattern |
|----------|----------|-------------------|
| `env_error` | SPM resolve 실패, xcodegen 에러 | `/error:\|fatal:\|xcodegen.*failed/i` |
| `code_error` | Swift 컴파일 에러, 타입 불일치, 동시성 warning | `/error:\|cannot find\|is not a member/i` |
| `scope_internal` | Firebase API 변경, 누락된 import | Worker `suggested_adaptation` present |
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
| Package Install | Denied (FirebaseAnalytics는 기존 Firebase 11.0.0 내 product) |
| File Access | Repository only |
| Max Execution Time | 5 minutes per TODO |
| Git Operations | Denied (Orchestrator handles) |

---

## TODOs

### [ ] TODO 1: Add FirebaseAnalytics to project.yml

**Type**: work

**Required Tools**: `xcodegen`

**Inputs**: (none)

**Outputs**:
- `project_updated` (string): `done` — project.yml에 FirebaseAnalytics 추가 완료

**Steps**:
- [ ] `project.yml`의 Firebase package dependencies 섹션에 `FirebaseAnalytics` product 추가
- [ ] `make generate` 실행하여 xcodeproj 재생성

**Must NOT do**:
- BabyCareWidgetExtension 타겟에 FirebaseAnalytics 추가 금지
- Firebase 버전(11.0.0) 변경 금지
- 다른 패키지 추가 금지
- Do not run git commands

**References**:
- `project.yml:22-41` — Firebase package 정의 및 dependency 패턴
- `project.yml:50-65` — BabyCare target dependencies 섹션

**Acceptance Criteria**:

*Functional:*
- [ ] `grep 'FirebaseAnalytics' project.yml` → 매칭됨
- [ ] `make generate` → exit 0

*Static:*
- [ ] project.yml YAML 문법 유효

*Runtime:*
- [ ] `make build` → exit 0 (SPM resolve + 컴파일 성공)

**Verify**:
```yaml
acceptance:
  - given: ["project.yml에 FirebaseAnalytics 추가됨"]
    when: "make generate && make build"
    then: ["xcodegen 성공", "SPM resolve 성공", "빌드 성공"]
commands:
  - run: "grep 'FirebaseAnalytics' project.yml"
    expect: "exit 0"
  - run: "make generate"
    expect: "exit 0"
  - run: "make build"
    expect: "exit 0"
risk: LOW
```

---

### [ ] TODO 2: Create AnalyticsService, AnalyticsEvents, and Tests

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `project_updated` (string): `${todo-1.outputs.project_updated}`

**Outputs**:
- `analytics_service` (file): `BabyCare/Services/AnalyticsService.swift`
- `analytics_events` (file): `BabyCare/Services/AnalyticsEvents.swift`

**Steps**:
- [ ] `BabyCare/Services/AnalyticsService.swift` 생성:
  - `AnalyticsTracking` protocol 정의 (trackScreen, trackEvent, setUserProperty 메서드)
  - `AnalyticsService: AnalyticsTracking` 구현 — `final class, Sendable, static let shared`
  - `FirestoreService` 싱글턴 패턴 따름
  - `Analytics.logEvent()` 래핑 — nonisolated 메서드로 구현
  - `isEnabled` 플래그: UserDefaults 기반, `Analytics.setAnalyticsCollectionEnabled()` 연동
  - `ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"]` 가드 — Preview 시 이벤트 전송 차단
  - AppDelegate의 `FirebaseApp.configure()` 직후 UserDefaults 옵트아웃 플래그 체크 → `Analytics.setAnalyticsCollectionEnabled()` 호출
  - User Property 6종 설정 메서드: `updateUserProperties()` — 아기 수, 앱 버전, 온보딩 완료, 주 사용 기능, 가족 공유 여부, 테마
  - `MockAnalyticsService: AnalyticsTracking` — 테스트용 Mock 구현 (동일 파일 내)
- [ ] `BabyCare/Services/AnalyticsEvents.swift` 생성:
  - `AnalyticsEvents` enum — 화면별 이벤트 이름 상수 (핵심 10개 뷰 기준)
  - `AnalyticsParams` enum — 파라미터 키 상수
  - `AnalyticsScreens` enum — 화면 이름 상수
  - `AnalyticsUserProperties` enum — User Property 이름 상수
  - Firebase 이벤트명 제한 준수: 영문 소문자 + 언더스코어, 40자 이내
- [ ] `BabyCareTests/BabyCareTests.swift`에 Analytics 테스트 추가:
  - MockAnalyticsService를 사용한 이벤트 로깅 검증
  - 옵트아웃 시 이벤트 미전송 검증
  - User Property 설정 검증

**Must NOT do**:
- AnalyticsService를 여러 파일로 분할 금지
- `@MainActor @Observable` 패턴 사용 금지 — Analytics는 상태 관리 불필요, `Sendable` 패턴 사용
- 이벤트 파라미터 과다 정의 금지 (이벤트당 최대 5개)
- Do not run git commands

**References**:
- `Services/FirestoreService.swift:5-6` — `final class: Sendable, static let shared` 패턴
- `Services/AuthService.swift:8-10` — 무상태 서비스 싱글턴
- `Services/FirestoreService.swift:3,8` — OSLog 로깅 패턴
- `App/AppDelegate.swift:12-14` — `FirebaseApp.configure()` 위치
- `App/AppState.swift:9-41` — AppState 싱글턴 구조

**Acceptance Criteria**:

*Functional:*
- [ ] `AnalyticsService.swift` 파일 존재
- [ ] `AnalyticsEvents.swift` 파일 존재
- [ ] `AnalyticsTracking` protocol 정의됨
- [ ] `MockAnalyticsService` 존재
- [ ] Preview 환경 가드 코드 존재
- [ ] User Property 6종 설정 메서드 존재

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 25개 이상 PASS (기존 회귀 없음 + 신규 Analytics 테스트)

**Verify**:
```yaml
acceptance:
  - given: ["AnalyticsService, AnalyticsEvents 파일 생성됨"]
    when: "make build && make test"
    then: ["컴파일 성공", "모든 테스트 통과"]
commands:
  - run: "test -f BabyCare/Services/AnalyticsService.swift"
    expect: "exit 0"
  - run: "test -f BabyCare/Services/AnalyticsEvents.swift"
    expect: "exit 0"
  - run: "grep 'protocol AnalyticsTracking' BabyCare/Services/AnalyticsService.swift"
    expect: "exit 0"
  - run: "grep 'XCODE_RUNNING_FOR_PREVIEWS' BabyCare/Services/AnalyticsService.swift"
    expect: "exit 0"
  - run: "make build"
    expect: "exit 0"
  - run: "make test"
    expect: "exit 0"
risk: LOW
```

---

### [ ] TODO 3: Add Page View Tracking to ContentView

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `analytics_service` (file): `${todo-2.outputs.analytics_service}`
- `analytics_events` (file): `${todo-2.outputs.analytics_events}`

**Outputs**:
- `page_tracking_done` (string): `done`

**Steps**:
- [ ] `ContentView.swift`에 `import FirebaseAnalytics` 추가
- [ ] `ContentView`에서 `selectedTab` 변경 시 `AnalyticsService.shared.trackScreen()` 호출
  - 기존 `onChange(of: selectedTab)` 또는 새로운 `.onChange` modifier 사용
  - 탭 인덱스를 `AnalyticsScreens` 상수로 매핑
- [ ] 앱 시작 시 User Property 초기 설정: `AnalyticsService.shared.updateUserProperties()`
  - ContentView의 `.onAppear` 또는 AppDelegate에서 호출

**Must NOT do**:
- 모든 개별 뷰에 `.onAppear` 트래킹 추가 금지 — ContentView 한 곳에서 탭 레벨 트래킹
- 개인 데이터를 screen 파라미터로 전송 금지
- Do not run git commands

**References**:
- `App/ContentView.swift:203-244` — TabView 및 selectedTab 바인딩
- `App/ContentView.swift:236-244` — 탭 전환 이벤트 처리 (haptic + recording sheet)

**Acceptance Criteria**:

*Functional:*
- [ ] ContentView에 `trackScreen` 호출 코드 존재
- [ ] 5개 탭 각각에 대한 화면 이름 매핑 존재

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 기존 테스트 통과

**Verify**:
```yaml
acceptance:
  - given: ["ContentView에 페이지 뷰 트래킹 추가됨"]
    when: "탭 전환 시"
    then: ["AnalyticsService.trackScreen() 호출됨", "올바른 화면 이름 전달"]
commands:
  - run: "grep -c 'trackScreen' BabyCare/App/ContentView.swift"
    expect: "exit 0"
  - run: "make build"
    expect: "exit 0"
risk: LOW
```

---

### [ ] TODO 4: Add Button Event Tracking to Key Views

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `analytics_service` (file): `${todo-2.outputs.analytics_service}`
- `analytics_events` (file): `${todo-2.outputs.analytics_events}`

**Outputs**:
- `button_tracking_done` (string): `done`

**Steps**:
- [ ] 핵심 10개 뷰에 버튼 이벤트 트래킹 추가 (각 뷰의 주요 버튼/액션에 `AnalyticsService.shared.trackEvent()` 호출):
  1. `Views/Dashboard/DashboardView.swift` — 대시보드 카드 탭, 빠른 기록 버튼
  2. `Views/Calendar/CalendarView.swift` — 날짜 선택, 기록 상세 열기
  3. `Views/Recording/RecordingView.swift` — 기록 시작/저장 버튼
  4. `Views/Recording/FeedRecordingView.swift` — 수유 기록 저장
  5. `Views/Recording/SleepRecordingView.swift` — 수면 기록 저장
  6. `Views/Recording/DiaperRecordingView.swift` — 기저귀 기록 저장
  7. `Views/Health/HealthView.swift` — 건강 데이터 조회
  8. `Views/AI/AIAdviceView.swift` — AI 조언 요청 버튼
  9. `Views/Growth/GrowthView.swift` — 성장 데이터 입력
  10. `Views/Products/ProductListView.swift` — 상품 탭/조회
- [ ] 각 이벤트는 `AnalyticsEvents` 상수 사용
- [ ] 이벤트 파라미터는 최소한으로: `view_name`, `action_type` 정도

**Must NOT do**:
- 위 10개 뷰 외의 파일 수정 금지 (나머지는 v2.8에서 점진 추가)
- Button을 커스텀 컴포넌트로 교체 금지 — 기존 Button action 클로저에 한 줄 추가만
- 아기 이름, 기록 내용, 건강 수치 등 개인 데이터를 이벤트 파라미터로 전송 금지
- 이벤트당 파라미터 5개 초과 금지
- Do not run git commands

**References**:
- `Views/Dashboard/DashboardView.swift` — 대시보드 구조
- `Views/Recording/RecordingView.swift` — 기록 뷰 구조
- `Views/Health/HealthView.swift` — 건강 뷰 구조
- `Services/AnalyticsEvents.swift` — 이벤트 상수 (TODO 2에서 생성)

**Acceptance Criteria**:

*Functional:*
- [ ] 10개 뷰 파일에 `trackEvent` 호출 존재
- [ ] 모든 이벤트가 `AnalyticsEvents` 상수 사용

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 기존 테스트 통과

**Verify**:
```yaml
acceptance:
  - given: ["핵심 10개 뷰에 버튼 트래킹 추가됨"]
    when: "각 뷰의 주요 버튼 탭 시"
    then: ["AnalyticsService.trackEvent() 호출됨", "AnalyticsEvents 상수 사용"]
commands:
  - run: "grep -rl 'trackEvent' BabyCare/Views/ --include='*.swift' | wc -l"
    expect: "≥ 10 files"
  - run: "make build"
    expect: "exit 0"
risk: MEDIUM
```

---

### [ ] TODO 5: Add Analytics Opt-Out Toggle to Settings

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `analytics_service` (file): `${todo-2.outputs.analytics_service}`

**Outputs**:
- `optout_done` (string): `done`

**Steps**:
- [ ] `SettingsView.swift`의 "앱 설정" 섹션에 Analytics 옵트아웃 토글 추가:
  - 위치: 알림 설정 뒤, 가족 공유 앞
  - 레이블: "앱 사용 데이터 공유"
  - 푸터: "앱 개선을 위해 사용 통계를 익명으로 수집합니다. 개인 기록은 포함되지 않습니다."
  - `@AppStorage` 또는 UserDefaults 바인딩
  - 토글 변경 시 `AnalyticsService.shared.setEnabled()` 호출
- [ ] 기본값: 활성화(true) — 옵트아웃 방식

**Must NOT do**:
- 별도 서브 화면(NavigationLink) 생성 금지 — 기존 섹션에 토글 추가만
- 옵트인 방식 금지 (기본 비활성화 금지)
- Do not run git commands

**References**:
- `Views/Settings/SettingsView.swift:94-139` — 앱 설정 섹션 구조
- `Views/Settings/NotificationSettingsView.swift` — 개별 토글 패턴 참조

**Acceptance Criteria**:

*Functional:*
- [ ] SettingsView에 "앱 사용 데이터 공유" 토글 존재
- [ ] 토글 변경 시 `AnalyticsService` 연동

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → 기존 테스트 통과

**Verify**:
```yaml
acceptance:
  - given: ["Settings에 옵트아웃 토글 추가됨"]
    when: "토글을 OFF로 변경"
    then: ["AnalyticsService.setEnabled(false) 호출", "UserDefaults에 저장"]
commands:
  - run: "grep '앱 사용 데이터 공유' BabyCare/Views/Settings/SettingsView.swift"
    expect: "exit 0"
  - run: "grep -c 'isAnalyticsEnabled\|analyticsEnabled\|setEnabled' BabyCare/Views/Settings/SettingsView.swift"
    expect: "exit 0"
  - run: "make build"
    expect: "exit 0"
risk: MEDIUM
```

---

### [ ] TODO 6: Update PrivacyInfo.xcprivacy

**Type**: work

**Required Tools**: `plutil`

**Inputs**: (none)

**Outputs**:
- `privacy_updated` (string): `done`

**Steps**:
- [ ] firebase-ios-sdk의 FirebaseAnalytics PrivacyInfo.xcprivacy 참조하여 필요 항목 파악
- [ ] `BabyCare/PrivacyInfo.xcprivacy`의 `NSPrivacyCollectedDataTypes` 배열에 항목 추가:
  - 앱 사용 데이터 (Analytics usage data)
  - 기기 식별자 (IDFV — not IDFA)
  - 진단 데이터 (Crash/performance)
- [ ] 각 항목에 수집 목적 명시: `NSPrivacyCollectedDataTypePurposes` = Analytics
- [ ] `NSPrivacyCollectedDataTypeLinked` = false (사용자 신원과 연결 안 함)
- [ ] `NSPrivacyTracking` = false 유지 확인
- [ ] `plutil -lint` 실행하여 문법 검증

**Must NOT do**:
- `NSPrivacyTracking`을 `true`로 변경 금지
- `NSUserTrackingUsageDescription` 추가 금지
- IDFA 관련 항목 추가 금지
- Do not run git commands

**References**:
- `BabyCare/PrivacyInfo.xcprivacy` — 현재 파일 (NSPrivacyTracking=false, CollectedDataTypes=[])
- firebase-ios-sdk GitHub: `FirebaseAnalytics/Sources/PrivacyInfo.xcprivacy`

**Acceptance Criteria**:

*Functional:*
- [ ] `NSPrivacyCollectedDataTypes` 비어있지 않음
- [ ] `NSPrivacyTracking` = false 유지
- [ ] 수집 목적이 Analytics로 명시

*Static:*
- [ ] `plutil -lint BabyCare/PrivacyInfo.xcprivacy` → exit 0

*Runtime:*
- [ ] `make build` → exit 0

**Verify**:
```yaml
acceptance:
  - given: ["PrivacyInfo.xcprivacy 업데이트됨"]
    when: "plutil -lint 실행"
    then: ["문법 유효", "NSPrivacyCollectedDataTypes 비어있지 않음", "NSPrivacyTracking=false"]
commands:
  - run: "plutil -lint BabyCare/PrivacyInfo.xcprivacy"
    expect: "exit 0"
  - run: "grep 'NSPrivacyCollectedDataTypes' BabyCare/PrivacyInfo.xcprivacy"
    expect: "exit 0"
risk: HIGH
rollback: "PrivacyInfo.xcprivacy는 제출 전까지 git revert 가능. 제출 후에는 새 빌드로만 수정 가능."
```

---

### [ ] TODO Final: Verification

**Type**: verification

**Required Tools**: `xcodebuild`, `plutil`

**Inputs**:
- `analytics_service` (file): `${todo-2.outputs.analytics_service}`
- `analytics_events` (file): `${todo-2.outputs.analytics_events}`
- `page_tracking_done` (string): `${todo-3.outputs.page_tracking_done}`
- `button_tracking_done` (string): `${todo-4.outputs.button_tracking_done}`
- `optout_done` (string): `${todo-5.outputs.optout_done}`
- `privacy_updated` (string): `${todo-6.outputs.privacy_updated}`

**Outputs**: (none)

**Steps**:
- [ ] `make verify` 실행 (build + test + design-verify)
- [ ] 모든 deliverable 파일 존재 확인
- [ ] AnalyticsService에 Protocol + Mock + Preview 가드 확인
- [ ] 핵심 10개 뷰에 trackEvent 호출 존재 확인 (grep)
- [ ] SettingsView에 옵트아웃 토글 존재 확인
- [ ] PrivacyInfo.xcprivacy 유효성 확인 (plutil -lint)
- [ ] NSPrivacyTracking=false 유지 확인
- [ ] NSUserTrackingUsageDescription 미존재 확인

**Must NOT do**:
- Do not use Edit or Write tools (source code modification forbidden)
- Do not add new features or fix errors (report only)
- Do not run git commands
- Bash is allowed for: running tests, builds, type checks
- Do not modify repo files via Bash (no `sed -i`, `echo >`, etc.)

**Acceptance Criteria**:

*Functional:*
- [ ] `AnalyticsService.swift` 존재
- [ ] `AnalyticsEvents.swift` 존재
- [ ] `AnalyticsTracking` protocol 정의됨
- [ ] 10개 뷰에 `trackEvent` 호출 존재 (grep 카운트 ≥ 10)
- [ ] SettingsView에 옵트아웃 토글 존재
- [ ] PrivacyInfo.xcprivacy `NSPrivacyCollectedDataTypes` 비어있지 않음
- [ ] `NSPrivacyTracking` = false
- [ ] `NSUserTrackingUsageDescription` Info.plist에 없음

*Static:*
- [ ] `make build` → exit 0
- [ ] `plutil -lint BabyCare/PrivacyInfo.xcprivacy` → exit 0

*Runtime:*
- [ ] `make test` → 모든 테스트 PASS (기존 25개 + 신규)
- [ ] `make verify` → exit 0

**Verify**:
```yaml
commands:
  - run: "make verify"
    expect: "exit 0"
  - run: "test -f BabyCare/Services/AnalyticsService.swift && test -f BabyCare/Services/AnalyticsEvents.swift"
    expect: "exit 0"
  - run: "grep -rl 'trackEvent' BabyCare/Views/ --include='*.swift' | wc -l"
    expect: "≥ 10"
  - run: "grep '앱 사용 데이터 공유' BabyCare/Views/Settings/SettingsView.swift"
    expect: "exit 0"
  - run: "plutil -lint BabyCare/PrivacyInfo.xcprivacy"
    expect: "exit 0"
  - run: "grep 'NSPrivacyTracking' BabyCare/PrivacyInfo.xcprivacy"
    expect: "contains false"
risk: N/A
```
