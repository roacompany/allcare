# BabyCare DesignSystemV2 (DS2) — 디자인 시스템 정본

> **Status: CANONICAL** (2026-06-08~). PO가 `git reset --hard origin/main`로 DS2를 정본 확정(대안 BCDS 폐기, 백업 `backup/bcds-v2.8.5-build86`). 이 문서는 DS2의 단일 진실 출처(SSOT)다.

## 0. 정본성 / 플래그

- `FeatureFlags.designSystemV2Preview`는 **컴파일타임 `static let = true`** (RemoteConfig 미연결). 이름의 "Preview"는 **역사적 잔재** — 실제로는 영구 활성 정본 게이트.
- 모든 V1 `else` 분기는 **정적 dead code**. Track A에서 점진 제거 중(`arch_test.sh` **Rule 4** 래칫 9→0이 회귀 차단).
- **V2 라이브 표면**: Dashboard(Favorites/HealthStyleFavoriteCard), Login(LoginView), Onboarding(ContentView).

## 1. 토큰 스케일 (DS2.swift)

| 축 | 토큰 | 비고 |
|---|---|---|
| **Color** | surface(Primary/Secondary), text(Primary/Secondary/OnAccent), accent, activity 7(feeding/sleep/diaper/solid/bath/temperature/medication), semantic 4(success/warning/**danger**=coral/**info**=skyBlue), tint 6(pastel*) | 모두 `AppColors` 재export — **자체 hex 없음 = 색값 drift 0**. light/dark는 Asset Catalog Dynamic Color 자동. |
| **Spacing** (8pt grid) | xs=4, sm=8, md=12, lg=16, xl=24, xxl=32 | |
| **Radius** | sm=12, md=16, lg=24 | |
| **Font** (Dynamic Type) | largeTitle/title/title2/title3/headline/body/callout/subheadline/caption/caption2 (10) | system Font 기반 = Dynamic Type 자동 |
| **Shadow** | sm(0.06,r4,y2) / md(0.08,r8,y4) / lg(0.12,r16,y8) + `.ds2Shadow(_:)` modifier | |

### 1.1 ⚠️ babycare-tokens.json과의 의도적 분기 (PO 결정 2026-06-09 = subset 명시)
DS2는 ROA 토큰 JSON의 **실용 8pt-grid subset**이며 통일하지 **않는다**(전역 교체+CLI 리스크 회피). **알려진 해저드**:
- **Radius `sm` 네이밍 충돌**: JSON `sm`=8 vs **DS2 `sm`=12**. (DS2는 12/16/24 3-step.)
- Spacing: DS2 `lg`=16 vs JSON `lg`=20. DS2는 JSON의 base16→lg16 rename + 20/40 drop.
- DS2.Color는 AppColors 일부 미노출: **`pumpingColor`(아래 §3 TODO)**, sageColor, indigoColor, healthColor, softPurpleColor. coral→danger / skyBlue→info rename.

## 2. 컴포넌트 인벤토리 (DS2Components.swift)

| 컴포넌트 | 사용 상태 |
|---|---|
| `DS2Button` (+ `DS2ButtonStyle`) | **LIVE** — ContentView onboarding(:351,355) |
| `DS2Card` / `DS2Section` / `DS2EmptyState` / `DS2ListRow` | **Preview-only** — DS2PreviewView showcase만 소비(product 사용 0). 향후 재사용 팔레트로 유지(Track A 결정: DS2PreviewView를 `#if DEBUG`로 가둬 출시 제외하되 컴포넌트 보존). |
| `HealthStyleFavoriteCard` (standalone) | **LIVE** — Dashboard 요약 카드(DashboardView+Shortcuts:174/188/201) |
| ~~`ActivityRingsCard`~~ | **삭제 예정**(orphan, 참조 0 — Track A Phase 1) |
| `DS2PreviewView` | Dev/Lab showcase(Settings 실험실). Track A에서 `#if DEBUG` 전환(출시 비노출). |

## 3. 사용 규칙

1. spacing/radius/color/font/shadow는 **반드시 `DS2.*` 토큰** 사용. 생 `CGFloat` 레이아웃 리터럴(`.padding(16)`, `cornerRadius: 12`) 금지.
2. **시스템 시맨틱 색은 의도적 비-토큰**(PO 결정 2026-06-09 = 유지): `Color(.systemGroupedBackground)` / `(.secondarySystemGroupedBackground)` / `(.systemGray5)`는 iOS가 light/dark/대비 자동 대응 — DS2가 일부러 모델하지 않음. `HealthStyleFavoriteCard:84`의 `secondarySystemGroupedBackground`는 Apple HIG 강제(inset-grouped 룩).
3. **Apple Health 스펙 고정 리터럴은 예외**: HealthStyleFavoriteCard의 5/3pt 마이크로 간격, 13/28/12pt 폰트, 84pt 카드높이는 Apple Health Favorites 스펙 핀 — 토큰화 금지(`// Apple Health spec` 주석).

## 4. 알려진 부채 / TODO (Track A)

- **`pumpingColor` #B56FD1**(유축, PR1에서 `babycare-tokens.json` + `Activity`에 추가)이 **`DS2.Color`에 미노출** → Track A Phase 3b에서 `DS2.Color.pumping` 추가(PR1 머지 후).
- DS2.swift 헤더 doc-comment의 "Preview / 폐기 가능" 표현 → 정본으로 교정됨(이 문서 §0).
- 거버넌스 가드: `arch_test.sh` Rule 4(designSystemV2Preview 9→0 래칫) + `BabyCareTests+DesignSystemV2.swift`(토큰값 단언 + 컴포넌트 render-smoke). `make design-verify`는 JSON만 검사(Swift 미스캔)라 Swift측은 arch-test가 가드.

## 5. 변경 이력

- 2026-06-09: Track A Phase 0 — DESIGN.md 신설 + Rule 4 가드 + DS2 테스트 (가드-먼저). 계획 = `docs/superpowers/specs/2026-06-09-track-a-ds2-cleanup.md`.
- 2026-06-08: DS2 정본 확정(PO git reset --hard, BCDS 폐기).
