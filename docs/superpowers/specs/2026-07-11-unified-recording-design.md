# 통합 기록 재설계 (Unified Recording) — 설계 문서

- **날짜**: 2026-07-11
- **브랜치**: `feat/unified-recording`
- **상태**: 설계 확정 (PO 승인 · "통합 재설계 먼저, 출시는 그다음")
- **범위**: 육아 기록(비임신) 기록하기 상호작용·UI·저장 코드의 전면 통합. 데이터 스키마 변경 없음.

---

## 1. 문제 (Problem)

"기록하기"가 사실상 **3개의 따로 노는 시스템**으로 쪼개져 있고, 그 위에 기능만 계속 얹혀 산만하다. (PO 확인: "전반적으로 다 산만 / 연속 기록이 안 됨 / 같은 걸 어디서 누르냐에 따라 달라짐 / 찾기·고르기 번거로움 / 카테고리 정렬·UI 안 맞음")

코드 실측으로 확인된 근거:

1. **경로 3개, 규칙 제각각**
   - 홈 '빠른 기록' 그리드 → 원탭 즉시저장(또는 `QuickInputSheet` 미니시트)
   - '기록하기'(+) 탭 → `RecordingView` 풀폼(카테고리 탭 → 서브타입 → 폼 → 저장)
   - 첫 기록 가이드 카드 → 또 다른 3버튼
   - **같은 `모유수유`가 홈 그리드에선 무입력 즉시저장(방향 `.left` 강제), 기록하기 탭에선 타이머+방향 풀폼.** 위치에 따라 결과가 다르다.

2. **서브타입 선택 UI가 3종**
   - 수유 = 칩 한 줄(폼 위, `FeedingSubPicker`) / 기저귀 = 큰 카드(폼 안, `DiaperTypeCard`) / 건강 = 세그먼트(폼 안). 한 개념(서브타입 고르기)에 3가지 인터랙션.

3. **저장 경험 제각각**
   - 저장 버튼: 수유·수면·건강 = 공용 `SaveButton`("저장") / 기저귀 = 인라인 복붙 버튼("바로 저장") / 미니시트 = 툴바 "저장". 라벨·코드 3종.
   - 풀폼은 저장 성공 시 **1.5초 뒤 시트 전체가 닫힘**(`RecordingView.handleSaved` → `isPresented = false`). 연속 기록(수유→기저귀→수면)이 기본인데 매번 다시 열어야 한다.

4. **저장 경로 3개 — 신뢰성 비대칭(숨은 데이터 유실)**
   - `performSaveActivity`(풀폼): 중복검출 + 실패 시 **오프라인 큐** 폴백.
   - `quickSave`(홈 그리드) / `savePrebuiltActivity`(미니시트): 중복검출 없음 + **오프라인 큐 없음** → 오프라인이면 롤백 후 유실.
   - Activity 구성 로직도 3벌(`performSaveActivity.applyTypeFields` / `QuickInputSheet.buildActivity` / `quickSave` 인라인).

5. **탭 이름 혼동** — `기록`(캘린더 조회)과 `기록하기`(+추가)가 거의 같은 단어.

6. **코드가 혼란을 그대로 반영** — `CategoryTabBar` 주석은 "유축은 풀폼 탭바 미노출"이라 하지만 실제로 `FeedingSubPicker`엔 유축이 5번째 칩으로 존재. 주석끼리 모순.

---

## 2. 목표 / 비목표

### 목표 (Goals)

- **G1. 하나의 규칙**: 어디서 누르든 같은 타입은 항상 같은 동작. 탭 비용은 '위치'가 아니라 '입력에 필요한 정보량'으로만 결정.
- **G2. 통합 기록 시트 1개**: 서브타입 칩 · 시간 편집기 · 저장 버튼을 단일 패턴으로 통일. 폼 4종 + 미니시트를 한 컴포넌트로 수렴.
- **G3. 연속 기록**: 저장 후 강제 시트 닫힘 폐기 → 원래 화면으로 복귀 + 타임라인 즉시 반영 + **되돌리기(Undo)** 스낵바. 다음 기록도 1탭.
- **G4. 단일 저장 파이프라인**: 오프라인 큐 · 중복검출 · 배지 · 리마인더 · 온도 트렌드 · 위젯 동기화 · 재고 차감 · 애널리틱스를 **전 진입점 일관**. quick/mini의 오프라인 유실 비대칭 제거.
- **G5. 진입·네이밍 정리**: 홈 그리드 + ＋런처(어느 탭에서든)를 동일 규칙으로. 기본 빠른기록 세트를 실사용 빈도대로 재정렬. 캘린더 탭 리네임.

### 비목표 (Non-goals)

- **Firestore 스키마/마이그레이션 변경 없음.** 기존 기록 100% 보존.
- **`Activity.ActivityType` 등 enum raw value 변경 없음** (Firestore 영구 계약).
- **GA4 이벤트 이름·`category` rawValue 변경 없음** (분석 계약 보존).
- **임신 기록 재설계 아님.** `.pregnancyOnly` / `.both` additive 임신 섹션 동작은 **보존**(별도 트랙).
- **새 기능 추가 아님.** 배지/위젯/인사이트/재고/앱평가 트리거 등은 동작 보존.
- 기록 항목 삭제 시 사진 purge, 오프라인 삭제 등은 별도 백로그(이 재설계 범위 밖).

---

## 3. 설계 (Design)

### 3.1 하나의 규칙 — `RecordEntryRule` (순수 정책)

```
enum RecordEntryMode { case instant, detail }
enum RecordEntryRule { static func mode(for: Activity.ActivityType) -> RecordEntryMode }
```

기본 매핑:

| 모드 | 동작 | 타입 |
|---|---|---|
| **.instant** | 그 자리서 즉시 저장 + 햅틱 + 되돌리기 스낵바 (화면 유지) | `diaperWet` · `diaperDirty` · `diaperBoth` · `bath` · `feedingSnack` |
| **.detail** | 통합 기록 시트가 그 타입으로 열림 (직전값 프리필) | `feedingBreast` · `feedingBottle` · `feedingPumping` · `feedingSolid` · `sleep` · `temperature` · `medication` |

- 이 규칙이 **홈 그리드 · ＋런처 · 첫기록 가이드 · FloatingTimerBanner** 전부에서 동일 적용 → "위치에 따라 다름" 제거.
- 매핑이 **한 정책 파일에 집중**돼 튜닝 쉬움(추후 사용자 커스텀 여지).
- **의식적 트레이드오프**: 대변 stool 상세(색/농도/발진)와 간식 음식명은 `.instant`라 저장 시점 입력 폼이 없다 → 필요 시 **타임라인 항목 탭 → 편집**(기존 기능)으로 추가. 근거: 기저귀·간식은 최고빈도 "그냥 발생" 이벤트라 속도 우선. (현행 홈 그리드도 이미 이 타입들을 즉시저장 → quick 경로 대비 무회귀, 풀폼 대비 의식적 단순화. PO 검토 항목으로 표기.)
- `feedingBreast`는 현행 홈 그리드에서 방향 `.left` 강제 즉시저장(데이터 품질 나쁨) → `.detail`로 승격하되 시트에서 "그냥 저장"이 1탭이라 부담 없음(방향은 직전 반대편 프리필).

### 3.2 타입 우선(type-first) — 서브타입 드릴다운 제거

**핵심 결정: "카테고리 탭 → 서브타입 선택 → 폼" 2단 드릴다운을 없앤다.** 그리드/런처의 각 타일이 **구체적인 타입 그 자체**(모유수유·분유·이유식·간식·유축·수면·소변·대변·소변+대변·체온·투약·목욕)이고, 카테고리(수유/기저귀/건강)는 **그리드의 시각적 정렬·색상 섹션**으로만 존재(인터랙션 레이어 아님).

- 타일 탭 → `RecordEntryRule` 분기(instant 즉시저장 / detail 통합 시트).
- **서브타입 칩·카드·세그먼트가 전부 사라진다** → "서브타입 UI 3종 제각각" 문제가 원천 제거. 폼 안에서 서브타입을 다시 고를 일이 없다(이미 타일에서 고름).
- "찾기·고르기 번거로움" 해소: 원하는 기록이 그리드에서 1탭 = 정확히 그것.

### 3.3 통합 기록 시트 — `UnifiedRecordSheet` (단일 타입)

`.detail` 타입 하나를 한 컴포넌트가 렌더. 서브타입 스위처 없음. 상단→하단:

1. **헤더**: 아이콘 + 타입명
2. **시간 편집기** — `RecordTimeEditor`(단일 컴포넌트): 접이식 + `지금 / 5분 전 / 15분 전 / 30분 전` 칩 + `DatePicker`. 풀폼의 `TimeAdjustmentSection`과 미니시트의 시간 섹션을 하나로 통일.
3. **타입별 본문 조각**(기존 재사용, 시트 셸에 플러그인): `TimerView` · `BreastSideSection` · `BottleAmountSection`(+quickFill) · `PumpingSection` · `SolidFoodSection` · `TemperatureSection` · `MedicationSection`(최근 투약) · `SleepQualitySection` · `SleepMethodSection` · `NoteField`.
4. **저장 버튼** — 공용 `SaveButton` 하나("저장"). "바로 저장" 인라인 버튼 제거.

- `presentationDetents`: 타입에 맞게(단순=medium, 타이머류=large) — 시트가 타입으로 판정.
- 임신 `.both` additive 임신 섹션: 통합 시트에는 미포함(육아 전용). 임신 기록 진입은 기존 `.pregnancyOnly` 경로/카드 유지(비목표).
- (선택·MVP 밖) 헤더 타입명 탭으로 인접 타입 전환 — 후속 여지로만 남김.

### 3.4 연속 기록 (Continuous logging)

- **.detail 저장 성공** → 시트 dismiss → 원래 컨텍스트(홈/＋런처 호출 위치) 복귀 → `todayActivities` 낙관 반영으로 타임라인에 즉시 표시 → `InfoToastCenter` "저장됨 · **되돌리기**" 스낵바(N초). **강제 1.5초 후 close 로직 폐기.**
- **.instant 저장** → 화면 유지 + 동일 되돌리기 스낵바.
- **Undo** = 방금 저장한 activity를 `deleteActivity`(기존 메서드)로 제거. 스낵바 만료 시 확정.
- 다음 기록: 홈 그리드/＋런처가 그대로라 1탭. → "연속 기록 안 됨" 해소. (오늘 추가된 '이어서 기록' 토스트 #71은 이 구조로 대체/흡수.)

### 3.5 진입점 — 전부 같은 규칙

모든 진입점의 타일은 **타입 우선**(§3.2): 카테고리별 시각 섹션·색상으로 정렬하되 각 타일 = 구체 타입.

1. **홈 '빠른 기록' 그리드** — `QuickRecordSettings.enabledTypes`(커스터마이즈, 사용자가 쓰는 타입 subset). 타일 탭 → `RecordEntryRule` 분기.
2. **가운데 ＋ '기록하기'** — `RecordLauncherSheet`(전체 타입 그리드 바텀시트). 어느 탭에서든 호출. 타일 탭 → 동일 `RecordEntryRule` 분기(instant는 런처 안에서 저장 후 닫힘, detail은 통합 시트로).
3. **첫 기록 가이드 카드** — 3버튼이 동일 규칙 경유(기존 `quickSave` 직접 호출 → 공용 경로로).
4. **FloatingTimerBanner** — 진행 타이머 타입의 통합 시트로.

### 3.6 단일 저장 파이프라인 — `ActivityDraft` + `commit`

- **`ActivityDraft`**(순수 struct): `babyId`, `type`, 시간(`startTime`/`endTime`/`manualAdjusted`/`timerDuration`), 타입별 값(`side`, `amount`, `feedingContent`, `foodName`, `foodAmount`, `foodReaction`, `temperature`, `medicationName`, `medicationDosage`, `sleepQuality`, `sleepMethod`, `stoolColor`, `stoolConsistency`, `hasRash`, `note`).
- **`ActivityDraftBuilder.build(_ draft) -> Result<Activity, RecordValidationError>`**(순수, `nonisolated static`): 현행 `applyTypeFields` + `validate`(수유/유축 1~500ml, 체온 34~43°C, 최소 1초, 수면 <24h) + 시간/타이머 우선순위 로직을 이관. **TDD 잠금.**
- **`ActivityViewModel.commit(draft:userId:currentUserId:)`**:
  1. `.unknown` 가드
  2. 중복검출(`hasDuplicateRecord`) → 필요 시 확인 다이얼로그(**전 경로 적용**)
  3. `ActivityDraftBuilder.build` → 실패 시 `errorMessage`
  4. `createdBy = currentUserId`, 낙관적 `todayActivities.insert`
  5. `firestoreService.saveActivity` → 성공 시 부수효과(`deriveLatestActivities` · `scheduleActivityReminderIfNeeded` · 온도 트렌드 · `evaluateBadgesIfNeeded` + 앱평가 마일스톤 · 위젯 동기화)
  6. 실패 시 **오프라인 큐 폴백**(`enqueueOfflineActivity`) + `InfoToastCenter.offlineSaved` — **전 경로 일관**(quick/mini 유실 비대칭 제거)
- 기존 `saveActivity`/`performSaveActivity`/`savePrebuiltActivity`/`quickSave` → `commit(draft:)` 위임으로 수렴. 호출부(4 record view + DiaperRecordView + DashboardView+Actions + QuickInputSheet)를 draft 구성으로 마이그레이션.
- **재고 차감**(`deductStockForActivity`)·`ProductPickerSheet`: 현재 View에서 호출 → 저장 성공 콜백으로 통일(모유 병수유는 분유 재고 미차감 분기 보존).
- **애널리틱스**: 저장 성공 후 발화. 타입/카테고리 rawValue 계약 보존(`record_save`·`dashboard_quick_record`·`feed_record_save`·`diaper_record_save`·`sleep_record_save`·`pumping_recorded`). 이벤트 발화 위치를 `commit` 성공 분기로 일원화하되 **이벤트 이름·파라미터 불변**.

### 3.7 내비게이션·네이밍

- 탭: `홈 | ` **`캘린더`** ` | ＋기록하기 | 건강 | 설정` (`기록` → `캘린더`로 리네임, `기록하기`와 혼동 제거). `AnalyticsScreens.calendar` 등 스크린 트래킹 이름은 내부 상수라 변경 불필요(라벨만).
- 기본 빠른기록 세트 재정렬: 야간 고빈도(모유수유·분유·수면·기저귀 소변/대변·체온) 우선, 저빈도(간식·유축) 뒤. `QuickRecordSettings.defaultTypes` 수정.

---

## 4. 제약·불변 준수

- Firestore 마이그레이션 0, enum raw value 불변, GA4 이벤트 계약 불변.
- arch `R1`(View→Service 직접 호출 금지: 재고차감·저장 전부 VM 경유) · `R3`(`Firestore.firestore()` 직접 호출 금지) 유지. **신규 컬렉션 없음 → Narrow Protocol 불필요.**
- `NavigationStack` 중첩 금지(통합 시트는 sheet 루트에서 단일 스택).
- `@AppStorage`에 사용자/임신 데이터 금지(해당 없음; `quickRecordEnabledTypes`·`lastSleepMethod`는 기기 로컬 설정이라 허용).
- `print()` 금지 → `AppLogger.<category>` / `logSilent`.
- 임신 `.pregnancyOnly` / `.both` additive 동작 보존.
- 테스트 append는 **첫 `BabyCareTests` 클래스 내부** (또는 도메인 분리 선례 파일). RED에서 실행 수 확인(vacuous pass 방지).
- 빌드번호 = ASC ground-truth(현 최고 99). 출시는 이 재설계 완료 후 별도 bump.

---

## 5. 엣지·회귀 주의

- 타이머 실행 중 타입 전환/시트 닫기 → 저장/폐기 확인 다이얼로그(기존 로직 이관).
- 수동 시간조정이 타이머보다 우선(현행 `applyManualTimeAdjustment` 순서 보존).
- 중복 경고 다이얼로그 **전 경로** 적용(현재 풀폼만).
- 오프라인 큐 **전 경로** 폴백(현재 풀폼만) — quick/mini 유실 fix.
- `.unknown` 센티넬: 저장/편집 진입 차단 가드 보존.
- 가족 공유: `userId = babyVM.dataUserId(currentUserId:)` owner-path, 배지는 `currentUserId` path.
- 재고 차감 후보 시트(`ProductPickerSheet`) 흐름 + 모유 병수유 미차감 분기 보존.
- 유축 온보딩 카피("짜낸 양…") 보존.
- 첫기록 가이드(#53)·D1 복귀 넛지(#54)와 정합(저장 경로 일원화에 편승).
- `FloatingTimerBanner` 재진입 경로 보존.

---

## 6. 테스트 전략

- **순수 로직 TDD**:
  - `ActivityDraftBuilder`: 타입별 필드 매핑 + 검증 경계(1~500ml, 34~43°C, 1초, 24h) + 시간/타이머/수동조정 우선순위.
  - `RecordEntryRule`: 타입 → 모드 매핑(instant/detail) exhaustive.
  - `hasDuplicateRecord`: 근접 시간 동일 타입.
- **VM 동작**: `commit` 성공 / 오프라인 폴백(큐 적재) / 실패 롤백 / 배지·재고 훅 / Undo 삭제.
- **회귀 동치**: 기존 저장 결과 필드 동일 + analytics 이벤트 발화 + 가족공유 path.
- 각 단계 `make verify` ALL CHECKS PASSED + arch R1–4=0 유지.

---

## 7. 단계 (Phases) — 각 단계 독립 `make verify` green

- **P0. 파이프라인 통일 (UX 불변)**: `ActivityDraft` + `ActivityDraftBuilder`(TDD) + `commit(draft:)`. 기존 4경로를 draft 구성 → `commit` 위임으로 마이그레이션. 오프라인 큐·중복검출을 전 경로로 확장. **UI 변화 0** → 안전 착지 지점.
- **P1. 통합 기록 시트**: `UnifiedRecordSheet` + `SubTypeChipRow` + `RecordTimeEditor` + 본문 조각 재구성. `RecordingView` 폼 4종 · `QuickInputSheet` 대체(진입 배선은 P2에서 전환).
- **P2. 하나의 규칙 + 연속 기록**: `RecordEntryRule` 배선(instant/detail). 저장 후 홈 복귀 + Undo 스낵바, 강제 close 폐기. 저장 라벨/버튼 통일.
- **P3. 진입·네이밍**: `RecordLauncherSheet`(＋) 바텀시트, 캘린더 탭 리네임, `defaultTypes` 재정렬.
- **P4. 정리**: 죽은 폼/경로 삭제(`RecordingView` 잔재·중복 저장 코드·유축 모순 주석), 문서/CHANGELOG.

각 단계 후 시각 QA(시뮬/기기) — 라이브 코어 변경이라 필수.

---

## 8. 리스크

- **라이브 코어(저장·삭제) 변경** → 단계별 TDD + 시각 QA로 방어. P0가 무UX변경이라 회귀 격리 용이.
- **병합 전략**: 단일 브랜치 순차 진행 후 단계별 PR vs 통합 PR — PO 결정(push/PR/머지는 PO 승인).
- **출시 게이트**: 완료 후 빌드 bump(≥100) → 시각 QA → v2.8.8(또는 2.8.9) 제출은 PO 결정.
