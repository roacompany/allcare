# 임신모드 v3 — 백본 설계 (데이터모델 + IA + 생애주기)

**작성일**: 2026-06-11 · **상태**: 설계 리뷰 대기 · **근거**: `context/ia-research.md`(6각도 리서치) + `context/audit-2026-06-11`(8차원 코드감사, MEMORY [[babycare-backlog]] ④)

## 0. 왜 원점인가 (진단)
현 임신모드(v2)의 4대 결함 — 출산전환 **중복아기(P0)** · 성별 **항상 .male(P1)** · 가족공유 **데이터 유실(P1)** · 손실 후 **주수 계속 증가** — 은 개별 버그가 아니라 **단일 근본 결함의 증상**이다:

> **임신을 "전역 모드 플래그"로 모델링했다.** (`AppContext` 4-state + `activePregnancy` 옵셔널 + 컴파일 flag 게이팅)

v3의 단일 원칙: **임신 = 아기와 동급의 '프로필 엔티티'.** 모드가 아니라 데이터. UI는 모드 토글이 아니라 **프로필 카드 스택**.

## 1. 목표 & 범위
- **목표**: 본격 임신 추적기(육아앱 속 전생애주기). 핵심 5: 주수 콘텐츠 · 태동 · 체중 · 산전검진 체크 · **부부 공동 기록**. + 손실 경로 v1 포함.
- **이 문서 = 백본 서브프로젝트 ①+②**: 데이터모델 · 공유/충돌 · IA/네비 · 생애주기 상태머신 · 마이그레이션. 
- **후속 서브-spec(별도)**: 주차 콘텐츠 라이브러리 · 산전검진 템플릿 · 태교 · 초음파 타임라인 · 커뮤니티. (이 백본의 데이터/IA 슬롯 위에 올라감)
- **불변**: 데이터 삭제 금지 · 임신데이터 Analytics/Crashlytics 금지 · 광고·커머스 0 · EDD append-only.

## 2. 데이터 모델 (신규)

### 2.1 프로필 엔티티
임신과 아기를 **공통 '케어 프로필'** 추상으로 통합. 두 구체 타입:
- `Baby` (born) — 기존 유지.
- `PregnancyProfile` (unborn) — 신규. babies와 **동급 컬렉션**.

```
users/{ownerUid}/pregnancyProfiles/{profileId}
  ownerUid: String                 // 소유자(산모) — 데이터가 사는 단일 트리
  sharedWith: [String]             // 파트너 UID 목록 (공동편집 멤버)
  lmpDate: Date?                   // 최종월경일
  eddSource: "lmp" | "ultrasound"  // EDD 산출 근거 (표시용)
  eddHistory: [{ value: Date, setAt: Date, source }]  // append-only (덮어쓰기 금지)
  babyNickname: String?            // 태명
  ultrasoundGender: Gender?        // Baby.Gender 재사용 (rawValue 영구계약)
  outcome: "ongoing"|"born"|"miscarriage"|"stillbirth"|"terminated"  // 흡수상태
  birthEventId: String?            // 출산 멱등 경계 (born 시 set)
  archivedAt: Date?                // 종료/출산 시각 (주수 freeze 기준)
  createdAt, updatedAt, createdBy: String
```

서브컬렉션(모두 **소유자 단일 트리 아래**, 각 레코드 독립 문서):
`kickSessions` · `prenatalVisits` · `weightEntries` · `symptoms` · `pregnancyChecklists` · `ultrasounds`(신규: 사진+주차).
각 레코드에 `createdBy` 스탬프(누가 기록했나, 부부 구분).

### 2.2 공유 = 소유자 단일 트리 + 역할맵 + 대칭 공동편집
**현 유실버그의 진원(파트너가 자기 트리에 사본 작성)을 제거한다.** 모든 임신 데이터는 **소유자 트리 한 곳**에만 산다. 파트너는 별도 사본을 만들지 않고 **같은 트리에 직접 write**한다.

- **rules**: `pregnancyProfiles/{id}` 및 모든 서브컬렉션의 read/write = `request.auth.uid == ownerUid || request.auth.uid in resource.data.sharedWith` (서브컬렉션은 부모 profile의 sharedWith 참조). collectionGroup partner read 규칙 유지·확장.
- **대칭 공동편집**(PO 결정): 산모·파트너 **둘 다 모든 기록 입력 가능**. `createdBy`로 작성자 표시.
- **충돌 처리**:
  - 서브컬렉션 레코드(태동/검진/체중/증상/초음파) = 각자 독립 문서 → **충돌 없음**(서로 다른 doc). 동일 레코드 동시편집만 last-write-wins(`updatedAt`), 희귀.
  - profile 스칼라 필드 = `updatedAt` 기반 last-write-wins. **EDD만 append-only**(eddHistory). "OO님이 수정함" 표시.
  - **실시간 리스너**(Firestore snapshot)로 양쪽 라이브 동기화 → stale overwrite 최소화.
- **초대**: 초대코드(카톡 친화) → 수신자 명시 수락. 수락 write는 **멱등**(이미 멤버면 no-op).
- **revoke/leave** = `sharedWith`에서 UID 제거 + 그 사람 기기 미러만 비움. **leave ≠ delete**(원본 보존).
- 비가역 CTA(출산/종료)는 **소유자 한정**(파트너 화면 미노출, 상단 역할 배지).

### 2.3 생애주기 상태머신 (단방향·흡수)
```
PregnancyProfile(ongoing)
   ├─ [출산] → birthEvent(멱등키) → Baby × N(다태아)  → profile.outcome=born (봉인)
   └─ [손실] → profile.outcome ∈ {miscarriage|stillbirth|terminated} (봉인, 별도 IA 브랜치)
```
- 봉인(born/손실) 시 임신 CTA·주수·검진·태교 알림 **자동 소멸**(상태 종속).
- 봉인 후 데이터 삭제 ❌ → 아카이브 보존.

## 3. IA / 네비게이션

### 3.1 AppContext 4-state 폐기
`empty/babyOnly/pregnancyOnly/both` 특수분기 제거 → **"케어 프로필 리스트 + 활성 선택"** 으로 환원.
- empty = 프로필 0개 → 온보딩
- 그 외 = 프로필 N개의 자연스러운 카드 렌더 (both = 임신+아기 카드 공존, 특수 if문 아님)
- `switch`에 `default:` 금지 규칙 유지(case 추가 시 컴파일러 강제).

### 3.2 홈 = 카드 스택 + 동적 정렬
- 각 프로필 = 카드 1장. 임신 카드 = **'오늘의 아기'**(태아 일러스트 + D-day + NN주N일 + 한국 태아크기 비유 + 태담). 보조 액션(태동/체중/검진)은 카드 하단 작은 버튼.
- **정렬 = 신호 기반**(D-day 임박도 + 마지막 기록 시각) + **수동 핀**. "베이비냐 임신이냐" 강요 없음. 기존 `InsightScorer` 우선순위 로직 재사용.

### 3.3 진입점 (2-track)
- **신규(empty)**: 온보딩 3-way — 임신준비 / 임신중 / 육아중 → 입구에서 상태 확정(혼란 원천 차단).
- **기존(아기 보유)**: '아기 추가'와 **같은 자리에 형제로 '임신 등록'** (둘째 임신 동선 학습 불필요).
- 활성 임신 있으면 '임신 등록' 진입점 숨김(중복 생성 방지).

### 3.4 탭
홈 | 캘린더 | ➕기록 | 건강 | 설정 유지. 임신 기록은 ➕기록에 통합(스크롤 밖 미도달 버그 해소 — 폼과 함께 단일 ScrollView). 건강 탭에 임신 건강(체중/검진/증상) 섹션.

## 4. 생애주기 플로우 상세

### 4.1 출산 전환 (정상)
1. **36주 이전 CTA 노출 금지.** 36~39주 윈도우에 **dismiss 가능 카드**(상시 배너 ❌). 카드 내 '아직이에요 / 예정일 조정' 동거.
2. '출산했어요' → 축하 → **출산일·성별(=ultrasoundGender prefill, 버그 수정)·체중·키·아기 수** 한 폼.
3. **멱등 트랜잭션**: `birthEventId`(= `profileId + ":birth"` 고정키). WriteBatch로 baby(N) 생성 + profile.outcome=born + babyCount increment, **모두 한 배치**. 재시도/오프라인 재탭 시 birthEventId 이미 처리됐으면 **no-op**(중복아기 P0 해소). 다태아 N은 birthEventId 하위 deterministic id(`birthEventId:0..N-1`)로 → "의도된 N명" vs "유령" 구분.
4. **봉인**: outcome=born → 임신 UI/알림 전부 소멸.
5. **아카이브**: 임신 데이터는 baby 타임라인 '임신 기간' 읽기전용 섹션으로 보존.

### 4.2 손실 경로 (유산/사산/중지) — v1 포함, 차별화
1. **별도 조용한 IA 브랜치**(출산으로도 empty로도 collapse ❌).
2. 소프트 단일 진입 '임신을 더 이상 이어가지 못하게 되었어요'. 유산<20주/사산≥20주는 **내부 분기만**(카피 정확성), 사용자에 임상 드롭다운 강요 ❌.
3. **주수 즉시 freeze**(archivedAt 기준 — 아카이브 주수증가 버그 해소). 시간기반→상태기반(회복/지원) 콘텐츠.
4. **모든 예약 알림 하드 취소**(멱등 teardown).
5. 데이터 보존 기본 + 명시적·되돌릴수있는 삭제만. 선택적 추모기록(이름·날짜·메모·사진, 강제·자동프롬프트 ❌).
6. **손실 경로 중 requestReview·수익화·업셀 전면 억제**(AppReviewPromptService 가드 추가).

## 5. 마이그레이션 (기존 v2 데이터 → v3)
- 기존 `users/{uid}/pregnancies/{id}`(+ 서브컬렉션) → `pregnancyProfiles/{id}` 스키마로 변환. **삭제 0, 멱등, 검증 게이트**(파일럿 fingerprint + 카운트 어서션).
- `ownerUserId`(현 비영속) → `ownerUid` 영속화. 공유 임신은 소유자 트리로 정규화(파트너 orphan 사본 있으면 소유자 트리로 흡수, 유실 복구).
- `transitionState=pending` orphan 문서 → birthEvent 모델로 변환 + Baby 존재여부 체크(중복 방지).
- migration은 별도 서브프로젝트 ⑧(데이터모델 확정 후 작성).

## 6. 반드시 피할 안티패턴 (리서치 Top 7, 현 버그 1:1)
상시 출산CTA · 비멱등 전환 · 손실 후 주수증가 · 전환/손실 시 데이터삭제 · 3-state 토글 · 파트너 자기트리 사본 · 죽은기능(HealthKit) 1급노출+feature creep. (상세 `context/ia-research.md`)

## 7. 한국 시장 필수
NN주N일+D-day · 한국 태아크기 비유(라임/아보카도/바나나/옥수수/가지/수박)+태담 · 산전검진 주차트리거 체크리스트(NT/쿼드/정밀초음파/임당) · 초음파 주차 타임라인 · 바우처 1회 정보카드(커머스❌) · **광고 0 = 구조적 강점**.

## 8. 재사용하는 현 자산
`outcomeType` enum(raw 영구계약) · `eddHistory` append-only · `Gender`(prefill 버그만 수정) · `PregnancyChecklistItem` · `pregnancy-weeks.json`(37주) · collectionGroup partner read · `createdBy`(PR #26) · `InsightScorer` 우선순위.

## 9. 서브프로젝트 분해 & 빌드 순서
1. **[이 문서] 데이터모델 + 공유/충돌** (토대)
2. **[이 문서] IA/네비 골격 + 상태머신**
3. 핵심 추적 UI (주수·태동·체중·검진·증상) — 백본 위
4. 주차 콘텐츠 라이브러리 (태아/엄마/배우자 3블록)
5. 산전검진 템플릿 + 초음파 타임라인
6. 출산 전환 + 손실 플로우 (멱등) — 상태머신 구현
7. 부부 공유 실시간 동기화 + 초대
8. 마이그레이션 (실데이터)
9. 태교 / 커뮤니티 (별도, 마지막)

각 서브프로젝트 = 독립 spec→plan→구현→검증 사이클.

## 10. 열린 질문 / 리스크
- 대칭 공동편집의 동일-레코드 동시편집 충돌은 last-write-wins로 충분한가(의료수치 체중 등)? — v1 LWW, 필요 시 추후 강화.
- `pregnancyProfiles`를 별도 컬렉션 vs `babies`에 `isUnborn` 플래그 — 별도 컬렉션 채택(스키마 명료·rules 분리). 마이그레이션 시 재검토.
- 커뮤니티는 범위·운영(신고/모더레이션) 부담 큼 → 최후순위, 별도 의사결정.

## 11. 현행 처리 (병행)
v2는 **v2.8.8 핫픽스(flag=false)로 비활성**(라이브 P0 차단, 데이터 보존). v3 완료 시 새 구현으로 재활성. → `hotfix/pregnancy-disable-v2.8.8`.
