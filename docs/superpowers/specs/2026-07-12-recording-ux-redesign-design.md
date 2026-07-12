# 기록하기 UX 전면 재설계 (C안 — 통합 + 스마트 추천)

- **날짜**: 2026-07-12
- **브랜치**: `fix/recording-ux` (빌드103 기반 · 기존 WIP `2923e84` 위에 이어감)
- **상태**: 설계 승인 완료 (PO "일단 만드세요", 2026-07-12) → 구현 착수
- **시각 시안(구조·톤 정본)**: https://claude.ai/code/artifact/444e78e9-b923-49b6-905d-d7e8012f81e5
- **선행 트랙**: [[2026-07-11-unified-recording-design]] · [[2026-07-12-feeding-taxonomy-pumped-milk-inventory]] (본 재설계가 이들 통합 저장경로 위에 얹힘)

## 배경

PO 기기 QA (빌드103): "기록하기 영역이 사용자경험을 매우 해친다 · UX 고려 없이 기획된 것으로 보임." 5탭 실제 렌더 캡처 + 코드맵으로 진단 → **저장 엔진(ActivityDraft→commit)은 건전, 무너진 것은 정보설계(IA) 층.** 부분 패치(모유 타이머·＋탭 그리드·유축 아이콘 = `2923e84`)를 넘어 IA 전면 재설계로 확정. PO는 진입점 모델 3안 중 **C(통합 + 스마트 추천)** 선택.

## 진단 6 → 해소 (traceability)

| # | 진단 (근거) | 해소 |
|---|---|---|
| 1 | 진입점 3~4곳(홈 빠른기록 9 / 기록탭 13 / 캘린더 버튼+FAB)이 제각각 | 홈=예측 / ＋탭=유일 전체판 / 캘린더=＋ 하나 |
| 2 | 기록탭 '수유'에 이유식·간식(고형식)·짜기(생산) 뒤섞임 | 수유·식사·짜기 분리 (자주/가끔 2계층) |
| 3 | 분유=커피잔, 기저귀 3종 아이콘 동일(`humidity.fill`) | 분유=병, 기저귀 3종 색+심볼 변별 |
| 4 | '수유' 한 섹션이 핑크+라일락+초록 3색 혼재 | 색 = 카테고리 1:1 |
| 5 | 전 타일 동일 크기·비중, 빈도 미반영 | 빈도 위계(자주 큰 타일·상단 / 가끔 작게·하단) |
| 6 | 모유=타이머·수면=시트 불일치, 시트 `.large` 남용 | 지속시간 활동 타이머 통일 + 시트 경중 조정 |

## 목표 / 비목표

**목표**: 기록 진입~입력을 일관된 IA·상호작용으로. 진입점 통합, 분류·위계·아이콘·색 정비, 지속시간 활동 타이머 통일, 시트 경중화, 패턴 기반 다음-기록 예측.

**비목표(이번 범위 밖)**: 저장 파이프라인 재작성(재사용), 새 Firestore 컬렉션(없음), 활동 데이터 모델 변경(없음 — 표시/진입/예측 층만), 임신 v3(무관·flag-off 불변), 위젯 재설계.

## 설계 결정

### D1. 진입점 모델 (진단 1)
- **홈**: 정적 `빠른 기록` 9칸 그리드 폐기 → **예측 스트립**("지금 기록할 것 같아요": 주 예측 1개 크게 + 이유 + 보조 2~3개) + **`전체 기록` → ＋탭**. 오늘 요약 카드는 유지.
- **＋기록탭**: **유일한 정식 전체판**. 상단 `추천`(예측 미러) + `자주 기록` + `가끔 기록`.
- **캘린더**: 빈상태 `기록 추가` 버튼 **또는** 우하단 FAB 중 **하나만** — FAB 유지, 빈상태 버튼은 같은 액션 재사용(중복 제거). ＋탭으로 라우팅.

### D2. 분류·위계 (진단 2·5)
`RecordTile.launcherSections` 재구성. 섹션에 `prominence`(frequent/occasional) 부여, 뷰가 타일 크기 차등.
- **자주 기록**: 수유(모유·분유·유축) · 수면 · 기저귀(소변·대변·소변+대변)
- **가끔 기록**: 식사(이유식·간식) · 건강(체온·투약·목욕) · 짜기(→ 재고 연결)
- 젖먹임(수유)·고형식(식사)·생산(짜기)이 개념적으로 분리됨.
- (선택) 자주 기록 내부에 `수유 / 수면 / 기저귀` 서브 그룹 헤더 — 색 코딩으로도 구분되므로 v1은 단일 '자주' 헤더 + 색/순서로 그룹 인지, 서브헤더는 후속.

### D3. 아이콘 (진단 3) — ⚠️ SF Symbols 제약 정직 반영
규칙 "100% SF Symbols" → **인앱 커스텀 아이콘 불가.** 시안의 SVG는 의도 전달용. 실제는 **최선의 SF Symbol + 강한 색 코딩**:
- **분유**: `cup.and.saucer.fill`(커피잔) → **병 계열**. SF Symbols에 유아용 젖병 없음 → `waterbottle.fill` 후보(핑크). 유축과는 **색**으로 구분(분유 핑크 / 유축 라일락).
- **유축**: `waterbottle.fill` + 라일락(`pumpingColor`) — 현행 유지(변별 OK).
- **모유**: `figure.and.child.holdinghands`("먹이는 대상 아님" 지적) → 후보 검증 필요. 대안: `heart.fill`(양육) / 젖먹임 표상 심볼 부재. **결정: 구현 시 SF Symbols 카탈로그 실사 후 최종 확정** — 색(핑크)+라벨로 보완. (task IMPL-ICON)
- **기저귀 3종**: `humidity.fill` 3개 동일 → SF Symbols에 대변/소변 전용 심볼 없음. **색 우선 변별**: 소변=앰버, 대변=브라운(신규 토큰), 소변+대변=앰버·브라운 조합. 심볼은 `drop.fill`(소변) 등 가용 범위에서 차등. **색이 주 변별자**임을 명시(정직).
- 나머지(수면 `moon.zzz.fill`·체온 `thermometer`·투약 `pills.fill`·목욕 `bathtub.fill`·이유식 `fork.knife`·간식 `carrot.fill`·짜기 `drop.fill`)는 현행 유지.

### D4. 색 = 카테고리 (진단 4)
`Activity.color`(또는 RecordTile override)가 카테고리별 단일 색: 수유=`feedingColor`(핑크) · 유축/짜기=`pumpingColor`(라일락) · 식사=`solidColor`(초록) · 기저귀 소변=`diaperColor`(앰버)·대변=신규 `stoolColor`(브라운) · 수면=`sleepColor`(인디고) · 체온=`temperatureColor`(코랄) · 투약=`medicationColor` · 목욕=`bathColor`(스카이). `stoolColor` = Asset Catalog Dynamic Color 신규 1종(라이트/다크).

### D5. 상호작용 통일 (진단 6)
- **타이머 통일**: `RecordEntryRule` — `.sleep`을 `.detail` → **`.timer`**로. 모유·수면 둘 다 탭→라이브 타이머(배너 정지=시간 저장). `stopAndSaveActiveTimer`/`makeDraft`는 이미 sleep endTime 처리 → 배선만.
- **지난 기록(retrospective) 경로**: `.timer` 타일은 탭=즉시 타이머라 "이미 끝난" 기록 입력 경로 필요. **결정**: 타일 **길게 누르기(long-press)** → `UnifiedRecordSheet`(시간 조절로 과거 입력). + 캘린더/타임라인 편집(기존 `ActivityEditSheet`) 유지. (task IMPL-RETRO)
- **시트 경중** (진단 6): `UnifiedRecordSheet` detent를 타입별로.
  - 컴팩트(`.medium` 또는 커스텀 높이): 체온·투약·분유/유축(값 1~2개).
  - 전체(`.large`): 수면(질·장소)·이유식(반응).
  - ⚠️ `.medium` 클리핑 회귀(빌드 이력) 재발 방지 = **컴팩트 바디를 medium 높이에 맞게 레이아웃 + 헤드리스 캡처로 실측 검증**(가정 금지).

### D6. 스마트 추천 (2단계) — 설명가능·안전
`NextRecordPredictor` (순수·`@MainActor` 불필요·Sendable struct in/out):
- **입력**: 최근 활동(타입별 마지막 시각) · 개인 평균 간격(타입별) · 시간대(낮잠/야간 수유 패턴) · 기존 `FeedingPredictionService v2`(주·야 개인화, 수유 시각).
- **출력**: `[NextRecordPrediction(type, reason: String, confidence)]` 순위. reason은 **중립 간격 언어**("마지막 수유 3시간 전 · 보통 3시간 간격") — 의료 단정/압박 금지(safety.md).
- **정직**: 순위·이유 노출, 탭 결과로 학습(간격 갱신), **데이터 0(신규)=예측 안 함 → 기본세트 폴백**(수유·수면·기저귀, "자주 기록하는 항목"). 가짜 예측 금지.
- **재활용**: 기존 `FeedingPredictionService`, `NextRecordSuggestionPolicy`(저장 후 이어서 제안), 홈의 "다음 수유 예상" 힌트.
- **비푸시**: 인앱 표면화만(알림 아님). 예측 빗나가도 `전체 기록` 한 번으로 전체판 → 막다른 길 없음.

## 재사용 (재작성 아님)
`ActivityDraft`·`ActivityDraftBuilder`·`ActivityViewModel+Save`(commit/persist/makeDraft) · `RecordEntryRule`(정책 확장) · `RecordTile`(구조 확장) · `UnifiedRecordSheet`(detent만) · `FeedingPredictionService` · `NextRecordSuggestionPolicy` · `QuickRecordSettings`(홈 예측 전환 시 역할 축소/제거) · 타이머(`ActivityTimerManager`/`FloatingTimerBanner`).

## 불변 규칙 준수
- **TDD**: 순수로직 RED→GREEN 우선. 테스트는 **첫 `BabyCareTests` 클래스 내부** append(파일 끝 append=vacuous pass 함정) + RED에서 실행 수 확인.
- **arch-test R1–4 = 0**: View→Service 직접 호출 금지(예측/저장은 VM 경유), `Firestore.firestore()` 직접 금지(신규 컬렉션 없음 → Narrow Protocol 불필요).
- **로깅**: `print()` 금지 → `AppLogger`. silent error=`logSilent`.
- **의료 안전(safety.md)**: 예측/카피에 의료 단정·압박 금지. 백분위/증상 판단 텍스트 금지.
- **데이터 보존**: 삭제/마이그레이션 없음(표시·진입·예측 층만). `Activity` 필드 무변경.
- **NavigationStack 중첩 금지**. **디자인 토큰**: `stoolColor` 신규 = `make design-sync`/`design-verify` 반영.
- **SF Symbols 100%**: 커스텀 아이콘 금지(D3 정직 반영).

## 단계별 계획 (각 단계 make verify green)

### Phase 1 — 통합·정리 (IA 기반) ← 먼저
가장 가시적·저위험. 저장 경로 미변경.
- **P1-1 [순수·TDD]** `RecordTile` 섹션 재구성: `prominence`(frequent/occasional) + `launcherSections` 신 그룹(자주: 수유·수면·기저귀 / 가끔: 식사·건강·짜기). 테스트=섹션 구성·순서·prominence.
- **P1-2 [순수·TDD]** 색/아이콘: `stoolColor` 토큰(Asset+design token) + 대변 타일 브라운 매핑 + 분유 병 심볼 + 기저귀 색 변별. 테스트=타입별 color/icon.
- **P1-3 [순수·TDD]** `RecordEntryRule.sleep = .timer`. 테스트=수면 모드=timer + 기존 모유 timer 회귀.
- **P1-4 [뷰]** `RecordLauncherSheet` 신 레이아웃(자주 큰 타일·가끔 작은 타일·섹션 헤더). `추천` 섹션 placeholder(Phase 2 연결 전 hidden 또는 정적 기본세트).
- **P1-5 [뷰·배선]** `UnifiedRecordSheet` detent 타입별(컴팩트/전체) + 컴팩트 바디 medium-fit **헤드리스 실측 검증**.
- **P1-6 [배선]** 수면 long-press→시트(retrospective) + 타이머 탭 경로.
- **P1-7 [뷰]** 캘린더 중복 추가 버튼 제거(FAB 단일화).
- **P1-8** `make verify` green + 헤드리스 캡처(기록탭·홈) 재확인.

### Phase 2 — 스마트 추천 (레이어)
- **P2-1 [순수·TDD]** `NextRecordPredictor`(입력→순위 예측, 이유 생성, 콜드스타트 폴백, 학습 간격). 광범위 테스트(경과/간격/시간대/신규/의료문구 부재).
- **P2-2 [뷰]** 홈 예측 스트립(`DashboardView+Summary` 9칸 그리드 → 예측 스트립 + `전체 기록`). 오늘 요약 유지.
- **P2-3 [뷰·배선]** ＋탭 `추천` 섹션 = predictor 연결.
- **P2-4 [배선]** 예측 학습(저장 시 간격 갱신) + analytics(`next_record_predicted/tapped`, 임신 데이터 무관).
- **P2-5** `make verify` green + 헤드리스 캡처.

## 위험 / QA
- **라이브 저장 코어 인접**: 타이머·detent 변경 → **출시 전 실기기 시각 QA 필수**(헤드리스는 시트 상호작용 한계). 커밋·머지·빌드104·재TF는 PO 승인.
- **SF Symbol 확정**: 모유/기저귀 심볼은 카탈로그 실사 후 → 미흡 시 색+라벨로 보완(정직).
- **시트 detent 클리핑**: medium-fit 실측(가정 금지).
- **홈 예측 회귀**: 정적 그리드 제거 시 QuickRecordSettings 의존 화면/설정 정리 확인.

## 완료 정의
Phase 1·2 각 `make verify` ALL CHECKS PASSED + 헤드리스 캡처 검증. 출시(빌드104·재TF·App Store)는 별도 PO 게이트 + 실기기 QA.
