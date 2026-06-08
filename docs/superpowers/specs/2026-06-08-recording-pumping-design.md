# 기록 경험 고도화 — 유축(Pumping) 통합 설계

- **작성일**: 2026-06-08 (개정: 2026-06-08 코드 대조 검증 + PO 결정 확정)
- **상태**: ✅ **리뷰 완료 · 결정 확정 — Phase 1 구현 대기**
- **베이스**: `main` = DS2 디자인시스템 정본 (`5facce6`, v2.8.4 빌드84)
- **근거**: 홀리스틱 5렌즈 분석 + 통합 합성 + 적대적 검증(SHIP_WITH_CHANGES) — `tasks/w14rwyj0c`
- **검증**: 6에이전트 워크플로우가 스펙 전 주장을 실제 코드에 대조(`wf_af72bfdb-ca2`). 척추(§2 카테고리 격리·§5.3#1 위젯 빌드가드·§5.3#2 CSV 혼동·§3 단일 타이머)는 **VERIFIED**. 본문 오류 2건(§4 컴파일러 안전망 과장, §6 QuickInputSheet 오분류)은 아래에 교정 반영.

## 1. 목표 & 범위

육아기록 앱에 **유축(breast pumping/搾乳)** 기록을 추가한다. 단 단순 enum 추가가 아니라, 유축이 드러낸 **기록 시스템의 정보구조·통계 정합성**을 함께 교정하는 통합 작업이다.

**Phase 1 (이번 — 단독 PR):** 유축 기록 + `.pumping` 분리집계 + 유축량 차트 + 색/아이콘 + CSV·위젯·라벨 정합 + 온보딩 카피 + analytics + 회귀 테스트.

**Phase 2 (분리/후속):** 모유 재고(stash) 관리, 좌우 개별 양(double pump), 유축 인사이트, (옵션) pump 세션 수동 duration. *유축 anomaly Z-score는 모유량 불안 자극 리스크로 영구 보류 후보.*

**비범위(YAGNI):** 재고/유통기한, 좌우 개별 양 필드, pump-then-bottle 즉시연결(아래 §8), 동시 타이머 2개.

## 2. 핵심 아키텍처 결정 ⚠️ (VERIFIED)

> **유축은 절대 `ActivityCategory.feeding`에 넣지 않는다. 신규 `ActivityCategory.pumping`으로 분리한다.**

`ActivityType.category`는 단순 입력 탭이 아니라 **`category == .feeding` 18개 필터 사이트(11개 파일)의 도메인 버킷**이다(grep으로 정확히 18곳/11파일 확정). 유축(짜낸 양)을 `.feeding`에 매핑하면 한 줄로 컴파일은 통과하나 다음이 *silent* 오염된다:

- `todayTotalMl`(섭취량), `todayFeedingCount`(횟수) — `ActivityViewModel.swift:65,53`
- `deriveLatestActivities` lastFeeding → `nextFeedingEstimate`/NextFeedingWidget/알림 — `ActivityViewModel.swift:245,96`, `FeedingPredictionService.swift:36`
- **PDF/병원 리포트 총분유량** (의사 섭취량 오판 = 환자안전) — `PDFReportService.swift:89,194,469`
- StatsViewModel(:20)/PatternAnalysisService(:45,115)/InsightService(:143,146)/CalendarViewModel(:32,45)/FeedingInsightProvider(:9)/PatternReportViewModel(:114)

**의료 정합 가드의 진짜 위치 = `Preprocessor.swift:98`** (교정): `HospitalReportService.swift:68`은 직접 `.feeding` 필터가 아니라 **이미 집계된 `dailyAggregates.feedingCount`를 읽는다**. 병원 리포트가 보호되는 이유는 그 집계를 만드는 `Preprocessor.swift:98`(`dayActivities.filter { category == .feeding }` → `feedingAmountMl`/`feedingCount`)이 18개 필터 중 하나이기 때문. **회귀 테스트는 `HospitalReportService`가 아니라 `Preprocessor` 출력/`dailyAggregates`를 조준한다.**

`.pumping` 신규 카테고리로 매핑하면 위 18개 `== .feeding` 필터가 **자동으로 유축을 배제**(코드 무변경). exhaustive switch(아래 §4에서 한정됨)가 새 카테고리 누락을 컴파일 차단 → 통계 silent 버그를 구조적으로 봉쇄한다. (도메인 표준과도 일치: Huckleberry·Glow Baby·BabyTracker 모두 유축 *데이터*를 수유와 분리 — 웹 확인.)

> **타이머 보너스 가드(VERIFIED)**: `ActivityTimerManager.swift:39`는 `category == .feeding || type == .sleep`만 타이머·Live Activity 적격으로 본다. `.pumping`은 `.feeding`이 아니므로 유축이 feeding Live Activity를 잘못 띄우지 않는다 — "never map to .feeding"가 통계뿐 아니라 타이머에도 load-bearing.

## 3. 입력 흐름

**주 경로 = 대시보드 빠른기록 그리드 → QuickInputSheet 미니시트** (분유와 동형, 1탭→양 입력→저장):

```
┌──────────────────────────────┐
│ (drop.fill) 유축              │  pumpingColor 헤더 (보라/자두)
│ 기록 시간    오후 2:30  ▼     │  기존 시간조정 섹션 재사용
│ 유축량          [ 120 ] ml    │  bottleInput UI 패턴 참조
│ 방향   [왼쪽][오른쪽][양쪽]    │  BreastSide(L/R/B) 재사용
│ 메모(선택) ____   [취소][저장] │  canSave: amount > 0
└──────────────────────────────┘
```

- **`needsTimer = false`** (VERIFIED 정당): 유축은 양이 ground-truth라 타이머 불필요. 앱은 *전역 단일 타이머*(`ActivityViewModel.swift:48` = 단일 `ActivityTimerManager`)라 유축 타이머를 켜면 진행 중 수면 타이머를 강제 정지(`RecordingView.swift:243-252`)시킴 → false가 정답. (동시/세션 타이머는 Phase 2 — 모델에 `duration`/`endTime` 이미 있어 무마이그레이션 가능, "지금은 영구 미지원"이 아님.)
- **`needsQuickInput = true` / `needsAmount = true`** — ⚠️ **이 둘은 `default:` 보유 switch라 컴파일러가 강제하지 않는다(§4 참조). 수동 case 추가 + 단위 테스트 필수.**
- **풀폼(FeedingSubPicker 5칸 확장)은 보류**: 적대검증이 짚은 a11y 회귀(라벨 11pt·`minimumScaleFactor(0.8)`·XXXL truncate, 빌드61 선례) 회피. 미니시트 단일 경로로 충분. 발견성은 그리드 **기본 노출(default-on, PO 확정)** 로 확보.
- ⚠️ **side 플러밍은 신규 작업(교정)**: `QuickInputSheet`에는 현재 `side` 관련 `@State`·Picker·save 할당이 **전혀 없다**(temperature/medication/amount/note만). [왼쪽/오른쪽/양쪽] 토글은 "bottleInput 복제"가 아니라 **신규 `@State selectedSide` + Picker + `save()` 내 `activity.side = ...` 추가**. `BreastSide`(`Activity.swift:126-138`)·`Activity.side`(`:11`)는 존재하므로 모델은 지원함.

## 4. 데이터 모델 (스키마 변경 0)

- `ActivityType.feedingPumping = "feeding_pumping"` 추가 (rawValue = Firestore 영구 계약, 신규라 마이그레이션 불필요. 현재 11 케이스와 충돌 0 — grep 확인).
- `ActivityCategory`에 `case pumping` 추가 + displayName "유축" (`Activity.swift:140-151`, displayName switch는 exhaustive → 컴파일 강제 ✅).
- `ActivityType.category` switch(`:85-96`, exhaustive no-default ✅): `.feedingPumping → .pumping` (**절대 `.feeding` 금지**). 컴파일러가 누락 차단.
- 필드 **전부 재사용**: `amount`(생산 mL, `Double?` `:10`)·`side`·`startTime`. **신규 필드 0.**
- `amount` doc comment 보강: "feeding류 = 섭취 mL / feedingPumping = 생산 mL. 합산 시 type/category 필터 필수."

### 4.1 ⚠️ 컴파일러 안전망의 정확한 한계 (검증으로 교정 — 스펙 최대 위험)

스펙 초안의 "7개 계산 프로퍼티 모두 exhaustive → default 금지 규칙이 컴파일러 안전망"은 **사실 거짓**이다. `Activity.swift` 실측:

| 프로퍼티 | 줄 | default? | `.feedingPumping` 추가 시 |
|---|---|---|---|
| `displayName` | :43 | ❌ 없음 | ✅ **컴파일 강제** |
| `icon` | :59 | ❌ 없음 | ✅ **컴파일 강제** |
| `color` | :73 | ❌ 없음 | ✅ **컴파일 강제** |
| `category` | :85 | ❌ 없음 | ✅ **컴파일 강제** |
| `needsTimer` | :98 | ⚠️ `default: return false` | ❌ **조용히 false** (우연히 정답이라 더 위험) |
| `needsAmount` | :107 | ⚠️ `default: return false` | ❌ **조용히 false** (원하는 값=true → **버그**) |
| `needsQuickInput` | :116 | ⚠️ `default: return false` | ❌ **조용히 false** (원하는 값=true → **버그**) |

→ case만 추가하고 끝내면 **green build인데 `needsAmount`/`needsQuickInput`가 false** = 미니시트 양 입력칸·빠른기록 경로 자체가 작동 안 함(헤드라인 기능이 조용히 깨짐).

**필수 조치**: `needsTimer`/`needsAmount`/`needsQuickInput` 3개 switch의 `default:`를 **제거하여 exhaustive화**(그제야 스펙 thesis가 참이 됨, ~5줄) + §7 TDD에 `feedingPumping.needsAmount==true / .needsQuickInput==true / .needsTimer==false` **명시 단언**.

### 4.2 forward-compat 부채 (PO 결정: 수용 + 추적 follow-up)

`ActivityType`은 String enum + `FirestoreService.swift:10-19` `decodeDocuments`가 unknown raw를 `compactMap`으로 **whole-document silent drop**(catch→warning→nil, 삭제 아님). 미업데이트 구버전 앱(가족 공유 5~10명)은 유축 기록이 있는 날 **전체 활동을 조용히 미표시**(UI 신호 0). 릴리즈 노트는 업데이트 안 하는 사용자에게 도달 못함.

**결정**: Phase 1은 그대로 진행하되 "릴리즈 노트만"으로 끝내지 않는다 → **추적 태스크 신설**: `ActivityType` unknown-tolerant decode(`.unknown` fallback case를 중립 "지원 안 되는 기록" row로 렌더) fast-follow. (이번 스코프 밖, 추적 등록.)

## 5. 통계·정합 (적대검증 보강 + 교정 포함)

### 5.1 자동 격리 (무변경 + 회귀 테스트로 박제)
`.pumping` 매핑으로 18개 섭취 집계가 자동 배제. **회귀 테스트 필수**(모두 testable computed로 확인됨):
- 유축 1건 추가 후 `todayTotalMl`(`:64`) / `todayFeedingCount`(`:52`) / `nextFeedingEstimate`(`:96`) 불변
- **`Preprocessor` 출력 / `dailyAggregates.feedingCount`·`feedingAmountMl` 불변** (의료 정합 — `HospitalReportService:68` 아님, §2 교정)
- PDF `총 분유량`(`PDFReportService:194`) 불변
- `StatsViewModel.feedingActivities`(`:19`) 유축 제외
- `BadgeEvaluator.eventKind(.feedingPumping) == nil` (단 `@unknown default: return nil`로 이미 안전 — 컴파일 강제 아님, §6 참조)
- → 누가 향후 category를 `.feeding`으로 되돌리는 회귀 가드.

### 5.2 신규 유축 통계
- `StatsViewModel`에 `pumpingActivities`(filter `category == .pumping`) + `dailyPumpingAmounts` computed 추가(`feedingActivities`/`dailyFeedingAmounts` `:19-33` 패턴 동형). **count는 base computed에서 derive**(별도 3개 computed 분할 금지 — 적대검증).
- StatsView에 **"유축량" mL 차트 1개**(일별 총 mL, `pumpingColor`) + **empty-state 가드**(`dailyFeedingCounts.isEmpty` 패턴 `StatsView.swift:114` 복제 — 기본노출이라 유축 안 하는 다수에게 빈 섹션 방지: 데이터 0이면 차트 숨김).

### 5.3 적대검증이 잡은 누락 (반영 + 교정)
1. **[필수/VERIFIED] `ActivityViewModel+Reminders.swift:42`** — WidgetActivity `colorHex` switch는 진짜 exhaustive(`category` over, default 없음, 줄 정확) → `.pumping` case **미추가 시 빌드 실패**. **위젯 hex 명시(교정)**: 위젯 팔레트는 이미 asset 토큰과 drift(feeding `#FF9FB5`/sleep `#7B9FE8`/diaper `#85C1A3`/health `#F4845F`). 유축 위젯 hex = **새 `pumpingColor` asset과 동일한 보라/자두 hex로 박는다**(drift 추종 금지). 또한 **[필수로 격상] 위젯 최근활동 strip(`:36-56`, 필터 없음)에서 유축 제외**: `.filter { $0.type.category != .pumping }` — 완전유축모 strip 도배 방지.
2. **[필수/VERIFIED] `ExportService` CSV** — `날짜,시간,유형,상세,기간(분),양(ml),체온,메모`(`:9`)에서 `amount`를 무조건 기록(`:22,26`)해 생산/섭취 mL conflate. **확정: 유축량 별도 컬럼 `유축량(ml)` 추가**(섭취 `양(ml)`과 분리), 유축 row의 섭취 컬럼은 공란, 유형 컬럼에 '유축' 명시(빈 셀 오인 방지). **side 렌더 확인(추가)**: `detail` 컬럼은 `side.displayName`이 `medicationName`에 덮어쓰여짐(`:18-20`) — 유축 side가 깨지지 않고 표시되는지 확인.
3. **[삭제/교정] ~~StatsView "수유량" 라벨 정직화~~** — **전제가 틀림**: StatsView에 "수유량" 라벨은 **없다**. feeding 차트는 "수유"(`:110`)로 `dailyFeedingCounts`를 **횟수(회)** BarMark(`:121-129`)로 그림 — mL 아님. mL 정직성 이슈는 PDF(`총 분유량` `:194`)·CSV에만 있고 이미 §5.3#2/§2에서 처리됨. → **이 항목 삭제.** 대신 §5.2 유축량 mL 차트는 기존 "수유"(횟수) 차트와 단위 비대칭(횟수 vs mL)이나, 라벨이 명확하면 수용(둘은 다른 것을 측정). 향후 feeding-mL 차트 추가는 별도 판단.

## 6. 손대는 파일 (체크리스트 — 컴파일강제 여부 정확화)

**[강제 — 컴파일러가 누락 차단 (default 없는 exhaustive, VERIFIED)]**
- `Models/Activity.swift` — `ActivityType.feedingPumping` rawValue + `ActivityCategory.pumping` + `category` 매핑(`.pumping`) + `displayName`/`icon`/`color` 4개 exhaustive case + amount doc comment. ⚠️ **추가로 `needsTimer`/`needsAmount`/`needsQuickInput`의 `default:` 제거(§4.1) — 이건 컴파일러가 안 잡으니 반드시 수동.**
- `Views/Recording/RecordingComponents.swift` — `CategoryTabBar` 순회를 `ActivityCategory.allCases`(`:11`)에서 **`[.feeding,.sleep,.diaper,.health]` 4-리터럴 상수**로(프로토콜 추상화 금지·YAGNI) → `.pumping` 탭 자동노출 차단. `categoryIcon`(:44)/`categoryColor`(:53) exhaustive → `.pumping` case 컴파일 강제.
- `Views/Recording/RecordingView.swift` — `selectedCategory` exhaustive switch(`:271`)에 `.pumping` no-op/도달불가 처리(탭바가 4-리터럴이라 `.pumping`이 selectedCategory에 안 들어옴). 컴파일 만족용.
- `ViewModels/ActivityViewModel+Save.swift` — `applyTypeFields`(`:72` exhaustive ✅)에 `feedingPumping`(feedingBottle `:77-83` 패턴 복제, 타이머 미적용).
- `Views/Components/ActivityRow.swift` — `colorForType`(`:110` `category` over, exhaustive ✅) `.pumping → pumpingColor`.
- `ViewModels/ActivityViewModel+Reminders.swift` — WidgetActivity `colorHex`(`:42` exhaustive ✅) `.pumping` case (+ §5.3#1 recent strip 유축 필터, hex 명시).

**[필수 — 단 컴파일러 미차단 (default/if-chain 보유), 기능·정합·테스트로 강제 (교정)]**
- ⚠️ `Views/Dashboard/QuickInputSheet.swift` — **재분류**: 3개 type-switch(`canSave:35 default true`/`body:118 default EmptyView`/`save:239 default break`) 모두 default 보유 → case 누락해도 컴파일 통과·무동작. **수동 추가 필수**: `feedingPumping` canSave(amount>0)/body(pumpInput 섹션 = 양 TextField + **신규 side Picker**)/save(amount + **신규 `activity.side` 할당**). + save 라운드트립 테스트로 amount·side 영속 단언.
- `Utils/Constants.swift` + `Assets.xcassets` — **`pumpingColor` 보라/자두 토큰**(light/dark, `feedingColor` 구조 복제). ⚠️ 민트/청록 금지(§8 collision). `ActivityType.color`(`:73` exhaustive)가 `.feedingPumping`을 컴파일 강제하므로 토큰 누락 시 빌드 실패로 드러남.
- `ViewModels/StatsViewModel.swift` — `pumpingActivities` + `dailyPumpingAmounts` computed.
- `Views/Stats/StatsView.swift` — "유축량" mL 차트 + empty-state 가드(§5.2).
- `Services/ExportService.swift` — CSV `유축량(ml)` 컬럼 + 유형 '유축' + side 렌더 확인(§5.3#2).
- `Services/QuickRecordSettings.swift` — `defaultTypes`(`:9-13` 리터럴 배열)에 `feedingPumping` **append**(기본 노출, PO 확정. 참고: bottle은 현재 default OFF — "bottle 패턴"이 아니라 의도적 노출).
- `Services/BadgeEvaluator+Mapping.swift` — `.feedingPumping: return nil` **명시 권장**(현재 `@unknown default: return nil` `:15`로 이미 nil — 컴파일 강제 아님, 방어적 명시 + §5.1 회귀 테스트로 박제).
- `ViewModels/CalendarViewModel.swift` — `.insert(.activity(category))`(`:167,221` 무조건 insert, switch 아님)에 **`.pumping` 제외 가드 추가**: `where category != .pumping`(또는 insert 전 필터). 유축 dot은 의도적 미표시('생산'은 아기 일과 아님)이나, 가드 없으면 `.activity(.pumping)` **orphan Set 멤버**가 남아 향후 generic 소비자(legend/a11y/badge)로 누출 위험. (`CalendarView+Grid.swift:99-118`은 if-chain이라 컴파일 변경 불필요 — 스펙 "exhaustive면 컴파일 대응" 표현 삭제.)
- `BabyCareTests/` — §7 테스트.

## 7. 검증 (TDD)

먼저 단위 테스트 → `make verify` green → 시뮬레이터 스크린샷 시각 확인.

**필수 단언(검증 갭 메움)**:
1. **`feedingPumping.needsAmount==true` / `.needsQuickInput==true` / `.needsTimer==false`** — §4.1 silent-default 버그 유일 가드.
2. **유축 저장 라운드트립**: amount **AND `side`** 영속(QuickInputSheet side 신규 플러밍 가드).
3. **격리(§5.1)**: 유축 1건 후 `todayTotalMl`/`todayFeedingCount`/`nextFeedingEstimate`/`Preprocessor` `feedingAmountMl`·`feedingCount`/PDF 총분유량/`StatsViewModel.feedingActivities` 불변.
4. **CSV**: 유축 mL이 `유축량(ml)`에 들어가고 섭취 `양(ml)`은 공란.
5. **캘린더**: 유축이 dot 미생성 + eventDots에 orphan `.activity(.pumping)` 미잔존.
6. **유축량 차트 empty-state**: 유축 0건 시 차트 숨김/안전 렌더.

**시각 검증**: 미니시트 입력·타임라인 색 구분(보라/자두 vs 핑크/블루/오렌지/민트, 4pt dot·다크모드 구분성)·유축량 차트·위젯 strip 유축 제외. `drop.fill` iOS17 가용 빌드 확인(이미 코드 다수 사용 — `DiaperRecordView:21`/`FeedingRecordView:166`/`Badge:33` 등).

## 8. 확정된 결정 (PO)
- **색 = `pumpingColor` 보라/자두 계열(예: ~#B07FD9 검증 후 확정), 아이콘 = `drop.fill`** — **민트/청록 폐기(검증 collision)**: 민트는 `solidColor`/`healthColor` `#9FDFBF`(바이트 동일 민트그린)·`sageColor` `#85C1A3`(위젯 배변색)과 충돌, 둘 다 영양 인접이라 오독 고위험. 보라/자두는 팔레트 빈 영역(`medicationColor` 라벤더·`softPurpleColor #A078D4`·`indigoColor #7B9FE8`≈수면블루와 구분되게). 4pt dot·다크모드 구분성 검증 후 asset 확정. *(`drop.fill`은 이미 소변·섭취량 mL 의미로도 쓰여 의미 중복 저위험 — 타임라인 글리프는 `cup.and.saucer.fill` 분유와 구분되므로 수용.)*
- **그리드 기본 노출(default-on)** — 신규 헤드라인 기능 발견성 우선(PO 확정). 비용: 유축 안 하는 다수의 홈에 영구 카드(제거 가능). → analytics(§10)로 효과 측정 후 재조정 여지.
- **완전유축 pump-then-bottle 즉시연결 = Phase 2**: '짜서 바로 먹이기'(전자)와 '짜서 보관 후 나중에'(완전유축모 다수, 후자) 두 패턴이라 즉시연결은 전자에만 맞음 → 정확 해법은 재고관리(Phase 2)와 묶임. Phase 1은 온보딩 카피(§9)로 "먹인 양은 분유로 별도 기록" 안내.
- **double pump 좌우 개별 양 = Phase 2** (optional 필드 후일 add = 무마이그레이션).
- **(옵션) pump 세션 수동 duration = Phase 2** (모델에 duration/endTime 이미 존재).

## 9. 온보딩 카피 (HIGH 갭 — 초안 확정 필요)

완전유축 사용자가 "유축량이 왜 섭취총량/병원리포트에 안 잡히지" 혼란을 막는 **유일 장치**. 초안:

> **유축 기록은 '짜낸 양'이에요.** 아기가 실제로 먹은 양은 따로 **분유/모유 수유**로 기록해 주세요. 그래야 섭취량 통계와 병원 리포트가 정확해요.

- **노출 위치**: 첫 유축 기록 미니시트 하단 각주(1회) + 빈 상태(첫 진입). 최소 1회 노출 보장.
- **i18n(MED 갭)**: 신규 한글 문자열('유축'/'유축량'/'유축량(ml)'/카피)은 기존 1,631 하드코딩 관행 따르되, **CSV 헤더·의료리포트 라벨은 추출 가능하게** 작성. 일관 컨벤션 확정.
- **a11y(MED 갭)**: 미니시트 + 신규 BreastSide 세그먼트는 VoiceOver 라벨 + Dynamic Type XXXL + 보라/자두 텍스트/dot 다크모드 대비를 §7 시각검증에 포함(기록 진입점 a11y 회귀 이력 — 빌드61).

## 10. Analytics (HIGH 갭 — 신설)

유축은 feeding 도메인(임신 아님)이라 analytics 허용(safety.md). **최소 `pumping_recorded` 이벤트**(side, **coarse-bucket amount** — raw mL 금지로 민감정보 granularity 회피). 이게 있어야 PO가 §8 default-on 효과와 Phase 2 우선순위를 결정할 두 질문에 답함: (1) 사용자 몇 %가 유축하나, (2) 분유 별도기록을 병행하나.

## 11. 구현 범위 — 3개 PR 순차 분리 (PO 확정, 교정)

스펙 §9 초안의 "전부진행"을 **하나의 엉킨 변경**이 아니라 **독립 3 PR 순차**로 해석(PO 확정). 이유: Track A는 스펙 자인 회귀 리스크, Track C는 PO OAuth 외부 의존 → 묶으면 blast radius 대(유축 환자안전 기능이 막힘).

1. **PR 1 — 유축 Phase 1 (이 스펙)**: 가치 driver + 테스트 스토리 가장 깨끗(§7). **먼저 단독 머지·빌드.**
2. **PR 2 — Track A (DS2 부채 정리)**: `ActivityRingsCard` 141줄 orphan 삭제, dual-mode 14건·V1 dead 경로 제거, 토큰 우회 회수, 테스트/가드 신설. *주의: 정리 자체가 회귀 리스크 → 가드/arch-test를 삭제보다 먼저 깔고 저위험부터 점진.* (BCDS 백업 회수 가능.)
3. **PR 3 — Track C (Sentry 마무리)**: OAuth(PO 액션) → dSYM upload phase PR → 시뮬 첫 event 검증 → 빌드 bump. PO OAuth에 게이트되니 독립 cadence.

각 PR은 자체적으로 green 검증. v2.8.4 train closed → 출시 빌드는 bump 필수.

## 12. 추적 follow-up (Phase 1 밖, 등록만)
- **forward-compat unknown-tolerant decode**(§4.2): `ActivityType` `.unknown` fallback + 중립 row → 구버전 가족기기 silent drop 방지.
- **feeding-mL 차트**(§5.3#3): 유축량 mL 차트와 단위 대칭 위해 feeding도 mL 차트 추가 여부.
- **pump 세션 수동 duration / double pump / stash 관리**(§8, Phase 2).
