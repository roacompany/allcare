# Learnings — weekly-highlights

## TODO 1
- `isHighlightV2Enabled`는 async (RC `fetchAndActivate`가 async) — 호출부는 `Task { await ... }` 패턴 필요
- `highlight_enabled` RC default=false + `highlight_ticker_pct` default=0 → 전체 off 안전 배포
- Layer 3 cache는 기존 pregnancy 패턴(UserDefaults)과 동일. PLAN 명세의 'Keychain' 언급은 pregnancy 구현과 일치시키기 위해 UserDefaults로 진행

## TODO 2
- `project.yml` path: BabyCare (폴더 전체) 방식 → 신규 .swift 파일은 xcodegen 자동 포함, project.yml 수정 불필요
- `deleteHighlightAICache(weekKey:)`는 `whereField(weekKey)` 쿼리 + batch delete로 다건 무효화 — RC version invalidation 시그널 처리에 적합
- `HighlightFirestoreProviding` extension은 FirestoreService+Highlight.swift 하단에 협소 protocol 선언 (PregnancyFirestoreProviding 패턴과 동일)

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
