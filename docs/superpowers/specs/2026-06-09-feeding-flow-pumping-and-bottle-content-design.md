# 기록 경험 고도화 — 유축 기록하기 통합 + 병수유 내용물(분유/모유)

- **작성일**: 2026-06-09
- **상태**: ✅ 설계 승인(PO) — 스펙 리뷰 후 구현
- **베이스**: `main` HEAD `0337714` (DS2 정본, 유축 Phase 1 머지 완료 #20/#21/#22). 로컬 버전 v2.8.6 빌드87(미커밋, TestFlight 업로드됨)
- **선행 스펙**: `2026-06-08-recording-pumping-design.md` (유축 Phase 1 = `.pumping` 카테고리 분리집계, QuickInputSheet 전용 경로). 본 스펙은 그 **후속 보강**.
- **트리거**: PO QA 중 발견 — ①유축이 "기록하기"(RecordingView)에 없어 "없는 기능"으로 보임(현재 홈 빠른기록 그리드 전용). ②유축한 모유를 병으로 먹인 **섭취**를 담을 타입이 없음(분유=formula, 모유수유=직수). 둘 다 PO 지적.

## 1. 목표 & 범위

**Phase 1 (이번 — 단독 PR, 빌드88):** 두 부분.
- **Part 1 — 유축을 기록하기(RecordingView) 수유 흐름에 노출**: 수유 하위선택(FeedingSubPicker)에 5번째 칩 '유축' 추가. (홈 빠른기록 그리드 진입점은 **유지** — 두 진입점.)
- **Part 2 — 병수유 내용물(분유/모유) 구분**: 분유(병)수유 폼에 [분유 / 유축한 모유] 토글. 유축한 모유 병수유 = **섭취**로 정확히 집계하되, "분유=formula"로 특정된 곳(분유재고 차감·병원리포트 분유량)에는 안 섞이게.

**불변(절대 규칙) — 선행 스펙 §2 계승:**
- 유축(`feedingPumping`) = **생산(짜낸 양)** → category `.pumping` → 섭취 18집계 자동배제. 절대 `.feeding` 금지.
- 병수유(분유 OR 모유)(`feedingBottle`) = **섭취(먹은 양)** → category `.feeding` → 섭취총량 포함(둘 다). 내용물(formula/breastMilk)은 **서술 하위속성**일 뿐 카테고리 불변.

**비범위(YAGNI / Phase 2):**
- 유축→보관(stash)→차감 **재고 잔량 연결**(생산·소비 balance). = 선행 스펙 §8 Phase 2.
- 좌우 개별 양(double pump) / pump 세션 수동 duration / 유축 anomaly.
- 병원리포트에 "모유(병) 양" 별도 줄(PO가 formula-only로 충분하다 확정 — §5.3). 추후 판단.

## 2. 입력 흐름

### Part 1 — 기록하기 유축
```
기록하기(RecordingView) → 상단 CategoryTabBar [수유/수면/배변/건강]  (← .pumping 탭 없음, 4-리터럴 유지)
  └ 수유 선택 → FeedingSubPicker (HStack→ViewThatFits)
      ┌─────┬─────┬─────┬─────┬─────┐
      │모유 │분유 │이유 │간식 │유축 │   ← 5번째 칩 신규, 보라(pumpingColor)
      │수유 │     │식   │     │     │
      └─────┴─────┴─────┴─────┴─────┘
  └ 유축 칩 선택 → FeedingRecordView(type: .feedingPumping)
      유축량 [ 120 ] ml   (+빠른채움)
      유축 방향 [왼][우][양]   (default 양쪽)
      온보딩 카피(선행 스펙 §9 동일 문구)
      [저장]  canSave: 양 > 0
```

### Part 2 — 병수유 내용물
```
  └ 분유 칩 선택 → FeedingRecordView(type: .feedingBottle)
      내용물 [ 분유 ] [ 유축한 모유 ]   ← 토글 신규, default 분유
      섭취량 [ 100 ] ml   (+빠른채움, 기존)
      [저장]
  → 저장 시: type=.feedingBottle(category .feeding=섭취), feedingContent=선택값
  → 분유든 모유든 섭취총량/예측에 정상 집계 (멘탈모델 안전: 둘 다 "먹은 양")
```
- 칩 라벨은 "분유" 유지(PO 승인 프리뷰 = "분유 폼 안에 토글"). 토글 라벨 "내용물: 분유 / 유축한 모유"로 자연스럽게. **저장 레코드의 표시는 내용물 인지**(타임라인 §5.4): breastMilk이면 "모유(병)".

## 3. 데이터 모델 (스키마 변경 최소)

### Part 1 — 변경 0
`.feedingPumping` / `.pumping` / amount / side 전부 선행 스펙(#20)에서 추가 완료. 기록하기 경로는 **기존 모델 재사용**.
- ⚠️ `applyTypeFields`의 `.feedingPumping` case(`ActivityViewModel+Save.swift:120-123`)는 현재 **dead**(유축이 QuickInputSheet 전용이라). 본 작업으로 **live화** — 이미 `activity.amount = Double(amount)` + `activity.side = selectedSide` 작성돼 있음(정확). **`isAmountValid` 가드 추가**(분유 parity, 0/무효 거부) + stale 주석 갱신.

### Part 2 — 신규 옵셔널 필드 1개
- `Activity.feedingContent: FeedingContent?` (옵셔널, Codable. 신규 필드라 마이그레이션 불필요).
- 신규 enum (`Activity` 내부, `BreastSide`/`FoodReaction` 패턴):
  ```swift
  enum FeedingContent: String, Codable, CaseIterable {
      case formula = "formula"          // 분유 (rawValue 영구계약)
      case breastMilk = "breast_milk"   // 유축한 모유
      var displayName: String { self == .formula ? "분유" : "모유" }  // exhaustive
  }
  ```
- **nil = 분유(formula)** 로 해석 (기존 feedingBottle 레코드 하위호환 — 전부 분유였음).
- `.feedingBottle`에서만 의미. 그 외 타입은 nil.
- **forward-compat 안전**: 신규 *옵셔널 필드*라 구버전 앱은 Codable에서 미지의 필드를 무시(레코드 drop 아님 — 선행 스펙 §4.2의 ActivityType rawValue drop 이슈와 무관). 구버전은 모유 병수유를 그냥 "분유"로 표시(열화 graceful).

## 4. 손대는 파일 (체크리스트)

**[Part 1 — 유축 기록하기]**
- `Views/Recording/RecordingComponents.swift` — `FeedingSubPicker`(`:70-114`):
  - `feedingTypes` 배열(`:74-79`)에 `(.feedingPumping, "유축", "drop.fill")` 추가(5번째).
  - **칩별 색**: 현재 `Color.pink` 하드코딩(`:102-105`) → per-type 색 helper. 수유류=`.pink`, `.feedingPumping`=`AppColors.pumpingColor`. selected/unselected 배경·전경 모두 해당 색 사용.
  - **a11y 레이아웃(5칸 잘림 방지)**: 단일 `HStack`(`:82`) → `ViewThatFits`로 (1순위) 5칸 가로 HStack, (fallback) 2줄 레이아웃. 11pt·`minimumScaleFactor(0.8)`(`:94-96`) 유지하되 큰 Dynamic Type에서 reflow. *(선행 스펙이 회피했던 a11y를 회피 아닌 해결.)*
- `Views/Recording/FeedingRecordView.swift`:
  - `accentColor`(`:27-35`)에 `.feedingPumping: AppColors.pumpingColor` 추가(default `.pink` 앞).
  - `canSave`(`:19-24`)에 `.feedingPumping` → `(Int(activityVM.amount) ?? 0) > 0` (분유와 동일).
  - 신규 `@ViewBuilder pumpingSection`(type==`.feedingPumping`): **유축량(ml)** TextField+`quickFillButtons` 재사용(라벨 "유축량") + **유축 방향** `SideButton` row(`breastSideSection:131-141` 패턴, 라벨 "유축 방향", `activityVM.selectedSide` 바인딩) + **온보딩 카피**(QuickInputSheet `:251` 동일 문구). body 섹션 스택(`:42-59`)에 삽입.
  - `onAppear`(`:62-73`): `.feedingPumping`은 직수 반대편 자동제안 대상 아님. 진입 시 `selectedSide = .both` 기본(QuickInputSheet 동형). (직수만 반대편 제안 유지.)
- `ViewModels/ActivityViewModel+Save.swift` — `.feedingPumping` case(`:120-123`)에 `isAmountValid` 가드 추가 + 주석 "미니시트 전용" → "빠른기록 + 기록하기 양 경로" 갱신.

**[Part 2 — 병수유 내용물]**
- `Models/Activity.swift` — `feedingContent: FeedingContent?` 필드(`amount:12`/`side:13` 인접) + `FeedingContent` enum(`BreastSide:141` 인접). displayName switch는 exhaustive(컴파일 강제 ✅).
- `Views/Recording/FeedingRecordView.swift` — `bottleAmountSection`(`:162-193`) 상단에 **내용물 토글** [분유/유축한 모유] 추가. `activityVM.selectedFeedingContent` 바인딩, default `.formula`.
- `ViewModels/ActivityViewModel.swift` (또는 +Save) — `selectedFeedingContent: Activity.FeedingContent = .formula` 상태 + `resetForm`(`+Save:249` 인접)에서 `.formula` 리셋.
- `ViewModels/ActivityViewModel+Save.swift` — `applyTypeFields` `.feedingBottle` case(`:78-86`)에 `activity.feedingContent = selectedFeedingContent` 추가.
- **분유 재고 차감 게이트** — 유축한 모유 병수유는 분유재고 차감 금지:
  - `ProductViewModel+CRUD.swift` `deductStockForActivity`(`:154`) 또는 호출처(`FeedingRecordView.save:232` + 기타 bottle 저장처)에서 `feedingContent == .breastMilk`이면 차감 skip. (구현: 호출처 게이트 또는 시그니처에 content 전달 — 구현 판단. 행동·테스트로 강제.)
- `Services/PDFReportService.swift` — "총 분유량"(`:194`) + "분유량(ml)"(`:223`) 합산을 **content in {formula, nil} 인 feedingBottle만**으로 필터. 모유 병수유는 분유량서 제외(섭취 횟수엔 잡힘).
- `Views/Components/ActivityRow.swift` — 타임라인 표시 라벨: feedingBottle + content==breastMilk → "모유(병)", 아니면 `type.displayName`("분유"). content-aware 표시 helper.

**[Part 2 — 일관성: 분유 입력 다른 진입점도 토글]** *(PO가 방금 겪은 "진입점 간 불일치"(유축이 그리드엔 있고 기록하기엔 없던) 재발 방지)*
- `Views/Dashboard/QuickInputSheet.swift` — bottle 입력 경로에 동일 내용물 토글 + save에 `feedingContent` 할당 + breastMilk 시 분유재고 미차감. (분유는 그리드 default-off지만 사용자가 켤 수 있음.)
- `Views/Dashboard/ActivityEditSheet.swift` — 기존 분유 레코드 편집 시 내용물 변경 가능(분유↔모유).

**[변경 없음]**
- `Services/QuickRecordSettings.swift` `defaultTypes`(`:9-13`) — 유축은 그리드 default-on 유지(이미 포함). 분유 default-off 유지.
- 섭취 18집계 사이트 — Part 1 유축은 `.pumping`이라 이미 배제, Part 2 병수유는 `.feedingBottle`이라 이미 포함. **무변경.**

## 5. 통계·정합 (잔물결 처리)

### 5.1 자동 격리/포함 (무변경 — 회귀 테스트로 박제)
- 유축(.pumping): `todayTotalMl`/`todayFeedingCount`/`nextFeedingEstimate`/`Preprocessor feedingAmountMl`·`feedingCount`/PDF 총분유량/`StatsViewModel.feedingActivities` **모두 배제** (선행 스펙 #20 회귀 테스트 유지).
- 병수유(분유 OR 모유, .feeding): 위 섭취집계에 **모두 포함** (둘 다 먹은 양).

### 5.2 분유 재고 (formula-specific)
- `categoryForActivity(.feedingBottle) = .formula`(`:136`). 차감은 content==formula(또는 nil)일 때만. 모유 병수유 → 분유재고 미차감.

### 5.3 병원리포트 PDF (formula-specific)
- "총 분유량"(`:194`)·"분유량(ml)"(`:223`)은 content in {formula, nil}만 합산 → "분유" = formula 정확 유지(의사 오판 방지).
- 모유 병수유의 섭취는 **수유 횟수 등 intake 지표엔 반영**되되 "분유량" 줄엔 미포함. (PO 확정: "모유(병) 양" 별도 줄은 Phase 1 보류.)

### 5.4 표시
- 타임라인 ActivityRow: feedingBottle+breastMilk → "모유(병) 100ml" / 그 외 → 기존 "분유 100ml".
- 유축 타임라인: 기존(보라 dot, "유축") 유지.

## 6. 검증 (TDD)

먼저 단위 테스트 → `make verify` green → 시뮬레이터 시각 확인.

**필수 단언:**
1. **유축 속성 회귀(#20 유지)**: `feedingPumping.needsAmount==true / .needsQuickInput==true / .needsTimer==false`.
2. **기록하기 유축 저장 라운드트립**: `saveActivity(type: .feedingPumping)` → category `.pumping`, **amount AND side** 영속. `isAmountValid` 0이면 저장 실패.
3. **유축 격리(회귀 유지)**: 유축 1건 후 `todayTotalMl`/`todayFeedingCount`/`nextFeedingEstimate`/`Preprocessor feedingAmountMl`·`feedingCount`/PDF 총분유량 **불변**.
4. **병수유(모유) 라운드트립**: `saveActivity(type: .feedingBottle)` + `selectedFeedingContent=.breastMilk` → category `.feeding`, `feedingContent==.breastMilk` 영속.
5. **병수유(모유)는 섭취 포함**: 모유 병수유 100ml 후 `todayTotalMl` **+100**(먹은 양으로 집계).
6. **병수유(모유)는 분유 미차감**: 모유 병수유 저장 시 formula 재고 차감 0.
7. **병수유(모유)는 분유량 제외**: PDF "총 분유량"/"분유량(ml)"에 모유 병수유 양 미포함.
8. **병수유(분유) 회귀**: content=.formula(또는 nil)는 분유재고 차감 + PDF 분유량 포함 + 섭취 포함 — 기존 동작 불변.
9. **canSave**: 유축 양 0 저장불가 / >0 가능.

**시각 검증:** 기록하기 수유 칩 5칸(유축=보라, ViewThatFits 큰글씨 reflow) / 유축 폼(양·방향·카피) / 분유 폼 내용물 토글 / 타임라인 "모유(병)"·"유축" 구분 / 다크모드 색 구분 / VoiceOver(유축 방향·내용물 토글 라벨).

## 7. 확정 결정 (PO)
- 유축 기록하기 노출 = **수유 칩에 별도 항목 추가**(토글로 묶기 아님 — 생산/섭취 멘탈모델 분리). 그리드 진입점 유지(두 진입점).
- 병수유 내용물 = **분유 폼 안 토글**(새 칩 아님). 둘 다 섭취.
- PDF 분유량 = **formula-only**(모유(병) 별도 줄 보류).

## 8. 출시
- 빌드87(유축=그리드 전용) **이후** 변경 → 다음 TestFlight = **v2.8.6 빌드88**. `make bump`(87→88) 가능(이번엔 정상 — 87이 로컬·소비 최대). 또는 수동 88.
- v2.8.6 train open, 88 > 87 > (만료된)86. App Store 미제출(TestFlight QA 단계).

## 9. 추적 follow-up (Phase 1 밖)
- 유축 stash 재고 연결(생산→보관→차감 balance) = Phase 2.
- 병원리포트 "모유(병) 양" 별도 줄.
- forward-compat unknown-tolerant decode(선행 스펙 §12, ActivityType rawValue drop) — 본 작업은 옵셔널 필드라 무관하나 별건 추적 유지.
