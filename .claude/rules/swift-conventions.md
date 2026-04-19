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
