# Weekly Highlights — PLAN

> 대시보드 "이번 주 하이라이트" 풀스코프 시각화 — 자동 롤링 티커 + AI 요약 bottom sheet + 4 카드 Sparkline 그리드. Phase 1 ML (`InsightScoringService` Top N) 활용 + Firebase Functions Claude API 프록시.

**Schema Version**: 1.1 | **Mode**: standard/interactive | **Status**: PENDING (v2.8.2 승인 대기)

> ⚠️ **EXECUTION PREREQUISITE**: v2.8.2 App Store **READY_FOR_SALE** 확인 후 시작. v2.8.2 심사 중 InsightScoringService API 변경 가능성 0이 된 시점부터 P0 착수.

---

## Verification Summary

### Agent-Verifiable (A-items)

| ID | Criterion | Method | Related TODO |
|----|-----------|--------|--------------|
| A-1 | `FirestoreCollections.highlightCache` 상수 정의 | `grep -q 'highlightCache' BabyCare/Utils/Constants.swift` | TODO 1 |
| A-2 | RC 2개 (`highlight_enabled`, `highlight_ticker_pct`) 등록 | `bash scripts/feature_flag_smoke.sh highlights` | TODO 1 |
| A-3 | Analytics 7 이벤트 상수 정의 | `grep -c 'highlight_' BabyCare/Services/AnalyticsEvents.swift` ≥ 7 | TODO 1 |
| A-4 | `HighlightAICache` Codable round-trip | `make test` → `testHighlightAICache_codableRoundTrip` | TODO 2 |
| A-5 | `HighlightAICache.isExpired` TTL 경계 (mock clock) | `make test` → `testHighlightAICache_TTLBoundary` | TODO 2 |
| A-6 | `firestore.rules` highlightCache 규칙 추가 + `make deploy-rules` exit 0 | `make deploy-rules` | TODO 2 |
| A-7 | `InsightService.topHighlights` 임신 metricKey 제외 | `make test` → `testTopHighlights_excludesPregnancyMetrics` | TODO 3 |
| A-8 | `InsightService` allowlist 필터 (feeding/sleep/diaper/health prefix만) | `make test` → `testTopHighlights_allowlistFilter` | TODO 3 |
| A-9 | `InsightService` AppContext 4-state별 노출 4 케이스 | `make test` → `testTopHighlights_appContextStates` | TODO 3 |
| A-10 | `HighlightTickerView` reduceMotion 자동 정지 | `make test` → `testHighlightTicker_reduceMotionPauses` | TODO 4 |
| A-11 | `HighlightTickerView` 인덱스 순환 (마지막→0) | `make test` → `testHighlightTicker_indexCycles` | TODO 4 |
| A-12 | `HighlightDetailSheet` 빈 데이터 placeholder 가드 (크래시 0) | `make test` → `testHighlightDetailSheet_emptyDataGuard` | TODO 5 |
| A-13 | Sparkline 정규화: 4주 클램프 + 음수/NaN 제거 | `make test` → `testSparkline_dataNormalization` | TODO 5 |
| A-14 | `HighlightAISummaryService` 200자 클램프 강제 | `make test` → `testAISummary_hardClampTo200Chars` | TODO 6 |
| A-15 | `HighlightAISummaryService` payload에 baby.name/birthDate 부재 | `make test` → `testAISummary_payloadAllowlistOnly` | TODO 6 |
| A-16 | `HighlightAISummaryService` 임신 metricKey 입력 시 즉시 reject | `make test` → `testAISummary_rejectsPregnancyMetric` | TODO 6 |
| A-17 | `WeeklyHighlightGrid` 4 카드 metricKey + 빈 데이터 가드 | `make test` → `testWeeklyHighlightGrid_4Cards` | TODO 7 |
| A-18 | DashboardView AppContext switch에 `default` case 부재 | `grep -c 'default:' BabyCare/Views/Dashboard/DashboardView.swift` 변화 없음 | TODO 8 |
| A-19 | `weekly_highlight_enabled=false` 시 신규 섹션 모두 hidden, 기존 `weeklyInsightsCard` 노출 | XCUITest `testFlag_off_fallbackToV1Card` | TODO 8 |
| A-20 | `weekly_highlight_enabled=true` 시 티커/그리드 노출, `weeklyInsightsCard` 숨김 | XCUITest `testFlag_on_v2Active` | TODO 8 |
| A-21 | 사전 캐시 워커 멱등성 (TTL 신선 시 호출 0회) | `make test` → `testPrecacheWorker_idempotent` | TODO 9 |
| A-22 | 캐시 키에 `weekKey`/`babyId` 포함하나 Analytics 이벤트 파라미터에는 부재 | `make test` → `testAnalytics_noWeekKeyOrBabyIdInParams` | TODO 9 |
| A-23 | DJB2 StableHash 코호트 분기 결정론적 (동일 userId → 동일 bucket) | `make test` → `testCohort_djb2Deterministic` | TODO 1 |
| A-24 | XCUITest 티커 표시 + 탭 → sheet | `make ui-test` → `testHighlightTicker_tapOpensSheet` | TODO 10 |
| A-25 | XCUITest 4 카드 그리드 표시 | `make ui-test` → `testHighlightGrid_4CardsVisible` | TODO 10 |
| A-26 | XCUITest 빈 상태 (`empty` AppContext) 섹션 hidden | `make ui-test` → `testHighlight_emptyStateHidden` | TODO 10 |
| A-27 | `make verify` 전체 체인 PASS | `make verify` | TODO Final |
| A-28 | `make plan-verify` PASS (brace glob 금지) | `make plan-verify` | TODO Final |
| A-29 | `make arch-test` 0 violations 유지 | `make arch-test` | TODO Final |
| A-30 | `make index-check` PASS (highlightCache composite query 없음 확인) | `make index-check` | TODO Final |
| A-31 | `make smoke-test` 크래시 0 | `make smoke-test` | TODO Final |

### Human-Required (H-items)

| ID | Criterion | Reason | Review Material |
|----|-----------|--------|-----------------|
| H-1 | VoiceOver 실기기 — 티커 자동 변경 알림 + 카드 접근성 라벨 | 시뮬레이터 VoiceOver 미지원 | `BabyCareUITests/PregnancyFlowTests.swift` a11y 패턴 참조 |
| H-2 | reduceMotion 실기기 토글 → 티커 정적 표시 + 수동 스와이프 | 시뮬레이터 a11y 환경값 부정확 | 실기기 설정 → 동작 → 접근성 → 동작 줄이기 |
| H-3 | AI 응답 의학적 적절성 — 5 metricKey × 5 시점 = 25 샘플 의료 감수 | LLM 응답 비결정론 + 의료 책임 | `.dev/qa-evidence/weekly-highlights/v2.8.3-ai-samples.md` |
| H-4 | 임신 데이터 leak audit — Firestore Console `highlightCache` 컬렉션 직접 조회 → `pregnancy_*` prefix metricKey 0건 | safety.md 핵심 invariant + GDPR | Firebase Console 직접 확인 |
| H-5 | AIGuardrailService 실 통과 — 25 샘플 응답 전수 가드레일 통과 | 단정형 표현 / 의학적 주장 / 금지어 | H-3과 동시 진행 |
| H-6 | 다크/라이트 모드 + iPad 12.9" UI 품질 | Dynamic Color 실기기 + iPad 미주력 타깃 | 실기기 스크린샷 5종 (small/medium/large iPhone + iPad portrait/landscape) |
| H-7 | Performance — 티커 + Sparkline 4 카드 동시 60fps | Instruments Profiler 실기기 측정 | Time Profiler / SwiftUI Hitches |
| H-8 | Firebase Functions `summarizeHighlight` 함수 실 배포 + 호출 테스트 | Functions 콜드 스타트 + 토큰 비용 | Firebase Console Functions 로그 |
| H-9 | 캐시 TTL 168h 실 동작 검증 | mock clock과 실 시간 차이 | TestFlight 빌드 1주 후 동작 확인 |
| H-10 | AI 응답 비용 모니터링 — 첫 100명 사용자 7일 Anthropic 사용량 ≤ 추정치 (사용자당 주 1회 × 25K tokens × $1/MTok ≈ $0.025/주) | 비가역 비용 | Anthropic Console + Firestore `usageStats` |

### Sandbox Agent Testing (S-items)

> BabyCare는 Tier 4 sandbox 인프라 없음 (Docker BDD/Gherkin `.feature` 파일 부재). UI 스크린샷 검증은 XCUITest (Tier 3, A-24~A-26)로 처리. 실 사용자 시나리오는 H-items로 위임.

(none)

### Verification Gaps

- **Tier 4 sandbox 부재**: BDD persona agent 인프라 없음 → 실 사용자 신규 발견 흐름은 H-items로 위임
- **Claude API mock**: 실 토큰 소비 H-item (H-3, H-8). 단위 테스트는 `HighlightAISummaryServiceProviding` protocol mock 사용
- **Firestore 실 DB 분리 없음**: `MockHighlightFirestore` 패턴 (기존 `MockPregnancyFirestore` 동일 구조)
- **TTL 168h 시뮬레이션**: 단위 테스트는 mock clock, 실 동작은 H-9 위임
- **reduceMotion 실기기 필수**: H-2 위임
- **Performance 측정**: Instruments H-7 위임

---

## External Dependencies Strategy

### Pre-work (user prepares before AI work)

| Dependency | Action | Command/Step | Blocking? |
|---|---|---|---|
| v2.8.2 App Store | READY_FOR_SALE 확인 | ASC API `/v1/apps/{app_id}/appStoreVersions` 조회 | **Yes** |
| Firebase Functions 프로젝트 | `babycare-admin` repo에 `functions/` 디렉토리 신규 추가, `firebase init functions` | `firebase init functions --project com.roacompany.allcare` | **Yes** |
| Anthropic API Key | Firebase Functions secret 환경변수 등록 (iOS 앱 번들 금지) | `firebase functions:secrets:set ANTHROPIC_API_KEY` | **Yes** |
| Firebase Functions 배포 권한 | Functions 배포 권한 확인 (roles/cloudfunctions.developer) | Firebase Console IAM | Yes |
| Anthropic Console 한도 | claude-haiku-4-5 RPM 50 / ITPM 50K (Tier 1) — 첫 100명 충분 | Anthropic Console Settings | No |

### During (AI work strategy)

| Dependency | Dev Strategy | Rationale |
|---|---|---|
| Firebase Functions `summarizeHighlight` | TypeScript 함수 신규 작성 + `firebase emulators:start --only functions` 로컬 테스트 | iOS 앱은 Firebase Functions SDK로 호출. 키 노출 0 |
| Claude API | `claude-haiku-4-5` 모델 + system prompt 1시간 prompt caching | 짧은 요약 최적 + 한국어 토큰 비용 절감 (캐시 hit $0.10/MTok) |
| Firestore `highlightCache` | `MockHighlightFirestore` 프로토콜 주입 mock 단위 테스트 | 실 Firestore 의존 없이 CRUD 경로 검증 |
| RemoteConfig | 단위 테스트는 RC 값 직접 주입 (`InsightWeights.fromRC()` 패턴 동일) | 네트워크 의존 0 |
| AnalyticsEvents | 상수 정의만으로 충분 (Analytics 호출 mocking 불필요) | 기존 패턴 일치 |
| AIGuardrailService | 프로토콜 주입 mock — 단위 테스트는 통과 가정, 실 가드레일은 H-5 | `prohibitedRules` 수정 금지 |

### Post-work (user actions after completion)

| Task | Related Dependency | Action | Command/Step |
|---|---|---|---|
| `firestore.rules` 배포 | Firestore highlightCache | App Store 승인 후 즉시 배포 | `make deploy-rules` |
| RC 키 등록 | RemoteConfig | Firebase Console에서 `highlight_enabled=false` / `highlight_ticker_pct=0` 수동 등록 | Firebase Console RC |
| RC rollout 단계 | RemoteConfig | 5% → 25% → 50% → 100% 단계 인상 (Crashlytics 무회귀 확인) | Firebase Console RC condition |
| Firebase Functions 배포 | `summarizeHighlight` | `firebase deploy --only functions:summarizeHighlight` | babycare-admin repo |
| Anthropic 사용량 모니터링 | Claude API | 첫 100명 사용자 7일 후 토큰 누적 확인 | Anthropic Console |
| AI 의료 감수 (H-3) | Claude API | 25 응답 샘플 의료 전문가 검토 | `.dev/qa-evidence/weekly-highlights/v2.8.3-ai-samples.md` |

---

## Context

### Original Request

베이비케어 대시보드에 "이번 주 하이라이트" 풀스코프 시각화 추가 (옵션 Y). 자동 롤링 티커 (5초) + 클릭 시 AI 요약 + Apple Charts 4주 sparkline + 4 카테고리 카드 그리드 (Feeding/Sleep/Diaper/Health) Sparkline + WoW.

### Interview Summary

**Key Discussions**:
- **풀스코프 옵션 Y 선택** vs 미니멀 X / 균형 Z — 사용자가 시각 임팩트 우선
- **AI 포함 (Path A) + Firebase Functions 프록시** — Codex synthesis 권고. iOS 클라이언트 Keychain 직접 호출은 의료앱 보안 부적합
- **v2.8.2 승인 후 시작 (Path C)** — InsightScoringService 호환성 확정 후 의존성 위험 0
- **`weeklyInsightsCard` 즉시 대체 X → RC fallback 공존** (DP-01 B): `highlight_enabled=false`일 때 v1 카드 보존, true일 때 신규 티커. XOR 보장 단일 게이트
- **임신 격리 allowlist 필터** (DP-03 B): metricKey 단일 진실 위치 + 다층 방어 + 단위 테스트
- **RC 2개 + Analytics 7 이벤트로 축소** (over-engineering 회피)
- **사전 캐시 워커: 주 1회 + pull-to-refresh** (scenePhase hook 제거, 비용 폭주 방지)
- **Sparkline 데이터 소스 = `fetchWeeklyMetricSnapshots(limit:4)`** (실시간 집계 X)
- **WeeklyHighlight ViewModel = `InsightService` 확장** (신규 클래스 0, review.md 가드 회피)

### Research Findings

- **Claude API**: 공식 Swift SDK 없음 → Firebase Functions 프록시 권고 (보안 + 의료앱)
- **claude-haiku-4-5** ($1/$5 MTok): 짧은 요약 최적, 한국어 영어 대비 2-3x 토큰 비용
- **Prompt caching 1시간 TTL**: system prompt 캐시 → 90% 절약 (cache hit $0.10/MTok), 최소 2048 토큰
- **200자 강제 = system prompt + `max_tokens` + 클라이언트 hard clamp** 조합 필수 (자연어 지시 단독 불충분)
- **TimelineView `.paused()` modifier** (iOS 17+) 공식 지원
- **Apple Charts `.chartXAxis(.hidden)` + `.chartYAxis(.hidden)`** Sparkline 공식 API
- **`AccessibilityNotification.Announcement(...).post()`** (iOS 17+) VoiceOver 알림
- **WCAG 2.2.2 Pause/Stop/Hide**: reduceMotion 시스템 설정 필수 존중
- **베베큐/모모힐 등 한국 육아앱**: 정적 통계 위주 → 자동 롤링 + AI 요약 + Sparkline = 시장 차별화

---

## Work Objectives

### Core Objective

대시보드에 "이번 주 하이라이트" 풀스코프 시각화 (자동 롤링 티커 + AI 요약 bottom sheet + 4 카드 Sparkline 그리드) 추가. Phase 1 ML `InsightScoringService` Top N 결과 활용. v2.8.3 출시.

### Concrete Deliverables

- `BabyCare/Models/HighlightAICache.swift` (신규 모델, Codable)
- `BabyCare/Services/FirestoreService+Highlight.swift` (CRUD + Mock 프로토콜)
- `BabyCare/Services/InsightService.swift` 확장 (topHighlights computed property + allowlist filter)
- `BabyCare/Views/Dashboard/HighlightTickerView.swift` (신규 View, TimelineView 기반)
- `BabyCare/Views/Dashboard/HighlightDetailSheet.swift` (신규 View, Sparkline + AI summary)
- `BabyCare/Views/Dashboard/WeeklyHighlightGrid.swift` (신규 View, 4 카드)
- `BabyCare/Services/HighlightAISummaryService.swift` (Firebase Functions 호출, 200자 클램프)
- `BabyCare/Utils/Constants.swift` 수정 (FirestoreCollections.highlightCache 32번째)
- `BabyCare/Services/AnalyticsEvents.swift` 수정 (7 이벤트 상수 추가)
- `BabyCare/Services/FeatureFlagService.swift` 확장 (highlight_enabled / highlight_ticker_pct)
- `BabyCare/Views/Dashboard/DashboardView.swift` 통합 (XOR gating: v1 vs v2)
- `BabyCare/Views/Dashboard/DashboardView+Shortcuts.swift` 수정 (weeklyInsightsCard XOR)
- `firestore.rules` 수정 (highlightCache 규칙 추가)
- `firestore.indexes.json` (highlightCache는 composite 불필요, 확인 후 미변경)
- `remoteconfig.template.json` 수정 (RC 2개 추가)
- `BabyCareTests/BabyCareTests.swift` 단위 테스트 14개 append
- `BabyCareUITests/PregnancyFlowTests.swift` XCUITest 5개 append (또는 신규 `WeeklyHighlightFlowTests.swift`)
- `BabyCareTests/MockHighlightFirestore.swift` (신규 mock, 기존 MockPregnancyFirestore 패턴)
- `scripts/feature_flag_smoke.sh` 확장 (RC 2개 fallback 검증)
- `babycare-admin/functions/src/summarizeHighlight.ts` (별도 repo, Functions 신규)
- `.dev/qa-evidence/weekly-highlights/v2.8.3-build{N}.md` (QA evidence)

### Definition of Done

- [ ] `make verify` PASS — A-27 전체 체인
- [ ] `make plan-verify` PASS — A-28 (brace glob 금지)
- [ ] `make arch-test` 0 violations — A-29
- [ ] `make index-check` PASS — A-30
- [ ] `make smoke-test` 크래시 0 — A-31
- [ ] 단위 테스트 354 → 368+ (14+ 추가)
- [ ] XCUITest 18 → 23+ (5+ 추가)
- [ ] 시뮬레이터 a11y identifier 5개 추가 (`weeklyHighlightTicker` / `highlightDetailSheet` / `weeklyHighlightGrid` / `highlightCard_0..3` / `weeklyInsightsCardV1`)
- [ ] `firestore.rules` highlightCache 규칙 추가 + `make deploy-rules` exit 0
- [ ] RC 2개 Firebase Console 수동 등록
- [ ] Firebase Functions `summarizeHighlight` 배포 + cold start ≤ 2s
- [ ] Anthropic prompt caching 활성 (cache_read_input_tokens > 0 응답에서)
- [ ] H-3 의료 감수 PASS (25 샘플 ≥ 80% 통과)
- [ ] H-4 임신 leak 0건 Firestore audit
- [ ] AI 응답 200자 클램프 적용 검증 (Functions 응답 + 클라이언트 hard clamp)
- [ ] v2.8.3 build TestFlight 업로드 → 실기기 무회귀 검증

### Must NOT Do (Guardrails)

- **DO NOT v2.8.2 심사 중 P0 시작** — READY_FOR_SALE 확인 후만
- **DO NOT iOS 앱에 Anthropic API Key 직접 번들** — Firebase Functions 프록시만
- **DO NOT `weeklyInsightsCard`를 `.opacity(0)` / `if false` 처리로 공존 흉내** — XOR 게이트 1곳 (`FeatureFlagService.isHighlightV2Enabled`)
- **DO NOT `AppContext` switch에 `default:` case 추가** — exhaustive 4-state 강제 (빌드 58 회귀 방지)
- **DO NOT `FeatureFlags.swift`에 `import FirebaseRemoteConfig`** — `FeatureFlagService` 단일 gateway
- **DO NOT `Swift.hashValue` / `Int.random` 코호트 분기** — DJB2 `StableHash` 강제
- **DO NOT `highlightCache` 경로를 flat (`users/{uid}/highlightCache/`)** — `users/{uid}/babies/{bid}/highlightCache/{YYYYWnn}` per-baby 격리
- **DO NOT AI payload에 baby.name / birthDate / 일기 본문 / 임신 데이터 포함** — allowlist 4 카테고리 metricKey + 집계 수치만
- **DO NOT Analytics 이벤트 파라미터에 weekKey / babyId / userId 포함** — `metricKey`, `category`, `position`, `ageHours` 만 허용 (weekKey = 준개인정보)
- **DO NOT bottom sheet stream 실시간 텍스트 변경** — Functions 응답 완료 후 일괄 표시 (AIGuardrailService 통과 보장)
- **DO NOT scenePhase=.active hook으로 사전 캐시 워커 트리거** — 앱 launch 1회 + pull-to-refresh만
- **DO NOT `prev > 0` 가드로 첫 주 metric dict 제외** — `nil` 또는 명시적 "데이터 없음" 분기
- **DO NOT 새 Firestore 컬렉션을 `indexes.json` 검증 없이 composite query 사용** — `make index-check` PASS 필수
- **DO NOT AI 응답 200자 강제를 system prompt 자연어 지시만으로 의존** — `max_tokens` + 클라이언트 hard clamp 3중 방어
- **DO NOT `AIGuardrailService.prohibitedRules` 수정** — safety.md 룰
- **DO NOT 외부 차트 라이브러리 추가** — Apple Charts만
- **DO NOT `BabyCareTests.swift` 외 신규 단위 테스트 파일 생성** — 단일 파일 정책 유지
- **DO NOT git 명령 실행** — Orchestrator만 commit
- **DO NOT v2.8.3 marketing version 안 올린 채 빌드** — `make bump` + project.yml CURRENT_PROJECT_VERSION

---

## Task Flow

```
TODO-1 (P0 인프라)
   ├── TODO-2 (Firestore 캐시 모델)
   ├── TODO-3 (InsightService 확장)
   │
   ├── TODO-6 (Firebase Functions + AI Service)
   │
   ├── TODO-4 (HighlightTickerView)
   ├── TODO-5 (HighlightDetailSheet)
   ├── TODO-7 (WeeklyHighlightGrid)
   │
   ├── TODO-8 (DashboardView 통합 + AppContext gating)
   │
   ├── TODO-9 (사전 캐시 워커)
   │
   └── TODO-10 (회귀 가드 — 테스트 + a11y identifier + QA evidence)
       │
       └── TODO-Final (Verification)
```

## Dependency Graph

| TODO | Requires (Inputs) | Produces (Outputs) | Type |
|---|---|---|---|
| 1 | (none) | `rc_keys` (list), `event_keys` (list), `collection_constant` (file), `feature_flag_method` (file) | work |
| 2 | `collection_constant` | `cache_model` (file), `firestore_crud` (file), `mock_firestore` (file), `firestore_rules` (file) | work |
| 3 | `cache_model`, `firestore_crud` | `insight_service_ext` (file) | work |
| 4 | `insight_service_ext`, `event_keys` | `ticker_view` (file) | work |
| 5 | `cache_model`, `insight_service_ext`, `event_keys` | `detail_sheet` (file) | work |
| 6 | `cache_model`, `event_keys` | `ai_service` (file), `functions_handler` (file, separate repo) | work |
| 7 | `insight_service_ext`, `event_keys` | `highlight_grid` (file) | work |
| 8 | `ticker_view`, `detail_sheet`, `highlight_grid`, `feature_flag_method` | `dashboard_integration` (file) | work |
| 9 | `ai_service`, `cache_model` | `precache_worker` (file) | work |
| 10 | all TODO outputs | `unit_tests` (list), `ui_tests` (list), `a11y_ids` (list), `qa_evidence_file` (file) | work |
| Final | all outputs | (none) | verification |

## Parallelization

| Group | TODOs | Reason |
|---|---|---|
| Group A | TODO 4, 5, 7 | UI components 독립 (티커/sheet/그리드) — InsightService 확장 후 병렬 가능 |
| Group B | TODO 6, Group A | AI service는 별도 repo (babycare-admin functions) — UI 작업과 병렬 |

## Commit Strategy

| After TODO | Message | Files | Condition |
|---|---|---|---|
| 1 | `feat(highlights): RC 2 + Analytics 7 + FirestoreCollections + StableHash cohort` | Constants/AnalyticsEvents/FeatureFlagService/remoteconfig.template.json | always |
| 2 | `feat(highlights): HighlightAICache model + FirestoreService CRUD + rules` | Models/Services/firestore.rules/MockHighlightFirestore | always |
| 3 | `feat(highlights): InsightService.topHighlights with allowlist + AppContext gating` | Services/InsightService.swift | always |
| 4 | `feat(highlights): HighlightTickerView (TimelineView + reduceMotion)` | Views/Dashboard/HighlightTickerView.swift | always |
| 5 | `feat(highlights): HighlightDetailSheet (Sparkline + AI summary + fallback)` | Views/Dashboard/HighlightDetailSheet.swift | always |
| 6 | `feat(highlights): HighlightAISummaryService + Firebase Functions summarizeHighlight` | Services/HighlightAISummaryService.swift + babycare-admin/functions/ (별도 repo) | always (2 commits) |
| 7 | `feat(highlights): WeeklyHighlightGrid 4 cards (Sparkline + WoW)` | Views/Dashboard/WeeklyHighlightGrid.swift | always |
| 8 | `feat(highlights): DashboardView XOR integration (v1 fallback / v2 active)` | Views/Dashboard/DashboardView.swift + DashboardView+Shortcuts.swift | always |
| 9 | `feat(highlights): precache worker (launch + pull-to-refresh)` | Services/HighlightPrecacheService.swift + App/BabyCareApp.swift | always |
| 10 | `test(highlights): unit 14 + XCUITest 5 + a11y identifiers + QA evidence` | BabyCareTests/+UITests/ + .dev/qa-evidence/weekly-highlights/ | always |

## Error Handling

### Failure Categories

| Category | Examples | Detection Pattern |
|---|---|---|
| `env_error` | Anthropic API key 미설정, Firebase Functions 권한 부재, Firestore rules 미배포 | `/EACCES\|401\|403\|PERMISSION_DENIED\|API_KEY/i` |
| `code_error` | Swift type error, SwiftLint 위반, arch-test 위반, 컴파일 fail | `/error:\|warning:\|violation/i` |
| `scope_internal` | InsightCandidate 시그니처 변경 필요, 새 metricKey 분류 누락 | Verify Worker `suggested_adaptation` present |
| `unknown` | 분류 불가 | Default fallback |

### Failure Handling Flow

| Scenario | Action |
|---|---|
| work fails | 최대 2회 재시도 → Analyze → 카테고리별 처리 |
| verification fails | 즉시 Analyze (재시도 없음) → 카테고리별 처리 |
| Worker timeout | Halt + 보고 |
| Missing Input | 의존 TODO skip, halt |

### After Analyze

| Category | Action |
|---|---|
| `env_error` | Halt + `issues.md` 로깅 (사용자 액션 필요: Firebase Functions/Anthropic 설정) |
| `code_error` | Fix Task 생성 (depth=1 limit) |
| `scope_internal` | Adapt → Dynamic TODO (depth=1, Fix Task 메커니즘 위임) |
| `unknown` | Halt + `issues.md` 로깅 |

## Runtime Contract

| Aspect | Specification |
|---|---|
| Working Directory | `/Users/roque/BabyCare` (또는 worktree) |
| Network Access | Allowed (Firebase, Anthropic via Functions) |
| Package Install | Denied (SwiftPM lockfile 변경 금지) |
| File Access | Repository only (BabyCare + babycare-admin functions 디렉토리만) |
| Max Execution Time | 5 minutes per TODO (Worker timeout) |
| Git Operations | Denied (Orchestrator handles) |

---

## TODOs

### [x] TODO 1: 인프라 — RC + Analytics + FirestoreCollections + FeatureFlag + Cohort

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `rc_keys` (list): `["highlight_enabled", "highlight_ticker_pct"]` — RC 2개 신규 키
- `event_keys` (list): 7개 Analytics 이벤트 상수명
- `collection_constant` (file): `BabyCare/Utils/Constants.swift` (FirestoreCollections.highlightCache 추가)
- `feature_flag_method` (file): `BabyCare/Services/FeatureFlagService.swift` (`isHighlightV2Enabled(userId:)` 메서드 추가)

**Steps**:
- [ ] `BabyCare/Utils/Constants.swift`에 `FirestoreCollections.highlightCache = "highlightCache"` 추가 (line ~101, weeklyMetrics 다음)
- [ ] `BabyCare/Services/AnalyticsEvents.swift`에 7 상수 추가:
  - `static let highlightTickerShown = "highlight_ticker_shown"`
  - `static let highlightTickerTapped = "highlight_ticker_tapped"`
  - `static let highlightTickerPaused = "highlight_ticker_paused"`
  - `static let highlightSheetOpened = "highlight_sheet_opened"`
  - `static let highlightSheetDismissed = "highlight_sheet_dismissed"`
  - `static let highlightCacheHit = "highlight_cache_hit"`
  - `static let highlightPatternReportTapped = "highlight_pattern_report_tapped"`
- [ ] `BabyCare/Utils/FeatureFlags.swift`에 `static let highlightsEnabled: Bool = true` 추가 (Layer 1 compile-time guard)
- [ ] `BabyCare/Services/FeatureFlagService.swift`에 `isHighlightV2Enabled(userId: String) -> Bool` 메서드 추가:
  - Layer 1: `guard FeatureFlags.highlightsEnabled else { return false }`
  - Layer 2: RC `highlight_enabled` fetch (fallback=false, A-18 invariant)
  - Layer 3: `StableHash.djb2(userId)` mod 100 < RC `highlight_ticker_pct` (cohort)
  - 반환 시 Keychain cache write (오프라인 fallback)
- [ ] `remoteconfig.template.json`에 2 키 추가:
  - `highlight_enabled`: BOOLEAN, default `false`
  - `highlight_ticker_pct`: NUMBER, default `0`
- [ ] `scripts/feature_flag_smoke.sh` 확장 — RC 2 키 fallback 기본값 검증

**Must NOT do**:
- Do not modify existing RC parameters
- Do not add `import FirebaseRemoteConfig` to FeatureFlags.swift (FeatureFlagService 단일 gateway)
- Do not use `Swift.hashValue` or `Int.random` for cohort
- Do not commit (Orchestrator handles)
- Do not run git commands

**References**:
- `BabyCare/Utils/Constants.swift:65-100` — FirestoreCollections enum
- `BabyCare/Services/AnalyticsEvents.swift:51-56` — 기존 insight events 패턴
- `BabyCare/Services/FeatureFlagService.swift:1-99` — Hybrid pattern + StableHash DJB2
- `BabyCare/Utils/FeatureFlags.swift` — compile-time guards
- `remoteconfig.template.json` — RC 16 기존 + 2 신규

**Acceptance Criteria**:

*Functional:*
- [x] `FirestoreCollections.highlightCache == "highlightCache"` (line 정의 확인)
- [x] 7 Analytics 상수 정의 (`grep -c 'highlight_' AnalyticsEvents.swift` ≥ 7)
- [x] `FeatureFlagService.isHighlightV2Enabled` 메서드 시그니처 존재
- [x] `FeatureFlags.highlightsEnabled == true` compile-time
- [x] `remoteconfig.template.json` 2 키 추가

*Static:*
- [x] `make build` exit 0
- [x] `make lint` exit 0
- [x] `make arch-test` 0 violations (baseline)

*Runtime:*
- [x] `make test` PASS — `testCohort_djb2Deterministic` (A-23)
- [x] `bash scripts/feature_flag_smoke.sh highlights` exit 0 (A-2)

**Verify**:
```yaml
acceptance:
  - given: ["FeatureFlags.highlightsEnabled=true", "RC highlight_enabled=true", "RC highlight_ticker_pct=100"]
    when: "isHighlightV2Enabled(userId:'u1') 호출"
    then: ["true 반환", "djb2 deterministic"]
  - given: ["RC highlight_enabled=false"]
    when: "isHighlightV2Enabled 호출"
    then: ["false 반환 (Layer 2 차단)"]
  - given: ["compile-time FeatureFlags.highlightsEnabled=false"]
    when: "isHighlightV2Enabled 호출"
    then: ["false 반환 (Layer 1 조기 종료, RC fetch 안 함)"]
commands:
  - run: "make test"
    expect: "exit 0"
  - run: "bash scripts/feature_flag_smoke.sh highlights"
    expect: "exit 0"
  - run: "grep -q 'highlightCache' BabyCare/Utils/Constants.swift"
    expect: "exit 0"
risk: LOW
```

---

### [x] TODO 2: HighlightAICache 모델 + FirestoreService CRUD + rules

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `collection_constant` (file): `${todo-1.outputs.collection_constant}`

**Outputs**:
- `cache_model` (file): `BabyCare/Models/HighlightAICache.swift`
- `firestore_crud` (file): `BabyCare/Services/FirestoreService+Highlight.swift`
- `mock_firestore` (file): `BabyCareTests/MockHighlightFirestore.swift`
- `firestore_rules` (file): `firestore.rules` (highlightCache 규칙 추가)

**Steps**:
- [ ] `BabyCare/Models/HighlightAICache.swift` 신규:
  ```
  struct HighlightAICache: Identifiable, Codable, Hashable {
    var id: String { "\(weekKey)_\(metricKey)" }
    let weekKey: String          // "2026W19"
    let metricKey: String        // "feeding_total_oz"
    let summary: String          // ≤200 chars
    let createdAt: Date
    let rcVersionHash: UInt32?   // RC weight fingerprint, invalidation 시그널
    var isExpired: Bool {
      Date().timeIntervalSince(createdAt) > 168 * 3600
    }
  }
  ```
- [ ] `BabyCare/Services/FirestoreService+Highlight.swift` 신규:
  - `HighlightFirestoreProviding` 프로토콜 (MockBadgeFirestore 패턴 동일)
  - `fetchHighlightAICache(userId:babyId:weekKey:metricKey:) async -> HighlightAICache?`
  - `saveHighlightAICache(_:userId:babyId:) async throws`
  - `deleteHighlightAICache(userId:babyId:weekKey:) async throws` (RC version invalidation)
  - 경로: `users/{userId}/babies/{babyId}/highlightCache/{weekKey}_{metricKey}`
  - 모든 read/write는 `babyVM.dataUserId()` 패턴 (가족 공유 호환)
- [ ] `BabyCareTests/MockHighlightFirestore.swift` 신규 (MockPregnancyFirestore 패턴):
  - In-memory dict 기반 mock
  - 호출 카운터 (cache hit/miss verification용)
- [ ] `firestore.rules` 수정:
  ```
  match /users/{uid}/babies/{bid}/highlightCache/{doc} {
    allow read: if request.auth != null && request.auth.uid == uid;
    allow create, update: if request.auth != null && request.auth.uid == uid
      && request.resource.data.metricKey.matches('^(feeding|sleep|diaper|health)_.+');
    allow delete: if request.auth != null && request.auth.uid == uid;
  }
  ```
  (allowlist regex로 임신 metricKey 차단 — defense in depth)
- [ ] `make deploy-rules` 로컬 syntax 검증 (실 배포는 post-work)
- [ ] `firestore.indexes.json` 확인 (highlightCache는 composite 불필요, 단일 doc 조회만)

**Must NOT do**:
- Do not use flat path (`users/{uid}/highlightCache/`) — must include `/babies/{bid}/`
- Do not access `authVM.currentUserId` directly — use `babyVM.dataUserId()`
- Do not skip rules allowlist regex (defense in depth)
- Do not commit
- Do not run git commands

**References**:
- `BabyCare/Models/WeeklyMetricSnapshot.swift:9-23` — Codable 패턴 동일
- `BabyCare/Services/FirestoreService+Insights.swift:9-31` — fetch/save 패턴
- `BabyCareTests/MockPregnancyFirestore.swift` — Mock 프로토콜 패턴
- `firestore.rules` — pregnancyChecklists/weeklyMetrics 규칙 참조
- `.claude/rules/firestore-rules.md` — collectionGroup 룰 + FieldValue.delete() 차이

**Acceptance Criteria**:

*Functional:*
- [x] `HighlightAICache` Codable 채택, `id` computed property 정의
- [x] `FirestoreService+Highlight` CRUD 3 메서드 존재
- [x] `HighlightFirestoreProviding` 프로토콜 정의
- [x] `MockHighlightFirestore` BabyCareTests 위치 (단위 테스트 단일 파일 정책 무관 — Mock은 별도 OK, 기존 MockBadge/Pregnancy 패턴)
- [x] `firestore.rules` highlightCache 규칙 추가 (allowlist regex 포함)

*Static:*
- [x] `make build` exit 0
- [x] `make lint` exit 0
- [x] `make arch-test` 0 violations
- [x] `make index-check` PASS

*Runtime:*
- [ ] `make test` PASS — A-4 testHighlightAICache_codableRoundTrip, A-5 testHighlightAICache_TTLBoundary (deferred to TODO 10)

**Verify**:
```yaml
acceptance:
  - given: ["HighlightAICache instance"]
    when: "encode → decode"
    then: ["모든 필드 보존", "id == weekKey + _ + metricKey"]
  - given: ["createdAt = now - 169h"]
    when: "isExpired"
    then: ["true 반환"]
  - given: ["createdAt = now - 167h"]
    when: "isExpired"
    then: ["false 반환"]
commands:
  - run: "make test"
    expect: "exit 0"
  - run: "make deploy-rules"
    expect: "exit 0 (idempotent)"
  - run: "make index-check"
    expect: "exit 0"
risk: MEDIUM
```

---

### [x] TODO 3: InsightService 확장 — topHighlights + allowlist + AppContext gating

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `cache_model` (file): `${todo-2.outputs.cache_model}`
- `firestore_crud` (file): `${todo-2.outputs.firestore_crud}`

**Outputs**:
- `insight_service_ext` (file): `BabyCare/Services/InsightService.swift` 확장

**Steps**:
- [ ] `InsightService`에 `topHighlights(for ctx: AppContext, weights: InsightWeights) -> [InsightCandidate]` 추가:
  - `empty` → `[]`
  - `pregnancyOnly` → `[]` (Phase 2 대상)
  - `babyOnly` / `both` → `InsightScoringService.selectTopN(...)` 결과
- [ ] **Allowlist 필터** — `InsightProvider` 호출 결과에 다음 적용:
  ```
  private static let allowedMetricKeyPrefixes: Set<String> = [
    "feeding_", "sleep_", "diaper_", "health_"
  ]
  candidates.filter { c in
    allowedMetricKeyPrefixes.contains { c.metricKey.hasPrefix($0) }
  }
  ```
- [ ] **임신 metricKey 명시적 reject**: `metricKey.hasPrefix("pregnancy_")` → assert fail (개발 build) + filter out (release)
- [ ] AppContext switch에 `default:` case 추가 금지 — 4 case 명시 (빌드 58 회귀 방지)
- [ ] `weeklyMetricSnapshots(limit: 4)` 결과를 Sparkline 데이터로 변환:
  - `sparklineData(for metricKey: String) -> [Double]` 메서드
  - 빈 데이터 → `[]` (placeholder 가드는 View 책임)
  - 음수/NaN 제거, 4주 클램프

**Must NOT do**:
- Do not include `default:` in AppContext switch
- Do not query Firestore directly (delegate to FirestoreService+Insights)
- Do not include pregnancy_ metricKey
- Do not allocate Combine subscriptions outside @Observable
- Do not commit
- Do not run git commands

**References**:
- `BabyCare/Services/Insights/InsightScoringService.swift:18-30` — selectTopN
- `BabyCare/Services/Insights/InsightProvider.swift:53-55` — candidates 프로토콜
- `BabyCare/Utils/AppContext.swift:1-31` — 4-state enum
- `BabyCare/Services/FirestoreService+Insights.swift:21-31` — fetchWeeklyMetricSnapshots
- `BabyCare/Services/Insights/InsightWeights.swift` — RC 매핑
- `.claude/rules/swift-conventions.md` — AppContext default 금지

**Acceptance Criteria**:

*Functional:*
- [x] `InsightService.topHighlights` 메서드 시그니처 존재
- [x] `empty` / `pregnancyOnly` AppContext 시 빈 배열 반환
- [x] `babyOnly` / `both` AppContext 시 Top N 반환
- [x] allowlist 필터 적용 (feeding/sleep/diaper/health prefix만)
- [x] `pregnancy_*` metricKey 입력 시 filter out
- [x] `sparklineData(for:)` 메서드 4주 클램프 + 음수/NaN 제거

*Static:*
- [x] `make build` exit 0
- [x] `make lint` exit 0
- [x] `make arch-test` 0 violations (Views가 InsightService 직접 참조 금지 유지)
- [x] `grep -c 'default:' BabyCare/Services/InsightService.swift` 변화 없음 (baseline: 1 napIntervalHours + 1 comment text, AppContext switch에 default 0개)

*Runtime:*
- [ ] `make test` PASS — A-7, A-8, A-9, A-13

**Verify**:
```yaml
acceptance:
  - given: ["AppContext=.empty", "babies=[]", "pregnancy=nil"]
    when: "topHighlights(for:.empty)"
    then: ["빈 배열 반환"]
  - given: ["AppContext=.babyOnly", "InsightScoringService Top 3 반환"]
    when: "topHighlights"
    then: ["3개 반환", "metricKey prefix 4 카테고리 안에 있음"]
  - given: ["candidates에 pregnancy_weeks_elapsed 포함"]
    when: "allowlist filter"
    then: ["pregnancy_weeks_elapsed 제외됨"]
  - given: ["weeklyMetricSnapshots 4주 history"]
    when: "sparklineData(for: feeding_total_oz)"
    then: ["4개 Double 배열", "NaN/음수 제거"]
commands:
  - run: "make test"
    expect: "exit 0"
  - run: "make arch-test"
    expect: "0 violations"
risk: MEDIUM
```

---

### [x] TODO 4: HighlightTickerView (TimelineView + reduceMotion + 일시정지)

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `insight_service_ext` (file): `${todo-3.outputs.insight_service_ext}`
- `event_keys` (list): `${todo-1.outputs.event_keys}`

**Outputs**:
- `ticker_view` (file): `BabyCare/Views/Dashboard/HighlightTickerView.swift`

**Steps**:
- [ ] `HighlightTickerView: View` 신규 생성:
  - `@Environment(InsightService.self) var insightService`
  - `@Environment(\.accessibilityReduceMotion) var reduceMotion`
  - `@State private var currentIndex: Int = 0`
  - `@State private var isPaused: Bool = false`
  - `let candidates: [InsightCandidate]` (InsightService.topHighlights 결과 주입)
- [ ] reduceMotion 분기:
  - `if reduceMotion || candidates.count <= 1` → 정적 단일 카드 + 좌우 스와이프 가능
  - `else` → `TimelineView(.periodic(from: .now, by: 5))` + `.paused(isPaused)` modifier (iOS 17+)
- [ ] 카드 콘텐츠: 아이콘 + title (≤30자) + changePercent 배지 (↑/↓ + %)
- [ ] 진행 dots: 하단 작은 점 N개 (currentIndex 강조)
- [ ] 탭 → `isPaused.toggle()` + onTapGesture → parent로 `selectedCandidate` 전달 (sheet 호출 시그널)
- [ ] `.onChange(of: currentIndex)`:
  - `AccessibilityNotification.Announcement(candidates[newIndex].accessibilityLabel).post()`
  - Analytics `highlightTickerShown` (metricKey, position) — weekKey/babyId 절대 미포함
- [ ] 빈 상태 (`candidates.isEmpty`): `EmptyView()` 반환 (섹션 자체 hidden)
- [ ] `accessibilityIdentifier("weeklyHighlightTicker")` 적용
- [ ] `.accessibilityElement(children: .combine)` 그룹화

**Must NOT do**:
- Do not use `Timer.publish` (TimelineView 권장 패턴 + .paused() iOS 17+)
- Do not create `Task` inside TimelineView context closure (누수 위험, P-3)
- Do not include weekKey/babyId in Analytics events
- Do not log AI summary content to Analytics
- Do not force animation when reduceMotion=true
- Do not commit
- Do not run git commands

**References**:
- `BabyCare/Views/Dashboard/DashboardView+Shortcuts.swift:6-72` — 기존 weeklyInsightsCard 패턴
- `BabyCare/Views/Components/AnnouncementBanner.swift` — 정적 배너 패턴 (reduceMotion fallback)
- External research: TimelineView `.paused()` iOS 17+ 공식
- External research: AccessibilityNotification.Announcement.post() iOS 17+

**Acceptance Criteria**:

*Functional:*
- [x] reduceMotion=true 시 자동 롤링 정지 (정적 표시)
- [x] reduceMotion=false 시 5초 간격 자동 롤링
- [x] 탭 → isPaused 토글 (정적 카드로 전환, `.paused()` modifier는 PeriodicTimelineSchedule 미지원)
- [x] 빈 candidates 시 EmptyView 반환
- [x] 인덱스 마지막 → 0 순환
- [x] accessibilityIdentifier="weeklyHighlightTicker"

*Static:*
- [x] `make build` exit 0
- [x] `make lint` exit 0
- [x] `make arch-test` 0 violations (Views가 Service 직접 호출 X — InsightService는 @Environment 주입만)

*Runtime:*
- [ ] `make test` PASS — A-10, A-11 (deferred to TODO 10)

**Verify**:
```yaml
acceptance:
  - given: ["reduceMotion=true", "3 candidates"]
    when: "TickerView render"
    then: ["정적 단일 카드", "TimelineView 미사용"]
  - given: ["candidates=[]"]
    when: "TickerView render"
    then: ["EmptyView 반환"]
  - given: ["currentIndex=2", "candidates.count=3"]
    when: "advance"
    then: ["currentIndex=0"]
commands:
  - run: "make test"
    expect: "exit 0"
  - run: "make lint"
    expect: "exit 0"
risk: MEDIUM
```

---

### [x] TODO 5: HighlightDetailSheet (Sparkline + AI summary fallback + 일괄 표시)

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `cache_model` (file): `${todo-2.outputs.cache_model}`
- `insight_service_ext` (file): `${todo-3.outputs.insight_service_ext}`
- `event_keys` (list): `${todo-1.outputs.event_keys}`

**Outputs**:
- `detail_sheet` (file): `BabyCare/Views/Dashboard/HighlightDetailSheet.swift`

**Steps**:
- [ ] `HighlightDetailSheet: View` 신규:
  - Inputs: `candidate: InsightCandidate`, `sparkline: [Double]`, `aiSummary: String?` (nil → fallback)
  - Layout: 헤더(아이콘 + title) → 즉시 fallback 텍스트 (candidate.detail) → AI summary (도착 시 교체) → Apple Charts Sparkline (LineMark + AreaMark) → "더 보기" NavLink → PatternReportView
- [ ] Sparkline 구현:
  - `Chart(weeklyData) { ... AreaMark(...) + LineMark(...) }`
  - `.chartXAxis(.hidden)` + `.chartYAxis(.hidden)`
  - `.interpolationMethod(.catmullRom)`
  - `.frame(height: 60)`
  - 빈 데이터 → 회색 placeholder rect
- [ ] AI summary 표시 로직:
  - Sheet open 시 fallback `candidate.detail` 즉시 표시
  - aiSummary != nil 시 fade transition으로 교체 (애니메이션 짧음)
  - **streaming 미사용** — 일괄 표시
  - 200자 초과 시 클라이언트 hard clamp (`.prefix(200)`)
- [ ] Analytics:
  - onAppear: `highlightSheetOpened(metricKey)` (weekKey/babyId 미포함)
  - onDisappear: `highlightSheetDismissed(metricKey, dwellMs: Int)`
- [ ] "더 보기" NavigationLink:
  - `NavigationLink { PatternReportView() }`
  - Analytics: `highlightPatternReportTapped(metricKey)`
- [ ] `presentationDetents([.medium, .large])`
- [ ] `accessibilityIdentifier("highlightDetailSheet")`

**Must NOT do**:
- Do not stream AI response (일괄 표시만 — AIGuardrailService 통과 보장)
- Do not exceed 200 chars in display (hard clamp `.prefix(200)`)
- Do not embed PatternReportView directly (NavLink만)
- Do not call HighlightAISummaryService directly (parent ViewModel 주입)
- Do not access authVM.currentUserId (use babyVM.dataUserId())
- Do not commit
- Do not run git commands

**References**:
- `BabyCare/Views/Growth/GrowthView+Charts.swift:1-80` — AreaMark + LineMark + interpolationMethod
- `BabyCare/Views/Dashboard/DashboardView.swift:90-149` — .sheet(item:) + presentationDetents
- `BabyCare/Views/Stats/PatternReportView.swift` — NavLink target
- External research: `.chartXAxis(.hidden)` + `.chartYAxis(.hidden)` 공식

**Acceptance Criteria**:

*Functional:*
- [x] aiSummary=nil 시 fallback 텍스트 표시
- [x] aiSummary=String 도착 시 교체
- [x] 200자 초과 입력 시 클램프 (`.prefix(200).count == 200`)
- [x] sparkline=[] 시 placeholder rect 표시 (크래시 0)
- [x] "더 보기" NavLink → PatternReportView push
- [x] accessibilityIdentifier="highlightDetailSheet"

*Static:*
- [x] `make build` exit 0
- [x] `make lint` exit 0
- [x] `make arch-test` 0 violations

*Runtime:*
- [ ] `make test` PASS — A-12, A-13 (deferred to TODO 10)

**Verify**:
```yaml
acceptance:
  - given: ["aiSummary=nil", "candidate.detail='지난 주 대비 수유량 12% 증가'"]
    when: "Sheet render"
    then: ["fallback 텍스트 표시"]
  - given: ["aiSummary 250자"]
    when: "Sheet render"
    then: ["200자로 클램프 + 표시"]
  - given: ["sparkline=[]"]
    when: "Sheet render"
    then: ["placeholder rect 표시, 크래시 0"]
commands:
  - run: "make test"
    expect: "exit 0"
risk: MEDIUM
```

---

### [ ] TODO 6: HighlightAISummaryService + Firebase Functions summarizeHighlight

**Type**: work

**Required Tools**: `firebase-cli` (post-work, deploy 단계만)

**Inputs**:
- `cache_model` (file): `${todo-2.outputs.cache_model}`
- `event_keys` (list): `${todo-1.outputs.event_keys}`

**Outputs**:
- `ai_service` (file): `BabyCare/Services/HighlightAISummaryService.swift`
- `functions_handler` (file): `babycare-admin/functions/src/summarizeHighlight.ts` (별도 repo)

**Steps**:

**iOS 측:**
- [ ] `BabyCare/Services/HighlightAISummaryService.swift` 신규:
  - `HighlightAISummaryServiceProviding` 프로토콜 (mock 주입)
  - `summarize(candidate: InsightCandidate, sparkline: [Double]) async throws -> String`
  - Firebase Functions httpsCallable `summarizeHighlight` 호출
  - 응답 받은 즉시 200자 hard clamp (`.prefix(200)`)
  - `AIGuardrailService.filter()` 통과 (기존 룰 사용, 수정 금지)
  - **임신 metricKey 입력 시 immediate reject** (assertion + filter)
  - cache 확인 후 stale-while-revalidate:
    1. fetch from `HighlightAICache` (TODO 2)
    2. 신선하면 즉시 반환 + 백그라운드 갱신 시작
    3. 만료/없으면 Functions 호출 + 결과 저장

**Functions 측 (babycare-admin repo):**
- [ ] `babycare-admin/functions/src/summarizeHighlight.ts` 신규:
  - `onCall` Cloud Function (region: `asia-northeast3` 권장)
  - Anthropic API 호출 (claude-haiku-4-5, max_tokens=150 ≈ 200자 한국어)
  - System prompt: 1시간 prompt caching enabled (`cache_control: { type: "ephemeral" }`)
  - System prompt 콘텐츠: 권유형 어조 + 200자 이내 + 의학적 단정 금지 + 한국어 + few-shot 3예시
  - Input payload allowlist 검증: `metricKey` prefix 4 카테고리만, `pregnancy_*` reject (HTTP 400)
  - User payload: 집계 수치만 (changePercent, currentValue, sampleSize, sparkline 4개 값) — baby.name/birthDate/임신 데이터 0
  - Response: `{ summary: string }` (Functions 측에서 1차 클램프)
  - Error: rate limit 429 → retry-after 헤더 준수 후 single retry
  - Anthropic ITPM 50K (Tier 1) 가드: per-user 일일 30 호출 cap (Firestore `usageStats/{uid}/{currentMonth}` 카운터)

**Must NOT do (iOS):**
- Do not bundle Anthropic API key in iOS app (Firebase Functions 프록시만)
- Do not stream response (일괄 표시)
- Do not include baby.name/birthDate/일기 본문/임신 데이터 in payload
- Do not modify AIGuardrailService.prohibitedRules
- Do not skip 200자 hard clamp (system prompt만 의존 X)
- Do not run git commands

**Must NOT do (Functions):**
- Do not log full payload (PII 위험 — metricKey/changePercent만 로깅)
- Do not skip allowlist validation
- Do not skip prompt caching (90% 비용 절감)
- Do not call without ITPM cap check

**References**:
- `BabyCare/Services/AIService.swift` — 기존 Claude API 호출 패턴 (참조만, 신규 작성)
- `BabyCare/ViewModels/AIAdviceViewModel.swift:84-89` — 시스템 프롬프트 4 topic 패턴
- `.claude/rules/safety.md` — AI 가드레일 + 임신 데이터 금지
- External research: claude-haiku-4-5 ($1/$5 MTok)
- External research: prompt caching `cache_control: ephemeral` (1시간)
- External research: 429 retry-after 헤더 준수
- `babycare-admin/functions/` (디렉토리 신규 생성 필요)

**Acceptance Criteria**:

*Functional:*
- [ ] `HighlightAISummaryService.summarize` 시그니처 존재 + protocol mock 주입 가능
- [ ] 응답에 200자 hard clamp 적용 (`response.prefix(200)`)
- [ ] payload에 baby.name/birthDate/일기 본문 부재 (testAISummary_payloadAllowlistOnly)
- [ ] 임신 metricKey 입력 시 throws/reject (testAISummary_rejectsPregnancyMetric)
- [ ] Functions `summarizeHighlight` 함수 존재 + onCall 패턴
- [ ] Functions allowlist validation HTTP 400 (테스트로 검증)

*Static:*
- [ ] `make build` exit 0 (iOS)
- [ ] `make lint` exit 0
- [ ] `make arch-test` 0 violations
- [ ] (babycare-admin) `npm run build` exit 0
- [ ] (babycare-admin) `npm run lint` exit 0

*Runtime:*
- [ ] `make test` PASS — A-14, A-15, A-16
- [ ] (babycare-admin) `npm test` PASS (Functions allowlist + 200자 클램프)

**Verify**:
```yaml
acceptance:
  - given: ["mock Functions가 250자 응답"]
    when: "summarize 호출"
    then: ["반환값 길이 == 200"]
  - given: ["candidate.metricKey='pregnancy_weeks_elapsed'"]
    when: "summarize 호출"
    then: ["throws ImmediateRejectError"]
  - given: ["cache 신선"]
    when: "summarize 호출"
    then: ["Functions 호출 카운터 == 0", "캐시 값 반환"]
commands:
  - run: "make test"
    expect: "exit 0"
  - run: "cd babycare-admin && npm test"
    expect: "exit 0 (allowlist + 200자 클램프)"
risk: HIGH
```

**Rollback Steps**:
- iOS: `HighlightAISummaryService.swift` 파일 삭제 + `HighlightDetailSheet` aiSummary 항상 nil 사용
- Functions: `firebase functions:delete summarizeHighlight --region asia-northeast3`
- 발생한 API 비용은 비가역 — pre-work에서 Anthropic ITPM cap 설정 필수

---

### [ ] TODO 7: WeeklyHighlightGrid (4 카드 Sparkline + WoW)

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `insight_service_ext` (file): `${todo-3.outputs.insight_service_ext}`
- `event_keys` (list): `${todo-1.outputs.event_keys}`

**Outputs**:
- `highlight_grid` (file): `BabyCare/Views/Dashboard/WeeklyHighlightGrid.swift`

**Steps**:
- [ ] `WeeklyHighlightGrid: View` 신규:
  - `LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12)`
  - 4 카드: Feeding / Sleep / Diaper / Health
  - 각 카드: 아이콘 + 카테고리명 + WoW 변화율 배지 (↑/↓ + %) + Sparkline 4주 (chart height 40)
- [ ] 각 카드의 `accessibilityIdentifier("highlightCard_\(index)")` (0..3)
- [ ] 카드 탭 시 `highlight_card_tapped(category)` Analytics
- [ ] 빈 데이터 (`sparkline.isEmpty`) 카드 — placeholder rect (회색)
- [ ] `.equatable()` modifier 적용 (LazyVGrid 재렌더 최적화)
- [ ] 임신 모드 (`pregnancyOnly`) 시 그리드 자체 hidden — InsightService.topHighlights와 동일 gating

**Must NOT do**:
- Do not include 5번째 카드 (Feeding/Sleep/Diaper/Health만)
- Do not query InsightService directly inside cell (parent에서 [Double] 주입)
- Do not include weekKey/babyId in Analytics
- Do not commit
- Do not run git commands

**References**:
- `BabyCare/Views/Dashboard/DashboardView+Summary.swift` — summaryCardsSection 패턴
- External research: LazyVGrid + `.equatable()` 16 차트 동시 렌더 권장
- TODO 3 outputs — `sparklineData(for:)` 사용

**Acceptance Criteria**:

*Functional:*
- [ ] 4 카드 렌더 (Feeding/Sleep/Diaper/Health metricKey 매핑)
- [ ] 각 카드 accessibilityIdentifier="highlightCard_0..3"
- [ ] 빈 sparkline 시 placeholder
- [ ] pregnancyOnly 시 hidden

*Static:*
- [ ] `make build` exit 0
- [ ] `make lint` exit 0
- [ ] `make arch-test` 0 violations

*Runtime:*
- [ ] `make test` PASS — A-17

**Verify**:
```yaml
acceptance:
  - given: ["4 metricKey + sparkline 4주"]
    when: "Grid render"
    then: ["4 카드 모두 표시", "Sparkline 4개 점"]
  - given: ["sparkline=[]"]
    when: "Grid render"
    then: ["placeholder rect 표시, 크래시 0"]
commands:
  - run: "make test"
    expect: "exit 0"
risk: MEDIUM
```

---

### [ ] TODO 8: DashboardView 통합 + AppContext gating + XOR v1/v2

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `ticker_view` (file): `${todo-4.outputs.ticker_view}`
- `detail_sheet` (file): `${todo-5.outputs.detail_sheet}`
- `highlight_grid` (file): `${todo-7.outputs.highlight_grid}`
- `feature_flag_method` (file): `${todo-1.outputs.feature_flag_method}`

**Outputs**:
- `dashboard_integration` (file): `BabyCare/Views/Dashboard/DashboardView.swift` (+ DashboardView+Shortcuts.swift)

**Steps**:
- [ ] `DashboardView.body`에서 v1/v2 XOR 분기:
  ```
  if appState.featureFlagService.isHighlightV2Enabled(userId: authVM.currentUserId) {
      HighlightTickerView(...)  // 신규
      // weeklyInsightsCard 미렌더
  } else {
      weeklyInsightsCard()  // 기존 (DashboardView+Shortcuts.swift)
  }
  ```
- [ ] `WeeklyHighlightGrid`는 `summaryCardsSection` 아래에 배치 (V2 활성 시만):
  - `if isHighlightV2Enabled { WeeklyHighlightGrid(...) }`
- [ ] AppContext 분기 (exhaustive switch, `default:` 금지):
  - `.empty` → 두 신규 섹션 모두 hidden (v1 fallback도 빈 상태)
  - `.babyOnly` / `.both` → 두 신규 섹션 노출
  - `.pregnancyOnly` → 신규 섹션 모두 hidden (임신 카드만 노출)
- [ ] `HighlightDetailSheet` state 관리:
  - `@State private var selectedHighlight: InsightCandidate?`
  - `.sheet(item: $selectedHighlight) { candidate in HighlightDetailSheet(candidate:sparkline:aiSummary:) }`
- [ ] `accessibilityIdentifier("weeklyInsightsCardV1")` v1 카드에 추가 (XCUITest XOR 검증용)

**Must NOT do**:
- Do not use `.opacity(0)` / `if false` to hide v1 (XCUITest false positive 위험)
- Do not add `default:` case to AppContext switch
- Do not query Firestore in body (use InsightService.topHighlights)
- Do not access authVM.currentUserId in body — use babyVM.dataUserId() for data, authVM.currentUserId for cohort only
- Do not commit
- Do not run git commands

**References**:
- `BabyCare/Views/Dashboard/DashboardView.swift:35-44` — AppContext switch 패턴
- `BabyCare/Views/Dashboard/DashboardView.swift:50-72` — 섹션 순서
- `BabyCare/Views/Dashboard/DashboardView+Shortcuts.swift:6-72` — weeklyInsightsCard 기존
- `.claude/rules/swift-conventions.md` — AppContext default 금지

**Acceptance Criteria**:

*Functional:*
- [ ] `isHighlightV2Enabled=false` 시 v1 `weeklyInsightsCard` 표시 + 신규 섹션 모두 hidden
- [ ] `isHighlightV2Enabled=true` 시 신규 티커/그리드 표시 + v1 hidden
- [ ] AppContext switch 4 case 명시
- [ ] `selectedHighlight` 변경 시 sheet 표시
- [ ] accessibilityIdentifier "weeklyHighlightTicker" / "weeklyInsightsCardV1" / "weeklyHighlightGrid"

*Static:*
- [ ] `make build` exit 0
- [ ] `make lint` exit 0
- [ ] `make arch-test` 0 violations
- [ ] `grep -c 'default:' BabyCare/Views/Dashboard/DashboardView.swift` 변화 없음 (A-18)

*Runtime:*
- [ ] `make test` PASS
- [ ] `make ui-test` PASS — A-19, A-20

**Verify**:
```yaml
acceptance:
  - given: ["isHighlightV2Enabled=true", "AppContext=.babyOnly"]
    when: "Dashboard render"
    then: ["weeklyHighlightTicker 존재", "weeklyInsightsCardV1 부재", "weeklyHighlightGrid 존재"]
  - given: ["isHighlightV2Enabled=false"]
    when: "Dashboard render"
    then: ["weeklyInsightsCardV1 존재", "weeklyHighlightTicker 부재"]
  - given: ["AppContext=.empty"]
    when: "Dashboard render"
    then: ["두 섹션 모두 hidden (EmptyView)"]
commands:
  - run: "make ui-test"
    expect: "exit 0"
  - run: "make arch-test"
    expect: "0 violations"
risk: HIGH
```

**Rollback Steps**:
- DashboardView.swift git revert (v1 보존되어 있으므로 안전)
- RC `highlight_enabled=false` 즉시 설정 (Firebase Console) — 코드 revert 없이 사용자에게 즉시 v1 fallback

---

### [ ] TODO 9: 사전 캐시 워커 (앱 launch + pull-to-refresh, scenePhase hook 미사용)

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `ai_service` (file): `${todo-6.outputs.ai_service}`
- `cache_model` (file): `${todo-2.outputs.cache_model}`

**Outputs**:
- `precache_worker` (file): `BabyCare/Services/HighlightPrecacheService.swift`

**Steps**:
- [ ] `HighlightPrecacheService` 신규 (`@Observable`, `@MainActor`):
  - `precomputeIfNeeded(userId:babyId:weekKey:) async`
  - 멱등성: UserDefaults 로컬 키 `"highlight.precache.\(weekKey)"` 존재 시 skip
  - in-flight 가드: `private var isPrecomputing: Bool` (중복 호출 방지)
  - TopN 결과 N=3 각각 `HighlightAISummaryService.summarize` 호출 → `HighlightAICache` 저장
  - Anthropic ITPM 50K 보호: per-user 일일 cap (`usageStats/{uid}/{YYYYMM}` Firestore 카운터)
- [ ] 호출 위치:
  - **앱 launch**: `BabyCareApp.swift` `.onAppear` 또는 `init()` 시점 1회 trigger
  - **Pull-to-refresh**: `DashboardView` `.refreshable` 액션
  - **scenePhase=.active 미사용** (비용 폭주 방지)
- [ ] RC 가드: `highlight_enabled=false` 시 워커 skip
- [ ] 임신 metricKey 입력은 InsightService topHighlights에서 이미 필터링됨 (defense in depth — Service에서 한 번 더 reject)

**Must NOT do**:
- Do not hook `scenePhase=.active` (Codex R-2 명시)
- Do not call AI without TTL check + idempotent guard
- Do not call AI for pregnancyOnly users
- Do not exceed per-user daily cap (30 calls/day)
- Do not commit
- Do not run git commands

**References**:
- `BabyCare/App/BabyCareApp.swift` — app launch hook 위치
- `BabyCare/ViewModels/ActivityViewModel.swift:197-204` — 기존 insight load 패턴
- External research: 캐시 키 weekKey 단위, stale-while-revalidate
- TODO 6 outputs — HighlightAISummaryService

**Acceptance Criteria**:

*Functional:*
- [ ] `precomputeIfNeeded` 멱등성 (이미 신선 시 호출 0회)
- [ ] in-flight 가드 (동시 호출 시 1회만 실행)
- [ ] RC false 시 skip
- [ ] Pregnancy metricKey 입력 시 reject (defense in depth)

*Static:*
- [ ] `make build` exit 0
- [ ] `make lint` exit 0
- [ ] `make arch-test` 0 violations

*Runtime:*
- [ ] `make test` PASS — A-21, A-22

**Verify**:
```yaml
acceptance:
  - given: ["UserDefaults key 'highlight.precache.2026W19' 존재"]
    when: "precomputeIfNeeded(weekKey:'2026W19')"
    then: ["HighlightAISummaryService 호출 카운터 == 0"]
  - given: ["isPrecomputing=true"]
    when: "precomputeIfNeeded 추가 호출"
    then: ["즉시 return, 호출 카운터 변경 없음"]
commands:
  - run: "make test"
    expect: "exit 0"
risk: MEDIUM
```

---

### [ ] TODO 10: 회귀 가드 (XCUITest + 단위 테스트 + a11y identifier + QA evidence)

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `dashboard_integration` (file): `${todo-8.outputs.dashboard_integration}`
- `precache_worker` (file): `${todo-9.outputs.precache_worker}`

**Outputs**:
- `unit_tests` (list): 14개 단위 테스트 (BabyCareTests.swift append)
- `ui_tests` (list): 5개 XCUITest (PregnancyFlowTests.swift append 또는 신규 WeeklyHighlightFlowTests.swift)
- `a11y_ids` (list): 5개 accessibility identifier
- `qa_evidence_file` (file): `.dev/qa-evidence/weekly-highlights/v2.8.3.md` (H-1~H-10 scaffold)

**Steps**:
- [ ] BabyCareTests.swift에 14 테스트 append (A-4~A-23에 대응):
  - testHighlightAICache_codableRoundTrip (A-4)
  - testHighlightAICache_TTLBoundary (A-5)
  - testTopHighlights_excludesPregnancyMetrics (A-7)
  - testTopHighlights_allowlistFilter (A-8)
  - testTopHighlights_appContextStates (A-9)
  - testHighlightTicker_reduceMotionPauses (A-10)
  - testHighlightTicker_indexCycles (A-11)
  - testHighlightDetailSheet_emptyDataGuard (A-12)
  - testSparkline_dataNormalization (A-13)
  - testAISummary_hardClampTo200Chars (A-14)
  - testAISummary_payloadAllowlistOnly (A-15)
  - testAISummary_rejectsPregnancyMetric (A-16)
  - testWeeklyHighlightGrid_4Cards (A-17)
  - testCohort_djb2Deterministic (A-23)
  - testAnalytics_noWeekKeyOrBabyIdInParams (A-22)
  - testPrecacheWorker_idempotent (A-21)
- [ ] XCUITest 5 추가 (`PregnancyFlowTests.swift` append):
  - testFlag_off_fallbackToV1Card (A-19)
  - testFlag_on_v2Active (A-20)
  - testHighlightTicker_tapOpensSheet (A-24)
  - testHighlightGrid_4CardsVisible (A-25)
  - testHighlight_emptyStateHidden (A-26)
- [ ] a11y identifier 5개 (이미 TODO 4/5/7/8에서 부착 — 검증만):
  - `weeklyHighlightTicker`
  - `highlightDetailSheet`
  - `weeklyHighlightGrid`
  - `highlightCard_0..3`
  - `weeklyInsightsCardV1`
- [ ] `.dev/qa-evidence/weekly-highlights/v2.8.3.md` scaffold:
  - H-1 VoiceOver / H-2 reduceMotion / H-3 AI 의료 감수 25 샘플 / H-4 Firestore audit / H-5 AIGuardrailService / H-6 다크/라이트 / H-7 Performance / H-8 Functions 배포 / H-9 TTL 168h / H-10 비용 모니터링 — 각 PASS/FAIL 체크박스
- [ ] `make plan-verify` 자체 통과 검증 (PLAN.md 파일 경로 brace glob 없음 확인)

**Must NOT do**:
- Do not create new test file in BabyCareTests (단일 파일 정책 — BabyCareTests.swift append)
- Do not skip a11y identifier verification (XCUITest 의존)
- Do not modify existing 354 tests (append only)
- Do not commit
- Do not run git commands

**References**:
- `BabyCareTests/BabyCareTests.swift:4394` — append 위치 (마지막 라인)
- `BabyCareUITests/PregnancyFlowTests.swift` — XCUITest 패턴
- `.dev/qa-evidence/v2.8.2.md` (기존 Phase 1 ML evidence) — scaffold 패턴
- `.claude/rules/build-gotchas.md` — PLAN brace glob 금지

**Acceptance Criteria**:

*Functional:*
- [ ] 14 단위 테스트 추가 (`make test` 결과 354 → 368+)
- [ ] 5 XCUITest 추가 (`make ui-test` 결과 18 → 23+)
- [ ] 5 a11y identifier 부착 검증 (grep)
- [ ] QA evidence scaffold 파일 존재

*Static:*
- [ ] `make build` exit 0
- [ ] `make lint` exit 0
- [ ] `make arch-test` 0 violations
- [ ] `make plan-verify` exit 0

*Runtime:*
- [ ] `make test` PASS — 모든 A-items 검증
- [ ] `make ui-test` PASS — A-19, A-20, A-24, A-25, A-26

**Verify**:
```yaml
acceptance:
  - given: ["PLAN.md 파일 경로 검증"]
    when: "make plan-verify"
    then: ["exit 0", "brace glob 0건"]
  - given: ["BabyCareTests.swift"]
    when: "test count"
    then: ["≥ 368"]
  - given: ["a11y identifier grep"]
    when: "grep -c 'accessibilityIdentifier' BabyCare/Views/Dashboard/"
    then: ["≥ 5"]
commands:
  - run: "make test"
    expect: "exit 0"
  - run: "make ui-test"
    expect: "exit 0"
  - run: "make plan-verify"
    expect: "exit 0"
risk: LOW
```

---

### [ ] TODO Final: Verification

**Type**: verification

**Required Tools**: `make`, `xcodebuild`, `xcrun`, `firebase` (deploy-rules)

**Inputs**:
- `rc_keys` (list): `${todo-1.outputs.rc_keys}`
- `event_keys` (list): `${todo-1.outputs.event_keys}`
- `collection_constant` (file): `${todo-1.outputs.collection_constant}`
- `feature_flag_method` (file): `${todo-1.outputs.feature_flag_method}`
- `cache_model` (file): `${todo-2.outputs.cache_model}`
- `firestore_crud` (file): `${todo-2.outputs.firestore_crud}`
- `mock_firestore` (file): `${todo-2.outputs.mock_firestore}`
- `firestore_rules` (file): `${todo-2.outputs.firestore_rules}`
- `insight_service_ext` (file): `${todo-3.outputs.insight_service_ext}`
- `ticker_view` (file): `${todo-4.outputs.ticker_view}`
- `detail_sheet` (file): `${todo-5.outputs.detail_sheet}`
- `ai_service` (file): `${todo-6.outputs.ai_service}`
- `functions_handler` (file): `${todo-6.outputs.functions_handler}`
- `highlight_grid` (file): `${todo-7.outputs.highlight_grid}`
- `dashboard_integration` (file): `${todo-8.outputs.dashboard_integration}`
- `precache_worker` (file): `${todo-9.outputs.precache_worker}`
- `unit_tests` (list): `${todo-10.outputs.unit_tests}`
- `ui_tests` (list): `${todo-10.outputs.ui_tests}`
- `a11y_ids` (list): `${todo-10.outputs.a11y_ids}`
- `qa_evidence_file` (file): `${todo-10.outputs.qa_evidence_file}`

**Outputs**: (none)

**Steps**:
- [ ] Run `make build` — 빌드 성공 확인
- [ ] Run `make lint` — SwiftLint 0 경고
- [ ] Run `make arch-test` — 0 violations
- [ ] Run `make test` — 354 + 14 = 368+ 단위 테스트 PASS
- [ ] Run `make ui-test` — 18 + 5 = 23+ XCUITest PASS
- [ ] Run `make index-check` — Firestore composite query 없음 확인
- [ ] Run `make smoke-test` — 시뮬레이터 런치 + 크래시 0
- [ ] Run `make plan-verify` — PLAN ↔ 코드 1:1 검증 (brace glob 금지)
- [ ] Run `make verify` — 전체 체인 PASS (build + lint + arch + test + design-verify)
- [ ] Verify `firestore.rules` highlightCache 규칙 추가 (grep)
- [ ] Verify `remoteconfig.template.json` 2 키 추가 (grep)
- [ ] Verify `babycare-admin/functions/src/summarizeHighlight.ts` 존재 (file exists check)
- [ ] Verify `.dev/qa-evidence/weekly-highlights/v2.8.3.md` H-items scaffold 존재
- [ ] Verify 5 a11y identifier 부착 (`grep -rn 'accessibilityIdentifier' BabyCare/Views/Dashboard/HighlightTickerView.swift BabyCare/Views/Dashboard/HighlightDetailSheet.swift BabyCare/Views/Dashboard/WeeklyHighlightGrid.swift`)
- [ ] Verify `FirestoreCollections.highlightCache` 정의 (grep Constants.swift)
- [ ] Verify 7 Analytics 이벤트 상수 (grep AnalyticsEvents.swift)
- [ ] Verify AppContext switch에 default 없음 (`grep -c 'default:' BabyCare/Views/Dashboard/DashboardView.swift` 변화 없음)
- [ ] Report H-items pending list (사용자 실기기 검증 + AI 감수 + Firestore audit 등)
- [ ] Report S-items: 0 (Tier 4 sandbox 부재 — 정상)

**Must NOT do**:
- Do not use Edit or Write tools (source code modification forbidden)
- Do not add new features or fix errors (report only)
- Do not run git commands
- Bash is allowed for: make/xcodebuild/grep test execution
- Do not modify repo files via Bash (no `sed -i`, `echo >`, etc.)
- Do not start AI Functions deploy (post-work — App Store 승인 후)
- Do not deploy `firestore.rules` (post-work)

**Acceptance Criteria**:

*Functional:*
- [ ] 모든 deliverable files 존재 (TODO 1~10 outputs 18개)
- [ ] `FirestoreCollections.highlightCache` 정의됨
- [ ] 7 Analytics 이벤트 상수 정의됨
- [ ] RC 2 키 `remoteconfig.template.json` 등록
- [ ] `firestore.rules` highlightCache 규칙 + allowlist regex 포함
- [ ] AppContext switch 4 case exhaustive (default 없음)
- [ ] XOR gating (v1 ↔ v2) DashboardView 구현
- [ ] 5 a11y identifier 부착
- [ ] QA evidence scaffold 파일 존재

*Static:*
- [ ] `make build` exit 0
- [ ] `make lint` exit 0 (SwiftLint strict)
- [ ] `make arch-test` 0 violations
- [ ] `make index-check` exit 0
- [ ] `make plan-verify` exit 0

*Runtime:*
- [ ] `make test` exit 0 (368+ tests)
- [ ] `make ui-test` exit 0 (23+ tests)
- [ ] `make smoke-test` exit 0 (크래시 0)
- [ ] `make verify` exit 0 (전체 체인)
