---
description: 새 SwiftUI View 추가 시 ViewModel을 함께 스캐폴드하여 arch-test 위반 선제 차단
---

# /swift-new-view {ViewName} [Category]

목적: BabyCare arch-test (View → Service 직접 참조 금지) 위반을 **파일 생성 시점부터 예방**.

## Behavior

인자:
- `{ViewName}` — 예: `BadgeGalleryView` (접미사 `View` 필수)
- `[Category]` — 선택, 파일 배치 디렉토리 힌트 (예: `Badges`, `Health`). 미지정 시 사용자에게 질문.

실행 순서:
1. **BaseName 추출**: `ViewName`에서 끝의 `View` 제거 → `Badge`
2. **ViewModel 파일 Write**:
   - 경로: `BabyCare/ViewModels/{BaseName}ViewModel.swift`
   - 내용: `@MainActor @Observable final class {BaseName}ViewModel` 스켈레톤 + `FirestoreService.shared` private 필드 + TODO 주석 ("load/save 메서드 여기에 추가")
3. **View 파일 Write**:
   - 경로: `BabyCare/Views/{Category}/{ViewName}.swift`
   - 내용: `struct {ViewName}: View`, `@State private var vm = {BaseName}ViewModel()`, `.task { await vm.load(userId:) }` 자리, body는 `Text("TODO: {ViewName}")`
   - **절대 FirestoreService 직접 참조 금지** 주석 상단 포함
4. **xcodegen**: 프로젝트 재생성
5. **arch-test baseline 확인**: `make arch-test` 실행, baseline 0 유지 확인

## 주의
- 이미 존재하는 View의 ViewModel만 생성하려면 `/swift-new-viewmodel {BaseName}` (별도 커맨드 또는 수동)
- `BadgeViewModel`처럼 이미 있는 ViewModel과 충돌 시 Stop
- `@Environment`로 주입받을 VM이 이미 AppState 싱글톤에 있다면 이 커맨드 사용 안 함 (직접 주입)

## 원칙
- arch-test 위반을 "late feedback"이 아닌 "sync-time 규칙"으로 전환
- CLAUDE.md "Views→Services 직접 참조 탐지" 규칙 준수
