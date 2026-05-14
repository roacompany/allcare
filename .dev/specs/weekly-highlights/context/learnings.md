# Learnings — weekly-highlights

## TODO 1
- `isHighlightV2Enabled`는 async (RC `fetchAndActivate`가 async) — 호출부는 `Task { await ... }` 패턴 필요
- `highlight_enabled` RC default=false + `highlight_ticker_pct` default=0 → 전체 off 안전 배포
- Layer 3 cache는 기존 pregnancy 패턴(UserDefaults)과 동일. PLAN 명세의 'Keychain' 언급은 pregnancy 구현과 일치시키기 위해 UserDefaults로 진행

## TODO 2
- `project.yml` path: BabyCare (폴더 전체) 방식 → 신규 .swift 파일은 xcodegen 자동 포함, project.yml 수정 불필요
- `deleteHighlightAICache(weekKey:)`는 `whereField(weekKey)` 쿼리 + batch delete로 다건 무효화 — RC version invalidation 시그널 처리에 적합
- `HighlightFirestoreProviding` extension은 FirestoreService+Highlight.swift 하단에 협소 protocol 선언 (PregnancyFirestoreProviding 패턴과 동일)

## TODO 10
- `WeeklyMetricSnapshot.init`은 `babyId` 없음, `weekStartDate` 필수 (`recordedAt` 아님)
- `PatternReport`는 `PatternAnalysisService.analyze()`로만 생성 가능 (직접 init 불가) — 테스트는 mock builder 패턴
- `make plan-verify`는 PLAN.md backtick `.swift` 참조 시 basename 폴백 — 슬래시 없는 경로는 전체 문자열이 basename. 디렉토리 포함 경로 필수
- `project.yml path: BabyCareUITests` → 신규 .swift 파일 xcodegen 자동 포함
- 별도 XCUITest 파일 (WeeklyHighlightFlowTests.swift)로 분리 — PLAN.md 파일명 참조 plan-verify 충족

## TODO 9
- `HighlightPrecacheService`를 `AppState`에 등록 — @Environment injection 일관성 유지 (별도 singleton 회피)
- AppState `private init()`에서 로컬 상수로 InsightService 먼저 할당 후 highlightPrecache에 주입 — self-reference 회피
- precomputeIfNeeded는 `.babyOnly` AppContext 고정 (babyId 존재 시 pregnancyOnly 아님)
- `scenePhase=.active` hook 금지 — @Observable re-render마다 트리거 위험. `.task`는 1회만 실행

## TODO 8
- `InsightCandidate`에 `Identifiable` 추가 (id = metricKey, 주차 내 unique) → `.sheet(item:)` 바인딩 가능
- async `isHighlightV2Enabled` 평가는 `.task` modifier + `@State var isHighlightV2Active`로 holding
- `FeatureFlagService.shared` 직접 접근 — @Environment 주입 없이 .task 내부에서 사용 가능
- 동일 View에 여러 `.task` modifier 체이닝 가능 (loadData + RC 평가 분리)
- AppContext switch에 `default:` 0개 유지 (A-18 invariant)

## TODO 6
- `FirebaseFunctions` product은 project.yml에 명시 추가 필요 (Firebase 11.9.0 패키지에 포함되어 있어도 product 선언 없으면 컴파일 에러)
- ESLint 9.x: `.eslintignore` deprecated → `eslint.config.js` flat config 권장 (현재 .eslintrc.js + lint 스크립트 src/ 한정 처리)
- Anthropic SDK 0.39: `client.messages.create()` + `cache_control: { type: "ephemeral" }` system 블록 prompt caching
- `RateLimitError.headers["retry-after"]`는 string — `parseInt` 변환 필요
- `HighlightAISummaryService`는 @MainActor 없이 Sendable final class — `HighlightFirestoreProviding` Sendable 의존하여 Task.detached 백그라운드 갱신
- Functions daily cap은 월별 서브컬렉션 (usageStats/{uid}/{YYYYMM}/highlightSummarize) — 월 단위 자동 파티셔닝 + old data 정리 용이

## TODO 7
- Swift 6: View + Equatable 동시 채택 시 `static func ==`을 `nonisolated`로 선언 → MainActor isolation 충돌 회피
- `.equatable()` modifier는 Equatable 채택 View에만 적용 — LazyVGrid 내부 직접 적용 불가, 컨테이너로 감싸는 패턴
- `WeeklyHighlightGridContainer` 분리 → TODO 8 DashboardView는 Container 사용 권장
- `AnalyticsEvents.highlightCardTapped` 추가 (8번째 이벤트, PLAN 스펙 7개에서 1개 추가)

## TODO 5
- iOS 26.4 SDK: `.accentColor` ShapeStyle shorthand 컴파일 실패 → `Color.accentColor` 사용
- 두 개의 `.onAppear` modifier 체이닝 가능 (초기값 세팅 + Analytics 추적 분리)
- NavigationLink Analytics는 `.simultaneousGesture(TapGesture)` 패턴 (destination 실행 차단 없이 이벤트 전송)
- arch_test.sh는 FirestoreService/AuthService 직접 참조만 검사 — AnalyticsService.shared는 Views에서 허용

## TODO 4
- PLAN 스펙 `.paused(isPaused)` modifier는 `PeriodicTimelineSchedule`에 미존재 (AnimationTimelineSchedule 전용) — `isPaused == true` 시 정적 카드로 분기하는 방식으로 대체 (기능 동등)
- `InsightCandidate`에 `accessibilityLabel` 필드 없음 — `title`로 대체. TODO 10 테스트 작성 시 주의
- `String.prefix(n)`은 Substring → `Text()` 전달 시 `String()` 캐스팅 필요
- TimelineView context closure에서 State 변경은 `.onChange` modifier로 분리 (Swift 6 경고 회피)

## TODO 3
- PLAN.md 파일 경로 drift: `BabyCare/Services/Insights/InsightService.swift` → 실제는 `BabyCare/Services/InsightService.swift` (Insights 서브폴더 없음). PLAN 5개 위치 일괄 수정
- InsightProvider 기존 metricKey는 dot notation (`feeding.count`, `diaper.wet`) 사용 — allowlist에 `_` (HighlightAICache용) + `.` (InsightProvider용) 양쪽 prefix 모두 포함
- AppContext 4-case 명시: `case .empty:`, `case .pregnancyOnly:`, `case .babyOnly, .both:` (combined) — `default:` 0회
- `nonisolated private static let` 패턴: @MainActor 클래스에서 test context 호환을 위한 상수 선언
- `refreshHighlightContext()` setter 추가: ViewModel → @Observable InsightService 상태 push 패턴 (Views→Services arch 위반 회피)
