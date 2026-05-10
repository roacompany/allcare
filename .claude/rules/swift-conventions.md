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

## Swift 6 Strict Concurrency

- **동일 optional inout 프로퍼티 read+write 한 줄 금지** — exclusive access 위반. `p?.x = p?.x ?? y` 대신 `if p?.x == nil { p?.x = y }` 로 분리. pregnancy-mode-v2 P2-3에서 컴파일 에러 발생.
- **Protocol은 default parameter 값 선언 불가** — protocol extension으로 convenience overload 제공:
  ```swift
  protocol P { func f(x: Int) }
  extension P { func f() { f(x: 5) } }
  ```
- **@MainActor @Observable class의 상수는 `nonisolated static let`** — test context(non-MainActor)에서 MainActor 호핑 없이 접근 가능. 예: `nonisolated static let threshold: TimeInterval = 60`.
- **Switch exhaustive 강제**: AppContext 등 4-state enum switch에서 `default:` case 금지. 새 case 추가 시 컴파일러가 모든 call-site 알림 (빌드 58 silent skip 회귀 방지 패턴).
