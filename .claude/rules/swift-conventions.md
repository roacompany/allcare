---
globs: "**/*.swift"
---

# Swift Conventions

- Swift 6.0, iOS 17+, 100% SF Symbols
- 모델: `Identifiable, Codable, Hashable` 채택, 신규 필드 optional
- 색상: `AppColors` enum (Asset Catalog 18개 Dynamic Color)
- 위젯 다크모드: `WidgetColors` adaptive enum
- 의학 데이터: 면책 문구 필수
- 테스트: BabyCareTests.swift 단일 파일에 append
- UIView는 단일 parent만 가능 — 여러 SwiftUI 컨텍스트에서 동일 UIView 인스턴스 공유 금지. UIViewRepresentable은 per-instance로 생성 (BannerAdManager per-instance 패턴 참조). 빌드 59 회귀 원인.
- **NavigationLink로 push되는 View는 body root에 NavigationStack 금지** — 중첩 NavigationStack 패턴은 iOS 17/18에서 toolbar items 결합 시 latent crash hotspot. PR #9에서 8개 view 일괄 해소 (StatsView/AIAdviceView/CryAnalysisView/DiaryView/GrowthView/SoundPlayerView/TodoView/DashboardPregnancyView). 사용자 "통계 누르면 종료" 회귀 root cause. 새 View 추가 시 push-only 면 NavigationStack 제거하고 부모(Dashboard/Settings/Health) 의 NavigationStack 사용. Tab root + push dual-use 시 push 측에서 wrap (DashboardView.swift:52 패턴).

## Swift 6 Strict Concurrency

- **동일 optional inout 프로퍼티 read+write 한 줄 금지** — exclusive access 위반. `p?.x = p?.x ?? y` 대신 `if p?.x == nil { p?.x = y }` 로 분리. pregnancy-mode-v2 P2-3에서 컴파일 에러 발생.
- **Protocol은 default parameter 값 선언 불가** — protocol extension으로 convenience overload 제공:
  ```swift
  protocol P { func f(x: Int) }
  extension P { func f() { f(x: 5) } }
  ```
- **@MainActor @Observable class의 상수는 `nonisolated static let`** — test context(non-MainActor)에서 MainActor 호핑 없이 접근 가능. 예: `nonisolated static let threshold: TimeInterval = 60`.
- **Switch exhaustive 강제**: AppContext 등 4-state enum switch에서 `default:` case 금지. 새 case 추가 시 컴파일러가 모든 call-site 알림 (빌드 58 silent skip 회귀 방지 패턴).
- **`[String: Any]` protocol 시그니처 금지**: Swift 6 Sendable 위반. Codable + Sendable struct 를 교환 통화로 사용, dict 직렬화는 구현체 내부 격리.
- **SwiftLint `statement_position`**: `do { try x() } catch { ... }` 한 줄 패턴 금지 — multi-line `do { ... } catch { ... }` 필수.

## Logging (AppLogger)

- **`print()` 사용 금지** — 모든 진단은 `AppLogger.<category>` 경유 (OSLog 기반 PII 마스킹, Console.app/Instruments 필터).
- **14 카테고리** (`Utils/AppLogger.swift`): admin / analysis / auth / badge / calendar / catalog / firestore / highlight / liveActivity / ml / pregnancy / push / sound / todo. 신규 카테고리는 알파벳 정렬 유지.
- **non-fatal silent error**: `logSilent(_ message: String, error: Error? = nil, logger: Logger)` 사용. `try? await` / empty catch 의도적 흘리기 진단용.
  ```swift
  // ❌ print("fetch failed: \(error)")
  // ❌ try? await op()  // 어디서 실패했는지 알 수 없음
  // ✅
  do { try await op() }
  catch { logSilent("op 실패", error: error, logger: AppLogger.ml) }
  ```
- **사용자에게 errorMessage 노출하는 분기에 `logSilent` 중복 사용 금지** (이중 표시 방지).
- 향후 Crashlytics non-fatal 연동 시 `logSilent` 단일 후크 포인트.

## ViewModel Helper Protocol

`ViewModels/Helpers/ViewModelHelpers.swift` 의 2 protocol 활용:

- **`LoadingStateful`** — `isLoading: Bool` 가진 VM 채택. `await withLoading { ... }` 로 defer 누락 invariant 보장 (early-return / throw / cancellation 모두 안전). 직접 토글 금지.
- **`OptimisticReplaceable`** — 배열 1개 item 교체 + Firestore save + 실패 시 rollback 패턴. ReferenceWritableKeyPath 로 배열 binding:
  ```swift
  if let error = await optimisticReplace(
      in: \.items, original: old, with: updated,
      save: { try await self.firestoreService.saveX(updated) }
  ) {
      errorMessage = "...: \(error.localizedDescription)"
  }
  ```
- 두 protocol 직교 — 동시 채택 가능. 단일 item 교체만 지원 (in-place mutation / append-or-replace 패턴은 별도 helper 후속 예정).
