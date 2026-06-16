# 임신 v3 — ③검진 PrenatalCareView (서브프로젝트 5) Implementation Plan

> 워크플로우: ①여정·②기록과 동일 — SCREENS.md §③검진 명세를 Phase 분할, 각 Phase 독립 PR, 순수 판정 로직은 TDD, 신규 컬렉션은 Narrow Protocol 5단계. flag-off 휴면.

**Goal:** `PrenatalCareView` stub → 한국 산전관리 허브. 한국 산전검진 일정·국민행복카드 바우처·산모수첩 수치를 주차별 자동 매핑하고 다음 검진 D-day~진료 준비까지 잇는다. SCREENS.md §③검진(8섹션) 참조.

**전제(완료):** 토대 #32 · 셸 #33 · ①여정 #34 · ②기록 #35–38. PregnancyViewModel(`prenatalVisits`·`checklistItems`·`currentWeekAndDay`·`activePregnancy`)·PrenatalVisit(D-day 로직)·pregnancyVitals(②기록 Phase B)·PregnancyChecklistView 재사용.

> **불변 규칙(.claude/rules):** ① 임신 수치 Analytics/Crashlytics 금지(safety.md). ② "정상/위험" 의학 단정 금지 — 참고선·범위·면책만. ③ 신규 컬렉션 = Narrow Protocol 5단계 + arch R3=0. ④ `[String:Any]` 시그니처 금지. ⑤ `babyVM.dataUserId()` 경유. ⑥ NavigationStack 중첩 금지(체크리스트 push는 부모 스택). ⑦ 모든 검진 데이터는 **의료감수 전 초안**(`context/prenatal-data.md`) — 면책 동반, H-item(산부인과 감수) 출시 선결.

---

## Phase A — 면책 배너 + 🔴 한국 산전검진 타임라인 (✅ 이 PR)

주차 자동 매핑의 순수 핵심. 신규 Firestore 0, `activePregnancy.currentWeek`만 사용.

- [x] `BabyCare/Models/KoreanPrenatalSchedule.swift` — `PrenatalScheduleStatus`(past/current/future) + `KoreanPrenatalScheduleItem` + `PrenatalTimelineNode` + `KoreanPrenatalSchedule`(standardItems 7종·`status(for:currentWeek:)`·`timeline`·`currentItem`). 순수, SwiftUI 무의존. 데이터는 prenatal-data.md 표(초기검사/NT/쿼드/정밀초음파/임당GTT/GBS/분만전) — 접종(Tdap·독감)은 검진 아니라 제외(감수주의 #6).
- [x] `BabyCareTests/BabyCareTests+PrenatalSchedule.swift` — 6 tests(경계 포함/주차 미상/정렬/currentItem).
- [x] `BabyCare/Views/Pregnancy/PrenatalCareComponents.swift` — `PrenatalDisclaimerBanner`(라일락 면책) + `KoreanPrenatalTimelineCard` + `PrenatalScheduleNodeRow`(3상태 점·"지금 여기"·Reduce Motion 정적 펄스·VoiceOver 결합 라벨).
- [x] `PrenatalCareView.swift` — stub → 면책 + 타임라인 + 후속 안내 1줄.
- [x] 검증: PrenatalScheduleTests 6 green · build SUCCEEDED · arch R1–4=0 · lint 0 error.

**비범위(Phase A):** 검진객체(PrenatalVisit) 연동(완료/누락 상태)·노드 탭→상세/추가는 Phase B. 타임라인은 현재 주차 대비 권장 시기만 표시(완료 단정 안 함).

---

## Phase B — 다음 검진 히어로 + 타임라인↔검진객체 연동

- [ ] `NextVisitHeroCard` — `PrenatalVisit.daysUntilScheduled/isDueSoon/isOverdue` 재사용(D-day 캡슐·주차 라벨·표준매핑 칩·[진료준비][완료] CTA). 검진 0건이면 빈 상태 카드 + [검진 추가].
- [ ] 타임라인 노드 ↔ PrenatalVisit 매핑: 등록 노드 = 완료/예정 상태, 미등록 = "이 검진 추가하기"(`PrenatalVisitFormSheet` visitType 프리필). `KoreanPrenatalScheduleItem.id` ↔ visit 표준유형 매핑.
- [ ] 완료 토글 = OptimisticReplaceable(낙관 업데이트+rollback) + 타임라인 동기화.
- [ ] TDD: 노드-방문 매핑/완료 상태 파생(순수). make verify green.

## Phase C — 산모수첩 디지털 미러 + 국민행복카드 바우처

- [ ] `MaternalRecordMirrorCard` — 최신 수치 칩 그리드(혈압·혈당=pregnancyVitals 재사용 / 체중=pregnancyWeights / 자궁저높이·태아추정체중=신규 필드 또는 PrenatalVisit 확장) + "전체 보기" → `MaternalRecordDetailSheet`(Apple Charts sparkline).
- [ ] `HappyCardVoucherCard` — 단태/다태 한도(prenatal-data.md: 100/140만·분만취약지 +20만)·사용기한 안내 + 수동 잔액 입력(카드사 미연동)·진행바 clamp. 커머스/결제 0. "실제 잔액은 정부24/카드사 확인" 면책.
- [ ] 신규 영속 필드(바우처 잔액·자궁저높이·EFW) = Narrow Protocol 5단계 또는 Pregnancy/PrenatalVisit 확장. arch R3=0.

## Phase D — 체크리스트 mini + 진료 준비 질문 + 음식 안전

- [ ] `WeeklyChecklistMiniCard` — PregnancyChecklistView 재사용(완료율 바·"전체" push, 자체 NavigationStack 금지).
- [ ] `VisitQuestionMemoCard` — 다음 검진 연결 질문 리스트(체크 메모) + 인라인 추가. 영속 위치(visit 임베딩 vs 신규) 결정.
- [ ] `FoodSafetyQuickRow` → `FoodSafetySheet`(한국 임산부 맥락 빠른 조회, 도구함 자산).

---

## Done Criteria (전체 ③검진)
- [ ] 8섹션(면책·히어로·타임라인·바우처·산모수첩·체크리스트·진료질문·음식안전) 노출, 빈 화면 금지.
- [ ] 의학 단정 텍스트 0 / 모든 수치·안내 면책 동반 / 임신 데이터 Analytics 미전송.
- [ ] 신규 컬렉션·필드 = Narrow Protocol 5단계 + arch R3=0. 보라(`DS2.Color.pregnancy`) 톤. `make verify` green. flag-off 휴면.

## 출시 선결(PO/H-item)
- 🔴 **산부인과 전문의 의료감수** — prenatal-data.md 전 항목(검진 시기·임당 기준·바우처 금액·산모수첩 참고치)은 초안. 앱 노출 전 검수 필수.
- 법무(개인 의료정보) · dev-flag on 시각 QA · RC rollout.
