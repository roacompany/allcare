# 임신모드 v3 — 백본 설계 (마스터)

**작성** 2026-06-11 · **상태** 설계 패키지 완성, 구현 전 PO 결정 대기.
이 문서 = **마스터/개요**. 상세는 `FEATURES.md`(기능 53) · `IA.md`("임신 노트" 구조) · `SCREENS.md`(10화면) · `context/{zerobase-review·ia-research·feature-inventory}`.

> ⚠️ **정정 이력**: 본 문서 초판(오전)의 "신규 `pregnancyProfiles` 컬렉션 + 마이그레이션 / 대칭 공동편집 단정 / 5탭 분산 통합 IA"는 이후 **zerobase-review**(코드 검증)와 **IA.md**(독립 모드)로 뒤집혔다. **본 개정판이 정본.**

## 0. 진단 (왜 원점)
4대 결함 — 출산전환 **중복아기(P0)** · 성별 **항상 .male(P1)** · 가족공유 **유실(P1)** · 손실 후 **주수 증가** — 은 단일 근본 결함의 증상: **"임신을 전역 모드 플래그로 모델링"**(AppContext 4-state + activePregnancy 옵셔널 + 컴파일 flag 게이팅).
원칙: **임신 = 아기와 동급 '프로필 엔티티'**(모드가 아니라 데이터). 단 zero-base 정정 — 이 원칙은 **데이터 재모델링이 아니라 런타임/IA층 교체 + 국소 수정으로 실현**한다(§2).

## 1. 목표 & 범위
- **목표**: 본격 임신 추적기 = **신규 임산부 정복**(PO 확정). 독립 공간 **"임신 노트"**(육아앱 속 또 하나의 앱). 손실 경로 **v1 포함**.
- **기능**: FEATURES.md 53개 LOCK(11영역 + 커뮤니티·태교·운동).
- **IA/화면**: IA.md(임신 노트) / SCREENS.md(10화면)로 위임.
- **불변**: 데이터 삭제 금지 · 임신데이터 Analytics/Crashlytics 금지 · 광고·커머스 0 · EDD append-only · 백분위/의학 판단 텍스트 금지.

## 2. 데이터 — ⚠️ 전면 재작성 철회 (zero-base 정정)
**v2 Pregnancy는 이미 정규화돼 있다**(코드 검증): 독립 컬렉션 `users/{uid}/pregnancies/{id}` + `sharedWith` + `outcome` enum(ongoing|born|miscarriage|stillbirth|terminated, raw 영구계약) + `eddHistory` append-only + WriteBatch `transitionState` + 서브컬렉션(kickSessions/prenatalVisits/weights/symptoms/checklists). → **새 컬렉션·실데이터 마이그레이션 불필요.**

"프로필 엔티티" 원칙은 다음으로 실현:
- **런타임 IA층 교체**: AppContext 4-state 특수분기 → 임신을 별도 공간으로(IA.md). 진짜 결함은 저장층이 아니라 이 게이팅/IA층 + 비영속 ownerUserId.
- **국소 P0/P1 수정**(전면 재작성 없이):
  - 중복아기 → `birthEventId`(=`pregnancyId+":birth"`) 멱등키 + 이미 born이면 no-op + Baby 존재 체크.
  - 성별오류 → `PregnancyTransitionSheet`가 `ultrasoundGender` 직접 대입(rawValue↔displayName 비교 제거, ~3줄).
  - 주수증가 → 아카이브 '최종 주차'는 `archivedAt` 기준 클램프.
  - 공유유실 → `ownerUserId` 영속화 + 공유 임신 쓰기 5경로(checklist/visit/weight/symptom 등)도 owner 트리 라우팅(현재 kick만 됨).
- **additive 신규 필드/컬렉션**(기존 문서 무손상, optional): `birthEventId` · `archivedAt`(없으면) · `ultrasounds`(초음파+주차) · `createdBy`(PR#26 보유).

### 2.1 공유 — 소유자 단일 트리 + 역할맵 (쓰기 범위 = 🔴열린 결정)
- 데이터는 소유자(산모) **단일 트리**에만. 파트너 사본 ❌(유실버그 진원 제거). rules: read/write = `owner || sharedWith 멤버`. collectionGroup partner read 유지.
- **✅ 확정 — 파트너 쓰기 = 비대칭** (2026-06-11 PO): 의료수치(체중/검진/증상)=**산모 owner-write**, 파트너=**읽기 + 감정/이벤트**(태담·코멘트·스탬프). 동시편집 충돌 표면 0 · 구현 단순. 비가역 CTA(출산/종료)=소유자 한정.
- 초대코드(카톡) + 멱등 수락(이미 멤버면 no-op). leave≠delete(미러만 비움). 비가역 CTA(출산/종료)=소유자 한정.

### 2.2 생애주기 상태머신 (단방향·흡수)
`Pregnancy(ongoing) ─[출산]→ birthEvent(멱등키) → Baby×N(다태아) ⟹ outcome=born(봉인)` / `─[손실]→ outcome∈{유산/사산/중지}(봉인, 별도 조용한 브랜치)`. 봉인 시 임신 CTA·주수·검진·태교 알림 자동소멸. 삭제 ❌ → 아카이브 보존.

## 3. IA / 네비게이션 → **IA.md ("임신 노트" 독립 모드)**
⚠️ 초판의 "5탭 분산 통합" **폐기**. PO 지시 = 임신은 **별도 공간**. 확정 구조(요약):
- **진입**: both=육아홈 `PortalCard` 1개 → **fullScreenCover** "임신 노트" / pregnancyOnly=임신노트가 앱 루트. 닫기 1번=육아 복귀(상태 자동보존). **신규 상태머신(activeSpace) 없음** — 기존 AppContext만(빌드56 orphan/휘발 회귀위험 제거).
- **내부 4탭**: ①여정(타임라인 척추·매일) ②기록(추적) ③검진(🔴한국검진/바우처/산모수첩 1급) ④더보기(도구·서가·추억·공유·커뮤니티·설정).
- **둘다 함정 해결**: 임신 기능 육아탭 **0 침투** · 색/칩 정체성(육아 핑크↔임신 보라) · 알림 출처 라벨([둘째 임신]).
- 상세 = IA.md, 화면별 = SCREENS.md.

## 4. 생애주기 플로우 (SCREENS.md #8·#9 상세)
- **출산**: 36주+ dismiss 가능 CTA(상시배너 ❌, '아직이에요/예정일조정' 동거) → 한 폼(이름·성별 prefill·생일·체중·키·아기수) → 멱등 WriteBatch → 육아 자동 착지 + 축하 + "임신 여정 다시보기". crash 시 `PregnancyRecoveryModal` 재개.
- **손실**: ④설정 깊은곳 "임신 정보 정리" → 조용한 모드(주수 freeze · 알림 하드취소 · 진행 UI 숨김 · 데이터 보존 · 선택적 추모 · requestReview/수익화 억제). both면 조용히 육아 복귀(첫째 화면 무침범).

## 5. 데이터 보정 (구 "마이그레이션" — 대형 과제 아님)
전면 마이그레이션 폐기. 필요 보정만: `ownerUserId` 영속화 백필 + 공유 orphan 사본(파트너 트리) 소유자 트리 흡수(유실 복구) + `transitionState=pending` orphan → birthEvent 변환 + Baby 존재 체크. 신규 필드는 additive(기존 무손상). → 서브프로젝트 1에 흡수.

## 6. 안티패턴 / 7. 한국 필수 / 8. 재사용 자산
- **안티패턴**(현 버그 1:1): 상시 출산CTA · 비멱등 전환 · 손실 후 주수증가 · 전환/손실 시 삭제 · 3-state 토글 · 파트너 자기트리 사본 · 죽은기능 1급노출+feature creep. (ia-research.md / feature-inventory.md)
- **한국 필수**: NN주N일+D-day · 한국 태아크기 비유+태담 · 산전검진 주차트리거(NT/쿼드/정밀초음파/임당) · 초음파 주차 타임라인 · 바우처 정보카드(커머스❌) · 광고 0.
- **재사용 자산**: outcome enum(raw 영구계약) · eddHistory · Gender(prefill 버그만 수정) · PregnancyChecklistItem · pregnancy-weeks.json(37주) · WriteBatch transitionState · PregnancyTransitionSheet/RecoveryModal/TerminationView · PregnancyDDayWidget · KickSession · collectionGroup partner read · createdBy(PR#26) · DashboardPregnancyView(→①여정 승격).

## 9. 서브프로젝트 & 빌드 순서 (정정)
1. **국소 P0/P1 수정 + ownerUserId 영속화** (작음·위험낮음, 구 마이그레이션 흡수)
2. **임신 노트 셸 + IA층 교체** (AppContext 활용, 신규 상태머신 없음)
3. **①여정 + ②기록** (핵심 추적 UI)
4. **③검진 + 🔴한국 데이터 큐레이션** (최대 신규작업 — 별도 페이즈)
5. **④더보기** (도구·서가·추억)
6. **출산전환 + 손실** (멱등, 기존 자산)
7. **부부 공유 실시간 + 초대**
8. **콘텐츠 라이브러리(주차/태교) · 커뮤니티 · 운동** (콘텐츠·운영 비용, 후순위)

각 서브프로젝트 = 독립 spec→plan→구현→검증. RC 단계 롤아웃으로 회귀 방지.

## 10. 구현 전 PO 결정 — ✅ 4개 확정 (2026-06-11)
1. ✅ **파트너 쓰기 = 비대칭** (산모 의료수치 / 파트너 읽기+태담·코멘트) — §2.1
2. ✅ **한국 검진/바우처/산모수첩 = 큐레이션 진행** → `context/prenatal-data.md`(의료감수 전 초안)
3. ✅ **RC = 5→25→100% 단계** 확정 (기존 `pregnancy_rollout_pct`)
4. ✅ **v2 `.both` 마이그레이션 = 1회 코치마크** 추가
+ (전략·코드무관) **의사·변호사 감수** = PO 병행 섭외 — zero-base가 짚은 진짜 출시 관문(v1·v2를 죽인 H-items). 코드 품질과 무관.

## 11. 현행 (v2 비활성)
v2 = **main에서 `pregnancyModeEnabled=false`**(v2.8.8/빌드91, PR #31 `9755e19`). App Store 미제출(별도 PO 결정). 라이브 P0 차단됨, 데이터 보존. v3 완료 시 새 구현으로 재활성.

## 패키지 / 열람
`FEATURES.md` · `IA.md` · `SCREENS.md` · `site.html`(모바일: https://docs.roafinance.me/babycare-pregnancy-v3.html?k=911015) · `context/{zerobase-review·ia-research·feature-inventory·issues(v2 stale)}`.
