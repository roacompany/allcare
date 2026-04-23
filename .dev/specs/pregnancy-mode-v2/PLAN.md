# pregnancy-mode-v2 — BabyCare iOS 임신 모드 v2 재설계

> v1 5빌드 회귀(56/58/59/60/61) 후 빌드 62에서 FeatureFlag=false로 hide된 임신 모드를 v2.8.0에서 구조적으로 재설계하여 안정 재노출한다. v1 Firestore 스키마 100% 보존, 데이터 삭제 절대 금지, baby-only 사용자 UX 회귀 0.

---

## Assumptions

> Standard/interactive 모드. 인터뷰 8개 질문 + Codex 4 DP 확정 — 모두 User/Agent 결정으로 기록. 실행 전 "가정"으로 남은 항목 없음.

---

## Context

### Original Request
- 사용자: "`.dev/NEXT_SESSION.md` 읽고 `/execute pregnancy-mode-v2` 진행"
- 실제 상황: `pregnancy-mode-v2` spec 미존재 → `/specify` 선행 → 이 PLAN.md
- NEXT_SESSION.md는 2026-04-18(빌드 60) 시점 핸드오프. 2026-04-19~20 빌드 61-62에서 FeatureFlag=false로 임시 hide됨.

### Interview Summary (Q1~Q8)

**Key Discussions**:
- **Q1 UX 공존**: additive card — baby UI 유지 + 홈 스크롤 임신 카드 삽입. AppContext enum 4-state 분기 일원화. 둘째 임신 UX 충족. 세그먼트 스위처/완전분리 비권장.
- **Q2 재노출 gate**: 엄격 — make verify + XCUITest 확장 + smoke + qa-check + plan-reviewer OKAY + codex SHIP + H-items 전부 [V] + TestFlight 내부 3일 무회귀.
- **Q3 RemoteConfig**: 도입 — Firebase RemoteConfig `pregnancy_mode_enabled` 키, fetch 실패 시 fallback=false 강제.
- **Q4 재작성 범위**: 최소 — 4개 전면 재작성(ContentView gating / DashboardPregnancyView / PregnancyTransitionSheet / ViewModel 통합 테스트), 나머지 View 수정만.
- **Q5 Orphan recovery**: Resume UI — pending 감지 시 모달 "전환이 멈춰있어요. 이어서 완료/취소". 자동 삭제 절대 금지.
- **Q6 타겟 릴리즈**: v2.8.0 (minor).
- **Q7 의료 검증**: 출시 전 필수 H-item — ACOG/대한산부인과학회 기준 산부인과 전문의 스팟체크.
- **Q8 스키마 변경**: v1 그대로 — 신규 필드 추가 없음, AppContext 런타임 계산.

**Codex 4 Decision Points (HIGH risk — 사용자 승인 완료)**:
- **DP-1 RemoteConfig 시점**: A (v2.8 함께 도입, v2.6.2 심사 → v2.7.2 Firebase 11.8.0 hotfix → v2.8 chain)
- **DP-2 Protocol 범위**: narrow (`PregnancyFirestoreProviding` — BadgeFirestoreProviding 패턴)
- **DP-3 작업 브랜치**: B (main 기준 새 worktree `pregnancy-mode-v2`, v2.6.2 심사 완료 후 생성)
- **DP-4 orphan 2개+**: A (1개만 Resume 모달, 2개+ 시 Settings 인라인 배너)

### Research Findings (4개 병렬 분석 에이전트 + Codex 전략 종합)

- **markTransitionPending() 호출처 부재** (gap-analyzer): 현재 codebase에 `markTransitionPending()` 명시적 호출 0건. pending orphan이 이론상 발생 불가 → Phase 0 선행 조사로 "pending 생성 경로" 확정 필수.
- **Firebase SDK 업그레이드 필요** (external-researcher): 11.0.0 → **11.8.0+ 업그레이드 필수** (Swift 6 strict concurrency Issue #14257 addOnConfigUpdateListener 크래시 fix). v2.7.2 hotfix로 분리.
- **additive card Health/Recording 진입점 미설계** (gap-analyzer): AppContext.both에서 태동/방문/체중 기록 경로 없음 → P1-4에서 해결.
- **v2.6.2 심사 대기 deadlock** (codex-strategist): 빌드 52 WAITING_FOR_REVIEW 상태에서 main에 Firebase 업그레이드 추가 시 심사 영향. P0-2에서 심사 완료 확인 gate.
- **5빌드 회귀 근본 원인 미재추적** (codex-strategist): 구조(gating 분산)인지 프로세스(테스트 부족)인지 불명. v2가 근본 원인을 해결하는지 검증 필수 → P0-1.
- **make index-check gap 3건은 이미 해소됨** (verification-planner): DRAFT 초기의 "gap 3건" 주장은 오류 (firestore.indexes.json L28, L36에 등재). 신규 복합 쿼리 도입 시 즉시 재등록 gate로 대체.
- **XCUITest Destination 불일치**: Makefile iPhone 17 Pro / ci.yml iPhone 16 Pro — 통일 권장.
- **위젯 타겟 RemoteConfig 직접 fetch 불가**: 메인 앱이 `PregnancyWidgetDataStore.clear()` 호출 로직 필요 (flag=false 시).

---

## Work Objectives

### Core Objective
v1 임신 모드의 5빌드 회귀 근본 원인을 **구조적으로 제거**한 v2 구현을 v2.8.0에 포함하여 RemoteConfig 100%로 안정 재노출한다. 데이터/스키마 100% 보존, baby-only 사용자 UX 회귀 0.

### Concrete Deliverables

**Phase 0 (Pre-work 산출물 - 문서/분리 PR)**:
- `.dev/specs/pregnancy-mode-v2/context/regression-rootcause.md` — v1 5빌드 회귀 근본 원인 분석
- `.dev/specs/pregnancy-mode-v2/context/submission-status.md` — v2.6.2 심사 상태 + v2.7.2 Firebase hotfix 일정
- `.dev/specs/pregnancy-mode-v2/context/pending-spec.md` — markTransitionPending 호출 경로 spec (3 시나리오 중 선택)
- `.dev/specs/pregnancy-mode-v2/context/h-items-evaluators.md` — H-items 10개 평가자/evidence 포맷
- 별도 feature branch `feat/firebase-11.8.0-compat` (Firebase 업그레이드, pregnancy와 분리)

**Phase 1-4 (코드 산출물)**:
- `BabyCare/Utils/AppContext.swift` — 신규 (static factory, 4-state, `default:` 금지)
- `BabyCare/Services/FeatureFlagService.swift` — 신규 Hybrid gateway (@Observable @MainActor, 3-layer fallback)
- `BabyCare/Utils/StableHash.swift` — 신규 (DJB2 deterministic cohort bucketing)
- `BabyCare/Views/Dashboard/DashboardPregnancyHomeCard.swift` — 신규 (additive card)
- `BabyCare/App/ContentView.swift` — 온보딩 2버튼 재설계, nested sheet 제거
- `BabyCare/Views/Pregnancy/PregnancyTransitionSheet.swift` — 출산/종료 CTA 분리
- `BabyCare/Views/Pregnancy/PregnancyRecoveryModal.swift` — 신규 (Resume UI, pending==1 시)
- `BabyCare/Views/Dashboard/DashboardPregnancyView.swift` — 최소 수정 (D-7 제거, Milestone nil-check)
- `BabyCare/Views/Health/HealthView.swift` — AppContext 정합 + 임신 섹션 추가(.both)
- `BabyCare/Views/Recording/RecordingView.swift` — AppContext 정합 + 임신 탭 추가(.both)
- `BabyCare/Services/PregnancyFirestoreProviding.swift` — 신규 narrow protocol (`fetchSharedPregnancy` 포함)
- `BabyCareTests/MockPregnancyFirestore.swift` — 신규
- `firestore.rules` — collectionGroup Partner read 규칙 추가
- `BabyCareTests/BabyCareTests.swift` — 신규 단위 테스트 20개+ append
- `BabyCareUITests/PregnancyFlowTests.swift` — 신규 XCUITest 8개 추가 (기존 10 + 신규 8 = 18)
- `BabyCare/Resources/pregnancy-weeks.json` — 의료 검증 반영 (변경 내역 별도 PR)
- `.dev/qa-evidence/v2.8.0.md` — H-items 10개 전부 [V]

**Phase 4 (출시 산출물)**:
- `/Users/roque/allcare/privacy.html` 갱신
- Firebase Console: RemoteConfig `pregnancy_mode_enabled` 파라미터 100% 배포
- TestFlight v2.8.0 빌드 + App Store 제출

### Definition of Done

- [ ] Phase 0 6개 TODO 완료 (P0-1~P0-5 + P0-2b) + v2.6.2 심사 상태 "APPROVED" 확정
- [ ] P0-2b: `feat/firebase-11.8.0-compat` PR main 머지 완료 + TestFlight v2.7.2 내부 무회귀 확인
- [ ] P0-5: firestore.rules collectionGroup Partner read 규칙 배포 + Firebase Console Rules Simulator 3 시나리오 PASS
- [ ] `make verify` PASS (281+ 단위 + 확장 신규 20+ = 301+ 단위 테스트, arch-test 0 violations)
- [ ] `make ui-test` PASS (XCUITest 18 = 10 기존 + 8 신규)
- [ ] `make plan-verify` PASS (PLAN ↔ 코드 1:1 매칭)
- [ ] `make smoke-test` PASS (시뮬 런치 + 크래시 체크)
- [ ] `make qa-check` PASS (`.dev/qa-evidence/v2.8.0.md` "PASS" 문자열 존재)
- [ ] `make index-check` PASS (pregnancy 관련 신규 복합 쿼리 + indexes.json 동기화)
- [ ] `make deploy-rules` PASS (firestore rules + indexes 배포)
- [ ] `bash scripts/pre_merge_check.sh` PASS
- [ ] `/review` 또는 `hoyeon:code-reviewer` SHIP 판정
- [ ] `/tribunal` 또는 codex review SHIP 판정
- [ ] H-1~H-10 10개 전부 [V] (각 evidence 포맷 준수)
- [ ] TestFlight v2.8.0 내부 테스터 3일 무회귀 (Crashlytics crash-free >= 99%, 임신 관련 crash 0건)
- [ ] RemoteConfig 100% 활성화 + 24시간 모니터링 무이상

### Must NOT Do (Guardrails)

> **Data/Schema 보존**:
- DO NOT pregnancy Firestore 문서 자동 삭제 (MEMORY: `feedback_no_data_deletion.md`, 2026-04-19 사용자 룰)
- DO NOT `PregnancyOutcome` rawValue 변경 (영구 계약, MEMORY: `feedback_enum_raw_value_contract.md`)
- DO NOT `EDD` 덮어쓰기 (eddHistory append-only 강제)
- DO NOT `Pregnancy` 모델에 새 필드 추가 (Q8: v1 스키마 그대로)
- DO NOT 출산 전환을 단일 write로 처리 (WriteBatch + transitionState 필수)
- DO NOT `KickEvent`를 별도 서브컬렉션으로 (KickSession.kicks 배열 임베딩)

> **아키텍처 위반 금지**:
- DO NOT `activePregnancy != nil` 단독 gating (AppContext 분기만, 빌드 60 회귀 패턴)
- DO NOT `PregnancyWidgetDataStore`를 기존 `WidgetDataStore`에 병합
- DO NOT UIView 인스턴스 SwiftUI 컨텍스트 간 공유 (per-instance, 빌드 59 회귀)
- DO NOT `authVM.currentUserId` 직접 사용 (`babyVM.dataUserId()` / `pregnancyVM.dataUserId()`)
- DO NOT `FirestoreCollections` 상수 없이 컬렉션명 하드코딩
- DO NOT `AppContext` switch에 `default:` 케이스 추가 (exhaustive 4-case 강제, 새 case 추가 시 컴파일러가 모든 switch 강제 알림 → 빌드 58 회귀 같은 silent skip 방지)
- DO NOT `FeatureFlagService`를 우회하고 `FirebaseRemoteConfig`를 `FeatureFlags.swift`에 직접 import (단일 gateway 강제)
- DO NOT `Swift.hashValue` 또는 `Int.random`으로 cohort bucketing (non-deterministic — `StableHash.djb2` 강제)

> **RemoteConfig 안전**:
- DO NOT RemoteConfig fetch 실패 시 fallback을 `true`로 (강제 `false`, Firebase Console 공식 설정)
- DO NOT `FeatureFlags.pregnancyModeEnabled` hardcoded bool을 true로 변경 후 RemoteConfig 래퍼 중첩 (AND 조합 위험)
- DO NOT `RemoteConfig.fetchAndActivate()` 를 `ContentView.task {}` 내부 호출 (첫 렌더 race)
- DO NOT `minimumFetchInterval = 0`을 prod 빌드에 (`ThrottledException` 위험)
- DO NOT RemoteConfig에 민감 정보 저장 (public-readable)

> **프라이버시/보안**:
- DO NOT 임신 데이터를 Firebase Analytics/Crashlytics custom params에 포함 (민감 건강 정보)
- DO NOT `AIGuardrailService.prohibitedRules` 수정

> **심사/배포 안전**:
- DO NOT v2.6.2(빌드 52) 심사 대기 중 main에 Firebase 업그레이드 merge (심사 영향)
- DO NOT feat/pregnancy-mode(빌드 60 시점)를 main에 바로 merge (5빌드 회귀 코드 포함)
- DO NOT `firestore.rules` pregnancy 블록 기존 조건 삭제/하향 조정
- DO NOT `firestore.indexes.json`의 기존 `todos` 인덱스 건드림 (Console 자동 생성분, 재작성 시 오탐)
- DO NOT `fetchActivePregnancy` 쿼리에 `transitionState isNotEqualTo "pending"` 조건 추가 (Resume UI 불가능화)

> **Scope 경계**:
- DO NOT `FirestoreServiceProtocol` 전체 도입 (DP-2: narrow만, v3+로 분리)
- DO NOT `DashboardPregnancyView` 전면 재작성 (Codex Rec-5: D-7 제거 + Milestone nil-check 2개 변경만)
- DO NOT XCUITest 15+ 목표 숫자 채우기 (Codex Rec-8: 8개 핵심 + 단위 테스트 12개)
- DO NOT `AppContext` enum을 `AppState` 내부 중첩 타입으로 (독립 `Utils/AppContext.swift`)

---

## Verification Summary

### Agent-Verifiable (A-items)

| ID | Criterion | Method | Related TODO |
|----|-----------|--------|-------------|
| A-0 | 전체 하네스 통과 | `make verify` (build+lint+arch-test+test+design-verify) | 모든 TODO |
| A-0b | 머지 게이트 | `bash scripts/pre_merge_check.sh` | 모든 TODO |
| A-1 | AppContext static factory 4-state 단위 테스트 12 | `make test` | P1-1 |
| A-2 | 6곳 gating 하드코딩 grep=0 | `grep -rn 'FeatureFlags.pregnancyModeEnabled && pregnancyVM' BabyCare/Views/ \| wc -l` → 0 | P1-2, P1-3, P1-4, P1-5 |
| A-3 | arch-test 0 violations | `make arch-test` | P1-1~P1-5 |
| A-4 | 빌드 58/60 회귀 방지 XCUITest | `testGating_babyAndPregnancy_showsBabyUI_빌드59회귀방지`, `test_babyAndPregnancy_showsBabyDashboard` | P1-3, P1-4 |
| A-5 | PregnancyDateMath 11 테스트 PASS | `make test` | P1-5 |
| A-6 | PregnancyOutcomeContractTests 4 PASS | `make test` | P2-1 |
| A-7 | Pregnancy(transitionState: "pending") mock 주입 시 Resume 상태 노출 단위 테스트 | `make test` | P2-2 |
| A-8 | RemoteConfig fetch 실패 fallback=false 단위 테스트 | `make test` | P2-4 |
| A-9 | feature_flag_smoke.sh PASS (RemoteConfig 전환 후에도) | `bash scripts/feature_flag_smoke.sh` | P2-4 |
| A-10 | MockPregnancyFirestore + PregnancyViewModel 통합 테스트 | `make test` | P2-3 |
| A-11 | XCUITest 18 PASS (10 기존 + 8 신규) | `make ui-test` | P3-1 |
| A-12 | pregnancy-weeks.json 구조 검증 | `python3 scripts/pregnancy_weeks_sanity.py .` | P3-2 |
| A-13 | 신규 복합 쿼리 index 동기화 | `make index-check` | P2-2, P2-3 (신규 쿼리 도입 시) |
| A-14 | Firestore rules + indexes 배포 | `make deploy-rules` | P4-1 |
| A-15 | PLAN ↔ 코드 매칭 | `make plan-verify` | TODO Final |
| A-16 | smoke-test PASS (시뮬 런치 + 크래시 0) | `make smoke-test` | TODO Final |
| A-17 | AppContext switch `default:` 0 hits (exhaustive 강제) | `grep -rn 'default:' BabyCare/ \| grep -B2 'AppContext' \| wc -l` → 0 | P1-1, P1-2~P1-4 |
| A-18 | `FeatureFlags.swift`에 `FirebaseRemoteConfig` import 없음 (단일 gateway) | `! grep -q 'import FirebaseRemoteConfig' BabyCare/Utils/FeatureFlags.swift` | P2-4 |
| A-19 | firestore.rules collectionGroup Partner 규칙 존재 | `grep -q '{path=\*\*}/pregnancies' firestore.rules && grep -q 'sharedWith is list' firestore.rules` | P0-5 |
| A-20 | `fetchSharedPregnancy` collectionGroup 구현 존재 | `grep -q 'fetchSharedPregnancy' BabyCare/Services/PregnancyFirestoreProviding.swift && grep -q 'collectionGroup' BabyCare/Services/FirestoreService+Pregnancy.swift` | P2-3 |

### Human-Required (H-items)

| ID | Criterion | Reason | Review Material | 평가자 (P0-4) |
|----|-----------|--------|----------------|-----|
| H-1 | 태동 햅틱 + 2시간+ 장시간 세션 안정성 | UIImpactFeedbackGenerator 진동 강도/패턴, 메모리/UI 안정성 XCUITest timeout 제약 | 실기기 KickSession 2시간 완료 스크린샷 + 기기 로그 | QA (팀원 지정) |
| H-2 | 출산 전환 + 축하 애니메이션 | WriteBatch 실 호출, 애니메이션 timing/감정 적절성 코드 판정 불가 | 실기기 TestFlight pregnancy→born 전환 완료 스크린샷 | Product + QA |
| H-3 | DashboardPregnancyHomeCard 시각 품질 (라이트/다크) | design-verify 통과해도 실제 대비/레이아웃 사람 판단 | `make screenshots` 캡처 + 사용자 리뷰 | 디자이너 |
| H-4 | pregnancy-weeks.json 37주 의료 검증 | ACOG/대한산부인과학회 기준 콘텐츠 정확성 (Q7: 출시 전 필수) | 전문의 서명 또는 출처 URL 명시 문서 | 산부인과 전문의 (외부) |
| H-5 | RemoteConfig off 실기기 (비행기 모드 fallback) | 실 RemoteConfig fetch 후 캐시 만료, 비행기 모드 fallback | TestFlight 실기기 설정 스크린샷 + 진입점 미노출 | QA |
| H-6 | 위젯 visual 3종 (small/medium/accessoryCircular) × 라이트/다크/잠금화면 | WidgetKit adaptive color 실기기 필수 | 실기기 홈/잠금화면 위젯 스크린샷 6장+ | 디자이너 + QA |
| H-7 | HealthKit 임신 데이터 opt-in 실기기 | 권한 요청 시스템 alert 실기기만 정상 | 권한 허용/거부 각 케이스 스크린샷 + 데이터 기록 확인 | QA |
| H-8 | Accessibility XXXL 전체 진입점 시각 | ViewThatFits 분기 후 레이아웃 잘림/오버플로 시각 판단 | 시뮬레이터 Dynamic Type XXXL 스크린샷 | 디자이너 |
| H-9 | transitionState=pending Recovery UI 실 orphan | 빌드 56-61 기간 실 orphan 문서 가진 계정에서 Resume UI 자연 노출 | Firebase Console 실 계정 transitionState=pending 주입 후 앱 확인 | QA + Engineer |
| H-10 | Privacy Policy 건강 데이터 항목 법적 검토 | 개인정보보호법/앱스토어 리뷰 정책 법적 판단 | 갱신된 privacy.html 리뷰 + 법무 검토 의견서 | 법무 (외부) |
| H-11 | Partner visibility 실 배포 검증 | firestore.rules collectionGroup이 실제로 partner에게 owner pregnancy read 허용하는지 Firebase Console + 실 계정 확인 | Rules Simulator 3 시나리오 결과 + 실 계정 sharedWith 파트너 앱에서 owner pregnancy 표시 스크린샷 | QA + Engineer |
| H-12 | RemoteConfig Hybrid 심사 safe 제출 | `FeatureFlags.pregnancyModeEnabled = true` + Console `pregnancyRolloutPct = 0` 심사 후 2.5.2 위반 없이 통과 | App Store Connect 심사 결과 + Firebase Console rollout 0% 유지 로그 | Engineer |

### Sandbox Agent Testing (S-items)

**none** — iOS 프로젝트로 Docker sandbox 인프라 부재. XCUITest(Tier 3)가 E2E 역할. Tier 4 Agent Sandbox는 본 프로젝트 out of scope.

### Verification Gaps

- **Tier 4 Agent Sandbox 전무**: iOS `xcrun simctl` 기반 headless launch는 가능하나 Docker sandbox 패턴 부재. v3+에서 `swift-snapshot-testing` 도입 검토.
- **FirestoreServiceProtocol 전체 미존재**: BadgeFirestoreProviding(배지 한정)만 존재. TODO P2-3 완료 전 PregnancyViewModel 통합 테스트 일부 제한.
- **XCUITest CI 미포함**: `.github/workflows/ci.yml:47`이 `BabyCareTests`만 실행. PR 자동화에 `make ui-test` 추가 권장(P3-1과 병행).
- **XCUITest Destination 불일치**: Makefile iPhone 17 Pro / ci.yml iPhone 16 Pro — 통일 필요(P0-2 후속).
- **TestFlight DAU 정확도**: "3일 무회귀" 판정 신뢰도는 내부 테스터 규모에 의존. 외부 사용자 수 명확화는 P0-4에서.
- **의료 검증 외부 dependency**: H-4는 산부인과 전문의 일정 블로커. v2.8 타임라인의 critical path.

---

## External Dependencies Strategy

### Pre-work (user prepares before AI work)

| Dependency | Action | Command/Step | Blocking? |
|------------|--------|-------------|-----------|
| App Store Connect | v2.6.2(빌드 52) 심사 상태 확인 | https://appstoreconnect.apple.com/ → Apps → 심사 대기/승인/거부 | 🔴 Yes |
| Firebase Console | RemoteConfig 파라미터 생성 | Project → Remote Config → `pregnancy_mode_enabled` (Bool, default=false) | 🔴 Yes |
| Firebase Console | Analytics User Property | `is_internal_tester` 등록 (TestFlight 고정용) | ⚪ Optional |
| 산부인과 전문의 | pregnancy-weeks.json 리뷰 약속 | 이메일/문서로 기한 공유 (Q7: 출시 전 필수) | 🔴 Yes |
| 법무 담당 | Privacy Policy 리뷰 약속 | 의견서 수령 기한 공유 (H-10) | 🔴 Yes |
| Git | main 기준 새 worktree 생성 (DP-3 B) | `/worktree create pregnancy-mode-v2` (v2.6.2 심사 완료 후) | 🔴 Yes |

### During (AI work strategy)

| Dependency | Dev Strategy | Rationale |
|------------|-------------|-----------|
| Firebase Firestore | Production DB 사용 (emulator 미설치), MockPregnancyFirestore (TODO P2-3 신규) | 기존 BadgeFirestoreProviding 패턴 |
| Firebase RemoteConfig | In-memory defaults plist mock (XCTest), 실 fetch는 TestFlight에서 검증 (H-5) | Firebase SDK 11.8.0+ async API |
| HealthKit | 시뮬 권한 alert 불안정 → 실기기 H-7로 이관 | 시뮬 한계 |
| XCUITest | iPhone 17 Pro sim (Makefile), CI iPhone 16 Pro 불일치 (수정 필요) | Xcode 16+ iPhone 17 Pro availability |
| AdMob | 시뮬 테스트 광고 ID | per-instance 구조 유지 (빌드 59 fix) |

### Post-work (user actions after completion)

| Task | Related Dependency | Action | Command/Step |
|------|--------------------|--------|-------------|
| Firebase RemoteConfig 100% | Firebase Console | `pregnancy_mode_enabled = true` 100% 배포 | Firebase Console → Remote Config → Publish |
| Privacy Policy 공개 | `/Users/roque/allcare/` | GitHub Pages 배포 | `cd /Users/roque/allcare && git push` |
| App Store 제출 | App Store Connect | v2.8.0 빌드 제출 + 심사 대기 | App Store Connect |
| feat/pregnancy-mode worktree 정리 | Git | v1 worktree 삭제 또는 보존 | `/worktree cleanup` (보존 권장 — 비교용) |
| CHANGELOG 작성 | CHANGELOG.md | v2.8.0 섹션 한국어/영어 | 수동 |
| 랜딩 페이지 동기화 | /Users/roque/allcare/ | `Skill("changelog-to-landing-sync")` | 수동 |

> **Blocking Pre-work 모두 완료 전 Phase 1 착수 금지.** Phase 0가 이 관리를 담당.

---

## Task Flow

```
Phase 0 (선행작업, 순차) — 심사 gate + 회귀 분석 + Firebase hotfix + 경로 spec + 평가자 정의 + Partner rules
    P0-1 → P0-2 (심사 확인) → P0-2b (Firebase 11.8.0 hotfix) ↗
                            → P0-3, P0-4, P0-5 (병렬) ↘ (P0-5는 rules 배포, rollout-runbook)
    ↓
Phase 1 (구조) — AppContext 선행, 나머지 순차
    P1-1 → P1-2 → P1-3 → P1-4 → P1-5
    ↓
Phase 2 (기능) — 병렬 가능한 부분 있음
    P2-1, P2-3 (병렬) → P2-2 (P0-3 결과에 의존) → P2-4 (P0-2b 완료 후)
    ↓
Phase 3 (검증) — P3-1 선행, P3-2/P3-3 병렬
    P3-1 → P3-2, P3-3 (병렬)
    ↓
Phase 4 (출시)
    P4-1 → P4-2 (TestFlight 3일 후)
    ↓
TODO Final: Verification
```

## Dependency Graph

| TODO | Requires (Inputs) | Produces (Outputs) | Type |
|------|-------------------|-------------------|------|
| P0-1 | — | `regression_analysis_path` (file) | work |
| P0-2 | `regression_analysis_path` | `submission_status_path` (file) | work |
| P0-2b | `submission_status_path` | `firebase_hotfix_pr_url` (string), `testflight_v272_build` (string) | work |
| P0-3 | — | `pending_spec_path` (file), `pending_is_valid` (string: "valid"\|"remove") | work |
| P0-4 | — | `h_items_evaluators_path` (file) | work |
| P0-5 | `submission_status_path` | `rules_deployed_at` (string), `collectionGroup_rule_active` (string) | work |
| P1-1 | `submission_status_path` | `appcontext_path` (file), `appcontext_tests_count` (string) | work |
| P1-2 | `appcontext_path` | `contentview_path` (file) | work |
| P1-3 | `appcontext_path` | `dashboard_card_path` (file), `dashboard_view_path` (file) | work |
| P1-4 | `appcontext_path` | `health_view_path` (file), `recording_view_path` (file) | work |
| P1-5 | `appcontext_path` | `dashboard_pregnancy_path` (file) | work |
| P2-1 | `appcontext_path` | `transition_sheet_path` (file) | work |
| P2-2 | `pending_spec_path`, `pending_is_valid`, `appcontext_path` | `recovery_modal_path` (file) or `skipped` (string) | work |
| P2-3 | — | `pregnancy_firestore_providing_path` (file), `mock_pregnancy_firestore_path` (file) | work |
| P2-4 | `${todo-P0-2b.outputs.firebase_hotfix_pr_url}` (merged) | `featureflag_service_path` (file), `stable_hash_path` (file) | work |
| P3-1 | `appcontext_path`, `contentview_path`, `dashboard_card_path`, `dashboard_view_path`, `health_view_path`, `recording_view_path`, `dashboard_pregnancy_path`, `transition_sheet_path`, `recovery_modal_path`, `pregnancy_firestore_providing_path`, `featureflag_service_path` | `xcuitest_count` (string) | work |
| P3-2 | `h_items_evaluators_path` | `pregnancy_weeks_verified_path` (file), `h4_evidence` (file) | work |
| P3-3 | `appcontext_path`, `contentview_path`, `dashboard_card_path`, `transition_sheet_path`, `recovery_modal_path`, `featureflag_service_path`, `h_items_evaluators_path` | `qa_evidence_v280_path` (file) | work |
| P4-1 | `qa_evidence_v280_path` | `privacy_html_path` (file) | work |
| P4-2 | P4-1 outputs | `testflight_build_number` (string), `rollout_log_path` (file) | work |
| Final | all outputs | — | verification |

## Parallelization

| Group | TODOs | Reason |
|-------|-------|--------|
| G1 (Phase 0 병렬) | P0-3, P0-4, P0-5 (+ P0-2b separate branch) | 상호 독립적 (P0-2 완료 후) |
| G2 (Phase 2 병렬) | P2-1, P2-3 | 서로 다른 파일 (TransitionSheet vs Protocol) |
| G3 (Phase 3 병렬) | P3-2, P3-3 | 의료 검증 외부 의존 vs 내부 QA |

## Commit Strategy

> **Orchestrator commits on behalf of Workers.**

| After TODO | Message | Files | Condition |
|------------|---------|-------|-----------|
| P0-1 | `docs(pregnancy-v2): regression rootcause analysis` | `.dev/specs/pregnancy-mode-v2/context/regression-rootcause.md` | always |
| P0-2 | `docs(pregnancy-v2): v2.6.2 submission status + firebase hotfix plan` | `.dev/specs/pregnancy-mode-v2/context/submission-status.md` | always |
| P0-3 | `docs(pregnancy-v2): markTransitionPending path spec` | `.dev/specs/pregnancy-mode-v2/context/pending-spec.md` | always |
| P0-4 | `docs(pregnancy-v2): H-items evaluators + evidence format` | `.dev/specs/pregnancy-mode-v2/context/h-items-evaluators.md` | always |
| P0-5 | `chore(rules): pregnancies collectionGroup partner read` | `firestore.rules` | always |
| P0-2b | `chore(firebase): 11.8.0 hotfix for Swift 6 concurrency` | `project.yml` (별도 브랜치 `feat/firebase-11.8.0-compat`, main merge) | always |
| P1-1 | `feat(pregnancy-v2): AppContext static factory + 12 unit tests` | `Utils/AppContext.swift`, `BabyCareTests.swift` | always |
| P1-2 | `feat(pregnancy-v2): ContentView 2-button onboarding, NOT logic removed` | `App/ContentView.swift`, `Views/Settings/AddBabyView.swift` | always |
| P1-3 | `feat(pregnancy-v2): additive DashboardPregnancyHomeCard` | `Views/Dashboard/DashboardPregnancyHomeCard.swift`, `Views/Dashboard/DashboardView.swift` | always |
| P1-4 | `feat(pregnancy-v2): HealthView/RecordingView AppContext parity + both-mode entry` | `Views/Health/HealthView.swift`, `Views/Recording/RecordingView.swift` | always |
| P1-5 | `fix(pregnancy-v2): DashboardPregnancyView remove D-7 limit, Milestone nil-check` | `Views/Dashboard/DashboardPregnancyView.swift` | always |
| P2-1 | `feat(pregnancy-v2): TransitionSheet split birth vs termination CTA` | `Views/Pregnancy/PregnancyTransitionSheet.swift`, `Views/Settings/SettingsView.swift` | always |
| P2-2 | `feat(pregnancy-v2): PregnancyRecoveryModal for pending orphan` | `Views/Pregnancy/PregnancyRecoveryModal.swift`, `ViewModels/PregnancyViewModel.swift` | conditional (P0-3 valid) |
| P2-3 | `feat(pregnancy-v2): PregnancyFirestoreProviding narrow protocol + MockPregnancyFirestore` | `Services/PregnancyFirestoreProviding.swift`, `BabyCareTests/MockPregnancyFirestore.swift`, `ViewModels/PregnancyViewModel.swift` | always |
| P2-4 | `feat(pregnancy-v2): FeatureFlagService Hybrid + StableHash (DJB2 cohort)` | `Services/FeatureFlagService.swift`, `Utils/StableHash.swift`, `Utils/FeatureFlags.swift`, `App/BabyCareApp.swift`, `Services/PregnancyWidgetSyncService.swift`, `project.yml`, `scripts/feature_flag_smoke.sh` | always |
| P3-1 | `test(pregnancy-v2): XCUITest +8, unit tests +20` | `BabyCareUITests/PregnancyFlowTests.swift`, `BabyCareTests.swift` | always |
| P3-2 | `chore(pregnancy-v2): pregnancy-weeks.json medical review reflected` | `Resources/pregnancy-weeks.json`, `.dev/qa-evidence/v2.8.0.md` (H-4 섹션) | always |
| P3-3 | `docs(pregnancy-v2): QA evidence v2.8.0 H-items all V` | `.dev/qa-evidence/v2.8.0.md` | always |
| P4-1 | `chore(pregnancy-v2): Privacy Policy pregnancy data section` | `/Users/roque/allcare/privacy.html` (별도 repo) | always |
| P4-2 | `chore(release): v2.8.0 TestFlight upload + RemoteConfig 100%` | `project.yml` (bump), `.dev/specs/pregnancy-mode-v2/context/rollout-log.md` | always |

> **No commit after Final** (Verification does not modify source).

## Error Handling

### Failure Categories

| Category | Examples | Detection Pattern |
|----------|----------|-------------------|
| `env_error` | Firebase SDK fetch 실패, simulator unavailable, 심사 대기 상태 blocking | `/Firebase SDK fetch failed\|simulator.*unavailable\|WAITING_FOR_REVIEW/i` |
| `code_error` | Swift 컴파일 에러, arch-test violation, XCUITest assertion fail | `/error:.*swift\|arch_test violation\|XCTAssert.*failed/i` |
| `scope_internal` | markTransitionPending 경로 결정 보류(P0-3), 의료 검증자 일정 변경 | verify Worker `suggested_adaptation` 존재 |
| `unknown` | 분류 불가 에러 | 기본 fallback |

### Failure Handling Flow

| Scenario | Action |
|----------|--------|
| work 실패 | 최대 2회 재시도 → Analyze → 아래 After Analyze |
| verification 실패 | 즉시 Analyze (재시도 없음) → 아래 After Analyze |
| Worker 타임아웃 | Halt + report |
| Missing Input | 의존 TODO skip + halt |
| H-4/H-10 외부 의존 미이행 | Halt + `.dev/specs/pregnancy-mode-v2/context/issues.md` 기록, 사용자 승인 대기 |

### After Analyze

| Category | Action |
|----------|--------|
| `env_error` | Halt + `issues.md` 기록 (특히 심사 상태) |
| `code_error` | Fix Task 생성 (depth=1) |
| `scope_internal` | Adapt → Dynamic TODO (depth=1, Fix Task 메커니즘 활용) |
| `unknown` | Halt + `issues.md` 기록 |

### Fix Task Rules
- Fix Task type은 항상 `work`
- Fix Task 실패 → Halt
- Max depth = 1

### Adapt Rules
- Adapt = Fix Task 메커니즘 (delegation)
- Scope check: DoD match OR file allowlist → adapt; both NO + non-destructive → adapt (OUT_OF_SCOPE 태그); both NO + destructive → halt
- P0-3 "pending 경로 정의"가 scope_internal 대표 사례 — 3 시나리오 중 선택에 따라 P2-2 구현/건너뛰기 결정

## Runtime Contract

| Aspect | Specification |
|--------|---------------|
| Working Directory | v2.6.2 심사 완료 후 생성될 `/Users/roque/BabyCare/.worktrees/pregnancy-mode-v2/` (DP-3 B) |
| Network Access | Allowed (Firebase fetch, TestFlight upload) |
| Package Install | 제한적 허용 (Firebase SDK 11.8.0+ SPM 업그레이드만) |
| File Access | Repo only + `/Users/roque/allcare/` (Privacy Policy) |
| Max Execution Time | 10분/TODO (P3-3 QA evidence 수집은 예외, 실기기 의존) |
| Git Operations | Orchestrator만 (Worker 금지) |

---

## TODOs

### [x] P0-1: v1 5빌드 회귀 근본 원인 재추적

**Type**: work

**Required Tools**: `git`

**Inputs**: (none)

**Outputs**:
- `regression_analysis_path` (file): `.dev/specs/pregnancy-mode-v2/context/regression-rootcause.md` — 빌드 56-61 각 회귀의 root cause + v2가 해결하는 방식

**Steps**:
- [ ] `git log feat/pregnancy-mode --oneline --since="2026-04-17" --until="2026-04-20"` 로 빌드 56-61 커밋 수집
- [ ] 각 빌드 bump 커밋 전후 diff 검토 → 회귀 유발 변경 식별
- [ ] CLAUDE.md `v2.7.1 임신 모드 회귀 이력` 섹션 + `.dev/specs/done/pregnancy-mode/context/learnings.md` 대조
- [ ] 각 회귀 분류: (a) 구조 버그 (gating 패턴) / (b) 프로세스 버그 (테스트 부족) / (c) external (Firestore 규칙/인덱스)
- [ ] v2 설계가 각 근본 원인을 해결하는지 1:1 매핑 표 작성
- [ ] 해결 불가/부분적 원인 명시 (있다면)

**Must NOT do**:
- Do not modify source code (분석 문서만 작성)
- Do not run git reset/rebase/push
- Do not run git commands beyond log/show/diff

**References**:
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/CLAUDE.md:v2.7.1 임신 모드 회귀 이력`
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/.dev/specs/done/pregnancy-mode/context/learnings.md`
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/.dev/NEXT_SESSION.md`

**Acceptance Criteria**:

*Functional:*
- [ ] 파일 존재: `.dev/specs/pregnancy-mode-v2/context/regression-rootcause.md`
- [ ] 5빌드(56/58/59/60/61) 각각 원인 + 분류 + v2 해결책 매핑 기재
- [ ] "v2 미해결" 회귀 항목 별도 기재 (있다면)

*Static:*
- [ ] `cat .dev/specs/pregnancy-mode-v2/context/regression-rootcause.md` — 섹션 5개 (빌드별) + 요약 매핑 표 포함

*Runtime:*
- [ ] (문서 TODO, 테스트 무관)

**Verify**:
```yaml
acceptance:
  - given: ["git history 접근 가능", "CLAUDE.md 기존 섹션 존재"]
    when: "P0-1 실행"
    then: ["regression-rootcause.md 생성", "빌드 5개 모두 root cause 분류", "v2 해결책 명시"]
commands:
  - run: "test -f .dev/specs/pregnancy-mode-v2/context/regression-rootcause.md"
    expect: "exit 0"
  - run: "grep -c '## 빌드' .dev/specs/pregnancy-mode-v2/context/regression-rootcause.md"
    expect: "stdout >= 5"
risk: LOW
```

---

### [x] P0-2: v2.6.2 심사 상태 확인 + Firebase 11.8.0 hotfix 계획

**Type**: work

**Required Tools**: `git`

**Inputs**:
- `regression_analysis_path` (file): `${todo-P0-1.outputs.regression_analysis_path}` — 회귀 분석 참조

**Outputs**:
- `submission_status_path` (file): `.dev/specs/pregnancy-mode-v2/context/submission-status.md` — v2.6.2 상태 + Firebase hotfix 분리 계획 (실제 hotfix 실행은 P0-2b)

**Steps**:
- [ ] 사용자에게 App Store Connect `v2.6.2 빌드 52` 현재 상태 확인 요청 (APPROVED/REJECTED/WAITING)
- [ ] 상태에 따라 분기 판단:
  - APPROVED → Firebase hotfix 진행 가능
  - WAITING 지속 → 심사 완료까지 Phase 1 시작 금지 표시
  - REJECTED → 대응 계획 별도 수립 후 Phase 1 보류
- [ ] `feat/firebase-11.8.0-compat` 브랜치 계획서 작성 (pregnancy와 분리, main 기준, 단독 PR)
- [ ] Firebase SDK 11.0.0 → 11.8.0+ 업그레이드 영향 범위 기재 (12개 VM, 위젯 타겟, test infra)
- [ ] hotfix PR 머지 → TestFlight v2.7.2 테스트 → main 머지 타임라인 표시
- [ ] `submission-status.md`에 심사 상태 + hotfix 일정 + v2.8 시작 예상일 표시

**Must NOT do**:
- Do not push Firebase 업그레이드를 main (심사 대기 중이면 절대 금지)
- Do not modify Firebase version in pregnancy-mode-v2 worktree (별도 브랜치)
- Do not run git commands (Orchestrator 담당)
- Do not skip 심사 상태 확인

**References**:
- External research (agent): Firebase SDK 11.8.0 Swift 6 concurrency fix (Issue #14257)
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/project.yml` — 현재 Firebase 11.0.0

**Acceptance Criteria**:

*Functional:*
- [ ] `submission-status.md` 파일 존재
- [ ] 문서에 v2.6.2 상태 명시 (APPROVED/WAITING/REJECTED + 날짜)
- [ ] Firebase hotfix 타임라인 명시 (PR 생성 → main 머지 → v2.8 시작)

*Static:*
- [ ] `grep -q "v2.6.2" .dev/specs/pregnancy-mode-v2/context/submission-status.md` PASS
- [ ] `grep -q "Firebase 11.8" .dev/specs/pregnancy-mode-v2/context/submission-status.md` PASS

*Runtime:*
- [ ] (문서 TODO)

**Verify**:
```yaml
acceptance:
  - given: ["사용자가 App Store Connect 상태 공유"]
    when: "P0-2 실행"
    then: ["submission-status.md 생성", "Firebase hotfix 분리 계획 표시", "v2.8 시작 gate 명시"]
commands:
  - run: "test -f .dev/specs/pregnancy-mode-v2/context/submission-status.md"
    expect: "exit 0"
risk: MEDIUM
rollback: "문서만 작성이므로 해당 파일 삭제 시 원복. 단 심사 상태 잘못 기록 시 Phase 1이 잘못된 시점에 시작될 위험 — 사용자 재확인 필수."
```

---

### [ ] P0-2b: Firebase 11.8.0 hotfix 실행 (branch → PR → main merge → TestFlight v2.7.2)

**Type**: work

**Required Tools**: `git`, `xcodegen`, `xcodebuild`, `xcrun altool`

**Inputs**:
- `submission_status_path` (file): `${todo-P0-2.outputs.submission_status_path}` — v2.6.2 심사 APPROVED 확인 필수

**Outputs**:
- `firebase_hotfix_pr_url` (string): 실제 머지된 PR URL (예: `https://github.com/.../pull/NNN`)
- `testflight_v272_build` (string): TestFlight v2.7.2 빌드 번호

**Steps**:
- [ ] v2.6.2 심사 상태 APPROVED 재확인 (submission-status.md에서)
- [ ] main 기준 `feat/firebase-11.8.0-compat` 브랜치 생성 (`git worktree add ../firebase-compat -b feat/firebase-11.8.0-compat main`)
- [ ] `project.yml`에서 Firebase SDK 버전 11.0.0 → 11.8.0+ (권장 12.x) 업데이트
- [ ] `make verify` (build + lint + arch-test + 281+ 단위 테스트 PASS 확인)
- [ ] `make smoke-test` PASS
- [ ] `make ui-test` PASS (XCUITest 10)
- [ ] 위젯 타겟 빌드 확인 (`xcodebuild -scheme BabyCareWidgetExtension build`)
- [ ] Worker는 빌드/테스트 PASS까지 수행. PR 생성 + main merge + TestFlight 업로드는 Orchestrator 또는 사용자 수행 (Runtime Contract: Git Operations Orchestrator만)
- [ ] `firebase_hotfix_pr_url`에 실제 URL 기록 (Orchestrator가 채움)
- [ ] `testflight_v272_build`에 빌드 번호 기록

**Must NOT do**:
- Do not merge before v2.6.2 심사 APPROVED (심사 영향 방지)
- Do not add pregnancy 관련 코드 변경 (pregnancy와 분리 원칙)
- Do not skip 위젯 타겟 빌드 확인 (BabyCareWidgetExtension 회귀 위험)
- Do not modify Firebase target membership (기존 12 VM 영향 검증만)

**References**:
- P0-2 `submission-status.md` — 심사 gate
- external-researcher: Firebase SDK 11.8.0 Swift 6 호환성
- Codex Rec-4: "Firebase 업그레이드를 v2.7.2 hotfix로 분리"

**Acceptance Criteria**:

*Functional:*
- [ ] `feat/firebase-11.8.0-compat` 브랜치 main에 머지 완료
- [ ] TestFlight v2.7.2 업로드 (Delivery UUID 확보)
- [ ] `firebase_hotfix_pr_url` 기록됨

*Static:*
- [ ] `make verify` exit 0 (upgrade 후)
- [ ] `make arch-test` 0 violations

*Runtime:*
- [ ] `make test` PASS (281+ 기존 + 위젯)
- [ ] `make ui-test` PASS (10 기존 XCUITest)

**Verify**:
```yaml
acceptance:
  - given: ["v2.6.2 APPROVED", "submission-status.md 준비"]
    when: "P0-2b 실행"
    then: ["Firebase 11.8.0 main merge", "v2.7.2 TestFlight 업로드", "pregnancy-v2 전제 조건 확보"]
commands:
  - run: "grep -q '11\\.[8-9]\\|12\\.' project.yml || true"
    expect: "exit 0 (main merge 후 실행)"
risk: HIGH
rollback: "main에서 `git revert <merge-commit>` 후 TestFlight v2.7.1로 회귀 빌드 재업로드. Firebase 업그레이드가 타 기능에 회귀 유발 시 신속 revert 가능 (pregnancy와 분리되어 있음)."
```

---

### [x] P0-3: markTransitionPending 호출 경로 spec 작성

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `pending_spec_path` (file): `.dev/specs/pregnancy-mode-v2/context/pending-spec.md` — 3가지 시나리오 분석 + 채택 시나리오
- `pending_is_valid` (string): "valid" (Resume UI 유효) 또는 "remove" (Resume UI 제거, P2-2 skip)

**Steps**:
- [ ] `Grep "markTransitionPending" /Users/roque/BabyCare/.worktrees/pregnancy-mode/BabyCare/` 호출처 전수 확인
- [ ] v1 설계 의도 검증: `markTransitionPending` 정의(`FirestoreService+Pregnancy.swift`)가 존재하는 이유 추정
- [ ] 3가지 시나리오 분석:
  - (a) 호출 누락 버그 — v2에서 WriteBatch 시작 전 `markTransitionPending()` 호출 추가 → Resume UI 유효 (pending_is_valid="valid")
  - (b) 의도적 미구현 — WriteBatch atomic이 충분하므로 pending 마킹 불필요 → Resume UI 제거, "임신 cancel" UI로 대체 (pending_is_valid="remove")
  - (c) 문서는 있지만 현재 cold code — v2 재설계 시 옵션 (a) 채택 권장
- [ ] 채택 시나리오 명시 + 근거 + 테스트 시나리오 3개 기술:
  - Normal: WriteBatch 성공 → transitionState=completed
  - Pending: markTransitionPending 후 앱 크래시 → transitionState=pending (Resume UI 대상)
  - Orphan: 기존 v1 빌드 56-61 기간 pending 문서 존재 → Recovery UI 노출
- [ ] `pending_is_valid` 값 결정 ("valid" 권장, Resume UI P2-2 실행)

**Must NOT do**:
- Do not modify source code (spec 작성만)
- Do not pre-implement markTransitionPending 호출 (P2-1에서 구현)
- Do not delete markTransitionPending 정의 (v1 자산 보존)

**References**:
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/BabyCare/Services/FirestoreService+Pregnancy.swift:154-192` — WriteBatch + transitionState 구현
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/BabyCare/ViewModels/PregnancyViewModel.swift` — 현재 호출 없음
- gap-analyzer 분석: "markTransitionPending 명시적 호출이 현재 codebase 어디에도 없음"

**Acceptance Criteria**:

*Functional:*
- [ ] `pending-spec.md` 파일 존재
- [ ] 3 시나리오 (a/b/c) 분석 기재
- [ ] 채택 시나리오 + 근거 명시
- [ ] 테스트 시나리오 3개 (Normal/Pending/Orphan) 기술
- [ ] `pending_is_valid` 값 명시 ("valid" 또는 "remove")

*Static:*
- [ ] `grep -c 'Scenario' .dev/specs/pregnancy-mode-v2/context/pending-spec.md` → 3 이상
- [ ] `grep -q 'pending_is_valid' .dev/specs/pregnancy-mode-v2/context/pending-spec.md` PASS

*Runtime:*
- [ ] (문서 TODO)

**Verify**:
```yaml
acceptance:
  - given: ["v1 codebase의 markTransitionPending 정의 존재, 호출 부재"]
    when: "P0-3 실행"
    then: ["pending-spec.md 생성", "3 시나리오 분석", "채택 결정 명시", "P2-2 분기 판단 가능"]
commands:
  - run: "test -f .dev/specs/pregnancy-mode-v2/context/pending-spec.md"
    expect: "exit 0"
risk: HIGH
rollback: "spec 잘못 작성 시 P2-2가 불필요 코드 생성 또는 필요한 Resume UI 미구현. 재검토 + 재작성 가능 (소스 변경 없음)."
```

---

### [x] P0-4: H-items 평가자 + evidence 포맷 정의

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `h_items_evaluators_path` (file): `.dev/specs/pregnancy-mode-v2/context/h-items-evaluators.md` — H-1~H-10 각 평가자/기준/evidence 포맷 + 외부 dependency 일정

**Steps**:
- [ ] H-1~H-10 10개 각각 표 작성: (평가자, 기준, evidence 포맷, 기한)
- [ ] H-4 (의료 검증) 외부 dependency 명시: 전문의 명단 협의 필요, 예상 일정 2주
- [ ] H-10 (Privacy Policy 법적 검토) 외부 dependency 명시: 법무 연락, 예상 일정 1주
- [ ] "TestFlight 3일 무회귀" metric 구체화: Crashlytics crash-free rate >= 99%, 임신 관련 crash 0건, 임신 사용자 최소 N명 테스트 (N은 사용자 결정)
- [ ] plan-reviewer + codex SHIP input 범위 명시: PR 3분할(P1, P2, P3+P4)마다 또는 최종 merge 전 1회

**Must NOT do**:
- Do not commit 외부 평가자를 AI 에이전트에게 할당 (H-4/H-10은 human)
- Do not modify source code
- Do not skip H-10 법적 검토 (앱스토어 정책 위반 리스크)

**References**:
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/.dev/qa-evidence/v2.7.1.md` — v2.7.1 H-items 포맷 샘플

**Acceptance Criteria**:

*Functional:*
- [ ] `h-items-evaluators.md` 파일 존재
- [ ] 10개 H-item 각각 (평가자, 기준, evidence, 기한) 표 기재
- [ ] H-4/H-10 외부 dependency 일정 명시
- [ ] TestFlight 무회귀 metric 구체화

*Static:*
- [ ] `grep -c '^| H-' .dev/specs/pregnancy-mode-v2/context/h-items-evaluators.md` → 10 이상

*Runtime:*
- [ ] (문서 TODO)

**Verify**:
```yaml
acceptance:
  - given: ["verification-planner가 H-1~H-10 생성"]
    when: "P0-4 실행"
    then: ["평가자/기준/evidence 포맷 정의", "외부 의존 일정 확정"]
commands:
  - run: "test -f .dev/specs/pregnancy-mode-v2/context/h-items-evaluators.md"
    expect: "exit 0"
risk: LOW
```

---

### [x] P0-5: firestore.rules collectionGroup Partner read 규칙 배포

**Type**: work

**Required Tools**: `firebase` CLI

**Inputs**:
- `submission_status_path` (file): `${todo-P0-2.outputs.submission_status_path}` — v2.6.2 APPROVED 확인

**Outputs**:
- `rules_deployed_at` (string): deploy timestamp + project ID
- `collectionGroup_rule_active` (string): "allow read if request.auth.uid in resource.data.sharedWith" 규칙 활성 확인

**Steps**:
- [ ] `firestore.rules` read 후 최상단 `service cloud.firestore` 블록에 collectionGroup 규칙 추가:
  ```
  match /{path=**}/pregnancies/{pregnancyId} {
    allow read: if request.auth != null
      && resource != null
      && resource.data.sharedWith is list
      && request.auth.uid in resource.data.sharedWith;
  }
  ```
- [ ] 기존 `match /users/{userId}/pregnancies/{pregnancyId}` 블록 보존 (owner write 규칙)
- [ ] Firebase Console → Rules Simulator에서 시뮬레이션: owner uid/allow, partner uid(sharedWith 포함)/allow, 무관 uid/deny
- [ ] simulator 모두 expected 결과일 때만 `make deploy-rules` 실행
- [ ] 배포 완료 timestamp + project ID 기록

**Must NOT do**:
- Do not modify existing owner 전용 write 규칙 (owner만 write 유지)
- Do not blind deploy (Rules Simulator 없이 금지)
- Do not deploy client code first (`feedback_firestore_rules_first.md` 룰 — 규칙이 항상 먼저)
- Do not run git commands (Orchestrator)

**References**:
- 기존 PLAN 포팅 — TODO 0-4 Partner visibility (Codex Rec Option A 병합)
- `feedback_firestore_rules_first.md` — 규칙 선배포 룰
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/firestore.rules` 원본

**Acceptance Criteria**:

*Functional:*
- [ ] `firestore.rules`에 collectionGroup 규칙 존재
- [ ] Firebase Console rules simulator 3 시나리오 결과 기록

*Static:*
- [ ] `grep -q '{path=\*\*}/pregnancies' firestore.rules` exit 0
- [ ] `grep -q 'sharedWith is list' firestore.rules` exit 0

*Runtime:*
- [ ] `make deploy-rules` exit 0 (prod 배포 성공)

**Verify**:
```yaml
acceptance:
  - given: ["v2.6.2 APPROVED", "rules simulator PASS"]
    when: "P0-5 실행"
    then: ["collectionGroup 규칙 배포", "partner PERMISSION_DENIED 방어"]
commands:
  - run: "grep -q '{path=\\*\\*}/pregnancies' firestore.rules && grep -q 'sharedWith is list' firestore.rules"
    expect: "exit 0"
  - run: "make deploy-rules"
    expect: "exit 0"
risk: HIGH
rollback: "잘못된 배포 시 이전 rules 파일로 `firebase deploy --only firestore:rules` 재배포. 30초 이내 전 사용자 반영. write 권한 확대 방향 변경만 없으면 안전."
```

---

### [x] P1-1: AppContext static factory + 4-state 단위 테스트

**Type**: work

**Required Tools**: `xcodegen`, `xcodebuild`

**Inputs**:
- `submission_status_path` (file): `${todo-P0-2.outputs.submission_status_path}` — 심사 APPROVED 확인 후 착수

**Outputs**:
- `appcontext_path` (file): `BabyCare/Utils/AppContext.swift` — static factory, 4-state
- `appcontext_tests_count` (string): "12" (단위 테스트 개수)

**Steps**:
- [ ] `BabyCare/Utils/AppContext.swift` 생성:
  ```swift
  enum AppContext: Equatable {
      case empty, babyOnly, pregnancyOnly, both
      static func resolve(babies: [Baby], pregnancy: Pregnancy?) -> AppContext {
          switch (babies.isEmpty, pregnancy != nil) {
          case (true, false): return .empty
          case (false, false): return .babyOnly
          case (true, true): return .pregnancyOnly
          case (false, true): return .both
          }
      }
  }
  ```
- [ ] `project.yml` 갱신 (XcodeGen sources glob에 Utils/ 포함 확인)
- [ ] `make build` → Swift 컴파일 PASS
- [ ] `BabyCareTests/BabyCareTests.swift`에 신규 `AppContextTests` MARK 섹션 추가:
  - 4-state × 3 use-case = 12 단위 테스트:
    - `.empty` → 온보딩 렌더 expected
    - `.babyOnly` → baby 대시보드만 (pregnancy 카드 미노출)
    - `.pregnancyOnly` → pregnancy 대시보드 렌더 (baby 미존재)
    - `.both` → baby + 임신 카드 공존
    - 각 state별 3개 gating 로직 (Dashboard/Health/Recording)
- [ ] `make arch-test` → 0 violations 유지 (Utils 계층 경계 OK)
- [ ] `make test` → 281+ 단위 + AppContextTests 12 = 293+ PASS

**Must NOT do**:
- Do not define AppContext inside AppState class (독립 파일 필수)
- Do not inject AppState into AppContext (static factory, AppState 주입 금지)
- Do not use Observable/ObservableObject for AppContext (pure value type)
- Do not run git commands

**References**:
- Codex Rec-7: "AppContext enum vs static function" — static 권장
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/BabyCare/Services/BadgeFirestoreProviding.swift` — narrow pattern 참조 (AppContext는 protocol이 아닌 enum이지만 독립 파일 원칙 동일)
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/BabyCareTests/BabyCareTests.swift:2958-2977` — 기존 gating 테스트 (연동)

**Acceptance Criteria**:

*Functional:*
- [ ] `Utils/AppContext.swift` 파일 존재, `enum AppContext` 정의
- [ ] `AppContext.resolve(babies:pregnancy:) -> AppContext` static 메서드 존재
- [ ] 4-state (empty/babyOnly/pregnancyOnly/both) 모두 정의

*Static:*
- [ ] `make build` exit 0
- [ ] `make arch-test` 0 violations
- [ ] `make lint` 0 errors

*Runtime:*
- [ ] `make test` PASS — AppContextTests 12 신규 PASS

**Verify**:
```yaml
acceptance:
  - given: ["P0-2 완료 (심사 상태 확인)"]
    when: "P1-1 실행"
    then: ["AppContext.swift 생성", "12 단위 테스트 PASS", "arch-test 0"]
commands:
  - run: "test -f BabyCare/Utils/AppContext.swift"
    expect: "exit 0"
  - run: "make build"
    expect: "exit 0"
  - run: "make test 2>&1 | grep -c 'AppContextTests'"
    expect: "stdout > 0"
risk: HIGH
rollback: "git revert. Utils/AppContext.swift 삭제 시 P1-2~P1-5 의존 실패 — P1-1 먼저 안정화 후 다음 TODO 진행."
```

---

### [ ] P1-2: ContentView 온보딩 재설계 (NOT 로직 제거, 2버튼)

**Type**: work

**Required Tools**: `xcodegen`, `xcodebuild`

**Inputs**:
- `appcontext_path` (file): `${todo-P1-1.outputs.appcontext_path}`

**Outputs**:
- `contentview_path` (file): `BabyCare/App/ContentView.swift` — AppContext 기반 분기, 2버튼 온보딩, nested sheet 제거

**Steps**:
- [ ] `ContentView.swift:61` NOT 로직 `!(FeatureFlags.pregnancyModeEnabled && pregnancyVM.activePregnancy != nil)` 제거
- [ ] 온보딩 View에 "아기가 태어났어요" / "임신 중이에요" 2버튼 동등 레벨로 (AddBabyView 내부 nested sheet 제거)
- [ ] AppContext.resolve() 호출 기반 분기:
  - `.empty` → 2버튼 온보딩
  - `.babyOnly` / `.pregnancyOnly` / `.both` → mainTabView
- [ ] `ContentView.swift:79, 96` data load 분기도 AppContext + RemoteConfig 기반으로 전환 (gap-analyzer 지적)
- [ ] `make build` + `make test` + `make arch-test` + `make lint` PASS
- [ ] XCUITest 기존 3개 (`test_onboarding_emptyState_*`, `test_onboarding_addBaby_*`, `test_appLaunch_*`) 여전히 PASS 확인

**Must NOT do**:
- Do not keep NOT 로직 (빌드 58 회귀 원인)
- Do not keep nested sheet (AddBabyView → PregnancyRegistrationView 중첩 금지)
- Do not modify XCUITest 기존 9개 assertions (신규 테스트는 P3-1에서)
- Do not commit RemoteConfig 통합 (P2-4에서)
- Do not run git commands

**References**:
- gap-analyzer: "gating 6곳 리팩토링에서 data load 분기(ContentView L79, L96) 누락 위험"
- ux-reviewer: "온보딩 분기를 AddBabyView 내부가 아닌 ContentView onboardingView 레벨에서 처리"

**Acceptance Criteria**:

*Functional:*
- [ ] `grep -c '!(FeatureFlags.pregnancyModeEnabled' BabyCare/App/ContentView.swift` → 0
- [ ] 온보딩 View에 "아기가 태어났어요" + "임신 중이에요" 문자열 존재
- [ ] ContentView에서 AppContext.resolve 호출

*Static:*
- [ ] `make build` exit 0
- [ ] `make arch-test` 0 violations
- [ ] `make lint` 0 errors

*Runtime:*
- [ ] `make test` PASS
- [ ] `make ui-test` PASS (기존 10개 XCUITest 전부 통과)

**Verify**:
```yaml
acceptance:
  - given: ["P1-1 완료"]
    when: "P1-2 실행"
    then: ["ContentView NOT 로직 제거", "2버튼 온보딩 구현", "XCUITest 10개 PASS"]
commands:
  - run: "! grep -q '!(FeatureFlags.pregnancyModeEnabled && pregnancyVM' BabyCare/App/ContentView.swift"
    expect: "exit 0"
  - run: "grep -q 'AppContext.resolve' BabyCare/App/ContentView.swift"
    expect: "exit 0"
  - run: "make ui-test"
    expect: "exit 0"
risk: MEDIUM
```

---

### [ ] P1-3: Additive DashboardPregnancyHomeCard 신규

**Type**: work

**Required Tools**: `xcodegen`, `xcodebuild`

**Inputs**:
- `appcontext_path` (file): `${todo-P1-1.outputs.appcontext_path}`

**Outputs**:
- `dashboard_card_path` (file): `BabyCare/Views/Dashboard/DashboardPregnancyHomeCard.swift` — 신규
- `dashboard_view_path` (file): `BabyCare/Views/Dashboard/DashboardView.swift` — AppContext 기반 카드 삽입

**Steps**:
- [ ] `DashboardPregnancyHomeCard.swift` 생성 (D-day, weekAndDay, 주요 체크리스트 요약, 태동 기록 바로가기 버튼)
- [ ] `DashboardView.swift:33` 분기 로직을 `switch AppContext.resolve(...)` 기반으로 교체
  - `.pregnancyOnly` → 기존 DashboardPregnancyView 렌더
  - `.both` → baby 대시보드 스크롤 중간에 `DashboardPregnancyHomeCard` 삽입 (최상단 아님, ux-reviewer 권장)
  - `.babyOnly` → 기존 baby 대시보드 (카드 미노출)
  - `.empty` → ContentView가 처리 (이 분기 미도달)
- [ ] `make build` + `make test` + `make arch-test` + `make lint` PASS
- [ ] XCUITest `test_babyAndPregnancy_showsBabyDashboard` 여전히 PASS

**Must NOT do**:
- Do not place card at top (사용자 시나리오 노이즈 — ux-reviewer 권장 따라 스크롤 중간)
- Do not embed PregnancyViewModel directly inside Card (environment 주입)
- Do not put card in BabyCareWidget target (메인 앱 타겟만)
- Do not run git commands

**References**:
- ux-reviewer: "임신 데이터를 꼭 최상단에 올릴 필요는 없습니다. 스크롤 내 중간 위치에 자연스럽게 배치"
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/BabyCare/Utils/PregnancyDateMath.swift` — D-day 계산 재사용
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/BabyCare/Views/Dashboard/DashboardPregnancyView.swift` — 기존 뷰 참조

**Acceptance Criteria**:

*Functional:*
- [ ] `DashboardPregnancyHomeCard.swift` 파일 존재
- [ ] DashboardView에서 AppContext.both 분기 시 카드 노출
- [ ] AppContext.babyOnly 시 카드 미노출

*Static:*
- [ ] `make build` exit 0
- [ ] `make arch-test` 0 violations

*Runtime:*
- [ ] `make test` PASS
- [ ] `make ui-test` PASS (`test_babyAndPregnancy_showsBabyDashboard` 유지)

**Verify**:
```yaml
acceptance:
  - given: ["P1-1 완료"]
    when: "P1-3 실행"
    then: ["Card 파일 생성", "AppContext 분기 정상", "ui-test PASS"]
commands:
  - run: "test -f BabyCare/Views/Dashboard/DashboardPregnancyHomeCard.swift"
    expect: "exit 0"
  - run: "make ui-test"
    expect: "exit 0"
risk: MEDIUM
```

---

### [ ] P1-4: HealthView / RecordingView AppContext 정합 + .both 임신 진입점

**Type**: work

**Required Tools**: `xcodegen`, `xcodebuild`

**Inputs**:
- `appcontext_path` (file): `${todo-P1-1.outputs.appcontext_path}`

**Outputs**:
- `health_view_path` (file): `BabyCare/Views/Health/HealthView.swift` — AppContext 기반, `.both` 시 임신 섹션 추가
- `recording_view_path` (file): `BabyCare/Views/Recording/RecordingView.swift` — AppContext 기반, `.both` 시 임신 탭 추가

**Steps**:
- [ ] `HealthView.swift:16` 분기 교체: AppContext.resolve() 기반
  - `.pregnancyOnly` → 기존 HealthPregnancyView
  - `.both` → baby Health 섹션 + 임신 건강 섹션 (태동/방문/체중) 함께 노출
  - `.babyOnly` → 기존 baby Health (임신 섹션 완전 숨김 — ux-reviewer 권장)
- [ ] `RecordingView.swift:70` 동일 패턴. `.both` 시 임신 탭 추가 (baby 4탭 + 임신 1탭 = 5탭)
- [ ] `AppContext.both` 시 Health 탭에서 pregnancy sub-collection 접근 경로 검증 (kick sessions, prenatal visits, weights, symptoms)
- [ ] `make build` + `make test` + `make arch-test` + `make lint` PASS

**Must NOT do**:
- Do not expose 임신 섹션 in `.babyOnly` (baby-only 사용자 UX 회귀 0)
- Do not add Tab 5 for baby-only mode (ux-reviewer 권장)
- Do not modify pregnancy Firestore path (users/{uid}/pregnancies/{pid}/...)
- Do not run git commands

**References**:
- gap-analyzer Blind Spot #7: "AppContext.both에서 탭바 임신 진입점 미정의 — UI/Data 모순"
- ux-reviewer: "HealthView/RecordingView additive 섹션은 AppContext `.babyOnly` 에서 완전히 숨겨서 기존 baby 사용자 경험을 보호"

**Acceptance Criteria**:

*Functional:*
- [ ] HealthView에서 AppContext.both 시 임신 섹션 렌더
- [ ] HealthView에서 AppContext.babyOnly 시 임신 섹션 미렌더
- [ ] RecordingView 탭 개수: babyOnly=4, both=5, pregnancyOnly=임신 전용

*Static:*
- [ ] `make build` exit 0
- [ ] `make arch-test` 0 violations

*Runtime:*
- [ ] `make test` PASS
- [ ] `make ui-test` PASS (`test_babyAndPregnancy_showsBabyDashboard` 유지)

**Verify**:
```yaml
acceptance:
  - given: ["P1-1, P1-3 완료"]
    when: "P1-4 실행"
    then: ["HealthView/RecordingView AppContext 분기", ".babyOnly 임신 섹션 미노출"]
commands:
  - run: "grep -c 'AppContext.resolve' BabyCare/Views/Health/HealthView.swift"
    expect: "stdout >= 1"
risk: MEDIUM
```

---

### [ ] P1-5: DashboardPregnancyView 최소 수정 (D-7 제거 + Milestone nil-check)

**Type**: work

**Required Tools**: `xcodegen`, `xcodebuild`

**Inputs**:
- `appcontext_path` (file): `${todo-P1-1.outputs.appcontext_path}`

**Outputs**:
- `dashboard_pregnancy_path` (file): `BabyCare/Views/Dashboard/DashboardPregnancyView.swift` — 최소 2 변경

**Steps**:
- [ ] 363-line 기존 View 유지. 2가지 변경만:
  - (1) D-7 CTA 제한 조건 제거 → "출산했어요!" CTA 항상 노출 (ux-reviewer 권장)
  - (2) Milestone 동적 로드 nil-check 추가 (pregnancy-weeks.json에서 주차 없을 때 graceful fallback)
- [ ] `make build` + `make test` + `make arch-test` + `make lint` PASS
- [ ] PregnancyDateMath 11 단위 테스트 모두 PASS 유지

**Must NOT do**:
- Do not 전면 재작성 (Codex Rec-5: 최소 수정 권장, v1 363-line Milestone 로직 재구현 금지)
- Do not change pregnancy-weeks.json schema (Q8: 스키마 그대로)
- Do not remove 기존 섹션 (D-day/체크리스트/방문/체중)
- Do not run git commands

**References**:
- Codex Rec-5: "DashboardPregnancyView 전면 재작성 대신 D-7 조건 제거 + Milestone nil-check 2개 변경으로 교체"
- ux-reviewer: "현재 D-7 이내에만 '출산했어요!' 배너가 나옵니다. D+1~D+30은 전환 버튼을 찾을 수 없음"
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/BabyCare/Views/Dashboard/DashboardPregnancyView.swift:57` — D-7 조건 라인

**Acceptance Criteria**:

*Functional:*
- [ ] D-7 조건 제거됨 → `grep -c 'days <= 7' BabyCare/Views/Dashboard/DashboardPregnancyView.swift` → 0 또는 해당 조건 제거 확인
- [ ] Milestone nil-check 추가됨

*Static:*
- [ ] `make build` exit 0

*Runtime:*
- [ ] `make test` PASS (PregnancyDateMath 11 + json 로드 2 = 13 PASS)

**Verify**:
```yaml
acceptance:
  - given: ["P1-1 완료"]
    when: "P1-5 실행"
    then: ["D-7 제거", "Milestone nil-check", "전면 재작성 아님"]
commands:
  - run: "[ $(wc -l < BabyCare/Views/Dashboard/DashboardPregnancyView.swift) -ge 300 ] && [ $(wc -l < BabyCare/Views/Dashboard/DashboardPregnancyView.swift) -le 400 ]"
    expect: "exit 0"
  - run: "! grep -q 'days <= 7' BabyCare/Views/Dashboard/DashboardPregnancyView.swift"
    expect: "exit 0"
risk: MEDIUM
```

---

### [ ] P2-1: PregnancyTransitionSheet 재작성 (출산/종료 CTA 분리)

**Type**: work

**Required Tools**: `xcodegen`, `xcodebuild`

**Inputs**:
- `appcontext_path` (file): `${todo-P1-1.outputs.appcontext_path}`

**Outputs**:
- `transition_sheet_path` (file): `BabyCare/Views/Pregnancy/PregnancyTransitionSheet.swift` — 출산 CTA만 노출

**Steps**:
- [ ] `PregnancyTransitionSheet.swift` 재작성: "출산했어요!" CTA만 (감정적 맥락 긍정)
- [ ] "임신이 종료되었어요" (miscarriage/stillbirth/terminated) CTA를 `SettingsView.swift` → 임신 관리 → 심층부로 이동 (ux-reviewer 권장)
- [ ] **P0-3 채택 시나리오 (a)일 경우 — pre/post write guard 패턴 적용** (기존 PLAN T1-5 포팅):
  - (1) `markTransitionPending(pregnancyId:transitionId:)` 호출 — `transitionPending: true` + `transitionId: UUID` + `transitionStartedAt: Timestamp` 필드 write (WriteBatch 시작 전, 별도 단일 write)
  - (2) WriteBatch commit: outcome=born + archivedAt + transitionState=completed + Baby 생성 원자적 write
  - (3) `clearTransitionPending(pregnancyId:)` 호출 — `transitionPending: false` 필드 write (batch 성공 후)
  - 앱 크래시 시 (1)만 완료된 경우 → P2-2 Recovery Modal이 감지
- [ ] Alert 메시지 보존: "되돌리려면 설정 > 이전 임신에서 복구해야 합니다" (ux-reviewer Must-do)
- [ ] WriteBatch 중복 방지 guard 추가 (동일 transitionId 재호출 no-op)
- [ ] PregnancyOutcomeContractTests 4개 + 단위 테스트 3개 추가:
  - `test_transitionToOutcome_marksPendingBeforeBatch`
  - `test_transitionToOutcome_clearsPendingAfterSuccess`
  - `test_transitionToOutcome_duplicateCall_secondCallIsNoop`
- [ ] `make build` + `make test` + `make arch-test` + `make lint` PASS

**Must NOT do**:
- Do not leave "임신 종료" CTA in transition sheet (감정 민감, ux-reviewer Must-do)
- Do not remove "되돌리려면 설정 > 이전 임신" Alert 메시지 (사용자 혼란 방지)
- Do not change WriteBatch 구조 (원자성 유지)
- Do not run git commands

**References**:
- ux-reviewer: "임신이 종료되었어요" CTA는 Settings 심층부로 분리. Alert 메시지 보존 Must-do
- Codex DP-1: markTransitionPending 호출 경로는 P0-3 결정 따름
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/BabyCare/Services/FirestoreService+Pregnancy.swift:markTransitionPending`

**Acceptance Criteria**:

*Functional:*
- [ ] PregnancyTransitionSheet에서 "임신이 종료되었어요" 버튼 미존재
- [ ] SettingsView 임신 관리 섹션에 "임신 종료" 심층 경로 존재
- [ ] Alert 메시지 "되돌리려면 설정 > 이전 임신" 포함

*Static:*
- [ ] `make build` exit 0
- [ ] `make arch-test` 0 violations

*Runtime:*
- [ ] `make test` PASS (PregnancyOutcomeContractTests 4 PASS)

**Verify**:
```yaml
acceptance:
  - given: ["P0-3 pending_is_valid 결정", "P1-1 완료"]
    when: "P2-1 실행"
    then: ["출산 CTA만 노출", "종료 CTA Settings 심층부 이동", "markTransitionPending 통합"]
commands:
  - run: "! grep -q '임신이 종료' BabyCare/Views/Pregnancy/PregnancyTransitionSheet.swift"
    expect: "exit 0"
  - run: "grep -q '임신 종료\\|이전 임신' BabyCare/Views/Settings/SettingsView.swift"
    expect: "exit 0"
  - run: "grep -q '되돌리려면 설정' BabyCare/Views/Pregnancy/PregnancyTransitionSheet.swift"
    expect: "exit 0"
risk: HIGH
rollback: "git revert PR 단위. WriteBatch 구조 건드리지 않으면 데이터 손상 없음."
```

---

### [ ] P2-2: PregnancyRecoveryModal (pending orphan Resume UI) — 조건부

**Type**: work

**Required Tools**: `xcodegen`, `xcodebuild`

**Inputs**:
- `pending_spec_path` (file): `${todo-P0-3.outputs.pending_spec_path}`
- `pending_is_valid` (string): `${todo-P0-3.outputs.pending_is_valid}` — "valid" 또는 "remove"
- `appcontext_path` (file): `${todo-P1-1.outputs.appcontext_path}`

**Outputs**:
- `recovery_modal_path` (file): `BabyCare/Views/Pregnancy/PregnancyRecoveryModal.swift` — 또는 "skipped" (pending_is_valid=="remove" 시)

**Steps**:
- [ ] 조건 분기:
  - `pending_is_valid == "remove"` → 이 TODO 완전 skip, outputs에 "skipped" 기록
  - `pending_is_valid == "valid"` → 아래 구현
- [ ] `PregnancyRecoveryModal.swift` 생성: "전환이 멈춰있어요. 이어서 완료 / 취소" 2버튼
- [ ] `PregnancyViewModel.swift`에 `pendingRecoveryState` @Observable 속성 추가
- [ ] **stale pending threshold 30초 적용** (기존 PLAN T1-5 포팅):
  ```swift
  if let pregnancy = activePregnancy, pregnancy.transitionPending == true {
      if Date().timeIntervalSince(pregnancy.transitionStartedAt ?? Date()) > 30 {
          // Show recovery modal: retry (=이어서 완료) or rollback (=취소)
      }
  }
  ```
  30초 이하면 정상 전환 중 → 모달 숨김. 초과 시 사용자 개입 요청
- [ ] `ContentView.task {}`에서 `loadActivePregnancy` 완료 후 pending 감지
- [ ] DP-4 A 적용: pending 문서 개수에 따라
  - 1개: 모달 표시
  - 2개 이상: Settings > 이전 임신 이력 인라인 배너 (모달 미표시, bug-triage Layer 0 조사 대상)
- [ ] **"취소" (Rollback) 경로**: `ref.updateData(["transitionPending": false, "transitionStartedAt": FieldValue.delete()])` → `transitionState: .ongoing` 복원. 자동 삭제 금지 (deleteActivePregnancy 사용 금지)
- [ ] **"이어서 완료" (Retry) 경로**: 기존 `PregnancyTransitionSheet` 재사용 + `recoverTransition(pregnancyId:transitionId:)` 호출 — **자동 retry 금지** (반드시 사용자 명시적 탭)
- [ ] `babyVM.hasInitialLoad && pending` 조합으로 로딩 경쟁 방지
- [ ] `willEnterForegroundNotification` 훅 등록 → 백그라운드에서 돌아올 때도 pending 재체크
- [ ] `make build` + `make test` + `make arch-test` + `make lint` PASS
- [ ] 단위 테스트 3개 추가:
  - `test_recovery_fromPendingState_onLoad_showsAlert`
  - `test_recovery_retry_completesTransition`
  - `test_recovery_rollback_restoresOngoingState`

**Must NOT do**:
- Do not auto-delete pregnancy document (사용자 피드백 Must NOT)
- Do not use `deleteActivePregnancy()` for "취소" (문서 보존 필수, gap-analyzer)
- Do not show modal during `babyVM.hasInitialLoad == false` (race condition)
- Do not implement 2개+ pending 처리 as separate UI (DP-4 A: 인라인 배너)
- Do not run git commands

**References**:
- DP-4 A: pending >= 2 시 Settings 배너만
- gap-analyzer: "showPendingRecoveryModal을 babyVM.hasInitialLoad && activePregnancy?.transitionState == pending 조합"
- ux-reviewer: "취소 시 transitionState 필드만 clear, 문서 보존"
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/BabyCare/ViewModels/PregnancyViewModel.swift:151` — deleteActivePregnancy (Resume 취소에 사용 금지)

**Acceptance Criteria**:

*Functional:* (pending_is_valid == "valid" 시)
- [ ] `PregnancyRecoveryModal.swift` 존재
- [ ] ViewModel에 `pendingRecoveryState` 속성
- [ ] 단위 테스트 3개 PASS

*Functional:* (pending_is_valid == "remove" 시)
- [ ] 파일 생성 없음, P2-2 skipped 기록

*Static:*
- [ ] `make build` exit 0

*Runtime:*
- [ ] `make test` PASS (+3 단위)

**Verify**:
```yaml
acceptance:
  - given: ["P0-3 pending_is_valid 결정"]
    when: "P2-2 실행"
    then: ["조건 분기 준수", "valid 시 모달 + 테스트 생성 / remove 시 skip"]
commands:
  - run: |
      if grep -q 'pending_is_valid.*valid' .dev/specs/pregnancy-mode-v2/context/pending-spec.md; then
        test -f BabyCare/Views/Pregnancy/PregnancyRecoveryModal.swift
      else
        ! test -f BabyCare/Views/Pregnancy/PregnancyRecoveryModal.swift
      fi
    expect: "exit 0"
risk: HIGH
rollback: "PregnancyRecoveryModal 삭제 시 ViewModel 속성도 제거. FieldValue.delete로만 transitionState 정리 (문서 보존)."
```

---

### [x] P2-3: PregnancyFirestoreProviding narrow protocol + MockPregnancyFirestore

**Type**: work

**Required Tools**: `xcodegen`, `xcodebuild`

**Inputs**: (none — 병렬 가능)

**Outputs**:
- `pregnancy_firestore_providing_path` (file): `BabyCare/Services/PregnancyFirestoreProviding.swift` — narrow protocol
- `mock_pregnancy_firestore_path` (file): `BabyCareTests/MockPregnancyFirestore.swift`

**Steps**:
- [ ] `BadgeFirestoreProviding.swift` 패턴 복사 → `PregnancyFirestoreProviding.swift` 생성 (12-17 메서드 narrow)
  - `savePregnancy`, `fetchActivePregnancy(currentUserId:)`, `fetchArchivedPregnancies`, `deletePregnancy`, `transitionPregnancyToBaby`, `markTransitionPending(pregnancyId:transitionId:)`, `clearTransitionPending(pregnancyId:)`, `saveKickSession`, `fetchKickSessions`, `savePrenatalVisit`, `fetchSharedPregnancy(currentUserId:)` 등
- [ ] **`fetchSharedPregnancy(currentUserId:) async throws -> Pregnancy?`** 신규 구현 (기존 PLAN T2-5 포팅): `Firestore.firestore().collectionGroup("pregnancies").whereField("sharedWith", arrayContains: currentUserId).limit(to: 1)` — 파트너 공유 pregnancy 감지
- [ ] `extension FirestoreService: PregnancyFirestoreProviding {}` 1줄
- [ ] `PregnancyViewModel` 타입 선언만 변경 (`private let service: PregnancyFirestoreProviding = FirestoreService.shared`)
- [ ] 다른 23개 VM 영향 없음 — narrow
- [ ] `MockPregnancyFirestore.swift` 생성 (Mock으로 반환값 주입 가능, sharedWith partner 시나리오 지원)
- [ ] PregnancyViewModel 통합 테스트 7개 추가:
  - `test_loadActivePregnancy_mockResponse_setsState` (loadActivePregnancy mock)
  - `test_fetchActivePregnancy_transitionPending_exposesRecoveryState` (Recovery)
  - `test_writeBatch_failure_errorHandled`
  - `test_loadActivePregnancy_noOwn_fallbackToSharedPregnancy_resolvesCorrectly` (파트너 공유 fallback)
  - `test_fetchSharedPregnancy_partnerInSharedWith_returnsPregnancy`
  - `test_fetchSharedPregnancy_noMatch_returnsNil`
  - `test_outcomeNil_document_handledGracefully`
- [ ] `make build` + `make test` + `make arch-test` + `make lint` PASS

**Must NOT do**:
- Do not 전체 FirestoreServiceProtocol (DP-2: narrow)
- Do not modify 23 other VMs (PregnancyViewModel만)
- Do not delete FirestoreService singleton (기존 호출처 유지)
- Do not run git commands

**References**:
- DP-2 A: narrow protocol
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/BabyCare/Services/BadgeFirestoreProviding.swift` — pattern 참조
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/BabyCareTests/MockBadgeFirestore.swift` — Mock 패턴 참조

**Acceptance Criteria**:

*Functional:*
- [ ] `PregnancyFirestoreProviding.swift` 존재, 10-15 메서드 declared
- [ ] `MockPregnancyFirestore.swift` 존재
- [ ] PregnancyViewModel 통합 테스트 5 신규

*Static:*
- [ ] `make build` exit 0
- [ ] `make arch-test` 0 violations

*Runtime:*
- [ ] `make test` PASS (+5 통합)

**Verify**:
```yaml
acceptance:
  - given: []
    when: "P2-3 실행"
    then: ["narrow protocol + mock 생성", "PregnancyViewModel 통합 테스트 5"]
commands:
  - run: "test -f BabyCare/Services/PregnancyFirestoreProviding.swift && test -f BabyCareTests/MockPregnancyFirestore.swift"
    expect: "exit 0"
risk: MEDIUM
```

---

### [ ] P2-4: FeatureFlagService Hybrid (compile-time + RemoteConfig pct + stable hash)

**Type**: work

**Required Tools**: `xcodegen`, `xcodebuild`, Firebase SDK 11.8.0+ (P0-2b hotfix 머지 완료 필수)

**Inputs**:
- `firebase_hotfix_pr_url` (string): `${todo-P0-2b.outputs.firebase_hotfix_pr_url}` — "pending"이면 HALT

**Outputs**:
- `featureflag_service_path` (file): `BabyCare/Services/FeatureFlagService.swift` — Hybrid gateway
- `stable_hash_path` (file): `BabyCare/Utils/StableHash.swift` — DJB2 deterministic bucketing

**Steps**:
- [ ] P0-2b hotfix PR main merge 확인 (Firebase 11.8.0+)
- [ ] `project.yml` BabyCare 타겟에 `FirebaseRemoteConfig` SPM product dependency 추가 (기존 Firebase 패키지 내 타겟 체크박스)
- [ ] `xcodegen generate`
- [ ] **`StableHash.swift` 생성** (기존 PLAN T1-4 포팅):
  ```swift
  enum StableHash {
      static func djb2(_ s: String) -> UInt64 {
          var hash: UInt64 = 5381
          for c in s.utf8 { hash = ((hash &<< 5) &+ hash) &+ UInt64(c) }
          return hash
      }
      static func bucket(_ uid: String, outOf: UInt64 = 100) -> UInt64 {
          djb2(uid) % outOf
      }
  }
  ```
- [ ] **`FeatureFlagService.swift` 생성** (Hybrid 3-layer):
  ```swift
  @MainActor @Observable
  final class FeatureFlagService {
      static let shared = FeatureFlagService()
      private(set) var pregnancyModeEnabled: Bool = false
      private let compileTime = FeatureFlags.pregnancyModeEnabled

      func bootstrap(userId: String) async {
          guard compileTime else { pregnancyModeEnabled = false; return }  // Layer 1: compile-time kill
          RemoteConfig.remoteConfig().setDefaults([
              "pregnancyModeEnabled": false as NSObject,
              "pregnancyRolloutPct": 0 as NSObject
          ])
          _ = try? await RemoteConfig.remoteConfig().fetchAndActivate()
          let pct = RemoteConfig.remoteConfig().configValue(forKey: "pregnancyRolloutPct").numberValue.intValue
          let enabled = RemoteConfig.remoteConfig().configValue(forKey: "pregnancyModeEnabled").boolValue
          let bucket = Int(StableHash.bucket(userId))
          pregnancyModeEnabled = compileTime && enabled && bucket < pct  // Layer 2: remote + cohort
          UserDefaults.standard.set(pregnancyModeEnabled, forKey: "lastKnownGood_pregnancyModeEnabled")
      }

      func coldStartDefault(userId: String) -> Bool {
          guard compileTime else { return false }
          return UserDefaults.standard.object(forKey: "lastKnownGood_pregnancyModeEnabled") as? Bool ?? false  // Layer 3: offline
      }
  }
  ```
- [ ] **App Store 2.5.2 safe submit 전략**: 심사 제출 시 `FeatureFlags.pregnancyModeEnabled = true` (compile-time) + Firebase Console `pregnancyRolloutPct = 0`. 심사관에게 기능은 보이되 0% 사용자 노출 → 2.5.2 "hidden feature" 위반 회피. **단, Firebase Console `pregnancyRolloutPct = 0` 선설정 확인 후에만 커밋** (안전 순서 가드)
- [ ] `FeatureFlags.swift`의 `pregnancyModeEnabled: Bool = false` → `= true` 변경 (compile-time kill switch는 `FeatureFlagService.compileTime`이 유지)
- [ ] `BabyCareApp.swift init()` 직후 `.task { await FeatureFlagService.shared.bootstrap(userId: authVM.currentUserId) }` 호출
- [ ] gating 6곳이 `FeatureFlagService.shared.pregnancyModeEnabled` 참조하도록 전환
- [ ] `PregnancyWidgetSyncService.swift`에 `clear()` 메서드 추가 + flag OFF 변화 감지 시 호출 (gap-analyzer blind spot #3: 위젯 타겟은 RemoteConfig 직접 불가)
- [ ] `scripts/feature_flag_smoke.sh` sed 패턴 업데이트 (`FeatureFlagService.shared.pregnancyModeEnabled` 기반 검증)
- [ ] 단위 테스트 5개 추가:
  - `test_stableHash_sameInputAlwaysSameBucket` — DJB2 deterministic
  - `test_featureFlag_compileTimeFalse_remoteIgnored` — Layer 1 kill
  - `test_featureFlag_compileTimeTrue_pct0_disabled` — Layer 2 cohort 0%
  - `test_featureFlag_compileTimeTrue_pct100_enabled` — Layer 2 cohort 100%
  - `test_featureFlag_coldStart_usesLastKnownGood` — Layer 3 offline fallback
- [ ] `.dev/qa-evidence/v2.8-remoteconfig.md` 생성 — cohort rollout 단계별 모니터링 포맷 (0→10→50→100%)
- [ ] `make build` + `make test` + `make arch-test` + `make lint` PASS

**Must NOT do**:
- Do not import `FirebaseRemoteConfig` in `FeatureFlags.swift` — `FeatureFlagService`가 단일 gateway
- Do not use `Swift.hashValue` (Swift 4.2 randomized) — `StableHash.djb2`만 사용
- Do not use `Int.random` for bucketing (non-deterministic)
- Do not call `RemoteConfig.fetch()` main thread blocking (async 강제)
- Do not set `minimumFetchInterval < 43200s` in RELEASE builds (ThrottledException)
- Do not set fetch 실패 fallback to `true` (Layer 3: lastKnownGood 또는 compile-time fallback)
- Do not commit `FeatureFlags.swift = true` before Firebase Console `pregnancyRolloutPct = 0` 확정 (2.5.2 submit 안전 순서)
- Do not run git commands

**References**:
- 기존 PLAN T1-4 포팅 (Codex Option A 병합)
- external-researcher: Firebase RemoteConfig iOS 권장 패턴, Swift 6 호환
- App Store Review Guideline 2.5.2 (Hidden Features)

**Acceptance Criteria**:

*Functional:*
- [ ] `FeatureFlagService.swift` 존재, Hybrid 3-layer 구현
- [ ] `StableHash.swift` 존재, DJB2 알고리즘
- [ ] BabyCareApp init에서 bootstrap 호출
- [ ] Firebase Console `pregnancyRolloutPct = 0` 설정 기록 (submission-status.md 업데이트)

*Static:*
- [ ] `make build` exit 0
- [ ] `make arch-test` 0 violations
- [ ] `! grep -q 'import FirebaseRemoteConfig' BabyCare/Utils/FeatureFlags.swift` (단일 gateway 강제)

*Runtime:*
- [ ] `make test` PASS (+5 단위)
- [ ] `bash scripts/feature_flag_smoke.sh` PASS

**Verify**:
```yaml
acceptance:
  - given: ["P0-2b Firebase hotfix 머지", "Firebase Console pregnancyRolloutPct=0 선설정"]
    when: "P2-4 실행"
    then: ["FeatureFlagService + StableHash 생성", "3-layer Hybrid", "2.5.2 safe submit 경로"]
commands:
  - run: "test -f BabyCare/Services/FeatureFlagService.swift && test -f BabyCare/Utils/StableHash.swift"
    expect: "exit 0"
  - run: "! grep -q 'import FirebaseRemoteConfig' BabyCare/Utils/FeatureFlags.swift"
    expect: "exit 0"
  - run: "grep -q 'djb2' BabyCare/Utils/StableHash.swift"
    expect: "exit 0"
  - run: "bash scripts/feature_flag_smoke.sh"
    expect: "exit 0"
risk: HIGH
rollback: "compile-time=true 전환은 `pregnancyRolloutPct=0`이면 사용자 노출 0% 보장. 문제 시 Firebase Console에서 pct=0 유지. FeatureFlagService 자체 revert 시 compile-time fallback."
```

---

### [ ] P3-1: XCUITest 신규 8개 확장

**Type**: work

**Required Tools**: `xcodegen`, `xcodebuild`

**Inputs**:
- `appcontext_path`, `contentview_path`, `dashboard_card_path`, `dashboard_view_path`, `health_view_path`, `recording_view_path`, `dashboard_pregnancy_path`, `transition_sheet_path`, `recovery_modal_path`, `pregnancy_firestore_providing_path`, `remote_config_service_path` — P1/P2 전 산출물

**Outputs**:
- `xcuitest_count` (string): "18" (10 기존 + 8 신규)

**Steps**:
> 이 TODO의 net-new 작업은 XCUITest 8개 추가만. 단위 테스트는 이미 P1-1(AppContext 12) / P2-3(PregnancyViewModel 통합 5) / P2-4(RemoteConfigService 3) 에서 누적 완료. 본 TODO는 별도 단위 테스트 추가 없음.

- [ ] 8개 XCUITest 추가 (Codex Rec-8 권장):
  1. `test_onboarding_twoButtons_showBoth` — 온보딩에서 "아기 태어났어요" + "임신 중이에요" 2버튼
  2. `test_context_empty_showsOnboarding` — AppContext.empty 라우팅
  3. `test_context_pregnancyOnly_showsPregnancyDashboard` — pregnancyOnly 라우팅
  4. `test_context_both_showsHomeCard_NOT_pregnancyDashboard` — both 시 baby 대시보드 + 카드
  5. `test_transition_sheet_noTerminationCTA` — 출산 sheet에 종료 CTA 미존재
  6. `test_recovery_modal_pendingOne_shows` (pending_is_valid=valid 시만) — pending 1개 감지 Resume 모달
  7. `test_recovery_modal_pendingMultiple_banner` (pending_is_valid=valid 시만) — pending 2+ 시 Settings 배너
  8. `test_a11y_XXXL_twoButtons_tappable` — a11y XXXL 온보딩 버튼 hittable
- [ ] `make ui-test` PASS (18 = 10 기존 + 8 신규)
- [ ] 후속 accounting 확인: 누적 단위 테스트 합계 >= 301 (281 기존 + AppContext 12 + PregnancyViewModel 통합 5 + RemoteConfigService 3 + PregnancyRecoveryModal 3 if valid) — Definition of Done에서 reconciliation

**Must NOT do**:
- Do not target 15+ 숫자 채우기 (Codex Rec-8: 8개 핵심)
- Do not duplicate launch arguments (UI_TESTING_WITH_PREGNANCY 기존과 충돌 회피)
- Do not break 기존 XCUITest 10개
- Do not run git commands

**References**:
- Codex Rec-8: "XCUITest 15+ 목표 제거, 핵심 8 + 단위 테스트"
- verification-planner: A-11 XCUITest 확장 명세

**Acceptance Criteria**:

*Functional:*
- [ ] PregnancyFlowTests 파일에 신규 8 테스트 함수 존재

*Static:*
- [ ] `make build` exit 0

*Runtime:*
- [ ] `make ui-test` → 18 테스트 PASS
- [ ] `make test` → 단위 테스트 총 301+ PASS

**Verify**:
```yaml
acceptance:
  - given: ["P1-1~P2-4 완료"]
    when: "P3-1 실행"
    then: ["XCUITest 8 신규", "단위 12 신규", "모두 PASS"]
commands:
  - run: "grep -c 'func test_' BabyCareUITests/PregnancyFlowTests.swift"
    expect: "stdout >= 18"
  - run: "make ui-test"
    expect: "exit 0"
risk: LOW
```

---

### [ ] P3-2: pregnancy-weeks.json 의료 검증 (H-4)

**Type**: work

**Required Tools**: (none — 외부 의존)

**Inputs**:
- `h_items_evaluators_path` (file): `${todo-P0-4.outputs.h_items_evaluators_path}` — 전문의 명단/일정 참조

**Outputs**:
- `pregnancy_weeks_verified_path` (file): `BabyCare/Resources/pregnancy-weeks.json` — 전문의 검증 반영
- `h4_evidence` (file): `.dev/qa-evidence/v2.8.0.md` H-4 섹션 — 전문의 서명 또는 출처 URL

**Steps**:
- [ ] P0-4에서 합의된 전문의에게 `pregnancy-weeks.json` 37주 리뷰 요청
- [ ] 피드백 수신 후 JSON 수정 (fruitSize, milestone, tip 텍스트 정확성)
- [ ] 변경 diff 최소화 (schema 변경 금지, Q8)
- [ ] `scripts/pregnancy_weeks_sanity.py .` PASS 재확인 (4-40주 연속, 금지어 0건)
- [ ] QA evidence 파일 H-4 섹션에 전문의 서명 또는 출처 URL (ACOG/대한산부인과학회 인용) 첨부
- [ ] `make test` PASS (pregnancy-weeks JSON load 테스트)

**Must NOT do**:
- Do not change JSON schema (Q8: 필드 추가 금지)
- Do not remove disclaimer key (의료 면책 필수)
- Do not commit before 전문의 서명 또는 출처 URL 확보
- Do not run git commands

**References**:
- Q7: 의료 검증 출시 전 필수
- `/Users/roque/BabyCare/.worktrees/pregnancy-mode/scripts/pregnancy_weeks_sanity.py`
- P0-4 h_items_evaluators_path — 전문의 지정

**Acceptance Criteria**:

*Functional:*
- [ ] pregnancy-weeks.json sanity PASS (37주 연속, 금지어 0건)
- [ ] `.dev/qa-evidence/v2.8.0.md` H-4 섹션에 "[V]" + evidence

*Static:*
- [ ] `python3 scripts/pregnancy_weeks_sanity.py .` exit 0

*Runtime:*
- [ ] `make test` PASS (json load)

**Verify**:
```yaml
acceptance:
  - given: ["P0-4 전문의 합의"]
    when: "P3-2 실행"
    then: ["37주 검증 반영", "H-4 evidence 첨부"]
commands:
  - run: "python3 scripts/pregnancy_weeks_sanity.py ."
    expect: "exit 0"
  - run: "grep -q 'H-4.*\\[V\\]' .dev/qa-evidence/v2.8.0.md"
    expect: "exit 0"
risk: MEDIUM
rollback: "git revert JSON 변경. 의료 검증 실패 시 v2.8 출시 중단 (Q7 gate)."
```

---

### [ ] P3-3: 실기기 QA evidence v2.8.0.md (H-items 10개 전부)

**Type**: work

**Required Tools**: (H-items 평가자 의존)

**Inputs**:
- `appcontext_path`, `contentview_path`, `dashboard_card_path`, `transition_sheet_path`, `recovery_modal_path`, `remote_config_service_path` — Phase 1-2 산출물
- `h_items_evaluators_path` (file): `${todo-P0-4.outputs.h_items_evaluators_path}`

**Outputs**:
- `qa_evidence_v280_path` (file): `.dev/qa-evidence/v2.8.0.md` — 10 H-items 전부 [V], "PASS" 문자열 포함

**Steps**:
- [ ] TestFlight v2.8.0 빌드 업로드 (bump + archive + export + upload)
- [ ] H-1~H-10 10개 실기기 QA 실행 (P0-4 평가자 지정 따라)
- [ ] 각 H-item evidence 첨부 (스크린샷/로그/서명)
- [ ] `.dev/qa-evidence/v2.8.0.md` 작성 — v2.7.1.md 포맷 참조
- [ ] 파일에 "PASS" 문자열 포함 (make qa-check 게이트)
- [ ] 사용자 dogfooding 4-state 전환 확인 ([V])
- [ ] `make qa-check` PASS

**Must NOT do**:
- Do not use AI evaluator for H-4/H-10 (외부 human 전용)
- Do not skip H-items (엄격 gate, Q2)
- Do not mark [V] before evidence 확보
- Do not run git commands

**References**:
- `.dev/qa-evidence/v2.7.1.md` — 포맷 샘플
- `scripts/qa_evidence_check.sh` — PASS 문자열 gate

**Acceptance Criteria**:

*Functional:*
- [ ] `.dev/qa-evidence/v2.8.0.md` 존재, "PASS" 포함
- [ ] H-1~H-10 10개 전부 [V] 표시
- [ ] Evidence (스크린샷/로그/서명) 첨부

*Static:*
- [ ] `bash scripts/qa_evidence_check.sh` PASS

*Runtime:*
- [ ] (수동 QA)

**Verify**:
```yaml
acceptance:
  - given: ["P1-1~P2-4 완료", "P0-4 평가자 정의"]
    when: "P3-3 실행"
    then: ["H-items 10 전부 [V]", "qa-check PASS"]
commands:
  - run: "make qa-check"
    expect: "exit 0"
  - run: "grep -c '\\[V\\]' .dev/qa-evidence/v2.8.0.md"
    expect: "stdout >= 10"
risk: MEDIUM
```

---

### [ ] P4-1: Privacy Policy + Firestore rules/indexes 배포

**Type**: work

**Required Tools**: `firebase` CLI

**Inputs**:
- `qa_evidence_v280_path` (file): `${todo-P3-3.outputs.qa_evidence_v280_path}` — [V] 확인

**Outputs**:
- `privacy_html_path` (file): `/Users/roque/allcare/privacy.html` — 임신/HealthKit 건강 데이터 항목 추가

**Steps**:
- [ ] `/Users/roque/allcare/privacy.html` 수정 — 임신 데이터, HealthKit 연동, KickSession 수집 명시
- [ ] 법무 의견서 반영 (H-10 evidence)
- [ ] GitHub Pages 배포 (`/Users/roque/allcare`로 cd, push)
- [ ] `make deploy-rules` → firestore.rules + firestore.indexes.json 배포 (pregnancy composite index 2개 + 신규 쿼리 index 포함)
- [ ] `make index-check` PASS (gap 0)

**Must NOT do**:
- Do not deploy Privacy Policy before 법무 검토 의견서
- Do not modify firestore.rules pregnancy 블록 기존 조건 (하향 조정 금지)
- Do not run git commands in /Users/roque/BabyCare (Privacy는 /Users/roque/allcare repo)

**References**:
- H-10 법적 검토 evidence (P0-4, P3-3)

**Acceptance Criteria**:

*Functional:*
- [ ] `/Users/roque/allcare/privacy.html` 임신 데이터 섹션 존재
- [ ] `firebase deploy --only firestore:rules,firestore:indexes` exit 0

*Static:*
- [ ] `make index-check` exit 0

*Runtime:*
- [ ] (수동 확인)

**Verify**:
```yaml
acceptance:
  - given: ["P3-3 H-10 [V]"]
    when: "P4-1 실행"
    then: ["Privacy Policy 공개", "Firestore rules/indexes 배포"]
commands:
  - run: "make index-check"
    expect: "exit 0"
  - run: "make deploy-rules"
    expect: "exit 0"
risk: MEDIUM
rollback: "Privacy git revert + push. Firestore rules는 이전 버전 재배포. Index는 제거 가능."
```

---

### [ ] P4-2: TestFlight v2.8.0 업로드 + RemoteConfig 100% rollout

**Type**: work

**Required Tools**: `xcodebuild`, `xcrun altool`, Firebase Console

**Inputs**:
- `qa_evidence_v280_path` (file): `${todo-P3-3.outputs.qa_evidence_v280_path}`
- `privacy_html_path` (file): `${todo-P4-1.outputs.privacy_html_path}`

**Outputs**:
- `testflight_build_number` (string): v2.8.0 빌드 번호
- `rollout_log_path` (file): `.dev/specs/pregnancy-mode-v2/context/rollout-log.md` — rollout 모니터링 로그

**Steps**:
- [ ] `make deploy` → plan-verify → verify → ui-test → smoke-test → qa-check → deploy-rules → bump → archive → export → upload
- [ ] TestFlight 내부 테스터 배포 대기 (3일)
- [ ] Crashlytics crash-free >= 99%, pregnancy 관련 crash 0건 확인
- [ ] TestFlight 내부 테스터 Resume UI / baby-only / both 시나리오 피드백 수집
- [ ] 3일 무회귀 확인 시 Firebase Console RemoteConfig `pregnancy_mode_enabled = true` 100% 배포 (Codex Rec-6 단순화)
- [ ] 24시간 Crashlytics 모니터링
- [ ] `rollout-log.md`에 timeline, crash 통계, 사용자 리포트 기록

**Must NOT do**:
- Do not rollout before 3일 무회귀 확인
- Do not skip 5→25→100% single-step 이유 (DAU 확인 후 Rec-6 판단)
- Do not commit source code changes during P4-2 (배포 단계)

**References**:
- Codex Rec-6: 3단계 rollout → TestFlight 검증 + 직접 100% (DAU 규모 보강 필요)
- Q2: 엄격 gate

**Acceptance Criteria**:

*Functional:*
- [ ] TestFlight v2.8.0 업로드 완료 (Delivery UUID 확보)
- [ ] TestFlight 3일 무회귀 확인
- [ ] RemoteConfig `pregnancy_mode_enabled = true` Firebase Console 적용
- [ ] rollout-log.md 24시간 모니터링 기록

*Static:*
- [ ] `make deploy` exit 0

*Runtime:*
- [ ] (수동 모니터링)

**Verify**:
```yaml
acceptance:
  - given: ["P3-3 H-items all V", "P4-1 Privacy/rules 배포"]
    when: "P4-2 실행"
    then: ["TestFlight 업로드", "3일 무회귀", "RemoteConfig 100%"]
commands:
  - run: "test -f .dev/specs/pregnancy-mode-v2/context/rollout-log.md"
    expect: "exit 0"
  - run: "grep -q 'Crashlytics crash-free.*9[9]' .dev/specs/pregnancy-mode-v2/context/rollout-log.md"
    expect: "exit 0"
risk: HIGH
rollback: "Firebase Console에서 pregnancy_mode_enabled = false 즉시. Firestore 데이터 보존. 재배포 불필요."
```

---

### [ ] TODO Final: Verification

**Type**: verification

**Required Tools**: `xcodegen`, `xcodebuild`, `firebase`, `python3`

**Inputs**:
- all P0-1~P4-2 outputs

**Outputs**: (none)

**Steps**:
- [ ] `make verify` — build + lint + arch-test + test + design-verify
- [ ] `make plan-verify` — PLAN ↔ 코드 1:1 매칭
- [ ] `make smoke-test` — 시뮬 런치 + 크래시 체크
- [ ] `make ui-test` — XCUITest 18 전체 PASS
- [ ] `make qa-check` — `.dev/qa-evidence/v2.8.0.md` "PASS" 확인
- [ ] `make index-check` — gap 0
- [ ] `bash scripts/pre_merge_check.sh` PASS
- [ ] Code review: `/review` 또는 `hoyeon:code-reviewer` SHIP 판정
- [ ] Tribunal: `/tribunal` 또는 codex 독립 리뷰 SHIP 판정
- [ ] 모든 deliverables 존재 확인 (Concrete Deliverables 목록)
- [ ] H-1~H-10 모두 [V] 확인
- [ ] v2.6.2 심사 상태 / Firebase hotfix merge 상태 최종 확인

**Must NOT do**:
- Do not use Edit or Write (verification type, 소스 수정 금지)
- Do not add new features or fix errors (report only)
- Do not run git commands (Orchestrator 담당)
- Bash allowed for: make verify/test/ui-test/smoke-test/qa-check/index-check, deploy-rules, pre_merge_check
- Do not modify files via Bash (no `sed -i`, `echo >`, etc.)

**Acceptance Criteria**:

*Functional:*
- [ ] Concrete Deliverables 모두 존재 (파일 체크)
- [ ] H-1~H-10 [V]
- [ ] v2.6.2 심사 완료, Firebase 11.8.0 hotfix merge 완료
- [ ] AppContext/RemoteConfig/Recovery/Protocol 신규 파일 모두 컴파일

*Static:*
- [ ] `make verify` exit 0
- [ ] `make arch-test` exit 0
- [ ] `make lint` exit 0
- [ ] `make plan-verify` exit 0
- [ ] `make index-check` exit 0

*Runtime:*
- [ ] `make test` PASS (301+ 단위)
- [ ] `make ui-test` PASS (18 XCUITest)
- [ ] `make smoke-test` PASS
- [ ] `make qa-check` PASS
- [ ] `bash scripts/pre_merge_check.sh` PASS

**Verify**:
```yaml
acceptance:
  - given: ["all P0-1~P4-2 완료", "plan-reviewer/codex SHIP"]
    when: "TODO Final 실행"
    then: ["전체 하네스 PASS", "Definition of Done 100%"]
commands:
  - run: "make verify"
    expect: "exit 0"
  - run: "make ui-test"
    expect: "exit 0"
  - run: "bash scripts/pre_merge_check.sh"
    expect: "exit 0"
risk: LOW
```
