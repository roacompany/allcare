# 기록 경험 고도화 — 유축(Pumping) 통합 설계

- **작성일**: 2026-06-08
- **상태**: 설계 확정 (PO 리뷰 대기)
- **베이스**: `main` = DS2 디자인시스템 정본 (`5facce6`, v2.8.4 빌드84)
- **근거**: 홀리스틱 5렌즈 분석 + 통합 합성 + 적대적 검증(SHIP_WITH_CHANGES) — `tasks/w14rwyj0c`

## 1. 목표 & 범위

육아기록 앱에 **유축(breast pumping/搾乳)** 기록을 추가한다. 단 단순 enum 추가가 아니라, 유축이 드러낸 **기록 시스템의 정보구조·통계 정합성**을 함께 교정하는 통합 작업이다.

**Phase 1 (이번):** 유축 기록 + `.pumping` 분리집계 + 유축량 차트 + 색/아이콘 + CSV·위젯·라벨 정합 + 회귀 테스트.

**Phase 2 (분리/후속):** 모유 재고(stash) 관리, 좌우 개별 양(double pump), 유축 인사이트. *유축 anomaly Z-score는 모유량 불안 자극 리스크로 영구 보류 후보.*

**비범위(YAGNI):** 재고/유통기한, 좌우 개별 양 필드, pump-then-bottle 즉시연결(아래 §8), 동시 타이머 2개.

## 2. 핵심 아키텍처 결정 ⚠️

> **유축은 절대 `ActivityCategory.feeding`에 넣지 않는다. 신규 `ActivityCategory.pumping`으로 분리한다.**

`ActivityType.category`는 단순 입력 탭이 아니라 **`== .feeding` 18개 집계 사이트(11개 파일)의 도메인 버킷**이다(grep 확정). 유축(짜낸 양)을 `.feeding`에 매핑하면 한 줄로 컴파일은 통과하나 다음이 *silent* 오염된다:

- `todayTotalMl`(섭취량), `todayFeedingCount`(횟수) — `ActivityViewModel.swift:53,65`
- `deriveLatestActivities` lastFeeding → `nextFeedingEstimate`/NextFeedingWidget/알림 — `ActivityViewModel.swift:245`, `FeedingPredictionService.swift:36`
- **PDF/병원 리포트 총분유량** (의사 섭취량 오판 = 환자안전) — `PDFReportService.swift:89,469`, `HospitalReportService.swift:68`, `Preprocessor:98`
- StatsViewModel/PatternAnalysis/InsightService/CalendarViewModel/FeedingInsightProvider 등

`.pumping` 신규 카테고리로 매핑하면 위 18개 `== .feeding` 필터가 **자동으로 유축을 배제**(코드 무변경). exhaustive switch가 새 카테고리 누락을 **컴파일 차단** → 통계 silent 버그를 구조적으로 봉쇄한다. (도메인 표준과도 일치: Huckleberry·BabyTracker·Glow 모두 유축을 수유와 분리.)

## 3. 입력 흐름

**주 경로 = 대시보드 빠른기록 그리드 → QuickInputSheet 미니시트** (분유와 완전 동형, 1탭→양 입력→저장):

```
┌──────────────────────────────┐
│ (drop.fill) 유축              │  pumpingColor 헤더
│ 기록 시간    오후 2:30  ▼     │  기존 시간조정 섹션 재사용
│ 유축량          [ 120 ] ml    │  bottleInput 패턴 복제
│ 방향   [왼쪽][오른쪽][양쪽]    │  BreastSide(L/R/B) 재사용
│ 메모(선택) ____   [취소][저장] │  canSave: amount > 0
└──────────────────────────────┘
```

- **`needsTimer = false`**: 유축은 양이 ground-truth라 타이머 불필요. 앱은 *전역 단일 타이머*(`ActivityViewModel.swift:48`)라 유축 타이머를 켜면 진행 중 수면 타이머를 강제 정지(`RecordingView.swift:244`)시킴 → false가 정답. (동시 타이머는 Phase 2.)
- **`needsQuickInput = true` / `needsAmount = true`**.
- **풀폼(FeedingSubPicker 5칸 확장)은 보류**: 적대검증이 짚은 a11y 회귀(라벨 11pt·`minimumScaleFactor(0.8)`·XXXL truncate, 빌드61 선례) 회피. 미니시트 단일 경로로 충분. 발견성은 그리드 **기본 노출(default-on)** 로 확보(PO 결정).

## 4. 데이터 모델 (스키마 변경 0)

- `ActivityType.feedingPumping = "feeding_pumping"` 추가 (rawValue = Firestore 영구 계약, 신규라 마이그레이션 불필요).
- `ActivityCategory`에 `case pumping` 추가 + displayName "유축".
- `category` switch: `.feedingPumping → .pumping` (**절대 `.feeding` 금지**).
- 필드 **전부 재사용**: `amount`(생산 mL)·`side`·`startTime`. **신규 필드 0.**
- `amount` doc comment 보강: "feeding류 = 섭취 mL / feedingPumping = 생산 mL. 합산 시 type/category 필터 필수."
- 7개 exhaustive 계산 프로퍼티(displayName/icon/color/category/needsTimer/needsAmount/needsQuickInput)에 case 추가 — default 금지 규칙이 컴파일러 안전망.
- **권장값**: icon `drop.fill`(iOS17 확실, 분유 cup과 구분), color 신규 `pumpingColor`(민트/청록 — feedingColor 핑크와 구분), needsAmount=true, needsTimer=false, needsQuickInput=true.
- **forward-compat 부채**: `ActivityType`은 non-failable String enum + `FirestoreService.swift:11-20` decode가 unknown raw를 silent drop → 미업데이트 구버전 앱(가족 공유)은 유축 기록을 조용히 미표시(삭제 아님). 릴리즈 노트로 안내, unknown-tolerant decode 전환은 범위 밖.

## 5. 통계·정합 (적대검증 보강 포함)

### 5.1 자동 격리 (무변경 + 회귀 테스트로 박제)
`.pumping` 매핑으로 18개 섭취 집계가 자동 배제. **회귀 테스트 필수**:
- 유축 1건 추가 후 `todayTotalMl` / `todayFeedingCount` / `nextFeedingEstimate` 불변
- PDFReport / Preprocessor 총분유량 불변 (의료 정합)
- `StatsViewModel.feedingActivities` 유축 제외
- `BadgeEvaluator.eventKind(.feedingPumping) == nil`
- → 누가 향후 category를 `.feeding`으로 되돌리는 회귀 가드.

### 5.2 신규 유축 통계
- `StatsViewModel`에 `dailyPumpingAmounts` computed 추가(`category == .pumping`). count는 derive(computed 3개 분할 금지 — 적대검증).
- StatsView에 "유축량" 차트 1개(일별 총 mL, `pumpingColor`).

### 5.3 적대검증이 잡은 누락 3건 (반드시 반영)
1. **[필수] `ActivityViewModel+Reminders.swift:42`** — WidgetActivity `colorHex` switch는 exhaustive(default 없음) → `.pumping` case 필수(미추가 시 **빌드 실패**). 동시에 **위젯 최근활동 strip에서 유축 노출 여부**: 완전유축모 도배 방지 위해 `.filter { $0.type.category != .pumping }` 적용(권장).
2. **[필수] `ExportService` CSV** — `양(ml)` 단일 컬럼이 생산/섭취 mL을 conflate. **확정: 유축량 별도 컬럼 `유축량(ml)` 추가**(섭취 `양(ml)`과 분리) → 의료/공유 산출물에서 섭취≠생산 명확 구분. 유축 row의 섭취 컬럼은 공란.
3. **[권장] StatsView "수유량" 라벨 정직화** — 기존 "수유량"은 실제 *분유 섭취 mL*(모유수유는 amount nil로 제외). 신규 "유축량"과 병치되면 혼란 → `PDFReportService:194`의 '총 분유량' 선례 따라 라벨 명확화.

## 6. 손대는 파일 (체크리스트)

**[강제 — 컴파일러가 누락 차단]**
- `Models/Activity.swift` — `ActivityType.feedingPumping` + `ActivityCategory.pumping` + category 매핑(`.pumping`) + 7 exhaustive switch + amount doc comment
- `Views/Recording/RecordingComponents.swift` — `CategoryTabBar` 순회를 `[.feeding,.sleep,.diaper,.health]` 리터럴 상수로(프로토콜 추상화 금지·YAGNI) → `.pumping` 탭 자동노출 차단. categoryIcon/categoryColor `.pumping` case
- `Views/Recording/RecordingView.swift` — `ActivityCategory` over하는 exhaustive switch에 `.pumping` 대응. **유축은 풀폼 미진입**(§3 보류)이므로 `.pumping`은 선택 탭이 될 수 없는 no-op/도달불가 처리(탭바가 4-리터럴이라 selectedCategory에 `.pumping`이 안 들어옴). 컴파일 만족용.
- `Views/Dashboard/QuickInputSheet.swift` — canSave/body/save switch에 `feedingPumping`(pumpInput 섹션 = bottleInput 복제 + side 토글)
- `ViewModels/ActivityViewModel+Save.swift` — `applyTypeFields`에 `feedingPumping`(feedingBottle 패턴 복제, 타이머 미적용)
- `Views/Components/ActivityRow.swift` — `colorForType` switch `.pumping → pumpingColor`
- `ViewModels/ActivityViewModel+Reminders.swift` — WidgetActivity colorHex `.pumping` case (+ recent strip 유축 필터)

**[비-컴파일강제 — 단 ExportService·StatsView·QuickRecordSettings·테스트는 기능/정합상 필수]**
- `Utils/Constants.swift` + `Assets.xcassets` — `pumpingColor` 토큰 + colorset(light/dark, feedingColor 구조 복제)
- `ViewModels/StatsViewModel.swift` — `dailyPumpingAmounts` computed
- `Views/Stats/StatsView.swift` — "유축량" 차트 + "수유량" 라벨 정직화
- `Services/ExportService.swift` — CSV 컬럼 정합
- `Services/QuickRecordSettings.swift` — `defaultTypes`에 `feedingPumping` **포함**(기본 노출, PO 결정)
- `Services/BadgeEvaluator+Mapping.swift` — `.feedingPumping: return nil` 명시(배지 제외, default 의존 금지)
- `Views/Calendar/CalendarView+Grid.swift` — 유축 dot 의도적 미추가('생산'은 아기 일과 아님). CalendarViewModel이 category exhaustive면 컴파일 대응만.
- `BabyCareTests/` — §5.1 회귀 테스트 + 유축 저장 라운드트립

## 7. 검증
TDD: 유축 저장 라운드트립 + 통계 분리 단위테스트(§5.1) 먼저 → `make verify` green → 시뮬레이터 스크린샷으로 유축 입력 미니시트·타임라인 색 구분·유축량 차트 시각 확인. `drop.fill` SF Symbol iOS17 가용성 빌드 확인.

## 8. 확정된 결정 (PO)
- **완전유축 pump-then-bottle 즉시연결 = Phase 2** (PO "뭐가 합리적이에요?" → 판단 위임). 이유: 유축엔 '짜서 바로 먹이기'와 '짜서 보관 후 나중에 먹이기'(완전유축모 다수) 두 패턴이 있어, 즉시연결은 전자에만 맞고 후자엔 틀림 → 정확한 해법은 재고관리(Phase 2)와 묶여야 함. Phase 1은 "먹인 양은 분유로 별도 기록" 온보딩 카피로 안내.
- **그리드 기본 노출(default-on)** — 신규 헤드라인 기능 발견성 우선.
- **double pump 좌우 개별 양 = Phase 2** — 지금 스키마에 미사용 optional 필드를 넣지 않음(후일 optional add = 무마이그레이션).
- **색 = `pumpingColor`(민트/청록), 아이콘 = `drop.fill`** — 핑크 수유와 시각 구분, iOS17 확실.

## 9. 다른 트랙 (병렬, 이 스펙과 별개)
PO "전부진행" 지시에 따라 구현 계획에 함께 포함:
- **Track A — DS2 부채 정리**: ActivityRingsCard 141줄 orphan 삭제, dual-mode 플래그 14건·V1 dead 경로 제거, 토큰 우회 회수, 테스트/가드 신설(BCDS 백업 회수 가능). *주의: 정리 자체가 회귀 리스크 → 저위험부터 점진.*
- **Track C — Sentry 마무리**: OAuth(PO 액션) → dSYM upload phase PR → 시뮬 첫 event 검증 → 빌드 bump.
