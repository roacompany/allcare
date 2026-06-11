# 임신모드 v3 재설계 — IA/UX 리서치 종합 (2026-06-11)

6각도 병렬 리서치(한국 IA / 글로벌 리더 IA / 출산전환 / 손실 플로우 / 가족공유 / 모드설계) 종합.
출처 앱: 280days·베이비빌리·마미톡·핑크다이어리·아이마중(KR) / Ovia·Flo·BabyCenter·What to Expect·The Bump·Glow(글로벌) / Apple Health·Firestore RBAC(공유) / Northeastern·DWP(손실).

## 핵심 진단 (6/6 각도 수렴)
BabyCare 4대 버그(임신/아기/both 혼란 · 상시 출산CTA · 공유유실 · 주수증가)는 모두
**"임신 = 전역 모드 플래그"** 단일 데이터모델 결함의 증상이다.
→ 해법: **임신을 모드가 아닌 '프로필 엔티티'(아기와 동급)로 모델링, UI는 통합 카드 스택.**

## IA 골격 옵션
- **A (강력추천) — 임신=unborn 프로필 엔티티 + 통합 카드 스택.** 4-state 분기 제거(프로필 리스트+활성선택으로 환원). both=두 카드 공존(특수분기 아님). 홈=신호기반 동적정렬(D-day 임박+최근기록)+수동핀. 진입 2-track(신규=3-way 온보딩 / 기존=‘아기 추가’ 옆 형제로 ‘임신 등록’). 마이그레이션 비용 최대지만 4대 버그 구조적 동시해소 유일안. → **PO가 '데이터모델까지 새로' 택함 = A와 정합.**
- **B (중간) — 현 4-state 유지+UI만 통합.** 마이그레이션 저비용·단기출시용, 근본결함 잔존(패치성). 공유모델은 B여도 A방식 선도입 필수.
- **C (비추천) — 별도 탭/모드 토글.** 리서치 명시 기각(both 표현불가·인지부하·탭왕복). Glow 앱분리 반면교사.

## 상태머신 (단방향·흡수상태)
`pregnancy 1 → birthEvent 1(idempotency 경계) → baby N(다태아)`

## 안티패턴 Top 7 (현 버그 1:1)
1. 항상 뜨는 '출산했어요' CTA → **36주 이전 노출 금지, 36~39주 dismiss 가능 카드** (Flo/BabyCenter)
2. 비멱등 단발 전환→중복아기 → **birthEventId 멱등키, 이미 delivered면 no-op** (Twiniversity 다태아 구분)
3. 손실 후 주수 계속 증가 → **즉시 freeze + 시간기반→상태기반 콘텐츠** (Ovia 'emotional sucker punch')
4. 전환/손실 시 데이터·공유그룹 삭제 → **삭제 금지, 아카이브 보존** (Apple Health, MEMORY 룰)
5. 임신/아기/both 동등 3-state 토글 → **단계 전환(사건)으로** (글로벌 리더 전원)
6. 파트너 자기 트리에 사본 작성→충돌/유실 → **소유자 단일트리 + roles 맵** (Firestore RBAC) ← 현 공유유실 유력원인
7. 죽은 HealthKit 같은 비작동 기능 1급 노출 + feature creep → **핵심 5기능으로 좁힘**
+ 손실 경로 중 requestReview 발화/수익화/업셀 → **전면 억제**. 'End vs Delete' 이분강요 → **중간 '조용히 보관/추모' 경로**.

## 출산 전환 (정상)
36주 게이트 dismiss카드(‘아직이에요/예정일조정’ 동거) → '출산했어요' → 출산일·성별·체중·키·아기수 한 폼 → 멱등 WriteBatch(birthEventId) → pregnancy outcomeType=born 봉인(CTA·임신알림 자동소멸) → 임신데이터는 baby 타임라인 '임신 기간' 읽기전용 아카이브(삭제❌, eddHistory append-only 유지).

## 손실 경로 (유산/사산/중지) — 한국 리더 전무 = 차별화 기회
별도 IA 브랜치(출산으로도 empty로도 collapse❌) / 소프트 단일진입('더 이상 이어가지 못하게 되었어요') / 주수 즉시 freeze·상태기반 콘텐츠 / 예약알림 하드취소(멱등 teardown) / 데이터 보존 기본·되돌릴수있는 명시삭제만 / 선택적 추모기록(강제·자동프롬프트❌) / 앱평가·수익화 억제 / exactly-once.

## 공유 (Apple Health 모델 + Firestore roles 맵)
**데이터=소유자(산모) 단일 트리, 파트너=읽기 미러** (공유유실 + '누구 트리에 저장' 동시해결, 파트너 사본❌).
초대코드(카톡친화) + 명시 수락(멱등 no-op). **roles 맵 권한분기**: 의료수치(체중·검진·증상)=산모 owner-write/파트너 read-only, 감정·이벤트(초음파·D-day·주수·태교)=파트너 commenter. 비가역 CTA(출산/종료)=소유자 한정·깊은메뉴·멱등. 파트너 화면 '읽기전용' 배지. 입력마다 createdBy(PR #26 보유). revoke/leave=roles UID 제거+미러만 비움(leave≠delete).

## 한국 시장 필수
1. **NN주 N일 + D-day 동시표기**, EDD append-only, LMP/초음파 출처표시
2. **태아 크기 한국 비유**: 12주 라임·16주 아보카도·20주 바나나·24주 옥수수·28주 가지·40주 수박 + 태담
3. **산전검진 = 주차트리거 체크리스트 시드**: 11~13주 NT·16주 쿼드·20주 정밀초음파·24~28주 임당. 검진=날짜+체크+수치+초음파사진 한 객체. (캘린더 과설계❌, 홈카드 '다가오는 검진' 1줄)
4. **초음파 아카이빙 1급**(주차순 타임라인) — 마미톡 단일 킬러기능
5. **단일앱 전생애주기**(임신준비→임신→출산→육아) — BabyCare 이미 정합
6. **국민행복카드/바우처 1회성 정보카드**(외부링크, 커머스❌)
7. **광고·커머스 0 = 구조적 강점**(AdMob 폐기), 핵심 5기능(주수콘텐츠·태동·체중·검진체크·공유)으로 좁힘

## 현 코드 자산 (버리지 말고 재해석)
AppContext 4-state, outcomeType{ongoing|born|miscarriage|stillbirth|terminated}(raw 영구계약), eddHistory append-only, WriteBatch+transitionState, markTransitionPending, PregnancyFirestoreProviding+collectionGroup partner read, PregnancyChecklistItem, pregnancy-weeks.json(37주).
