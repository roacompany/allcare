# Changelog

All notable changes to BabyCare are documented here.

## [2.8.3] - 2026-05-12 (TestFlight 빌드 67/68)

### Added — Weekly Highlights v2 (Phase 1 ML 활용)

- **자동 롤링 티커**: 대시보드 상단 5초 간격 자동 전환, reduceMotion 대응 (TimelineView)
- **AI 요약 bottom sheet**: 하이라이트 탭 → Sparkline + Claude 4.5 Haiku 200자 요약 + 폴백
- **Sparkline 4 카드 그리드**: feeding/sleep/diaper/health (LazyVGrid + .equatable + WoW 변화율)
- **AI 캐시 아키텍처**: iOS 앱은 Firestore `highlightCache` read-only. 본인 Claude Code Pro 구독으로 처리 — babycare-admin Vercel Cron (02 KST daily) → cloudflared tunnel → Mac LaunchAgent → `claude` CLI → Firestore. 동시성/약관/비용 동시 해결.
- **FeatureFlagService.isHighlightV2Enabled**: 3-layer (compile-time flag + RC `highlight_enabled` + DJB2 `highlight_ticker_pct` cohort)
- **XOR 통합**: DashboardView `weeklyInsightsCard` v1 fallback / v2 active 안전망
- **AI payload allowlist**: baby.name/birthDate/일기 본문 0 (의료앱 안전)

### Changed

- **InsightService.topHighlights**: allowlist + AppContext gating (feeding/sleep/diaper/health 만, pregnancy_ leak 0)
- **FirestoreCollections**: `highlightCache` 추가 (32번째)
- **RC 2 키**: `highlight_enabled` / `highlight_ticker_pct` (0% rollout default)
- **Analytics**: 7개 이벤트 (`highlight_shown/tapped/ai_loaded/...` weekKey/babyId 미포함, 준개인정보 보호)

### Tests

- 단위 테스트 +17 (allowlist / scoring / cohort / fallback)
- XCUITest +5 (a11y 5 identifiers, `weeklyInsightsCardV1` fallback)
- QA evidence — H-3 AI 의료 감수 25 샘플 / H-4 Firestore audit / H-7 Performance 보류

### Known Issues

- **CI Test 단계 인프라 부채**: macos-15 + Xcode 26.x + iOS 26.2 simulator 조합에서 `signal abrt before bootstrapping` (rules/simulator-targets.md documented). PR #5 머지는 admin override — 별도 PR 로 분리 예정. Build/Lint/Arch 는 PASS.
- 실기기 무회귀 검증, RC `highlight_enabled` 활성화, AI 의료 감수 25 샘플은 후속 작업.

## [2.8.2] - 2026-05-10 (TestFlight 빌드 65/66, App Store READY_FOR_SALE)

### Added — Phase 1 ML 인사이트

- **InsightScorer 프로토콜**: HeuristicScorer / StatisticalAnomalyScorer / HybridScorer + Factory
- **WeeklyMetricSnapshot**: Firestore 영속 (`users/{uid}/babies/{bid}/weeklyMetrics/{YYYYWnn}`) — per-baby Z-score history
- **Hybrid mode**: history ≥ 4주면 per-baby Z-score, 미만이면 Heuristic fallback (신규 사용자 회귀 0)
- **InsightWeights RC 외부화**: 9개 medical weight + scorer_mode + min_history_weeks + history_weeks
- **Analytics 3종**: `insight_generated/shown/tapped` (Phase 2 supervised label 수집)
- **Admin Insights ML 탭**: `/api/users/[uid]/insights/[bid]` Top 3 score / 전체 metric / 주차별 시계열 / RC default 가중치 (babycare-admin `33acb7f`)

### Changed

- **InsightProvider 4분할**: Feeding/Diaper/Sleep/Health (sub-metric 분리)
- **InsightScoringService**: scorer 디스패치 + telemetry
- **Firestore**: 31개 컬렉션 (30 + weeklyMetrics)

### Build & Deploy

- v2.8.2 빌드 65/66 — `make deploy` full chain PASS
- 354 단위 테스트 PASS (+9 Phase 1 ML)
- `make plan-verify` 파일 경로 brace glob 금지 학습 (build-gotchas.md)
- ASC API 5-step 자동 제출 → AFTER_APPROVAL READY_FOR_SALE

## [2.8.1] - 2026-05-06 (App Store READY_FOR_SALE)

### Fixed — AdMob 정책 차단 hotfix

- **`FeatureFlags.adsEnabled = false`**: 1-line kill switch (SDK init + AdBannerView UI 모두 가드, 코드 보존)
- 정책 차단 사유: AdMob Console 확인 + 항소 사용자 액션 필요
- TestFlight 빌드 65 → App Store 자동 출시

### Note

이후 v2.8.x 후속에서 AdMob 완전 폐기됨 (`ddb63d1`): SDK/UI/Info.plist/SKAdNetwork/app-ads.txt/privacy.html 일괄 제거. 12 파일 -467 lines.

## [2.8.0] - 2026-05-02 (TestFlight 빌드 63/64, App Store READY_FOR_SALE)

### Added — 임신 모드 v2 재설계

- **AppContext 4-state enum**: `empty/babyOnly/pregnancyOnly/both` 중앙화 (`AppContext.resolve(babies:pregnancy:)` static factory)
- **Hybrid 게이팅**: 컴파일타임 `FeatureFlags.pregnancyModeEnabled` (Layer 1 guard) + `FeatureFlagService` 단일 gateway로 RC `pregnancy_mode_enabled` (Layer 2, fetch 실패 fallback=false). DJB2 deterministic cohort.
- **PregnancyFirestoreProviding narrow protocol** + **MockPregnancyFirestore**
- **WriteBatch + transitionState**: 출산 전환 atomic, `markTransitionPending` 2-step 패턴, `FieldValue.delete()` rollback
- **EDD `eddHistory` append-only** (덮어쓰기 금지)
- **PregnancyWidgetDataStore**: lmpDate/dueDate 원본 저장, Provider 동적 계산, FeatureFlag=false 시 clearIfFlagDisabled
- **DashboardPregnancyHomeCard**: baby > pregnancy 우선순위 (`babies.isEmpty=false`면 baby UI 유지, 카드 additive)
- **PregnancyRecoveryModal**: transitionState=pending orphan Resume UI
- **PregnancyTerminationView**: 출산/종료 CTA 분리

### Fixed — AdMob 미노출

- ASC API 직접 조회: `isOrEverWasMadeForKids=false` → COPPA 의무 대상 아님
- `tagForChildDirectedTreatment = true` → `false` (광고 풀 5-20% 축소 해제)
- 정책 충돌 0 (privacy.html / IDFA 약속 / ATT 무관)

### Tests

- XCUITest 18 (+8) — 임신 플로우
- 단위 345 (+26) — KickSession/PregnancyDateMath/PregnancyOutcome/CryAnalysisViewModel/a11y

### Build & Deploy

- Firebase 11.9.0 hotfix (PR #3 `7d80f93`) — Swift 6 concurrency Issue #14257
- firestore.rules collectionGroup Partner read 배포 (top-level `match /databases/{db}/documents` scope 필수)
- v2.8.0 빌드 63/64 ASC API 5-step 자동 제출 → AFTER_APPROVAL 출시

## [2.7.1] - 2026-04-19 (TestFlight 빌드 62)

### 빌드 61 → 62: 임신 모드 임시 hide

5빌드 회귀 누적 + 검증 부족 영역 다수로 인해 `FeatureFlags.pregnancyModeEnabled = false`.
- UI 6곳(ContentView/Dashboard/Health/Recording/Settings/AddBaby) 자동 hidden
- Firestore 데이터는 보존 (사용자 자기 임신 기록 그대로)
- 재설계 spec(v2.8+) 완료 후 복귀 예정
- TestFlight 빌드 62 — Delivery UUID `34d596a2-fecc-4a4d-9f2b-98c6969c79df`

### Hot fixes (빌드 60 → 61)

- **fix(badges) H-4 회귀**: 가족 공유 시 owner 배지가 파트너에게 노출되던 회귀 수정.
  `babyVM.dataUserId()` (owner uid) 전달 → `BadgeEvaluator` → owner path 저장 + 파트너 화면에 노출.
  fix: `saveActivity/Growth/quickSave`에 `currentUserId` 별도 파라미터 추가, 배지 부여만 본인 path
  강제. `BadgeHomeStrip/BadgeGalleryView`도 `authVM.currentUserId` 직접 사용.
- **fix(a11y) H-8 회귀**: AccessibilityXXXL에서 AddBabyView "아직 태어나지 않았나요?"
  진입점 미노출 회귀. `ViewThatFits(in: .horizontal)`로 horizontal/vertical 자동 분기.

### Added — 임신 모드 (P0)

**임신 데이터 모델**
- Pregnancy, KickSession, PrenatalVisit, PregnancyChecklistItem, PregnancyWeightEntry 6모델
- PregnancyOutcome enum (ongoing/born/miscarriage/stillbirth/terminated)
- FirestoreCollections 5개 추가 (pregnancies, kickSessions, prenatalVisits, pregnancyChecklists, pregnancyWeights)
- WriteBatch 기반 Pregnancy→Baby 원자적 전환 (transitionState 복구 지원)

**임신 모드 UI**
- 온보딩 + 설정→아기 추가: AddBabyView "아직 태어나지 않았나요?" 진입점 → PregnancyRegistrationView (LMP/EDD 상호 계산)
- 홈 탭: DashboardPregnancyView (D-day 카드, 주차별 정보, 체크리스트 프리뷰, 다음 산전 방문)
- 건강 탭: HealthPregnancyView (태동 세션, 산전 방문 목록, 체중 차트)
- + 버튼: 임신 모드 항목 세트 (태동/방문/체중/증상)
- 산전 체크리스트: 카테고리별 (1/2/3분기 + 출산 준비), 번들 템플릿 + 사용자 추가
- 출산 전환: 2단계 확인, WriteBatch 원자적 전환, 축하 화면 → 육아 모드
- 이전 임신 이력: PregnancyArchiveView (설정 탭)

**임신 D-day 위젯**
- PregnancyDDayWidget (systemSmall/systemMedium/accessoryCircular)
- lmpDate/dueDate 원본 저장 + Provider 동적 계산 (앱 미실행 시에도 주차/D-day 갱신)
- 일 단위 타임라인, WidgetColors 다크모드 대응

**파트너 공유**
- Pregnancy.sharedWith 배열 기반 read-only 공유
- PregnancyShareView (이메일 초대 → sharedWith 추가/제거)
- firestore.rules: 파트너 읽기 허용, 쓰기 차단

**HealthKit 연동**
- HealthKitPregnancyService (opt-in, .pregnancy 타입)
- 설정 탭 토글, 권한 거부 시 graceful fallback

**기타**
- FeatureFlags.pregnancyModeEnabled 게이팅 (6곳)
- Localizable.strings 임신 키 91개
- 위젯 타겟 ko.lproj/Localizable.strings 추가
- PregnancyWidgetSyncService (VM 변경 시 자동 위젯 동기화)

**증상 일지 (PregnancySymptom)**
- PregnancySymptom 모델 + Severity enum (mild/moderate/severe, 선택)
- pregnancies/{pid}/pregnancySymptoms 서브컬렉션 (cascade delete 포함)
- PregnancySymptomMemoSheet 저장 연동 (RecordingView 진입점)
- pregnancySymptoms FirestoreCollections 상수 (총 6 임신 컬렉션)

**임신 주차 콘텐츠 확장**
- pregnancy-weeks.json 10주 → 37주 연속 (4-40주, ACOG/대한산부인과학회 일반 정보 기반)
- 의료 전문가 스팟체크 의뢰 대상

### Added — 배지 시스템 백필

- BadgeEvaluator.backfillIfNeeded: 시스템 도입 전 누적 활동/성장 기록을
  count() 집계로 1회 백필 → UserStats 절대값 set + threshold 도달 배지
  silent 부여 (firstRecord/feeding100/sleep50/diaper200/growth10/
  routineStreak3·7·30)
- UserStats.migratedAtV1 idempotency flag
- FirestoreService+Activity/Growth: count() + earliest fetch API
- FirestoreService+Stats: setStatsAbsolute (절대값 덮어쓰기)
- ContentView 런칭 훅: 로그인 + babies 로드 후 백필 실행

### Fixed
- PregnancyViewModel environment 주입 누락 (BabyCareApp)
- loadActivePregnancy 앱 시작 시 미호출 (ContentView.task)
- 위젯 주차/D-day 정적 스냅샷 → lmpDate/dueDate 동적 계산
- updateEDD 시 위젯 sync 누락
- transitionToBaby 시 위젯 clear 누락
- BadgeEvaluator silent failure: try? → do/catch + OSLog (subsystem
  com.roacompany.allcare, category Badge)
- BadgeHomeStrip race: .task(id: uid) + presenter.current 관찰 자동 리프레시
- 백필 robustness: fetchStats throw 시 재시도 가능 (return false), per-baby
  partial fail 시 migratedAtV1 미마킹 → 다음 런치 재시도
- **빌드 58**: ContentView gating `babies.isEmpty AND !activePregnancy → onboarding`
  (이전: pregnancy 있어도 onboarding으로 떨어짐). AddBabyView onDismiss `babyVM.resetForm()`
  추가. PregnancyRegistrationView LMP/EDD DatePicker range 제약 + createPregnancy
  서비스 레벨 validation + 활성 임신 중복 방지.
- **빌드 59**: fetchActivePregnancy composite index 누락 → firestore.indexes.json
  (outcome + createdAt DESC) 등록 + deploy. AdBanner per-instance 복원 (UIView
  single-parent 위반 회귀): 각 placement가 자체 BannerView + 독립 backoff retry.
- **빌드 60 (CRITICAL)**: baby/pregnancy 공존 시 baby UI 우선
  (DashboardView/HealthView/RecordingView 3곳 gating: `babies.isEmpty &&
  activePregnancy != nil`). Settings "활성 임신 삭제" escape hatch 추가
  (cascade subcollection delete). XCUITest 1개 + 단위 테스트 4개 회귀 방지.

### Internal
- 테스트 195 → 252 단위 + 9 XCUITest (PregnancyFlowTests, 빌드 56 회귀 방지 3건 포함)
- privacy.html 임신 데이터 수집 항목 + HealthKit 고지 추가
- terms.html 제5조의2 임신 모드 면책 조항 추가
- 하네스 보강 (5 신규 make 타겟): `plan-verify` (PLAN ↔ 코드 1:1 검증),
  `smoke-test` (시뮬레이터 런치 + 크래시 체크), `qa-check` (QA evidence 게이트),
  `ui-test` (XCUITest 9개), `deploy-rules` (Firestore rules + indexes 자동 배포)
- `make index-check` 신규: Firestore composite index 누락 조기 탐지 (silent
  failure 예방). 기존 코드의 announcements/purchases/todos 3개 gap 식별
- `BadgeFirestoreProviding` protocol + `MockBadgeFirestore` 도입 (BadgeEvaluator
  통합 테스트 가능, ISP 패턴)
- `bug-triage` agent 추가 (Layer 0/Firestore → 1/Gating → 2/아키텍처 → 3/로직
  진단 순서로 root cause 파악)
- `firestore-collection` skill 보강 (indexes.json + rules + deploy-rules 게이트)
- `.claude/rules/safety.md`: 임신 모드 6개 금지 규칙 (Analytics/EDD 덮어쓰기/
  WriteBatch 출산전환/위젯 데이터 분리/baby > pregnancy gating 등)
- `.claude/rules/swift-conventions.md`: UIView single-parent 룰 (빌드 59 회귀
  교훈)
- `make verify` ALL CHECKS PASSED
- arch-test 0 violations 유지
- harness-score 96% Grade A 유지

### Release Notes (TestFlight / App Store, 한국어)

> 임신 모드를 새롭게 출시했습니다. LMP/EDD 기반 주차 계산, D-day 위젯, 태동
> 기록, 산전 진찰·체중·증상 일지, 출산 준비 체크리스트, 파트너 공유, Apple
> Health 연동까지 출산 전 모든 여정을 도와드립니다. 출산 후에는 한 번의 탭으로
> 육아 기록으로 전환됩니다. 안정성과 성능도 함께 개선했습니다.

### Release Notes (English, summary)

> Introducing Pregnancy Mode: due-date countdown widget, kick session tracking,
> prenatal visits, weight & symptom journal, trimester checklists, partner
> sharing, and Apple Health integration. One-tap conversion from pregnancy to
> baby tracking after birth. Plus stability and performance improvements.

---

## [2.7.0] - 2026-04-15

### Added — Feature Enhancement Rollout (9 Items)

**대시보드**
- 컨텍스트 인사이트 카드 4종 (수유/수면 예측/건강 알림/성장 마일스톤) — `InsightService`

**수면 분석**
- 수면 퇴행 자동 감지 (4/8/12개월 ±2주, -20% 임계)
- 최적 취침 시간 추천 (최근 7일 밤잠 중앙값 ±30분)
- 낮잠 vs 밤잠 비율 트렌드
- 수면 품질 점수 (총수면 + 깨는 횟수 + 낮잠 적정성)

**예방접종**
- D-day 카운트다운 카드 + 대시보드 알림
- D-14 / D-7 / D-1 단계별 푸시 알림
- 부작용 기록 (6 type × 3 severity)
- 완료율 ProgressView (0/34 + 지연 N건 배지)

**일기**
- 월간 기분 분포 자동 요약
- 1/3/6/12개월 전 오늘 회고 카드
- Apple Charts 기반 월별 기분 트렌드
- 사진 갤러리 모드 (3열 LazyVGrid)

**식품 안전 (이유식 ↔ 알레르기 연동)**
- 이유식 기록 시 알레르기 반응 자동 제안
- 식품별 시도 히스토리 타임라인 (첫 시도 → 재시도 → 안전 확인)
- 안전 / 주의 / 금지 분류 대시보드
- 최근 90일 이유식 데이터 자동 로드

**병원 리포트**
- 소아과 방문 체크리스트 자동 생성 (다음 접종 D-day / 성장 이상 / 증상 키워드)
- 성장 백분위 요약 + 최근 2주 활동 요약 PDF 임베드
- PDF 공유 버튼 (AirDrop / Messages / Mail)

**제품 추천**
- 월령 기반 자동 추천 (0~36개월 정적 카탈로그 30개)
- 소모품 재구매 푸시 알림 + 대시보드 카드
- 쿠팡 딥링크 (SafariView)
- 인기 용품 섹션 (구매 기록 기반 Top N)

**위젯**
- 다음 수유 예상 위젯 (FeedingPredictionService v2)
- 다음 낮잠 예상 위젯
- 오늘 활동 요약 위젯 (수유/수면/기저귀)
- 성장 백분위 위젯 (WHO 밴드 기반, 면책 문구 포함)
- Lock Screen 위젯 3종 (iOS 17+ accessoryCircular / Rectangular / Inline)

### Changed

- 배지 Phase 2 코드 리뷰 반영: 공유 아기 경로(`babyVM.resolvedUserId`), `LocalizedStringKey("badge.detail.close")`, `UINotificationFeedbackGenerator` 인스턴스 재사용, `@unknown default`
- `Vaccination` 모델: `sideEffectRecords: [VaccineSideEffect]?` + `daysUntilScheduled` computed property (startOfDay 비교)
- `HealthViewModel`: `nextVaccination`, `vaccinationCompletionRate`, `vaccinationCompletionText`
- `PDFReportService`: `RenderContext` struct로 파라미터 정리, 3개 페이지 추가

### Fixed

- `HealthView`: `solidFoodActivities`가 `todayActivities`로 제한되던 문제 → 최근 90일 fetch
- `GrowthView.saveRecord` 호출 시 `baby` 파라미터 전달 → 위젯 동기화 활성화

### Internal

- 단위 테스트 107 → 195 (+88)
- `make verify` ALL CHECKS PASSED
- arch-test 0 violations 유지
- harness-score 96% Grade A 유지

---

## [2.6.2] - 2026-04-11

### Added
- 울음 분석 (베타, stub) — Health 탭 → 5초 녹음 → 5 라벨 확률 (hungry/burping/bellyPain/discomfort/tired)
- AdMob production App ID + Banner Unit ID + SKAdNetworkItems 43개 확장
- 성장 차트 v2 (WHO AreaMark 밴드 3rd~97th + 백분위 추이)
- Firebase Analytics (GA) 통합 (10개 뷰 트래킹)
- 패턴분석 v2 (발열 연속일, 데이터 품질 경고, 기간 비교)
- FloatingTimerBanner (메인 화면 진행 중 타이머)

### Fixed
- AdBannerView `UIScreen.main` → scene-aware `safeScreenWidth()` (iOS 26.5 Beta 크래시 fix)
- Live Activity 실시간 카운팅 + leftover cleanup + race condition
- TimeAdjustment 미래 시점 클램프
- 캘린더 월 전환 로딩 인디케이터
