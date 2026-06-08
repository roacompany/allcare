# Track A — DS2 디자인시스템 부채 정리 (PR 2)

- **작성일**: 2026-06-09
- **상태**: 📋 **스코프 확정 · 실행 대기** (PR 1 유축 머지 후 main에서 새 브랜치)
- **베이스**: `main` = DS2 정본 (`5facce6` 계열, v2.8.4 빌드84). PR 1(유축, `147a734`) 머지 후 시작.
- **근거**: 4영역 read-only 정밀 조사(`wf_a77e463b-8e3`) — dead-code / dual-mode flag / token-bypass / guards-first.
- **출처 결정**: 유축 스펙 §11 — "전부진행"을 엉킨 1커밋이 아니라 **유축 → Track A → Track C 독립 PR 순차**로 분리(PO 확정).
- **불변 규칙**: **가드를 삭제보다 먼저** 깔고, **저위험부터 점진**. 각 단계 `make verify` green + atomic 커밋(파일별 독립 revert 가능).

## 0. 핵심 사실 (조사 확정)

- `FeatureFlags.designSystemV2Preview`는 **컴파일타임 `static let = true`** (`Utils/FeatureFlags.swift:29`, RemoteConfig 미연결) → **모든 V1 `else` 분기가 정적 dead code**.
- **9개 분기 사이트**: ContentView:258 / LoginView:36 / DashboardView:113·114·124·126 / DashboardView+Shortcuts:136(cascade)·429 / SettingsView:213(KEEP/decision).
- **플래그가 컴파일 상수라 런타임 토글 테스트 불가** → dead V1 제거의 회귀 가드는 **grep 기반 arch-test(Rule 4)가 유일한 방법**.
- **DS2 컴포넌트 라이브러리(DS2Card/Section/EmptyState/ListRow)는 product 사용 0** — `DS2PreviewView`(Settings 실험실 showcase)만 살려둠. → preview-only 사용자 부채.

## 1. KEEP vs DELETE 분류 (증거 기반)

**KEEP (실제 사용 — 건드리지 않음)**
- `DS2.swift` 토큰 네임스페이스 — ContentView(12)+LoginView(~40) 실사용. canonical 토큰 레이어.
- `DS2Button` + `DS2ButtonStyle` — ContentView:351,355 onboardingViewV2(live)에서 사용.
- `HealthStyleFavoriteCard.swift` — DashboardView+Shortcuts:174,188,201 live V2 요약 카드(유축으로 V1 카드를 dead로 만든 장본인).
- `cardStyle()`(Extensions:114) — DashboardView+Summary:75,96 live 사용. `highlightTickerOrV1Card`(공유). **삭제 금지.**

**SAFE_DELETE (위험 NONE)**
- `ActivityRingsCard.swift` (141L) — 앱 전역 참조 0, preview조차 미참조. 'Dashboard V3 시범카드'였으나 babyDashboard에 미연결.

**NEEDS_CARE (dead지만 cascade/순서 주의)**
- `dashboardV1Layout`(DashboardView:64-78), `onboardingViewV1`(ContentView:265, 57L), `loginV1`(LoginView:312, ~188L) — dead else 분기.
- **CASCADE 세트**: summaryCardsSection V1 분기 → `feeding/sleep/diaperSummaryCard` + `statsAndPatternLinks` + `summaryCardStyle` extension (~140L, 상호의존). 한 atomic 단위로 삭제.
- `DS2Card/Section/EmptyState/ListRow` — preview-only. **DS2PreviewView 운명 결정 후** prune.

## 2. 위험순 실행 계획

### Phase 0 — 가드 먼저 (동작 변경 0) ⭐ 삭제 전 필수
- **0a. `DesignSystemV2/DESIGN.md` 신설** (현재 앱 전역 DESIGN.md 0개). 내용: ① canonical 상태(2026-06-08 DS2 정본, 플래그 영구 true) ② 토큰 5축 표(Color 24/Spacing 6/Radius 3/Font 10/Shadow 3, Color는 AppColors 재export라 색값 drift 없음) ③ **스케일 drift 경고**: DS2 `lg=16` vs babycare-tokens.json `lg=20`, **Radius `sm`=12(DS2) vs 8(JSON) 네이밍 충돌** ④ Apple-Health off-token 예외(HealthStyleFavoriteCard 5/3/13/28/12/84) ⑤ **`pumpingColor` #B56FD1이 tokens.json·Activity엔 있으나 DS2.Color enum엔 누락** (3b에서 보강) ⑥ 컴포넌트 인벤토리 + 사용 규칙.
- **0b. `arch_test.sh` Rule 4 (키스톤 래칫 가드)**: `grep -rn designSystemV2Preview BabyCare/ | grep -v FeatureFlags.swift | grep -v /DesignSystemV2/ | grep -v '//' | wc -l`, **BASELINE_R4=8**. Rule 3 패턴(per-rule counter + count<baseline 시 update nudge) 복제. 인라인할 때마다 8→0 래칫 → **dead V1 재유입 시 FAIL**. *(위험 HIGH if 없음 — 반쪽 인라인/재유입 silent 회귀)*
- **0c. `BabyCareTests+DesignSystemV2.swift` 신설** (DS2 테스트 0개): ① 토큰값 단언(DS2.Spacing.lg==16, .xl==24, Radius.md==16, Shadow.md.radius==8) + `XCTAssertTrue(FeatureFlags.designSystemV2Preview)` canonical 잠금 ② render-smoke(DS2Card/Button/Section/EmptyState/ListRow/HealthStyleFavoriteCard `.body` 빌드 — **스냅샷 라이브러리 없음**, 구조 테스트만). 토큰은 nonisolated static let이라 non-MainActor 테스트 접근 가능.
- → `make verify` green. 이후 단계의 안전망.

### Phase 1 — 안전 삭제 (위험 NONE)
- **1. `ActivityRingsCard.swift` 통째 삭제** (141L orphan). 참조/import 갱신 0. Rule 4 baseline 불변.

### Phase 2 — dead V1 분기 인라인 (Rule 4 8→0, 파일별 atomic)
- **2a. LoginView**: `loginV2` 인라인 + `loginV1`(~188L) 삭제 + orphan 헬퍼(bgGradient/accentPurple/fieldBorder grep 후) 정리. Rule 4 8→7. *(V2 로그인 라이트/다크 스모크 먼저)*
- **2b. ContentView**: `onboardingViewV2` 인라인 + `onboardingViewV1`(57L) 삭제. 7→6.
- **2c. DashboardView**: `dashboardV2Layout` 인라인 + `dashboardV1Layout`(64-78) 삭제 + ternary 3개 단순화(spacing→14, scrollContentBackground→.hidden, background→systemGroupedBackground). 6→2.
- **2d. CASCADE (DashboardView+Shortcuts)**: summaryCardsSection V2 인라인 + V1 분기(155-163) + `feeding/sleep/diaperSummaryCard`·`statsAndPatternLinks`·`summaryCardStyle` extension 세트 삭제(:429 site 동반). ⚠️ `cardStyle()`·`highlightTickerOrV1Card` **유지**. 2→0. *(V2 Favorites 섹션 스모크 먼저)*
- → **Rule 4 = 0**: dead V1 완전 제거 + 재유입 차단 증명.

### Phase 3 — 토큰 위생 (저위험, 유지 파일)
- **3a. HealthStyleFavoriteCard 토큰화 4건** (시각 no-op): L42 spacing 12→`DS2.Spacing.md`, L43 spacing 4→`.xs`, L82 padding 16→`.lg`, L85 cornerRadius 12→`DS2.Radius.sm`. Apple-Health 의도 리터럴(5/3/13/28/12/84)엔 `// Apple Health spec — intentional off-token` 주석.
- **3b. `pumpingColor` #B56FD1을 `DS2.Color` enum에 추가** (DESIGN.md 인벤토리 갭 해소 — 유축 보라색이 DS2 네임스페이스에도 노출).

## 3. ✅ PO 결정 확정 (2026-06-09 — 모두 저churn·저위험)
1. **`DS2PreviewView` = `#if DEBUG`로 가둠.** SettingsView:213 실험실 Section을 `#if DEBUG`로 감싸 **출시 빌드에서 제외**(footer 약속 이행). 플래그를 always-true로 인라인하지 **않음**(인라인하면 Lab 도구가 production에 노출됨). **DS2Card/Section/EmptyState/ListRow 4컴포넌트 = KEEP** (Preview가 #if DEBUG에서 계속 살림 — 향후 재사용 팔레트). → §Phase 2에 "SettingsView:213을 `#if DEBUG` 래핑" 추가, preview-only 4컴포넌트 삭제 단계 **제거**.
2. **스케일 충돌 = DESIGN.md에 의도적 subset 명시.** 정합 통일 안 함(전역 교체+CLI 리스크 회피). DS2를 8pt-grid 실용 subset으로 문서화하고 **Radius `sm`=12(DS2) vs 8(JSON) 네이밍 충돌을 '알려진 해저드'로 박제**. 값 변경 0. → §Phase 0a DESIGN.md에 반영(이미 0a에 기술됨).
3. **시스템 그룹/그레이 색 = 유지.** 토큰화 안 함(iOS 시스템 시맨틱 색은 라이트/다크/대비 자동 대응, DS2가 의도적 미모델). HealthStyleFavoriteCard:84 `secondarySystemGroupedBackground`는 Apple HIG 강제라 유지. DESIGN.md에 "system 시맨틱 색은 의도적 비-토큰" 규칙으로 기록. → §Phase 3에서 시스템 색 교체 작업 **없음**.

## 4. 비범위 / 후속
- Track C(Sentry)는 별도 PR 3.
- 토큰 drift 정합(결정 2-A 선택 시)은 roa-design-system CLI 영향 — 별도 검토.
- `make design-verify`는 JSON만 검사(Swift 미스캔) → Rule 4/5(arch-test)가 Swift측 가드.
