# BabyCare (베이비케어 - AI 육아기록)

## Planning (기획 프로세스)

```
/specify [설명]           → .dev/specs/{name}/PLAN.md 생성
/specify --autopilot      → 무인 플랜 생성
/specify --quick           → 경량 플랜
/execute {name}           → PLAN.md 기반 자동 실행
```

- 스펙: `.dev/specs/{name}/PLAN.md` (활성) / `.dev/specs/done/{name}/` (아카이브)
- 컨텍스트: `.dev/specs/{name}/context/` (outputs.json, learnings.md, issues.md, audit.md)

## Design (디자인 시스템)

```bash
make design-verify   # ROA 토큰 검증 (100%)
make design-sync     # 토큰 → DesignSystem.generated.swift
make screenshots     # 주요 화면 스크린샷 캡처
```

- 디자인 토큰: `design/tokens/babycare-tokens.json`
- ROA 설정: `.roa-design.json` (brand: #FF9FB5)
- 위젯 다크모드: `WidgetColors` adaptive enum

## Build & Deploy (Makefile)

```bash
make build         # xcodegen + xcodebuild
make test          # 단위 테스트 345개
make lint          # SwiftLint 검사
make arch-test     # 아키텍처 경계 검사
make verify        # 빌드 + 린트 + 아키텍처 + 테스트 + 디자인토큰
make plan-verify   # PLAN ↔ 코드 1:1 검증 (활성 spec)
make smoke-test    # 시뮬레이터 런치 + 크래시 체크
make qa-check      # QA evidence 파일 게이트
make ui-test       # XCUITest (PregnancyFlowTests 18개)
make deploy-rules  # Firestore rules + indexes 자동 배포
make deploy        # 원커맨드 배포 (verify→bump→archive→export→upload)
make bump          # 빌드 번호 +1
make status        # 버전/커밋/테스트 상태
```

## Architecture

- **패턴**: @MainActor @Observable MVVM, AppState 싱글톤 (23 VM)
- **서비스 분리**: ActivityTimerManager, FeedingPredictionService v2 (day/night 개인화), WeeklyInsightService v3 (Provider+Scoring+per-baby Z-score), PercentileCalculator, MedicationSafetyService
- **주간 인사이트 v3 (Phase 1 ML)**: `Services/Insights/` — `InsightProvider` (Feeding/Diaper/Sleep/Health, sub-metric 분리), `InsightScorer` 프로토콜 (HeuristicScorer / StatisticalAnomalyScorer / HybridScorer + Factory), `InsightScoringService` 디스패치, `InsightWeights` RC 외부화. **WeeklyMetricSnapshot** Firestore 영속 (`users/{uid}/babies/{bid}/weeklyMetrics/{YYYYWnn}`) — per-baby history 입력. Hybrid mode: history ≥ minSamples(=4)면 Z-score, 미만이면 Heuristic fallback (신규 사용자 회귀 0). RC: `insight_scorer_mode` / `insight_min_history_weeks` / `insight_history_weeks` + 9개 medical weight. Analytics: `insight_generated/shown` 발화 (Phase 2 supervised label 수집 — `insight_tapped`는 탭 가능 UI 추가 시 logInsightTapped 연결). 임신 데이터는 절대 포함 금지 (safety.md).
- **성장 차트**: GrowthView+Charts — Apple Charts AreaMark WHO 밴드(3rd~97th) + 백분위 추이 트렌드
- **인프라**: RetryHelper (지수 백오프), OfflineQueue (쓰기 큐잉+자동 sync), CachedAsyncImage (2-tier), NetworkMonitor
- **가족 공유**: Baby.ownerUserId + BabyViewModel.dataUserId() — 공유 아기 데이터 경로 자동 라우팅
- **Firestore**: 200MB persistent cache, 30개 컬렉션 상수 (FirestoreCollections 24개 + 6 pregnancy), 페이지네이션 (일기 커서/구매 limit/할일 필터). collectionGroup Partner read 규칙 배포 (2026-04-23)
- **배지 시스템**: Badge/UserStats 모델, BadgeCatalog 8개, FirestoreService+Badge/Stats, BadgeEvaluator 단일 진입점 + Activity/Growth/Routine save path 연동. Phase 2 UI: BadgePresenter + BadgeViewModel (@Observable, arch-test baseline 0) + BadgeSnackbarView + BadgeGalleryView (3-section grid + BadgeTileView + BadgeDetailSheet) + BadgeHomeStrip (Dashboard top) + SettingsView "내 배지" row + Localizable.strings 25 keys — `.dev/specs/badges-ui/PLAN.md` (14 A-items 완료, 5 H-items QA 대기)
- **분석**: Services/Analysis/ — 6단계 파이프라인
- **Narrow Protocol 패턴 (11종, ISP)**: 신규 Firestore 컬렉션 추가 시 5단계 필수 — (1) `FirestoreCollections.X` 상수 (2) `FirestoreService+X.swift` 확장 (3) `XFirestoreProviding` narrow protocol + `extension FirestoreService: XFirestoreProviding {}` (4) `BabyCareTests/MockXFirestore.swift` (호출 카운터 + 에러 주입) (5) `firestore.rules` / `firestore.indexes.json` 확인. 완성 11종: Pregnancy / Badge / Cry / AuthMigration / Storage / FCMToken / Catalog / Sound / Analysis / OfflineQueue / Highlight. arch-test Rule 3 baseline=0 강제 (Firestore.firestore() 직접 호출 금지).
- **VM Helper Protocol**: `ViewModels/Helpers/ViewModelHelpers.swift` — `LoadingStateful` (`withLoading { ... }` defer 누락 invariant 보장) + `OptimisticReplaceable` (`optimisticReplace(in:original:with:save:)` ReferenceWritableKeyPath 기반 자동 rollback). ViewModel 동시 채택 가능. 호출처 8건 적용 (HealthVM/ActivityVM/RoutineVM).
- **AppLogger**: `Utils/AppLogger.swift` — 단일 subsystem (Bundle.main.bundleIdentifier), **15 카테고리** (admin / analysis / analytics / auth / badge / calendar / catalog / firestore / highlight / liveActivity / ml / pregnancy / push / sound / todo). `print()` 금지, `Logger(subsystem:category:)` 직접 선언 금지 (Round 7 baseline=0), non-fatal silent error 는 `logSilent(_:error:logger:)` 경유 (Crashlytics 단일 후크 후보).
- **임신 모드 v2 (v2.8.0+)**: Hybrid 게이팅 — 컴파일 타임 `FeatureFlags.pregnancyModeEnabled` (Layer 1 guard) + `FeatureFlagService` 단일 gateway로 RemoteConfig `pregnancy_mode_enabled` (Layer 2, fetch 실패 시 fallback=false). StableHash DJB2 deterministic cohort. AppContext 4-state enum (`empty/babyOnly/pregnancyOnly/both`)로 앱 상태 중앙화 — `AppContext.resolve(babies:pregnancy:)` static factory. PregnancyFirestoreProviding narrow protocol + MockPregnancyFirestore (BadgeFirestoreProviding 패턴). outcomeType enum(`ongoing|born|miscarriage|stillbirth|terminated`, raw value 영구 계약), WriteBatch + transitionState 전환 (atomic). `markTransitionPending` 2-step 패턴. EDD `eddHistory` 배열 append-only. `PregnancyViewModel.dataUserId()` 공유 패턴. 임신 데이터 Analytics payload 금지. PregnancyWidgetSyncService→PregnancyWidgetDataStore (lmpDate/dueDate 원본 저장, 위젯 Provider 동적 계산, FeatureFlag=false 시 clearIfFlagDisabled). HealthKit 연동 (opt-in). 파트너 공유 (sharedWith collectionGroup read). baby > pregnancy UI 우선순위: `babies.isEmpty`가 false이면 baby UI 유지 + DashboardPregnancyHomeCard 카드 additive. DashboardPregnancyHomeCard / PregnancyRecoveryModal (transitionState=pending orphan Resume UI) / PregnancyTerminationView (출산/종료 CTA 분리). FieldValue.delete()로 transitionState 필드만 rollback (문서 보존). `activePregnancy != nil` 단독 체크 금지.
- **탭**: 홈 | 캘린더 | ➕기록 | 건강 | 설정

## Conventions

- Swift 6.0, iOS 17+, 100% SF Symbols
- 모델: `Identifiable, Codable, Hashable` 채택, 신규 필드 optional
- Firestore 컬렉션명: 반드시 `FirestoreCollections.*` 상수 사용 (하드코딩 금지)
- 색상: `AppColors` enum (Asset Catalog 18개 Dynamic Color)
- 의학 데이터: 면책 문구 필수
- AI 가드레일: AIGuardrailService.prohibitedRules 수정 금지
- 테스트: BabyCareTests.swift 단일 파일에 append (도메인 분리 예외: Pregnancy / Widgets / FeatureFlags / WeeklyHighlights 선례, 단일 파일 4,900+라인 임계 초과 시)
- 공유 아기 데이터: `babyVM.dataUserId()` 사용 필수 (authVM.currentUserId 직접 사용 금지)
- 로깅: `print()` 금지 — 모든 진단은 `AppLogger.<category>` 경유 (PII 자동 마스킹). silent error 는 `logSilent` helper.

## Must NOT Do

- Baby.gender Optional 변경 금지
- AIGuardrailService 금지어 수정 금지
- 백분위 의학적 판단 텍스트 금지
- 외부 차트 라이브러리 금지 (Apple Charts만)
- 데이터 로딩/저장 시 authVM.currentUserId 직접 사용 금지
- 임신 데이터를 Firebase Analytics/Crashlytics custom params에 포함 금지 (민감 건강정보)
- KickEvent 별도 서브컬렉션 생성 금지 (KickSession.kicks 배열 임베딩)
- EDD 덮어쓰기 금지 (eddHistory append 강제)
- 출산 전환을 단일 write로 처리 금지 (WriteBatch + transitionState 필수)
- Pregnancy 위젯 데이터를 기존 WidgetDataStore에 병합 금지 (PregnancyWidgetDataStore 분리)
- `print()` 직접 호출 금지 — `AppLogger.<category>` 경유 (PII 마스킹, Console.app 필터 활용)
- `Firestore.firestore()` 직접 호출 금지 (ViewModels/Views/그 외 Services) — `FirestoreService+X.swift` 경유 필수. arch-test Rule 3 자동 차단 (baseline=0).

## Harness

harness-score: 96% (Grade A) — 2026-04-17

### 완성 단계 정의 (중요)

"완성"은 **3단계**로 분리한다. TODO done = 완성 아님.

| 단계 | 마커 | 의미 | Gate |
|---|---|---|---|
| **coded** | `[x]` | 코드 작성 + `make verify` PASS | 단위 테스트 + lint + arch |
| **verified** | `[V]` | 실기기/시뮬레이터 사용자 플로우 검증 완료 | `make smoke-test` + QA evidence 파일 |
| **shipped** | `[S]` | TestFlight 업로드 + 빌드 번호 기록 | `make deploy` 완료, 사용자 검증 |

- PLAN.md 항목 체크 시 위 기호 사용
- `make deploy`는 `verified` 단계까지 통과한 것만 shipped로 인정
- CLAUDE.md "Recent Changes" 섹션에는 shipped만 기록

## Recent Session (2026-06-10) — 앱 평가(App Store 리뷰) 팝업 + v2.8.7 빌드 89 TestFlight

### 앱 평가 팝업 (PR #29, squash `9366769`)
- PO "앱평가 팝업 추가" → brainstorm → spec → plan → 서브에이전트 3명 TDD 구현 → 적대적 코드리뷰(CRITICAL/HIGH 0, MEDIUM 1건 즉시 수정) → PR #29 CI Verify pass → 머지
- `AppReviewPromptService` (@MainActor @Observable, **순수** one-shot 게이트 · UserDefaults `autoReviewPromptConsumed` · StoreKit/SwiftUI/Firestore 무의존 · 원자 check-and-set) + `ContentView` 단일 초크포인트 (`@Environment(\.requestReview)` — scene 활성 · 배지 스낵바 없음 · 라이브 `UIApplication.applicationState` 가드로 700ms 정착 중 백그라운드 전환 시 샷 보존)
- 트리거 v1 = 기록 누적 20개(`ActivityViewModel+Save.evaluateBadgesIfNeeded`, `fetchStats` narrow protocol) + 병원리포트 완료(`HospitalReportSheet.onChange`). 먼저 도달한 1개만. 설정 > 정보 "리뷰 남기기" 딥링크(자동 1회와 **독립**). `FeatureFlags.appReviewPromptEnabled` 컴파일 킬스위치. analytics `review_prompt_requested {trigger, source}`
- ⚠️ `@Environment(\.requestReview)`는 **`import StoreKit` 필요**(Xcode 26.5). 배지·하이라이트 트리거는 v1.1 보류(스펙 §12). 스펙/플랜 = `docs/superpowers/{specs,plans}/2026-06-10-app-review-prompt*`
- 단위 테스트 7개 + `make verify` green(arch R1–4=0, design 29/29)

### v2.8.7 빌드 89 TestFlight (미출시)
- 빌드 89 = 앱 평가 팝업 + v2.8.6 이후 누적 미출시 수정(#24 forward-compat · #25 firestore 인덱스 · #26 createdBy · #27 코드감사 8건 · #28 캘린더 저장버그)
- ASC ground-truth(최고 빌드 88) 확인 후 **수동** bump v2.8.7/89(`make bump` 회피) → `make upload` → VALID. App Store 심사 **미제출**(PO 결정 대기)

## Recent Session (2026-06-09) — 유축 기록하기 통합 + 병수유 내용물 + v2.8.6 출시

### 릴리즈 트레인 꼬임 해소 (DS2 정본화 부작용)
- TestFlight 빌드 86 = 폐기된 BCDS v2.8.5 (6/8 `git reset --hard` 시 이미 업로드돼 있었음 — 빌드번호 monotonic). ASC 실조회 + 적대검증 워크플로우로 확정
- **BCDS 빌드 86 expire** (ASC API, 테스터 보호) + 로컬 빌드카운터(84) < TF 소비최대(86) 불일치 → v2.8.6 빌드 87로 점프
- **교훈**: `make bump` 맹신 금지 — reset 후 committed 버전이 TF 실제와 어긋날 수 있음. ASC API로 ground truth 확인 후 수동 세팅

### 유축 기록하기 통합 + 병수유 내용물 (PR #23 `2e98198`)
- PO QA 발견: ①유축이 "기록하기"에 없음(그리드 전용) ②유축한 모유 먹인 섭취 담을 타입 없음(분유=formula/모유수유=직수)
- **brainstorming → spec → writing-plans → executing-plans** 풀 워크플로우 (스펙·플랜 = `docs/superpowers/{specs,plans}/2026-06-09-feeding-flow-pumping-and-bottle-content*`)
- 유축: `FeedingSubPicker` 5번째 칩(보라·ViewThatFits) + `FeedingRecordView` 유축 폼. 병수유: `Activity.feedingContent`(분유/모유) + 토글(기록/빠른기록/편집)
- 불변: 유축=생산(.pumping 제외) / 병수유=섭취(.feeding 포함). formula-특정(분유재고·PDF 분유량)은 `isFormulaBottle`로 분리
- `make verify` green (arch R1~R4=0, 신규 단위테스트, design 100%), CI Verify pass

### v2.8.6 빌드 88 출시
- 빌드 88 (유축 기록하기 + 병수유) archive+upload → VALID → **App Store 제출 WAITING_FOR_REVIEW (AFTER_APPROVAL)**
- v2.8.6 = DS2 대시보드(Apple Health) + Sentry + 유축 + 병수유의 첫 App Store 릴리즈 (v2.8.4/2.8.5는 TF 전용 미릴리즈, v2.8.5 BCDS 폐기)

## Recent Session (2026-05-22) — v2.8.3 출시 동기화 + Round 7

### v2.8.3 App Store 출시 확인 (main `aebd137`)
- ASC API 확인: v2.8.3 빌드 69 `appStoreState=READY_FOR_SALE` — AFTER_APPROVAL 자동 출시 완료
- 로컬 stale 동기화: CHANGELOG / `.dev/release-notes/v2.8.3.md` / CLAUDE.md / MEMORY.md
- **train closed** → 다음 fix는 v2.8.4 bump 필수 (build-gotchas.md `code 90186/90062`)

### Round 7 (#16 `54473cb`): try? await silent sweep + 8 Service Logger 통일
- `try? await` 40 → 15 (의도적 skip만): 25 call-site `do { try await op() } catch { logSilent(...) }`
  - 카테고리: firestore 14 / pregnancy 3 / ml 3 / auth 2 / highlight 1 / analysis 1 / push 1
  - 의도적 skip 잔류: Task.sleep 12 / FeatureFlag fetch 2 / AppLogger doc comment 1
- 8 Service self-declared Logger → AppLogger 통일 (BadgeEvaluator / SoundLibrary / SoundPlayer / LiveActivity / Calendar / Analytics / Firestore + Catalog/Purchase/User extension)
- `subsystem` 하드코딩 제거, `import OSLog` 7 Service 제거
- AppLogger 카테고리 14 → 15 (`analytics` 신규, 알파벳 정렬)
- 27 files +208/-108. `make verify` PASS.

### 누적 (round 1~7)
| 지표 | round 1 전 | round 7 후 |
|---|---|---|
| arch-test R3 violations | 10 | **0** |
| narrow protocol | 3 | 11 |
| Service self-declared Logger | 7 | **0** |
| `import OSLog` (Service) | 7 | **0** |
| AppLogger 카테고리 | — | 15 |
| `print()` 잔존 | 7 | 0 |
| `try? await` 잔존 | 40 | 15 (의도적 skip만) |
| BabyCareTests.swift | 4,901 라인 | 2,518 라인 |

## Recent Session (2026-05-17) — 코드 품질 6 라운드 (PR #10~#15)

### 다각도 코드 작성 수준 점검 (75/100 B)
- 구조 78 / 가독성 76 / Swift 6 동시성 82 / 테스트 64 (3-agent 병렬)
- arch-test 안전 신호 vs 실제 위반 76건 괴리 식별 — Rule 3 도입 동기

### Round 1 (#10 `936747f`): arch-test Rule 3 + AppConstants + 3 narrow protocol
- `scripts/arch_test.sh` per-rule baseline 리팩토링 + Rule 3 신설 (Firestore.firestore() 차단)
- `AppConstants` 5 도메인 상수 (secondsPerHour/Day, kickSessionMaxSeconds, feedingTimerMaxSeconds, highlightCacheTTLSeconds, feverThresholdCelsius) + 13파일 sweep
- Cry / AuthMigration / Storage narrow protocol 3종 — R3 10→5

### Round 2 (#11 `e2f4c05`): R3 baseline 0 달성
- FCMToken / Catalog / Sound / Analysis / OfflineQueue 5종 narrow protocol
- OfflineQueue PendingOperation Sendable 표시 ([String:Any] 누수 차단)

### Round 3 (#12 `1608c42`): BabyCareTests Pregnancy 분리
- 8 클래스 → `BabyCareTests+Pregnancy.swift` (-768 라인)

### Round 4 (#13 `a00296c`): VM helper protocol
- `LoadingStateful` + `OptimisticReplaceable` (`ViewModels/Helpers/ViewModelHelpers.swift`)
- 8 호출처 sweep (HealthVM 6 / ActivityVM 1 / RoutineVM 3)

### Round 5 (#14 `36be921`): AppLogger 인프라
- 14 카테고리 단일 subsystem + `logSilent` helper
- `print()` 7건 → AppLogger / Critical silent error 2건 (ActivityVM:206 ML, PregnancyVM:82-86) 진단 로깅

### Round 6 (#15 `1b44d1f`): BabyCareTests 추가 분리
- Widgets / FeatureFlags / WeeklyHighlights 3 도메인 (-1,615 라인)
- 누적: 4,901 → 2,518 라인 (-48.6%), 21 → 6 클래스

### 누적 지표
- arch-test R3 violations: 10 → **0** (영구 차단)
- narrow protocol: 3 → **11**, Mock: 4 → **12**
- `print()` 잔존: 7 → **0**
- 모든 PR squash merge, CI Verify 통과

## Recent Session (2026-05-02) — App Store v2.8.0 심사 제출

### AdMob 미노출 근본 원인 fix (5b6ac5f)
- ASC API 직접 조회로 확정: `isOrEverWasMadeForKids=false`, `kidsAgeBand=null` → COPPA 의무 대상 아님
- `tagForChildDirectedTreatment = true`가 자체 제한으로 광고 풀 ~5-20% 축소 → `false` 변경
- 정책 충돌 0 (privacy.html / IDFA 약속 / ATT 무관)

### v2.8.0 빌드 64 TestFlight + App Store 제출
- 빌드 64 (`51a6cd4d-...`): AdMob fix + PatternReport Keychain + Admin 보안 헤더 포함
- Privacy Policy v2.8.0 §3 GitHub Pages 라이브 (allcare `817b787`)
- ASC API 5-step 자동화 (`reviewSubmissions` 신 API):
  1. POST /v1/appStoreVersions (v2.8.0 생성)
  2. build 64 link
  3. PATCH appStoreVersionLocalizations (ko release notes 315자)
  4. POST reviewSubmissions + reviewSubmissionItems
  5. PATCH submitted=true → state: WAITING_FOR_REVIEW
- 심사 결과 12-48h, AFTER_APPROVAL 자동 출시

### Makefile DEST UDID 명시 (d9f8f14)
- `DEST ?= 'platform=iOS Simulator,arch=arm64,id=E8CF2728-...'` (iOS 26.4 명시)
- 환경변수 override 가능 (다른 머신 호환)
- iOS 26.2 mkstemp signal kill 회피

## Recent Session (2026-05-01) — 보안 감사 + fix

### /cso security audit (4 targets, 6 findings → all fixed)
- **iOS** `9d5de14`: PatternReportViewModel AI API 키 UserDefaults → Keychain 마이그레이션 (F3, AIAdviceViewModel과 동일 패턴)
- **Admin** `ce5deaa`: npm audit fix (next 16.1.6→16.2.4, HTTP smuggling CVE) + `/api/health` verifyAdmin 강제 + Next.js 보안 헤더 6종 (X-Frame-Options/HSTS/CSP/Permissions-Policy 등)
- **Admin** `2f6bf0e`: firebase-admin 13.7.0 → 13.8.0 minor (transitive CVE는 v14 출시 대기)
- **결과**: critical=1→0, high=9→0, moderate=10 (Firebase Admin transitive — acceptable risk)
- **보고서**: `.gstack/security-reports/2026-05-01-114353.json` (.gstack/ gitignored)
- **/harness 신규가입 플로우**: 79% Grade B (구조/실행/개선 100%, 맥락 56%, 계획 33%, 검증 78%)

## Recent Session (2026-04-23~24) — v2.8.0 빌드 63

### pregnancy-mode-v2 재설계 (21 TODOs, 20 commits on feat/pregnancy-mode-v2)
- **Firebase 11.9.0 hotfix** (PR #3, main merge `7d80f93`): Swift 6 concurrency Issue #14257 fix
- **Phase 0**: 회귀 분석 + 심사 확인 + markTransitionPending spec + H-items 평가자 + firestore.rules collectionGroup Partner read 배포 (2026-04-23 11:08Z)
- **Phase 1**: AppContext static factory (14 tests) + ContentView 2-button 온보딩 + DashboardPregnancyHomeCard additive + HealthView/RecordingView .both 진입점 + DashboardPregnancyView D-7 제거
- **Phase 2**: PregnancyTransitionSheet 출산 CTA + PregnancyTerminationView 분리 + PregnancyRecoveryModal (pending orphan) + PregnancyFirestoreProviding narrow protocol + MockPregnancyFirestore + FeatureFlagService Hybrid + StableHash (DJB2)
- **Phase 3**: XCUITest +8 (18) + unit +26 (345) + pregnancy-weeks 37주 sanity + QA evidence v2.8.0.md H-1~H-12 scaffold
- **Phase 4**: Privacy Policy §3 임신 데이터 (법무 검토 대기) + v2.8.0 bump + rollout-log
- **TestFlight v2.8.0 빌드 63**: Delivery UUID `09fa6305-8981-4593-b2a1-de1e3d150463` (2026-04-23 10:33 KST, make deploy full chain PASS)

## Recent Session (2026-04-16~19)

### 임신 모드 P0 완성 (feat/pregnancy-mode)
- **TODO 1-12**: 모델(6종) + Firestore(5 컬렉션) + VM + JSON 리소스 + 온보딩/홈/건강/기록/체크리스트/전환 UI + FeatureFlag + Localizable 68키
- **TODO 13**: D-day Widget — PregnancyDDayWidget (small/medium/accessoryCircular) + PregnancyWidgetDataStore (lmpDate/dueDate 동적 계산) + PregnancyWidgetSyncService
- **TODO 14**: HealthKit 연동 (opt-in)
- **TODO 15**: 파트너 공유 (PregnancyShareView + FirestoreService addPartner/removePartner + sharedWith read-only)
- **TODO 16**: 이전 임신 이력 (PregnancyArchiveView)
- **TODO 17**: 테스트 34개 추가 (195→229)
- **위젯 수정**: environment 주입 누락 fix, loadActivePregnancy 호출 추가, 동적 계산 전환, 위젯 ko.lproj 추가, updateEDD/transition sync 누락 수정

### 빌드 61-62 핫픽스 + 임신 disable (2026-04-19)
- **fix(badges) H-4**: BadgeFirestoreProviding protocol + MockBadgeFirestore — 가족 공유 시 owner path → currentUserId 강제로 배지 격리. 호출처 7곳 수정
- **fix(a11y) H-8**: AddBabyView 임신 진입점 ViewThatFits — AccessibilityXXXL truncate 방지
- **feat(harness)**: 자동 검증 layer — 26+ 신규 단위/UI 테스트 (KickSession/PregnancyDateMath/PregnancyOutcome/CryAnalysisViewModel + a11y XCUITest), `make index-check` + `scripts/{pregnancy_weeks_sanity,feature_flag_smoke,pre_merge_check}`
- **feat(automation)**: `bug-triage` agent + `firestore-collection` skill 보강 (indexes.json + deploy-rules 게이트)
- **feat(pregnancy)**: 증상 일지 (PregnancySymptom 6번째 컬렉션), pregnancy-weeks 4-40 연속 37 entries
- **feat(firestore)**: announcements + todos composite index 등록 + deploy
- **revert(pregnancy)**: FeatureFlag=false (5빌드 회귀 56/58/59/60/61 누적 + 검증 공백 → 재설계 대기). UI hidden, 데이터 보존
- **TestFlight**: v2.7.1 빌드 61 → 62 — 빌드 62 Delivery UUID `34d596a2-fecc-4a4d-9f2b-98c6969c79df`
- **TestFlight**: v2.7.1 빌드 56 업로드 완료

## Current Status

- **Version**: v2.8.8 (빌드 99 committed+업로드, main `340853c`, 2026-07-11 실측) — **App Store 미제출**. 임신 v3 전체(flag-off 휴면, #32~#38·#48~#52) + 데이터 무결성(#39~#44·#49) + 이탈방지 P0(#53·#54) + **버그fix #55~#58(수면자정·접종콜드스타트·Storage사진purge·오프라인큐확대) + UX Clean Sweep #59~#73(코드청결 A1~A3·코어루프 B1~B5·리텐션 C1~C6·데이터 D1)** 포함. **ASC 최고 빌드 = 99(2026-07-11 업로드, 이전 98은 #53/#54까지)** — 빌드 93/94(`tf/pregnancy-v3-test` flag-on QA 전용·머지 금지)·95~97(쿠팡식 실험). **App Store 라이브 = v2.8.6 (빌드 88, READY_FOR_SALE)** — 유축 + 병수유 + DS2 대시보드 + Sentry. v2.8.7(빌드 89)은 TF VALID·미제출(2.8.8 제출 시 동반 출시)
- **App Store**:
  - **v2.8.8 — main committed(빌드 92)·미제출** (임신 v3 flag-off 휴면 포함 — 제출해도 임신 UI 노출 0. rollout은 RC 재배선 + 의료감수 후. 제출 여부 = PO 결정)
  - **v2.8.7 — App Store 미제출** (TestFlight 빌드 89 VALID, 앱 평가 팝업 + #24~#28 누적수정. 2.8.8 제출 시 동반 출시)
  - **v2.8.6 READY_FOR_SALE** (출시 완료 2026-06-10 — 유축 기록 + 병수유 내용물(분유/모유) + DS2 대시보드 정본화 + Sentry 첫 릴리즈. 빌드 88 승인+AFTER_APPROVAL 자동출시. ⚠️ v2.8.4/v2.8.5는 TestFlight 전용 미릴리즈 — v2.8.5 BCDS 폐기, v2.8.6로 건너뜀)
  - v2.8.0 READY_FOR_SALE (임신 모드 v2, 자동 출시 완료)
  - v2.8.1 READY_FOR_SALE (광고 제거 hotfix, 자동 출시 완료)
  - v2.8.2 READY_FOR_SALE (Phase 1 ML 인사이트, 자동 출시 완료 2026-05-10)
  - **v2.8.3 READY_FOR_SALE** (Weekly Highlights v2 + nested NavigationStack fix, AFTER_APPROVAL 자동 출시. versionId `4ed5eea1-2ef6-4cfb-a5dc-0ceb8fa3f7e6`, ASC API 확인 2026-05-22). **train closed** — 다음 fix는 v2.8.4 bump 필수 (build-gotchas.md `code 90186/90062`)
- **TestFlight**: **v2.8.8 빌드 95~97** (쿠팡식 실험 워크트리, 2026-06-28) / **빌드 94/93** (`tf/pregnancy-v3-test` 브랜치 — 임신 v3 flag-on QA 전용·머지 금지), v2.8.7 빌드 89 (`87739d1f-...`, VALID·미출시), v2.8.6 빌드 88 (`08c69b5a-...`, 유축 + 병수유, **출시됨**), 빌드 87 (superseded) / v2.8.5 빌드 86 (BCDS, **만료**) / v2.8.4 빌드 84 (DS2 Apple Health spec)
  - 이전: v2.8.3 빌드 69 (`c040f15f-...`, nested NavigationStack fix), 68/67, 66 (v2.8.2 ML), 65 (v2.8.1), 64 (v2.8.0)
- **Firebase**: 11.9.0
- **Firestore**: 35개 컬렉션 상수 (24 기본 + 9 pregnancy[v3에서 pregnancyVitals/contractionSessions/pregnancyMoods 추가] + weeklyMetrics/highlightCache). rules/index deploy 완료
- **Remote Config**: 18개 파라미터 (pregnancy 2 + weight 9 + insight 5 + highlight 2). `highlight_enabled=false` / `highlight_ticker_pct=0` 기본
- **테스트**: 단위 테스트 함수 ~564 + XCUITest ~27 (정적 집계 2026-07-09, 임신 v3 계열 PregnancyTracking 46·PrenatalSchedule 41 포함). `make verify` green + smoke PASS (2026-07-09 실행). CI Test 인프라 정상 (PR #7/#8, 2026-05-15).
- **규모**: 347 Swift 파일(앱 타깃), 23개 VM, 35개 Firestore 컬렉션 상수
- **AdMob**: 완전 폐기 (2026-05-10 `ddb63d1`) — SDK/UI/Info.plist/SKAdNetwork/app-ads.txt/privacy.html 일괄 제거 12 파일 -467 lines
- **Admin**: Vercel 자동 배포 (Insights ML 탭 + lastAccessedAt fallback + Weekly Highlights worker `c283ef5`)
- **Privacy Policy**: https://roacompany.github.io/allcare/privacy.html v2.8.0 §3 라이브 (법무 검토 미수령)
- **PR #5 머지** (2026-05-14 `18defbb`): Weekly Highlights v2 admin override squash merge. CI 6 iter — Build/Lint/Arch PASS, Test 단계 iOS 26.2 sim documented bug + Firebase init in CI 해결 부채.
- **PR #7 머지** (2026-05-15 `2c57c1f`): CI Test 인프라 fix. **진짜 root cause**: stub plist API_KEY 35자 (39자 필수) → `+[FIRInstallations validateAPIKey:]` SIGABRT. 4 iter 추측 fix 후 `-resultBundlePath` artifact + verbose log로 stack trace 확보 → 1줄 fix. 365 test PASS / 5 skip (사전 부채). 학습: **`-quiet` 플래그가 데이터를 가리면 추측 commit이 누적된다 — diagnostic 인프라부터 깔 것**.
- **PR #8 머지** (2026-05-15 `c291e33`): CI Test 사전 부채 5건 fix. root cause 4종 — (1) timezone: KST 자정 → UTC 어제 → CI runner Calendar.current 다른 month 인식 (Diary 2건) → 4/15 정오로 변경, (2) 단일 변수 reduceMotion=true 로 두 분기 검증 → 3 case 분리 + production helper 추출(testable), (3) assertionFailure가 throw 전 SIGTRAP → 제거 (HighlightAISummaryService), (4) stillbirth duration 0초는 직전 AISummary host crash 연쇄. 370/370 PASS. 학습: **timezone 테스트는 월 중간+정오 / assertionFailure 와 throw 양립 불가 / 단위 테스트가 production 함수 직접 호출해야 inversion detect 가능**.

## v2.7.1 임신 모드 회귀 이력 (재설계 참고)

5빌드에 걸친 회귀:
- 빌드 56: AddBabyView 진입점 orphan (UI 누락)
- 빌드 58: ContentView gating 조건 누락 (`babies.isEmpty AND !activePregnancy`)
- 빌드 59: Firestore composite index silent failure + 광고 UIView single-parent 위반
- 빌드 60 CRITICAL: baby/pregnancy 우선순위 (3개 View gating, escape hatch 추가)
- 빌드 61: H-4 가족 공유 배지 격리 + H-8 a11y XXXL 진입점 미노출

검증 안 된 영역 (재설계 시 spec 필수):
- 출산 전환 실 시나리오 (단위 4개만)
- HealthKit 실기기 동작
- 위젯 visual (다크/라이트/잠금화면)
- pregnancy-weeks 37주 의료 검증 (현재 agent 자동 생성)
- 태동 햅틱·2시간+ 긴 세션 안정성
- 출산 축하 애니메이션

## Recent Changes (v2.7.1 — TestFlight 빌드 56, 2026-04-17)

### 임신 모드 (P0)
- **feat(pregnancy)**: Pregnancy/KickSession/PrenatalVisit/ChecklistItem/WeightEntry 6모델 + FirestoreService+Pregnancy (WriteBatch 전환) + PregnancyViewModel
- **feat(pregnancy-ui)**: 온보딩 서브링크 + DashboardPregnancyView (D-day/주차/체크리스트) + HealthPregnancyView (태동/방문/체중) + RecordingView 분기 + 체크리스트 + 전환 시트 + 아카이브
- **feat(pregnancy-widget)**: PregnancyDDayWidget (small/medium/accessoryCircular) + 동적 lmpDate/dueDate 계산 + 일 단위 타임라인 + PregnancyWidgetSyncService
- **feat(pregnancy-share)**: 파트너 공유 (sharedWith read-only) + PregnancyShareView
- **feat(pregnancy-healthkit)**: HealthKitPregnancyService (opt-in)
- **fix(pregnancy-widget)**: environment 주입 누락, loadActivePregnancy 미호출, 정적 스냅샷→동적 계산, updateEDD/transition sync 누락, 위젯 ko.lproj 추가

### Feature Enhancement Rollout (v2.7.0 기반)
- **feat(dashboard)**: 인사이트 카드 4종 (InsightService)
- **feat(sleep)**: 수면 퇴행 감지 + 최적 취침 + 품질 점수
- **feat(vaccination)**: D-day + 부작용 기록 + 완료율
- **feat(diary)**: 월간 요약 + 회고 + 기분 트렌드
- **feat(food-safety)**: 이유식↔알레르기 연동
- **feat(hospital-report)**: PDF 통합 + 공유
- **feat(products)**: 월령 추천 + 쿠팡 딥링크
- **feat(widgets)**: NextFeeding/NextNap/TodaySummary/GrowthPercentile + Lock Screen 3종

## Recent Changes (v2.6.2)

- **feat(cry-analysis)**: 울음 분석 기능 (베타, stub) — Health 탭 → 5초 녹음 → 5 라벨 확률 바 (hungry/burping/bellyPain/discomfort/tired). FeatureFlags.cryAnalysisEnabled gate. CryRecord 독립 Firestore 컬렉션. "신호와 유사해요" 패턴 + 면책 배너. CoreML 실모델은 v2.7+ 예정.
- **chore(privacy)**: NSMicrophoneUsageDescription + PrivacyInfo NSPrivacyCollectedDataTypeAudioData + privacy.html 울음분석 섹션
- **chore(ads)**: AdMob production App ID (ca-app-pub-6369815556964095~1504777334) + Banner Unit ID + SKAdNetworkItems 43개 확장 + app-ads.txt
- **fix(ads)**: AdBannerView `UIScreen.main` → scene-aware `safeScreenWidth()` (iOS 26.5 Beta TestFlight 51 크래시 fix — WindowScene 기반)
- feat(growth): 성장 차트 v2 — WHO AreaMark 밴드(3rd~97th) + 백분위 추이 트렌드 + "또래 상위 XX%"
- feat(analytics): Firebase Analytics (GA) 통합 — 10개 뷰 트래킹, 옵트아웃, PrivacyInfo
- feat(pattern-report): 패턴분석 v2 — 발열 연속일, 데이터 품질 경고, 기간 비교 토글, 수유 예측
- feat(timer): FloatingTimerBanner — 메인 화면 상단에 진행 중인 타이머 표시
- fix(live-activity): 실시간 카운팅 (Text(timerInterval:)) + leftover cleanup + race condition fix
- fix(ux): TimeAdjustment 미래 시점 클램프, 캘린더 월 전환 로딩 인디케이터
- docs(privacy): 개인정보처리방침 Firebase Analytics 반영
- chore(deploy): -allowProvisioningUpdates + sub-make deploy chain

## v2.7 Pre-flip Items (울음 분석 실모델 통합 시 필수)

- [ ] CreateML MLSoundClassifier로 `.mlmodel` 훈련 (Donate-a-Cry Corpus 기반)
- [ ] `CryAnalysisService.analyzeStub()` → 실모델 호출로 교체, `topLabel` 채움 (argmax)
- [ ] 히스토리 필터: stub 시절 저장된 `isStub=true` 레코드 숨김 또는 뱃지 카피 재검토
- [ ] `CryAnalysisViewModel` phase 전이 단위 테스트 추가

## Compound (개선 루프)

- **3번 반복** → Skill로 자동화
- **3번 같은 실수** → `.claude/rules/`에 규칙 추가
- **learnings**: `.dev/learnings/` (세션별 학습 기록)
- **세션 마무리**: `/wrap`으로 패턴 발견 + learnings 축적

## Verification (검증 프로세스)

```bash
make verify      # 빌드+린트+아키텍처+테스트+디자인 (에이전트 자율 루프)
make lint        # SwiftLint (.swiftlint.yml)
make arch-test   # 아키텍처 경계 검사 (Views→Services 직접 참조 탐지)
make dead-code   # 미사용 코드 탐지
```

- **CI**: `.github/workflows/ci.yml` — PR 시 make verify 자동 실행
- **리뷰**: 주요 변경 시 `/review` 또는 교차 검증 에이전트 활용
- **3-Agent QA**: Visual/UX + Code Quality + Mobile Responsive → 취합

## Active TODO

### 즉시 (사용자 액션)
- [ ] LMS 데이터 스팟체크 (WHO 원본 CSV 대조)
- [ ] 카탈로그 상품 30~40개 등록 (admin /catalog)
- [ ] Figma 토큰 설정 (FIGMA_TOKEN)

### 리팩토링 잔여
- [ ] 로컬라이제이션 (1,631개 한국어 하드코딩 → Localizable.strings 추출, 다국어 기반)
- ✅ `try? await` silent sweep — Round 7 (#16 `54473cb`) 완료. 25 call-site `logSilent` 교체, 잔여 15건은 의도적 skip (Task.sleep / FeatureFlag fetch / doc comment).
- ✅ 8 Service self-declared `Logger(...)` → `AppLogger` 통일 — Round 7 완료. BadgeEvaluator / SoundLibrary / SoundPlayer / LiveActivity / Calendar / Analytics / FirestoreService + Catalog/Purchase/User extension. `subsystem` 하드코딩 + `import OSLog` 0.
- [ ] VM helper protocol 확장 — in-place mutation / append-or-replace 패턴 (RoutineVM toggleItem / HealthVM saveHospitalVisit)
- [ ] `arch_test.sh` BASELINE 자동 갱신 (현재 수동, 잊으면 silent positive)
- ✅ InsightService 분할 — #47 (`d4e70fe`, 2026-06-18) 606→110줄, +Cards/+Highlights extension 분리
- ✅ GitHub Actions `actions/checkout@v4` → v5 — #45 (`52723c0`, 2026-06-18) + arch_test `--update-baseline` 플래그

### 로드맵
- ✅ P0: 임신 모드 v2 — v2.8.0 App Store 출시 완료 (2026-05-02 승인)
- ✅ P0: 광고 제거 hotfix — v2.8.1 출시 완료 (2026-05-06)
- ✅ P0: Phase 1 ML 인사이트 — v2.8.2 출시 완료 (2026-05-10)
- ✅ P0: Weekly Highlights v2 — v2.8.3 TestFlight 67/68 (2026-05-12), PR #5 main merge (2026-05-14)
- ✅ P0: v2.8.3 App Store 출시 — 빌드 69 nested NavigationStack fix + Weekly Highlights v2 (2026-05-17 제출 → AFTER_APPROVAL 자동 출시, ASC `appStoreState=READY_FOR_SALE` 확인 2026-05-22)
- ✅ CI Test 단계 인프라 fix — PR #7 머지 (`2c57c1f`, 2026-05-15). stub plist API_KEY 35→39자 + AppDelegate XCTest 가드 + iOS 18.x sim 강제. **부채**: CI에서 처음 실행된 테스트 5건 사전 실패 — 별도 PR 예정 (`-skip-testing`로 임시 우회 중).
- [ ] v2.8 RC Rollout (심사 통과 후): Firebase Console `pregnancy_rollout_pct` 0→5→25→50→100% 단계 (Crashlytics 무회귀 확인)
- ~~AdMob 항소~~ — AdMob 완전 폐기(2026-05-10 `ddb63d1`)로 무의미. `adsEnabled` flag는 코드에 존재하지 않음(2026-07-09 감사 확인) — 재도입 시 신규 구현
- [ ] Phase 2 ML: 4주+ 데이터 누적 후 anomaly mode 활성화 (`insight_scorer_mode=anomaly`) 또는 CoreML 합성 baseline
- P2: 사진 AI OCR, AI 실시간 제안
- P4~P6:
  - ✅ ~~수면장소~~ / ~~배지 Phase 1~~ / ~~badges-ui Phase 2~~ / ~~feature-enhancement-rollout 9개~~ (2026-04-15)
  - ⏳ 커스텀활동, Apple Health, 커뮤니티
- Admin: SERVICE_ACCOUNT, 사용자관리, 통계, 개인정보처리방침

### 즉시 처리 필요 (사용자 액션)
- ✅ TestFlight 빌드 69 (nested NavigationStack fix) — 사용자 "통계 누르면 종료" 회귀 해소 검증 완료 (2026-05-17)
- ✅ v2.8.3 App Store 출시 — AFTER_APPROVAL 자동 출시 완료 (ASC API 확인 2026-05-22, `appStoreState=READY_FOR_SALE`)
- [ ] **production 모니터링** — Crashlytics + Firebase Analytics + ASC 리뷰로 v2.8.3 무회귀 / nested NavigationStack fix 크래시 감소 / nav 9 경로 사용자 사용 패턴 확인
- [ ] Firebase Console RC `highlight_enabled=true` + `highlight_ticker_pct` 0→5→25→50→100% 단계 활성화 (Crashlytics 무회귀 확인 후)
- [ ] H-3 AI 의료 감수 25 샘플 (Admin batch Cron 결과 기반) — Phase 2 ML supervised label 수집 + 사후 검증
- ✅ CI Test 사전 부채 5건 fix — PR #8 머지 (`c291e33`, 2026-05-15). root cause 4종: timezone(Diary 2건), 단일변수로 두 분기 검증(HighlightTicker), assertionFailure가 throw 전 SIGTRAP(AISummary), 직전 host crash 연쇄(stillbirth). 370/370 PASS, 0 skip. multi-model 리뷰(Gemini+Claude SHIP) + CR-001(testable helper 추출) 적용.
- [ ] AdMob Console 차단 사유 확인 + 항소 (코드 폐기는 완료, 항소만 user action)
- [ ] H-10 법무 검토 → `/Users/roque/allcare/privacy.html` §3 보강 (1주 external)

### 추후 개선 (P2)
- [ ] Admin Insights 탭 RC 라이브 가중치 (현재 default만, Firebase Admin SDK RC 추가)
- [ ] Phase 2 ML: CoreML 합성 데이터 baseline (1-2주, InsightScorer 프로토콜 swap)
- [ ] Dashboard 콘텐츠 저장소 catalog 이관 (이유식 18 + 발달 18 하드코딩)
- [ ] H-4 산부인과 전문의 pregnancy-weeks 의료 검증 (2주 external)
- [ ] 로컬라이제이션 (1,631개 한국어 하드코딩 → Localizable.strings 추출)
