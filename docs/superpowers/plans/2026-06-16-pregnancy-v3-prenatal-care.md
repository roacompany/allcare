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

## Phase B — 다음 검진 히어로 + 타임라인 노드→검진 추가 (✅ 이 PR, 추가분)

- [x] `NextVisitHeroCard` — `PrenatalVisitPlanner.nextRelevantVisit`(미완료 중 임박 예정, 없으면 최근 지연) + D-day 캡슐(완료/오늘/D-N/D+N 지연)·이번 주 권장 검진 칩(`currentItem`)·[완료 체크] 토글. 검진 0건 → 빈 상태 + [검진 추가].
- [x] 타임라인 노드 탭 → `PrenatalVisitFormSheet` 프리필(visitType=`visitTypeHint`, 예정일=`suggestedDate` LMP+중앙주차). 노드 우측 `+` 아이콘·a11y 힌트.
- [x] 완료 토글 = 기존 `togglePrenatalVisit`(저장 userId = **소유자 path `dataUserId`**, #41 공유 격리 준수).
- [x] TDD: `nextRelevantVisit`(임박/지연 fallback/완료·빈) + `suggestedDate`(LMP 중앙주차/nil) + `visitTypeHint` — **PrenatalScheduleTests 12 green(A6+B6)**.
- [ ] (이연) 타임라인 노드별 **완료/누락 상태 배지**(visit↔검진 주차 매핑) — 노드-방문 fuzzy 매핑이라 별도. 현재는 "추가" 어포던스까지.

## Phase C — 산모수첩 디지털 미러 + 국민행복카드 바우처 (✅ 이 PR, 추가분)

- [x] `MaternalRecordMirrorCard` — 최신 혈압·혈당·체중 칩(`MaternalRecordMirror.latestMeasurements` 순수 추출, 기존 pregnancyVitals/pregnancyWeights 재사용) + "전체 보기" → `MaternalRecordDetailSheet`(체중 `LineMark` 추이 + 혈당 기록). 빈 상태 = ②기록 유도.
- [x] `HappyCardVoucherCard` — `HappyCardVoucher.supportAmount`(단태 100만/다태 140만/분만취약지 +20만, `fetusCount` 기반) + 사용기한·사용처·신청 디스클로저 + 면책. 커머스 0.
- [x] TDD: 미러 최신추출(항목별·빈·부분) + 바우처 금액(단태/다태/취약지) — PrenatalScheduleTests **15 green**(A6+B6+C3).
- [ ] (이연) 자궁저높이·태아추정체중(EFW)=신규 필드 / 바우처 **수동 잔액 입력·진행바**=Pregnancy 필드(@AppStorage 금지 — #41 기기전역 누수). 둘 다 영속 추가라 별도.

## Phase D — 체크리스트 mini + 진료 준비 질문 + 음식 안전 (✅ 이 PR, 추가분)

순수 로직 3종 TDD(`PregnancyChecklistPlanner`·`VisitPrepQuestion`/임베딩·`PregnancyFoodSafety`) → 뷰 3종 → PrenatalCareView 배선.

- [x] `WeeklyChecklistMiniCard` — `PregnancyChecklistPlanner.weeklyHighlights`(현재 삼분기 미완료 top3·주차 미상 폴백) + 완료율 바 + "전체 체크리스트" NavigationLink push(부모 스택·자체 NavigationStack 0). 빈 상태=시작 CTA / 다 완료=긍정 라벨. 토글 저장=소유자 path(#41).
- [x] `VisitQuestionMemoCard` — **영속=PrenatalVisit.preparationQuestions 임베딩 결정**(신규 컬렉션 X·Firestore.Encoder 자동 직렬화·검진과 함께 소유자 path 저장 → #41 자동 준수). 체크(물어봤어요) 토글 + 인라인 vertical TextField 추가. 검진 0건 → 안내. VM 글루=`PregnancyViewModel+PrenatalQuestions.swift`(본체 비대화 방지 분리).
- [x] `FoodSafetyQuickRow` → `FoodSafetySheet` — `PregnancyFoodSafety`(한국 임산부 11항목·의료감수 전 초안·advisory 3레벨[대체로 괜찮아요/주의/피하는 게 좋아요], "안전/위험" 단정 회피) + `.searchable` 이름·키워드 검색 + 면책 배너. 커머스 0.
- [x] TDD: 플래너(삼분기 매핑·완료율·weeklyHighlights·limit·nil 폴백 5) + 질문(Codable 라운드트립·구버전 nil 호환·openQuestionCount 3) + 음식안전(비퇴화·검색 empty/키워드/무매치·대소문자 4) — **PrenatalScheduleTests 27 green(A6+B6+C3+D12)**.
- [x] (이연 — 전부 완료, 후속 4커밋): ① 타임라인 노드별 완료/누락 배지(`PrenatalVisitPlanner.nodeProgress` visit↔주차 fuzzy 매핑, `8213212`) · ② 바우처 수동 잔액+진행바(`Pregnancy.voucherUsedAmount`, `2c8eef9`) · ③ 진료질문 삭제(contextMenu, `8e3c3fc`) · ④ 산모수첩 자궁저높이/EFW 신규 필드(`PregnancyVitalEntry.fundalHeight/estimatedFetalWeight` + 미러 + ②기록 입력폼 섹션, `7696131`). 순수 로직 누적 TDD 41 green. flag-off.

---

## Done Criteria (전체 ③검진)
- [x] 8섹션(면책·히어로·타임라인·바우처·산모수첩·체크리스트·진료질문·음식안전) 노출, 빈 화면 금지.
- [x] 의학 단정 텍스트 0 / 모든 수치·안내 면책 동반 / 임신 데이터 Analytics 미전송.
- [x] 신규 컬렉션 0(질문=PrenatalVisit 임베딩 필드) + arch R3=0. 보라(`DS2.Color.pregnancy`) 톤. `make verify` green(빌드·27 prenatal+전체 유닛·arch R1–4=0·lint 0err·design 100%). flag-off 휴면.

## 출시 선결(PO/H-item)
- 🔴 **산부인과 전문의 의료감수** — prenatal-data.md 전 항목(검진 시기·임당 기준·바우처 금액·산모수첩 참고치)은 초안. 앱 노출 전 검수 필수.
- 법무(개인 의료정보) · dev-flag on 시각 QA · RC rollout.
