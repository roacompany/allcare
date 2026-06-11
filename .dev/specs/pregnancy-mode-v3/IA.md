# 임신모드 v3 — 독립 모드 IA ("임신 노트")

작성 2026-06-11 · PO 지시 "임신모드는 별도" → 독립 공간 설계. 3개 구조안(탭바/허브/여정) 병렬 생성 → 심사·종합. 기능 세트 = FEATURES.md(53). 데이터모델 정정 = zerobase-review.md.

모든 핵심 자산이 실재함을 확인했습니다(AppContext 4-state, ContentView 분기, PregnancyTransitionSheet, PregnancyRecoveryModal, DashboardPregnancyHomeCard, PregnancyWidgetDataStore, PregnancyTerminationView 등). 세 안의 코드 전제는 환각이 아닙니다. 추천안을 작성하겠습니다.

---

# 임신 '독립 모드' IA 추천안 (PO 제시용)

> 세 구조안 검토 결과, **여정 타임라인(안3)을 베이스로, 허브(안2)의 가벼움과 탭바(안1)의 공간 토글 모델을 접목**하는 것을 추천합니다. 아래에 채점 → 추천 IA → 화면/플로우 → 별도모드 함정 해법 순으로 정리했습니다.

---

## 1. 기준별 채점 (1~5, 높을수록 우수)

| 기준 | 안1 탭바 (앱속앱) | 안2 단일 허브 | 안3 여정 타임라인 |
|---|:---:|:---:|:---:|
| 둘다케이스 명료성 | 4 | 4 | **5** |
| 진입/전환 마찰 | 3 | **5** | 4 |
| 53기능 위계 적합 | **5** | 3 | **5** |
| 한국 산모 동선 | 4 | 4 | **5** |
| 학습 용이성 | 3 | **5** | 4 |
| 가벼움 | 2 | **5** | 3 |
| **합계 (30점 만점)** | **21** | **26** | **26** |

### 채점 근거 (핵심만)
- **안1 탭바**: 53기능 위계는 최강(5탭 명시 분류)이나 `@State activeSpace` 신규 상태머신 + 조건부 진입점(pregnancyOnly에서 exit 숨김) = **빌드 56 "진입점 orphan" 회귀 유형 재발 위험**이 가장 큼. 두 TabView 셸 = 유지보수 표면 최대 → 가벼움/학습 최하.
- **안2 허브**: 진입(카드탭)·이탈(커버닫기) 단일 가역 제스처 = 마찰·학습 최강, fullScreenCover로 가벼움도 최강. 단 **단일 스크롤에 53기능 = 위계가 '카드 순서'에만 의존** → 깊은 기능 발견성 낮고 동적 재정렬 규칙이 어긋나면 신뢰 붕괴. fullScreenCover 위 NavigationStack 중첩 = **PR #9 toolbar crash 핫스팟 재발**.
- **안3 여정**: '시간좌표 유무'라는 단일 칼로 53기능을 타임라인 융합 vs 탭 격리로 가름 = 위계 적합 최강 + 한국 검진×주차 매핑이 ③검진 탭에 완결 = 한국 동선 최강. '평행공간 2개 + 웜홀 1개'가 둘다케이스를 가장 깔끔히 차단. 약점은 ④더보기 비대화 + 타임라인 응집 집계 복잡도.

**결론**: 안2와 안3 동점(26). 안3이 위계·한국동선·둘다케이스에서 우위, 안2가 가벼움·마찰·학습에서 우위. → **안3을 골격으로 채택하되, 안3의 두 약점(가벼움·집계복잡도)을 안2의 패턴으로 봉합**한다.

---

## 2. 추천 단일 구조: "임신 노트" — 여정 척추 + 허브형 가벼움

### 조직 원리 (한 문장)
> **시간좌표가 있는 것은 여정 타임라인(①)에 융합하고, 좌표 없는 도구는 탭(②③④)에 격리한다.** 단, ①은 안2처럼 **읽기 중심 + 요약 카드 + 1탭 드릴다운**으로 항상 가볍게 유지한다.

### 핵심 결정 3가지
1. **진입 방식 = fullScreenCover (안2 채택, 안3의 "별도 TabView 루트 교체" 기각)** — 이유: 루트 교체는 신규 상태머신(activeSpace)이 필요해 회귀 위험. fullScreenCover는 기존 `AppContext` 스위치 위에 모달만 얹으므로 **신규 전역 상태 0**. 둘다케이스에서 dismiss 한 번이면 정확히 떠났던 육아 홈 복귀(상태 자동 보존).
2. **내부 네비 = 4탭 (안3 채택, 안1의 5탭/안2의 무탭 기각)** — 5탭은 검진/영양 분리로 무겁고, 무탭은 발견성 약함. 4탭(여정/기록/검진/더보기)이 위계와 발견성의 균형점.
3. **①여정 = 안3 타임라인 + 안2 동적 카드** — 무한스크롤 척추는 유지하되, "오늘" 섹션은 안2식 요약 카드 + QuickLogStrip으로 **첫 화면을 가볍게**. 과거/미래 스크롤은 무한이 아니라 **주차 단위 lazy 페이징**으로 안3의 성능 우려 봉합.

### ASCII 구조도 — 전체

```
                          앱 진입 (AppContext.resolve)
                                    │
        ┌───────────────────────────┼───────────────────────────┐
     empty                    pregnancyOnly                  babyOnly / both
        │                           │                              │
   온보딩 "임신중"            임신노트 = 앱 루트              육아 5탭 = 루트
        │                  (육아탭 없음, fullScreen 아님)         │
   PregnancyReg ──────────────────▶ │                   ┌─────────┴─────────┐
        │                           │                babyOnly             both
   AppContext 전이                  │              (임신 진입점 없음)   홈 최상단
                                    │                                PregnancyPortalCard
                                    │                                "🤰 둘째 24주·D-112 ›"
                                    │                                      │ 탭
                                    │                                .fullScreenCover
                                    └──────────────┬───────────────────────┘
                                                   ▼
                          ┌─────────────────────────────────────────┐
                          │   임신 노트 (보라 액센트 · 4탭 TabView)    │
                          │   상단칩: [← 육아로]  "🤰 임신 24주"       │  ← both에서만 칩
                          ├─────────────────────────────────────────┤
                          │  ①여정    ②기록    ③검진    ④더보기      │
                          └─────────────────────────────────────────┘
```

### ASCII 구조도 — 내부 4탭 + 53기능 위계

```
① 여정 (척추·매일) ───────────────── 안3 타임라인 + 안2 가벼움
   [sticky 헤더]  NN주N일 · D-day · 40주 진행바           ← A 주차/D-day
   ┌─ "오늘" 섹션 (안2 동적 카드, 첫화면 가볍게) ─┐
   │  • 오늘의 데일리팁 / 아기크기비교            ← B
   │  • QuickLogStrip ▸태동 ▸증상 ▸체중 (탭1회시트) ← A 입력 → ②로 점프
   │  • [동적승격] 검진 D-2 카드 / 진통타이머(37주+) ← C/A
   │  • 미완 체크리스트 상위 3                     ← C
   └──────────────────────────────────────────┘
   ↑위 스크롤(과거): 지난 주차 카드 — 그 주 기록·초음파·일기 응집  ← A/D 역류
   ↓아래(미래): 다가올 주차 콘텐츠 예고 · 예정 검진              ← B/C
   ※ 무한 아님 → 주차단위 lazy 페이징 (성능 봉합)

② 기록·추적 (상시도구·매일 여러번) ── 시간좌표 약한 A 집결
   태동 · 체중+그래프 · 증상/기분 · 혈압/혈당 · 약/수분/수면 · 진통타이머
   → 저장 시 ①여정 해당 주차에 자동 역류

③ 검진 (한국동선 심장·가끔) ───────── C 전부 + G 일부
   • 검진객체 타임라인(일정+수치+초음파 1객체)
   🔴 한국검진×주차 자동매핑 (11~13주 NT/1차기형아 · 15~20주 정밀초음파 · 24~28주 임당)
   🔴 국민행복카드 바우처 잔액·안내 + 산모수첩 디지털 미러
   • 주차별 체크리스트 · 진료준비질문
   • 음식안전조회(식사맥락 빠른링크)                          ← G

④ 더보기 (가끔·1회성 라이브러리) ──── 안2식 "접어 묶기"로 비대화 방지
   ▸ 도구함(접힘)  : 예정일계산·출산준비물·출산가방·출산계획서·이름짓기·다태아·위젯  ← E
   ▸ 콘텐츠 서가   : 발달일러스트·감수아티클·태교음악/동화·운동/요가·영양가이드/영양제 ← B아카이브/G/K
   ▸ 정서·추억     : 임신일기·만삭타임랩스·초음파타임라인·아기편지/태담 (작성=여기, 노출=①핀) ← D
   ▸ 함께보기      : 부부/가족 초대코드 · 응원/태담 스탬프                  ← F
   ▸ 커뮤니티                                                          ← K
   ▸ 공간설정      : 알림 절제(주차/검진/태동) · 임신정보수정 · 출산/종료 전환 ← J/H/I

위계: 매일=①② · 가끔=③④ · 1회성=④도구함  →  척추(①)는 항상 가볍고 맥락적
```

### 진입 / Exit 명세

| 상태 | 진입 | Exit |
|---|---|---|
| **empty** | 온보딩 "임신중이에요" → `PregnancyRegistrationView` → AppContext가 pregnancyOnly 전이 | — |
| **pregnancyOnly** | 앱 루트가 곧 임신 노트(fullScreenCover 아님, NavigationStack 루트) | **나갈 곳 없음** → 상단칩·닫기버튼 숨김 (안1의 "exit 숨김"을 그대로 채택) |
| **both** | 육아 홈 최상단 `PregnancyPortalCard` 1개 = **유일한 문** → `.fullScreenCover`로 임신 노트 | 좌상단 `[← 육아로]` 칩 = cover dismiss → 떠났던 육아 홈 복귀 |
| **딥링크(위젯/푸시)** | 곧장 fullScreenCover 열어 ①여정 또는 해당 카드 도달 | 동일 |

### 둘다 전환 모델 (안1·안2·안3 종합)
- **평행공간 2개 + 웜홀 1개** (안3 골격): 임신 기능을 육아 5탭에 **0개 침투**(PO 지시 준수). 진입문은 `PregnancyPortalCard` 단 하나.
- **fullScreenCover 모달 분리** (안2 채택): 임신 노트에 있는 동안 육아 탭바 안 보임 → 컨텍스트 오염 0. dismiss = 단일 가역 제스처 → 학습비용 0.
- **공간 정체성 시그널** (안1·안3 공통): 육아=브랜드 핑크 `#FF9FB5` `house`, 임신=보라/라일락 `figure.and.child.holdinghands`. 상단칩이 "지금 어느 공간"을 항상 표시 → 0.5초 인지.
- **알림 출처 라벨링** (3안 공통): `[둘째 임신] 24주 검진 D-2` vs `[로아(첫째)] 수유` → 탭 시 해당 공간 직행 딥링크.
- **상태 보존**: 두 공간 스크롤위치·선택탭 각자 보존. 임신 노트 닫고 다시 열면 마지막 본 주차 그대로. (fullScreenCover라 별도 activeSpace 저장 불필요 = 안1의 @State 휘발 문제 원천 제거.)

### 53기능 배치 (매일/가끔/1회성 위계, 중복 없는 1차 거주지)

| 영역(개수) | 매일 | 가끔 | 1회성 | 거주지 |
|---|:---:|:---:|:---:|---|
| A 추적(8) | ● | | | 주차/D-day=①헤더, 입력도구=②, 진통타이머=막달 ①②승격 |
| B 주차콘텐츠(5) | ● | | | 데일리팁/크기비교=①, 발달일러스트/감수아티클=주차상세+④서가 |
| C 산전검진(4) | | ● | | 전부 ③ (한국매핑·바우처·산모수첩·체크리스트·진료준비질문) |
| D 정서기록(4) | | ● | | 작성=④, 노출=①여정 주차 핀 |
| E 도구(6~7) | | | ● | ④도구함 접힘(계산기·준비물·가방·계획서·이름·다태아·위젯) |
| F 공유(2) | | ● | | ④함께보기(초대코드·스탬프, 스탬프는 ①카드 반응 표시) |
| G 영양(2) | | ● | | ③(음식안전 식사맥락) + ④서가(영양가이드/영양제) |
| H 전환(2) | | | ● | ①막달 "출산했어요" CTA + ④설정 |
| I 손실(1) | | | ● | ④설정 깊은 곳 (조용·수동) |
| J 알림(1~3) | | ● | | ④공간설정 알림센터(절제 default), 각 탭이 D-day 소스 |
| K 커뮤니티/태교/운동(3) | | ● | | ④서가·커뮤니티 |

### 출산 전환 (무손실 승계 — 3안 동일, 기존 자산 재사용)
```
①막달(D-7~) "출산했어요" CTA (기존 birthCTABanner 재사용)
   → PregnancyTransitionSheet (babyName/gender/birthDate 입력)
   → WriteBatch atomic: Pregnancy.outcome=.born + archivedAt  ∥  새 Baby 생성
      (babyNickname→name, ultrasoundGender→gender, dueDate→생일 prefill)
   → 임신 데이터 삭제 0 (초음파→첫앨범, 일기/만삭사진 = "지난 임신" ④아카이브 읽기전용 영속)
   → AppContext 자연 재해석: pregnancyOnly→babyOnly / both→both(임신1건 종료)
   → fullScreenCover dismiss → 육아 모드 자동 착지 + 출산축하 + "임신 여정 다시보기" 링크
   ⚠ 크래시 대비: transitionState=pending → 다음 진입 PregnancyRecoveryModal 재개
```

### 손실 분기 (조용한 추모 모드 — 출산과 코드·UI 완전 분리)
```
④설정 깊숙이 "임신 정보 정리" (절제 라벨, D-day·축하톤 0)
   → PregnancyTerminationView (outcome = miscarriage/stillbirth/terminated)
   → 즉시 "조용한 모드":
      ① 주수 freeze (①헤더 주차 진행 영구 정지)
      ② 모든 임신 알림 취소 (J) + 위젯 제거 (PregnancyWidgetDataStore.clear)
      ③ QuickLogStrip/검진/진통/응원스탬프/커뮤니티 등 '진행' UI 전면 숨김
      ④ 데이터 100% 보존 (no_data_deletion 룰) — 일기·초음파 조용히 열람 가능
      ⑤ 보라/축하 → 차분한 중립 톤으로 공간 리스킨, 위로 메시지 화면
   → babyOnly였으면 임신 공간 자동 종료 / both였으면 조용히 육아 복귀
      (둘째 상실이 첫째 육아 화면 침범 금지)
   → 손실 데이터: Analytics/Crashlytics/인사이트 ML 절대 미포함 (safety.md)
   → 출구 존중: 다시 권유 안 함, 새 임신은 본인 자발적 등록 시에만
```

---

## 3. 화면 인벤토리 + 핵심 플로우

### 주요 화면 인벤토리
| # | 화면 | 신규/재사용 | 비고 |
|---|---|---|---|
| 1 | `PregnancyNoteRootView` (4탭 TabView 셸) | **신규** | 보라 액센트, 상단 공간칩 |
| 2 | `PregnancyJourneyView` (①여정 타임라인) | `DashboardPregnancyView` 승격 | sticky 헤더 + lazy 주차 페이징 |
| 3 | `PregnancyTrackingHubView` (②기록) | 부분 재사용 | `PregnancyRecordingSheets` 묶음 |
| 4 | `PrenatalCareView` (③검진) | 부분 신규 | 🔴한국검진/바우처/산모수첩 = 신규 데이터 큐레이션 |
| 5 | `PregnancyMoreView` (④더보기) | 신규 셸 | 도구함/서가/추억/공유/설정 섹션 |
| 6 | `WeekDetailView` (주차 상세) | 재사용 | 발달콘텐츠+감수아티클 |
| 7 | `PregnancyPortalCard` (both 진입문) | `DashboardPregnancyHomeCard` 격상 | 육아 홈 최상단 |
| 8 | `PregnancyTransitionSheet` | **기존 그대로** | 출산 승계 |
| 9 | `PregnancyRecoveryModal` | **기존 그대로** | pending orphan 복구 |
| 10 | `PregnancyTerminationView` | **기존 그대로** | 손실 분기 |
| 11 | `PregnancyDDayWidget` / `PregnancyWidgetDataStore` | **기존 그대로** | 딥링크 진입 |

### 핵심 플로우 4종
```
[플로우 A — both 일상 진입] 육아홈 → PortalCard 탭 → fullScreenCover(①여정)
                              → QuickLog 태동 1탭 → 시트 저장 → ①주차카드 역류 → [←육아로] dismiss
[플로우 B — 한국 검진 동선]   ①여정 검진D-2 카드 → ③검진 → 다음검진 객체
                              → 🔴바우처 잔액 확인 → 진료준비질문 작성 → 산모수첩 미러 확인
[플로우 C — 출산]            ①막달 "출산했어요" → TransitionSheet → WriteBatch → 육아 착지 + "여정 다시보기"
[플로우 D — 손실]            ④설정 "임신 정보 정리" → Termination → 조용한모드 freeze/보존/추모
```

---

## 4. 별도 모드 함정(둘다 혼란·전환마찰)의 구조적 해법

| 함정 | 안별 약점 | 추천안 해법 (종합) |
|---|---|---|
| **둘다 컨텍스트 혼동** | — | ① 임신 기능 육아탭 **0 침투** ② fullScreenCover = 한 번에 한 공간만 ③ 보라/핑크 + 상단칩 정체성 시그널 ④ 알림 출처 prefix |
| **진입점 orphan (빌드56 회귀)** | 안1 최대 — 조건부 exit칩 gating | **진입문 1개(PortalCard)** + pregnancyOnly는 칩 숨김. AppContext×진입점 매트릭스를 **XCUITest 전수 고정** |
| **신규 상태머신 휘발 (안1 activeSpace)** | 안1 @State 휘발 | **activeSpace 폐기.** fullScreenCover + 기존 AppContext만 사용 → 신규 전역상태 0, 휘발 문제 원천 제거 |
| **단일 스크롤 무게 (안2)** | 안2 — 53기능 다 들어오면 길어짐 | ④에 **접어 묶기**(도구함/서가/추억/공유 섹션) + ①은 요약카드만, 깊은건 1탭 드릴다운 |
| **타임라인 집계 복잡·성능 (안3)** | 안3 — 무한스크롤 리사이클 | **주차단위 lazy 페이징**(무한 아님) + 역류는 "소속 주차" 단일 키로 단순화 |
| **NavigationStack 중첩 crash (안2, PR#9)** | 안2 fullScreenCover+push 중첩 | 임신 노트 내부는 **4탭 각자 독립 NavigationStack** → cover 위 단일 스택 깊이 제한, 전수 toolbar QA |
| **전환마찰** | 안1 cross-dissolve 다경로 | dismiss/카드탭 **단일 가역 제스처**만 + 상태 자동 보존 |
| **출산↔손실 혼재 (감정 안전)** | — | 위치/톤/후속모드 완전 분리: 출산=①막달 능동·밝음 / 손실=④설정 깊은곳 수동·조용 + 즉시 freeze/추모 |

### 핵심 차별화 한 줄
> **"activeSpace 신규 상태머신을 버리고(안1 회귀위험 제거), fullScreenCover 단일 모달로 평행공간을 분리하며(안2 마찰최소), 여정 타임라인 척추로 53기능을 시간좌표 기준 위계화한다(안3 위계최강) — 한국 검진×주차 매핑을 1급 시민으로."**

### PO 결정 필요 사항 (구현 전)
1. **③검진 한국매핑 데이터 큐레이션** — 표준검진×주차표 + 바우처/산모수첩 미러는 외부 데이터 큐레이션 필요. 가장 큰 신규 작업, 별도 페이즈 권장.
2. **RC 단계 롤아웃** — 기존 `pregnancy_rollout_pct` 활용. v2.7.1식 다중빌드 회귀 방지 위해 페이즈 분할 필수.
3. **v2 마이그레이션 코치마크** — 기존 `DashboardPregnancyHomeCard`(additive card)에 익숙한 .both 산모에게 "임신 카드 → 임신 노트 입구로 격상" 안내 1회.

**관련 파일(절대경로)**: `/Users/roque/BabyCare/BabyCare/App/ContentView.swift`, `/Users/roque/BabyCare/BabyCare/Utils/AppContext.swift`, `/Users/roque/BabyCare/BabyCare/Views/Dashboard/DashboardPregnancyView.swift`, `/Users/roque/BabyCare/BabyCare/Views/Dashboard/DashboardPregnancyHomeCard.swift`, `/Users/roque/BabyCare/BabyCare/Views/Pregnancy/PregnancyTransitionSheet.swift`, `/Users/roque/BabyCare/BabyCare/Views/Pregnancy/PregnancyRecoveryModal.swift`, `/Users/roque/BabyCare/BabyCare/Views/Settings/PregnancyTerminationView.swift`, `/Users/roque/BabyCare/BabyCareWidget/Provider/PregnancyWidgetDataStore.swift`
