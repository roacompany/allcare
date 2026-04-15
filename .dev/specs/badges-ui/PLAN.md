# 배지 시스템 Phase 2 — UI Layer (Snackbar + Gallery + Home Strip)

> Phase 1(`badges`)에서 완성한 Badge/UserStats 모델 + BadgeEvaluator 기록 훅을 사용자에게 시각적으로 노출. 백엔드/데이터 레이어 변경 없음. **모든 UI는 ROA 디자인 토큰 + AppColors 준수, 외부 라이브러리 금지.**
>
> **Phase 2 범위**: BadgeSnackbarView (신규 획득 토스트) · BadgeGalleryView (전체 갤러리) · BadgeHomeStrip (홈 미리보기) · Localizable.strings (타이틀/설명) · 단위 + 스냅샷 테스트
> **Phase 2 제외**: 가족 공유 필터 토글 UI, Retroactive 배지 토글, 배지 상세 shareable 이미지 (Phase 3 후속)

## Verification Summary

### Agent-Verifiable (A-items)
| ID | Criterion | Method | Related TODO |
|----|-----------|--------|-------------|
| A-1 | `BadgeEvaluator.evaluate()` 반환값이 `AppState` 또는 전용 presenter로 전파되어 snackbar 트리거 | `make test` (presenter 단위) | TODO 1 |
| A-2 | `BadgeSnackbarView` — 아이콘 + 타이틀 + 자동 3초 dismiss + 탭 시 갤러리 이동 | `make test` + manual | TODO 2 |
| A-3 | `BadgeGalleryView` — 8개 정의 전체 그리드 (3열), earned/locked 상태 구분 (채도 + locked 아이콘) | `make build` | TODO 3 |
| A-4 | `BadgeGalleryView` — 탭 시 `BadgeDetailSheet` (타이틀/설명/획득일/진행도) | `make build` | TODO 3 |
| A-5 | `BadgeHomeStrip` — 홈 상단 가로 스크롤, 최근 획득 5개 + "전체 보기" 링크. 0개 시 prompt "첫 배지를 획득해보세요" | `make build` | TODO 4 |
| A-6 | aggregate 배지 진행도 — `UserStats.{statsField} / threshold` ProgressView (0~1 clamp, locked만 표시) | `make test` | TODO 3 |
| A-7 | `Localizable.strings` (ko) — 8개 × 2(title + desc) = 16 키 추가, BadgeCatalog.titleKey/descriptionKey 모두 매핑 | `make build` | TODO 5 |
| A-8 | 설정 탭 → "내 배지" 진입 동선 추가, 홈 스트립 "전체 보기"도 동일 뷰 | `make build` | TODO 4 |
| A-9 | Snackbar queue — 동시 다중 획득 시 순차 표시 (race condition 없음, 기존 presenter에 queue) | `make test` | TODO 2 |
| A-10 | `BadgeCategory` 섹션 분리 (firstTime/aggregate/streak) — 갤러리 내 3 섹션 헤더 | `make build` | TODO 3 |
| A-11 | 단위 테스트 94 → 105+ (presenter queue + progress clamp + locked/earned state) | `make test` | TODO 6 |
| A-12 | `make verify` ALL CHECKS PASSED | `make verify` | TODO Final |
| A-13 | `make lint` 0 violations, `make arch-test` baseline 유지 | `make lint` + `make arch-test` | TODO Final |
| A-14 | ROA 디자인 토큰 100% (AppColors enum 사용, 하드코딩 Color 금지) | `make design-verify` | TODO Final |

### Human-Required (H-items)
| ID | Criterion | Reason | Review Material |
|----|-----------|--------|----------------|
| H-1 | 실기기 다크모드/라이트모드 배지 갤러리 시각 품질 | Asset Catalog Dynamic Color 검증 | 실기기 Xcode Preview |
| H-2 | Snackbar 애니메이션 부드러움 (VoiceOver 없이도 자연스러움) | UX 품질 감각 | TestFlight |
| H-3 | 배지 획득 순간의 Haptic 피드백 적절성 (notificationOccurred(.success)) | Haptic 강도는 주관적 | 실기기 |
| H-4 | 가족 공유 계정에서 상대방 배지 안 보임 검증 (earnedByUserId == 본인만 갤러리 노출) | 의도된 privacy 경계 | 실기기 2계정 |
| H-5 | 3-Agent QA (Visual/UX + Code Quality + Mobile Responsive) 통과 | 시각 회귀 방지 | 3-Agent 취합 |

### Sandbox Agent Testing (S-items)
none — iOS 네이티브 앱, sandbox infra 없음

### Verification Gaps
- Snackbar 자동 dismiss 타이밍은 단위 테스트로만 보강 (실기기 UI 타이밍은 H-2)
- Haptic 강도는 H-3에서 주관 판단

## TODO List

### TODO 1 — Badge Presenter (신규 획득 전파 레이어) ✅ 2026-04-15
- [x] `BadgePresenter.swift` (신규, @MainActor @Observable) — `pending: [Badge]` 큐 + `current: Badge?` + `dismiss()` / `enqueue(_:)` API
- [x] `AppState`에 `badgePresenter: BadgePresenter` 추가
- [x] BadgeEvaluator 호출 3지점에서 반환값 `newlyEarned`을 `AppState.shared.badgePresenter.enqueue(_:)`로 연결
- [x] **검증**: 단위 테스트 4개 — enqueue 1건, FIFO drain, 빈 큐 dismiss no-op, 빈 enqueue no-op (테스트 94→102, +8 sleep-method 포함)

### TODO 2 — BadgeSnackbarView ✅ 2026-04-15
- [x] `Views/Badges/BadgeSnackbarView.swift` — ContentView overlay (`.top`), 아이콘 + 타이틀 + "축하합니다!" + 탭 시 chevron
- [x] spring 애니메이션, 3초 auto-dismiss, 탭 시 설정 탭 이동 + `.showBadgeGallery` notification
- [x] 다중 획득 큐 처리 — `.onChange(of: presenter.current?.id)` 감지, 0.3초 gap 후 다음 표시
- [x] Haptic `UINotificationFeedbackGenerator().notificationOccurred(.success)` on show

### TODO 3 — BadgeGalleryView + Progress ✅ 2026-04-15
- [x] `BadgeGalleryView.swift` — ScrollView + LazyVStack + LazyVGrid(3열), 섹션 3개 (firstTime/aggregate/streak)
- [x] `BadgeTileView` — saturation 1.0↔0.1 + opacity 1.0↔0.7 + `lock.fill` overlay + aggregate 진행도 ProgressView
- [x] `BadgeDetailSheet` — `.sheet` presentationDetents(.medium), 아이콘 + 타이틀 + 설명 + earnedAt/progress 분기
- [x] `BadgeViewModel` (@MainActor @Observable) — Service 직접 호출 금지 원칙 준수 (arch-test 통과)
- [x] **단위 테스트 3건**: progress clamp (underflow/overflow/inRange), 섹션 카운트

### TODO 4 — BadgeHomeStrip + 설정 동선 ✅ 2026-04-15
- [x] `BadgeHomeStrip.swift` — DashboardView 상단 alertBannersSection 아래 삽입, BadgeViewModel 로드
- [x] earned 0개 시 empty prompt (링크 → 갤러리), earned 있을 때 가로 ScrollView + 최근 5개 + "전체 보기"
- [x] SettingsView "내 배지" row 추가 (NavigationLink → BadgeGalleryView)

### TODO 5 — Localizable.strings ✅ 2026-04-15
- [x] 8개 배지 × (title + desc) = 16키 + 섹션 헤더 3개 + 공통 5개 + snackbar 1개 = 총 25키
- [x] `BabyCare/ko.lproj/Localizable.strings` 업데이트

### TODO 6 — 단위 테스트 추가 ✅ 2026-04-15
- [x] BadgePresenter 큐 4건 (TODO 1에서 추가 완료)
- [x] BadgeTile 진행도 clamp 3건 (underflow 0, overflow 1, 0.5)
- [x] 섹션 카운트 1건 (firstTime:1 / aggregate:4 / streak:3)
- [x] Localizable 키 매핑 1건 (BadgeCatalog.all 전체 NSLocalizedString 검증)
- [x] **실제**: 94 → 107 테스트 (+13, 목표 105+ 초과)

### TODO Final — Verify ✅ 2026-04-15
- [x] `make verify` ALL CHECKS PASSED (빌드 + 린트 + 아키텍처 + 테스트 + 디자인토큰 100%)
- [x] arch-test baseline 0 유지 (BadgeViewModel 도입으로 View→Service 직접참조 제거)
- [ ] 3-Agent QA — 사용자 액션 (실기기 확인 필요)
- [ ] Code review — 다음 세션

## Architecture Notes

### Presenter 분리 이유
BadgeEvaluator는 데이터 레이어(Service). UI 트리거는 `AppState.badgePresenter`가 담당. 이 분리로 Phase 1 단위 테스트(94개)가 UI 코드에 의존하지 않음.

### 가족 공유와 배지 Privacy
- 배지는 `earnedByUserId == 본인 uid` 조건으로 개인 소유 (Baby.ownerUserId 무관)
- BadgeGalleryView는 `authVM.currentUserId`로 fetch (데이터 로드가 아닌 **UI 표시 용도**이므로 `babyVM.dataUserId()` 사용 안 함)
- H-4에서 실기기 2계정 검증

### Localization Placeholder
- Phase 2는 ko만 (현재 앱 기본 locale). CLAUDE.md "TODO 리팩토링 잔여: 로컬라이제이션 (1,631개 한국어 하드코딩 → Localizable.strings 추출, 다국어 기반)" 작업의 **선행 케이스**로서 배지 UI만 먼저 .strings 적용 → 추후 리팩토링의 시범 케이스

### 외부 라이브러리 금지 — Haptic / Animation
- Haptic: `UINotificationFeedbackGenerator` (UIKit)
- Animation: `SwiftUI.spring(response:dampingFraction:)` 기본
- 외부 애니메이션 라이브러리(Lottie 등) 금지

## Must NOT Do (배지-specific)

- `Badge` 모델 필드 변경 금지 (Phase 1에서 확정, Firestore 스키마 회귀 방지)
- `BadgeCatalog.all` 엔트리 추가/삭제 금지 (Phase 2는 UI만)
- `conditionVersion` 증가 금지 (기존 획득 배지 재평가 트리거 위험)
- 배지 획득 순간 push notification 발송 금지 (Phase 3 스펙에서 별도 논의)
- 배지 기반 과금/유료화 로직 금지
