# Cry Analysis (울음 분석) - Stub-First Implementation Plan

> BabyCare iOS에 ChatterBaby 스타일 울음 분석 기능을 stub-first로 추가. `.mlmodel` 없이 서비스 인터페이스 + UI + 인프라 레이어만 완성하고 CoreML 연결부는 stub. Feature flag로 진입점 gate.
> Mode: standard/autopilot

---

## Assumptions

> 이전 세션 NOTES.md(2026-04-10) 결정 + 본 autopilot 세션에서 autonomous하게 적용한 결정들.

| Decision Point | Assumed Choice | Rationale | Source |
|---------------|----------------|-----------|--------|
| **DP-01: 데이터 저장** | 독립 `cryRecords` Firestore 컬렉션 | Activity 오염 방지, 롤백 용이 | NOTES.md (prior user decision) |
| **DP-02: 결과 처리** | 명시적 "저장" 버튼, 자동 Activity 연계 금지 | 오분류가 공식 기록으로 굳는 것 방지 | NOTES.md |
| **DP-03: .mlmodel** | placeholder 번들 금지, stub 서비스만 구현 | Boundaries 명시, production slip 방지 | NOTES.md |
| **DP-04: 통계/패턴** | MVP 제외, v2 이관 | 부정확 모델 기반 통계 = 오정보 리스크 | NOTES.md |
| **서비스 격리 방식** | `@MainActor final class` (원 NOTES의 `actor` 제안 오버라이드) | `SoundPlayerService` 패턴 일치, AVAudioPCMBuffer non-Sendable 이슈 회피, 코드베이스 유일 actor 방지 | tradeoff-analyzer SWITCH 권고 |
| **Feature flag 구현** | 컴파일 타임 `enum FeatureFlags { static let cryAnalysisEnabled = false }` | Remote Config 없음, 단순 상수로 충분 | tradeoff-analyzer, codex synthesis |
| **기본 flag 값** | `false` (완전 숨김) | stub slip 방지 — DP-03 취지 | autopilot-rule (lower risk) |
| **VM 등록 위치** | `AppState` 등록 보류, `CryAnalysisView` 내부 `@State private var vm = CryAnalysisViewModel()` | stub 단계에서 전역 공유 필요 없음, AppState.init() 부팅 비용 회피 | tradeoff-analyzer CONSIDER |
| **Stub 결과 값** | 고정 dummy `[hungry:0.2, burping:0.2, bellyPain:0.2, discomfort:0.2, tired:0.2]` + `isStub: true` 필드 | App Review "misleading" 리스크 회피, 랜덤 금지 | gap-analyzer, codex synthesis |
| **AVAudioPCMBuffer 취급** | 녹음 tap 내부에서 `[Float]`로 변환 후 actor/class 경계 통과 | Swift 6 non-Sendable, `@unchecked Sendable` 금지 | gap-analyzer |
| **AVAudioSession 조율** | 녹음 시작 시 `SoundPlayerService` 재생 중이면 `pause()` 호출 후 category `.playAndRecord`로 전환, 종료 시 `.playback` 복원 | SoundPlayerService 충돌 방지 | gap-analyzer |
| **권한 denied UX** | "마이크 권한이 필요합니다" + 설정 딥링크(`UIApplication.openSettingsURLString`) 버튼 | 기본 UX, H-item으로 검증 | gap-analyzer |
| **NSMicrophoneUsageDescription 문구** | "아기 울음 분석을 위해 마이크 접근 권한이 필요합니다. 녹음은 기기 내에서만 처리되며 외부로 전송되지 않습니다." | NOTES.md 명시 문구 (tradeoff Option A와 일치) | NOTES.md, tradeoff DP-03 |
| **PrivacyInfo.xcprivacy** | `NSPrivacyCollectedDataTypeAudioData` 추가 (NOTES.md 결정 존중) | tradeoff는 보류 권고했으나 NOTES.md가 user 권위. 저장된 dummy 결과에 `isStub: true`로 필터링 가능 | NOTES.md (user authoritative) |
| **녹음 길이** | 5초 | UX 권고 하한, 한 손 조작 편의 | autopilot-rule |
| **`CryRecord` 스키마** | `id, babyId, recordedAt, durationSeconds, probabilities: [CryLabel: Double], topLabel: CryLabel?, isStub: Bool, note: String?` | 신규 필드 optional 원칙 | codebase-pattern |
| **히스토리 쿼리** | 최근 20건 limit, `recordedAt desc` | 기존 페이지네이션 패턴 | codebase-pattern |
| **Onboarding 영속화** | `@AppStorage("cryAnalysisOnboardingShown")` | 기존 onboarding 플래그 패턴 | codebase-pattern |
| **진동 피드백** | 녹음 시작/종료 `UIImpactFeedbackGenerator(style: .medium)` | UX 권고 직접 반영 | ux-reviewer |
| **테스트 대상** | `CryRecord` Codable round-trip, `CryAnalysisService` stub 결과 shape(확률 합 ≈ 1.0, 5 키 존재, `isStub == true`), `FeatureFlags.cryAnalysisEnabled == false` | 실제 모델 없으므로 인터페이스만 검증 | verification-planner |
| **FirestoreService 리팩토링** | 본 스프린트 범위 밖. `CryAnalysisViewModel`에서 Firestore 직접 호출 (기존 패턴) | Integration test는 Verification Gap으로 기록 | scope-limit |
| **v2.6.1 심사 대기** | 코드 merge는 develop에 계속하되 TestFlight 제출은 v2.6.1 승인 후 | Apple 동시 심사 불가 | tradeoff DP-02 (Pre-work에 기록) |

> **Note**: 이 결정들은 사용자 명시 확인 없이 적용됐다. 틀린 것이 있으면 `/specify --interactive`로 재실행하라.

---

## Verification Summary

### Agent-Verifiable (A-items)

| ID | Criterion | Method | Related TODO |
|----|-----------|--------|--------------|
| A-1 | `make build` 성공 (xcodegen + xcodebuild) | `make build` → exit 0 | All |
| A-2 | `make test` 통과 (기존 38 + 신규 테스트) | `make test` → exit 0 | 7, Final |
| A-3 | `make design-verify` 토큰 100% | `make design-verify` → exit 0 | Final |
| A-4 | `make verify` 전체 파이프라인 통과 | `make verify` → exit 0 | Final |
| A-5 | `CryRecord` Codable round-trip 정상 | XCTest assertion | 7 |
| A-6 | `CryAnalysisService.analyzeStub()` 반환값: 5개 라벨, 확률 합 1.0 ± 0.001, `isStub == true` | XCTest assertion | 7 |
| A-7 | `FeatureFlags.cryAnalysisEnabled == false` (프로덕션 기본값) | XCTest assertion | 7 |
| A-8 | `FirestoreCollections.cryRecords == "cryRecords"` 상수 존재 | XCTest assertion | 7 |
| A-9 | `NSMicrophoneUsageDescription` 키가 `project.yml` info.properties에 존재 | `grep NSMicrophoneUsageDescription project.yml` → 일치 | 1 |
| A-10 | `PrivacyInfo.xcprivacy`에 `NSPrivacyCollectedDataTypeAudioData` 항목 존재 | `grep NSPrivacyCollectedDataTypeAudioData BabyCare/PrivacyInfo.xcprivacy` | 1 |
| A-11 | `privacy.html`에 "울음" 또는 "마이크" 섹션 존재 | `grep -E "울음\|마이크" privacy.html` | 1 |
| A-12 | `FirestoreCollections.cryRecords`가 `CryAnalysisViewModel`에서 사용되고 하드코딩 경로 없음 | `grep -n '"cryRecords"' BabyCare/ViewModels/CryAnalysisViewModel.swift` → 0 hits (상수만 사용) | 4 |
| A-13 | `ActivityType` enum 미수정 (git diff 비어있음) | `git diff BabyCare/Models/Activity.swift` → 0 변경 | All |
| A-14 | `AIGuardrailService.prohibitedRules` 미수정 | `git diff -- BabyCare/Services/AIGuardrailService.swift` → prohibitedRules 미변경 | All |
| A-15 | 경고 0건 유지 (`make test` 출력 warning 카운트) | `make test 2>&1 \| grep -c warning:` → 0 | Final |

### Human-Required (H-items)

| ID | Criterion | Reason | Review Material |
|----|-----------|--------|----------------|
| H-1 | 마이크 권한 다이얼로그가 실기기에서 NOTES.md 문구 그대로 노출 | 시뮬레이터 권한 플로우 불안정 | 실기기 수동 |
| H-2 | 권한 거부 후 "설정 열기" 딥링크 플로우 동작 | 자동화 어려움 | 실기기 수동 |
| H-3 | 면책 배너가 결과 카드 상단 **고정** 노출 (caption 숨김 금지) | UI/UX 시각 판단 | `CryAnalysisView` 스크린샷 |
| H-4 | 녹음 버튼 44pt × 44pt 이상, 한 손 조작 가능 | 접근성 시각 판단 | Xcode Preview 또는 실기기 |
| H-5 | 확률 바 차트 시각적 완성도 (색 대비, 라벨 가독성) | 디자인 판단 | Xcode Preview |
| H-6 | VoiceOver accessibility announcement (녹음 중/완료 상태) | 접근성 시각/청각 검증 | 실기기 VoiceOver |
| H-7 | 진동 피드백 (`UIImpactFeedbackGenerator`) 감도 | 시뮬레이터 무음 | 실기기 수동 |
| H-8 | 면책 문구가 `AIGuardrailService.prohibitedRules` 금지어 회피 (`"가능성이 높습니다"` 등 비포함) | 도메인 판단 | 코드 리뷰 |
| H-9 | `privacy.html` 업데이트 문구 자연스러움 + 법적 정확성 | 법/UX 판단 | `privacy.html` diff |
| H-10 | 최초 1회 면책 onboarding 동작 (`@AppStorage` 영속화) | 사용자 플로우 검증 | 실기기 |
| H-11 | SoundPlayerService 재생 중 녹음 시작 → 재생 일시정지 → 녹음 완료 후 재생 재개 플로우 | 실기기 체감 | 실기기 수동 |
| H-12 | **NOTES.md DP-01 vs tradeoff-analyzer DP-01 모순 확인**: PrivacyInfo 오디오 수집 선언을 stub v2.6.2에 포함하는 것이 App Review에 문제 없는지 | 심사 정책 판단 — 본 PLAN은 NOTES.md 따름 | Apple Developer 문서 + NOTES.md 재확인 |

### Sandbox Agent Testing (S-items)

> iOS 앱은 docker-compose BDD 샌드박스 불가. `make screenshots` + `ScreenshotTests.swift` append로 대체 (기존 패턴 `testRecordingSheet()` 참조).

| ID | Scenario | Agent | Method |
|----|----------|-------|--------|
| S-1 | HealthView에 "울음 분석" 카드 섹션 노출 확인 (feature flag `true` 빌드에서) | screenshot agent | `make screenshots` → `03_health_cry_card.png` (신규 케이스 추가) |
| S-2 | `CryAnalysisView` 초기 화면 (녹음 버튼, 면책 배너, onboarding 후 상태) | screenshot agent | `testCryAnalysisView()` 신규 |
| S-3 | `CryAnalysisView` 결과 상태 (5개 확률 바 차트 + 저장 버튼) — stub 결과 주입 | screenshot agent | `testCryAnalysisResult()` 신규 |
| S-4 | 권한 거부 상태 UI (설정 열기 버튼 노출) | screenshot agent | `testCryAnalysisPermissionDenied()` 신규 |

**Sandbox prerequisites**: `make screenshots` 가 정상 동작. S-items 실행 시 임시로 `FeatureFlags.cryAnalysisEnabled = true` override (`#if SCREENSHOT_TESTS` 분기) 필요.

### Verification Gaps

- **Tier 2 (Integration) 부재**: `FirestoreService` 는 class 직접 의존 구조. `CryAnalysisViewModel`의 Firestore 저장 경로는 본 스프린트에서 protocol 추출 없이 기존 패턴 유지. Mock 기반 저장 인터페이스 검증은 향후 과제.
- **Tier 3 (E2E) 부재**: XCUITest가 screenshot 전용. 전체 플로우(진입 → 녹음 → 결과 → 저장) 자동 E2E 없음. S-items 스크린샷이 부분 대체.
- **마이크 권한 시뮬레이터 제약**: `AVAudioSession.requestRecordPermission` 은 시뮬레이터에서 항상 granted/denied 고정. 권한 플로우 검증은 H-items로 분류.
- **PrivacyInfo 정책 불확실성**: H-12 참조. stub 단계에 audio data 선언을 하는 것이 Apple 정책상 안전한지 사람 확인 필요.

---

## External Dependencies Strategy

### Pre-work (user prepares before AI work)

| Dependency | Action | Command/Step | Blocking? |
|------------|--------|-------------|-----------|
| v2.6.1 App Store 심사 상태 | 심사 완료 대기 (**TestFlight 제출 전 승인 필요**) | App Store Connect 수동 확인 | **Yes** (TestFlight 제출 시점만, develop merge는 무방) |
| Xcode 15+ & iOS 17 시뮬레이터 | 로컬 빌드 환경 확인 | `xcodebuild -version` | Yes |
| 실기기 (마이크 권한 H-items 검증용) | USB 연결 + provisioning | Xcode Devices | H-items 단계에서 Yes |

### During (AI work strategy)

| Dependency | Dev Strategy | Rationale |
|------------|-------------|-----------|
| AVFoundation (마이크) | stub: `CryAnalysisService.analyzeStub()`가 AVAudioEngine 초기화 없이 고정 dummy 반환 | 실제 녹음 없이 인터페이스 계약만 구현. `.mlmodel` 준비 시 서비스 내부만 교체 |
| SoundAnalysis.framework | **본 스프린트 미사용** (stub-only) | DP-03 boundary |
| CoreML | **본 스프린트 미사용** (stub-only) | DP-03 boundary |
| Firestore `cryRecords` | 기존 `FirestoreCollections.*` 상수 + `babyVM.dataUserId()` 경유 | 기존 패턴 준수 |
| Apple Charts | 기존 dependency 재사용 | 외부 차트 라이브러리 금지 규약 |

### Post-work (user actions after completion)

| Task | Related Dependency | Action | Command/Step |
|------|--------------------|--------|-------------|
| Firestore 규칙 업데이트 | `cryRecords` 서브컬렉션 | `firestore.rules`에 `users/{uid}/babies/{bid}/cryRecords` 읽기/쓰기 규칙 추가 | Firebase Console 또는 `firebase deploy --only firestore:rules` |
| H-items 12건 수동 검증 | 실기기 테스트 | H-1 ~ H-12 각 항목 수동 확인 | 실기기 + Xcode |
| v2.6.2 심사 제출 | v2.6.1 승인 후 | `make deploy` 후 App Store Connect 제출 | `make deploy` (단, v2.6.1 승인 확인 후) |
| `.mlmodel` 훈련 (차후) | Donate-a-Cry corpus | CreateML MLSoundClassifier 훈련 후 `CryAnalysisService.analyze()` 실제 구현 교체 + feature flag `true` | 별도 스프린트 |
| Feature flag ON 시점 | 실제 모델 준비 완료 후 | `FeatureFlags.cryAnalysisEnabled = true` | 코드 PR |

---

## Context

### Original Request
BabyCare iOS 앱에 울음 분석 기능을 추가. 이전 세션(2026-04-10)에서 탐색 + 분석까지 완료, 4개 DP 모두 "B" (lower risk) 옵션으로 확정. 본 세션은 NOTES.md를 로드하여 `/specify --autopilot`으로 PLAN 생성.

### Interview Summary

**Key Discussions**:
- **DP-01 데이터 저장**: 독립 `cryRecords` 서브컬렉션 (Activity 오염 금지, 롤백 easy) — NOTES.md 확정
- **DP-02 결과 처리**: 명시적 "저장" 버튼만 (자동 Activity 연계 금지) — NOTES.md 확정
- **DP-03 .mlmodel**: placeholder 번들 금지, stub 서비스 인터페이스 + UI만 구현 — NOTES.md 확정
- **DP-04 통계/패턴**: MVP 제외, v2 이관 — NOTES.md 확정
- **서비스 격리**: `actor` → `@MainActor final class` 로 오버라이드 (tradeoff 권고)
- **Feature flag**: 컴파일 타임 enum 상수 (Remote Config 불필요)
- **VM 등록**: AppState 보류, View 로컬 @State

### Research Findings

- **audio 인프라 전무**: `SoundPlayerService` 는 playback only, 녹음 인프라 0. AVAudioEngine/SoundAnalysis 미사용.
- **Activity 모델 수정 금지**: `ActivityType` enum `CaseIterable` → 전수 switch 검토 위험. 독립 `CryRecord` 사용.
- **HealthView 섹션 카드 패턴**: `BabyCare/Views/Health/HealthView.swift:12-178` — `HealthSectionCard`, 삽입 지점 "아기 소리" 다음 "일기" 이전 (line ~174 근처).
- **FirestoreCollections**: `BabyCare/Utils/Constants.swift:65-87` — 21개 상수, `cryRecords` append.
- **가족 공유 라우팅**: `babyVM.dataUserId()` 필수 (`authVM.currentUserId` 직접 사용 금지).
- **Swift 6 concurrency**: `AVAudioPCMBuffer` non-Sendable → actor 경계 통과 불가 → `[Float]` 변환.
- **`SoundPlayerService` 패턴**: `@MainActor final class` + AVFoundation — `CryAnalysisService` 동일 패턴 채택.
- **Tradeoff Risk**: 대부분 LOW/MED. HIGH 리스크 3건(PrivacyInfo 시점, v2.6.1 심사 타이밍, 권한 문구)은 NOTES.md 결정을 존중하거나 Pre-work/Assumptions에 반영.

---

## Work Objectives

### Core Objective
BabyCare iOS에 울음 분석 기능의 **UI + 서비스 인터페이스 + 인프라 레이어**를 완성한다. CoreML 연결부는 stub으로 남겨 feature flag OFF 상태로 production에 숨긴 채 merge 가능한 상태를 만든다.

### Concrete Deliverables

1. **권한/프라이버시**:
   - `project.yml` info.properties 에 `NSMicrophoneUsageDescription` 추가
   - `BabyCare/PrivacyInfo.xcprivacy` 에 `NSPrivacyCollectedDataTypeAudioData` 항목 추가
   - `privacy.html` 업데이트 (울음 분석 온디바이스 처리 명시)

2. **모델/상수**:
   - `BabyCare/Models/CryRecord.swift` (신규)
   - `BabyCare/Models/CryLabel.swift` (신규, enum)
   - `BabyCare/Utils/Constants.swift` 에 `FirestoreCollections.cryRecords` 추가
   - `BabyCare/Utils/FeatureFlags.swift` (신규, `enum FeatureFlags`)

3. **서비스/ViewModel**:
   - `BabyCare/Services/CryAnalysisService.swift` (신규, `@MainActor final class`, AVAudioSession 조율 + stub interface)
   - `BabyCare/ViewModels/CryAnalysisViewModel.swift` (신규, `@MainActor @Observable`)

4. **View**:
   - `BabyCare/Views/Health/CryAnalysisView.swift` (신규, 녹음 UI + 면책 배너 + 확률 바 + 히스토리 + onboarding + 권한 denied 상태)
   - `BabyCare/Views/Health/HealthView.swift` 수정 (섹션 카드 추가, feature flag gate)

5. **테스트**:
   - `BabyCareTests/BabyCareTests.swift` append (`CryRecord` codable, `CryAnalysisService` stub, `FeatureFlags`, `FirestoreCollections.cryRecords`)

### Definition of Done

- [ ] `make verify` 통과 (빌드 + 38+ 테스트 + 디자인 토큰)
- [ ] 경고 0건 유지
- [ ] `FeatureFlags.cryAnalysisEnabled == false` (production 기본)
- [ ] A-1 ~ A-15 모두 PASS
- [ ] Activity 모델, AIGuardrailService 미변경 (git diff 확인)
- [ ] H-items 12건은 post-work 로 분리 (PLAN 승인 대상 아님)
- [ ] S-items 4건은 ScreenshotTests append (Post-work 단계에서 flag override로 실행)

### Must NOT Do (Guardrails)

- Activity 모델/`ActivityType` enum 수정 금지
- 자동 Activity 기록 생성 금지 (결과 → 명시적 "저장" 버튼만)
- Placeholder `.mlmodel` 번들 포함 금지
- `SoundAnalysis.framework`, `CoreML.framework` 본 스프린트 import 금지 (stub는 AVFoundation 미사용도 가능 — 인터페이스만)
- `PatternReport`에 울음 이유 차트/통계 추가 금지
- 단정적 라벨 단독 표시 금지 ("배고픔" 단독 X)
- `AIGuardrailService.prohibitedRules` 수정 금지
- "가능성이 높습니다" 등 AI 금지어 사용 금지
- 새 SPM/CocoaPods 의존성 추가 금지
- 전체화면 alert 면책 남발 금지
- `RecordingView` HealthType enum 케이스 추가 금지
- 백그라운드 녹음 (`UIBackgroundModes: audio`) 금지
- `authVM.currentUserId` 직접 사용 금지 → `babyVM.dataUserId()` 사용
- Firestore 경로 하드코딩 금지 → `FirestoreCollections.*` 상수 사용
- `BabyCareTests.swift` 외 신규 테스트 파일 생성 금지
- `@unchecked Sendable` 로 Swift 6 concurrency 에러 우회 금지
- `AVAudioPCMBuffer` 를 actor/class 경계 간 직접 전달 금지 (`[Float]` 변환 필수)
- Stub 결과에 `Float.random()` 등 랜덤값 사용 금지 (고정 dummy 값)
- `AppState` 에 `CryAnalysisViewModel` 등록 금지 (View 로컬 `@State` 사용)
- `CryRecord` 를 `Activity.swift` 에 중첩/extension 으로 추가 금지
- Git 명령 실행 금지 (Worker 제약; Orchestrator 만 commit)

---

## Task Flow

```
TODO 1 (권한/프라이버시)  ──┐
TODO 2 (모델/상수/Flag)   ──┼── TODO 3 (Service) ──┐
                         └──────────────────────┴── TODO 4 (VM) ── TODO 5 (View) ── TODO 6 (HealthView) ── TODO 7 (Tests) ── TODO Final
```

## Dependency Graph

| TODO | Requires (Inputs) | Produces (Outputs) | Type |
|------|-------------------|-------------------|------|
| 1 | - | `project_yml` (file), `privacy_info` (file), `privacy_html` (file) | work |
| 2 | - | `cry_record` (file), `cry_label` (file), `constants_updated` (file), `feature_flags` (file) | work |
| 3 | `cry_record`, `cry_label` | `cry_service` (file) | work |
| 4 | `cry_service`, `cry_record`, `cry_label`, `constants_updated` | `cry_vm` (file) | work |
| 5 | `cry_vm`, `feature_flags` | `cry_view` (file) | work |
| 6 | `cry_view`, `feature_flags` | `health_view_updated` (file) | work |
| 7 | `cry_record`, `cry_service`, `feature_flags`, `constants_updated` | `tests_updated` (file) | work |
| Final | all | - | verification |

## Parallelization

| Group | TODOs | Reason |
|-------|-------|--------|
| P1 | TODO 1, TODO 2 | 독립된 파일들, 서로 의존 없음 |
| 순차 | TODO 3 → 4 → 5 → 6 | 각 단계가 다음 단계의 contract 정의 |
| P2 | TODO 6, TODO 7 | 6은 HealthView, 7은 테스트 파일 — 독립 |

## Commit Strategy

| After TODO | Message | Files | Condition |
|------------|---------|-------|-----------|
| 1 | `chore(privacy): add microphone usage description and audio data privacy manifest for cry analysis` | `project.yml`, `BabyCare/PrivacyInfo.xcprivacy`, `privacy.html` | always |
| 2 | `feat(cry-analysis): add CryRecord model, CryLabel enum, FeatureFlags, and cryRecords Firestore collection constant` | `BabyCare/Models/CryRecord.swift`, `BabyCare/Models/CryLabel.swift`, `BabyCare/Utils/FeatureFlags.swift`, `BabyCare/Utils/Constants.swift` | always |
| 3 | `feat(cry-analysis): add CryAnalysisService stub with AVAudioSession coordination` | `BabyCare/Services/CryAnalysisService.swift` | always |
| 4 | `feat(cry-analysis): add CryAnalysisViewModel with recording state machine and Firestore save` | `BabyCare/ViewModels/CryAnalysisViewModel.swift` | always |
| 5 | `feat(cry-analysis): add CryAnalysisView with recording UI, disclaimer banner, probability chart, and onboarding` | `BabyCare/Views/Health/CryAnalysisView.swift` | always |
| 6 | `feat(cry-analysis): add cry analysis section card to HealthView gated by feature flag` | `BabyCare/Views/Health/HealthView.swift` | always |
| 7 | `test(cry-analysis): add unit tests for CryRecord, CryAnalysisService stub, FeatureFlags, and FirestoreCollections` | `BabyCareTests/BabyCareTests.swift` | always |

> **Note**: TODO Final은 verification only, no commit.

## Error Handling

### Failure Categories

| Category | Examples | Detection Pattern |
|----------|----------|-------------------|
| `env_error` | xcodegen 미설치, Xcode 버전 불일치, 시뮬레이터 부팅 실패 | `/command not found\|No such module\|simulator.*unavailable/i` |
| `code_error` | Swift 6 Sendable 에러, type mismatch, lint 실패, XCTest fail | `/error:\|warning:\|XCTAssert.*failed/i` |
| `scope_internal` | FirestoreCollections 기존 상수와 충돌, HealthView 삽입 지점 미발견 | Worker `suggested_adaptation` present |
| `unknown` | 분류 불가 | Default fallback |

### Failure Handling Flow

| Scenario | Action |
|----------|--------|
| work fails | Retry up to 2 times → Analyze → (below) |
| verification fails | Analyze immediately (no retry) → (below) |
| Worker times out | Halt and report |
| Missing Input | Skip dependent TODOs, halt |

### After Analyze

| Category | Action |
|----------|--------|
| `env_error` | Halt + log to `issues.md` (user 개입 필요) |
| `code_error` | Create Fix Task (depth=1) |
| `scope_internal` | Adapt via Dynamic TODO (depth=1) |
| `unknown` | Halt + log to `issues.md` |

### Fix Task Rules

- Fix Task type 은 항상 `work`
- Fix Task 실패 → Halt (no further Fix Task)
- Max depth = 1

### Adapt Rules

- DoD match OR file allowlist → adapt
- depth=1 limit
- Dynamic TODO 추가 시 PLAN.md 에 `(ADDED)` 마커 + `amendments.md` 감사 로그

## Runtime Contract

| Aspect | Specification |
|--------|---------------|
| Working Directory | `/Users/roque/BabyCare` |
| Network Access | Denied (no new deps, no external API calls during dev) |
| Package Install | Denied |
| File Access | Repository only |
| Max Execution Time | 5분 per TODO (make build 는 제외, make verify 는 Final에서 10분) |
| Git Operations | Denied (Orchestrator handles commits) |
| Xcode CLI | Allowed (`xcodebuild`, `xcodegen`) |
| Make targets | Allowed (`make build`, `make test`, `make verify`, `make design-verify`) |

---

## TODOs

### [x] TODO 1: 권한 + 프라이버시 매니페스트 + 개인정보처리방침 업데이트

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `project_yml` (file): `project.yml` - Microphone usage description 추가
- `privacy_info` (file): `BabyCare/PrivacyInfo.xcprivacy` - Audio data collection 선언 추가
- `privacy_html` (file): `privacy.html` - 울음 분석 울음 소리 처리 섹션 추가

**Steps**:
- [ ] `project.yml` 의 `info.properties` (또는 `settings.base` 내 플래그) 블록 위치 탐색
- [ ] `NSMicrophoneUsageDescription` 키 추가, 값: `"아기 울음 분석을 위해 마이크 접근 권한이 필요합니다. 녹음은 기기 내에서만 처리되며 외부로 전송되지 않습니다."`
- [ ] `BabyCare/PrivacyInfo.xcprivacy` 의 `NSPrivacyCollectedDataTypes` 배열에 `NSPrivacyCollectedDataTypeAudioData` 엔트리 추가:
  - `NSPrivacyCollectedDataTypeLinked`: false
  - `NSPrivacyCollectedDataTypeTracking`: false
  - `NSPrivacyCollectedDataTypePurposes`: `["NSPrivacyCollectedDataTypePurposeAppFunctionality"]`
- [ ] `privacy.html` 의 "2. 개인정보의 수집 및 이용 목적" 섹션에 "울음 소리 분석: 마이크로 녹음된 오디오는 기기 내에서만 처리되며 외부 서버로 전송되지 않습니다" 취지 단락 추가
- [ ] 모든 파일이 parseable (YAML/XML/HTML) 한지 sanity check

**Must NOT do**:
- 다른 InfoPlist 키 수정 금지
- 기존 PrivacyInfo 항목 수정/삭제 금지
- privacy.html 의 다른 섹션 수정 금지
- Git commands 실행 금지

**References**:
- `project.yml` - 기존 info.properties 패턴 (NSCalendarsFullAccessUsageDescription 참고)
- `BabyCare/PrivacyInfo.xcprivacy` - 기존 NSPrivacyAccessedAPITypes 구조
- `privacy.html` - 기존 "2. 개인정보의 수집 및 이용 목적" 섹션

**Acceptance Criteria**:

*Functional:*
- [ ] `grep -c "NSMicrophoneUsageDescription" project.yml` → ≥ 1
- [ ] `grep -c "NSPrivacyCollectedDataTypeAudioData" BabyCare/PrivacyInfo.xcprivacy` → ≥ 1
- [ ] `grep -E "울음\|마이크" privacy.html` → ≥ 1 라인
- [ ] 권한 문구 정확히 NOTES.md 지정 문자열과 일치 (`grep "아기 울음 분석을 위해" project.yml`)

*Static:*
- [ ] `xcodegen generate` → exit 0 (project.yml 파싱 성공)
- [ ] `plutil -lint BabyCare/PrivacyInfo.xcprivacy` → OK
- [ ] HTML 구조 깨짐 없음 (`head`/`body`/section 태그 균형)

*Runtime:*
- [ ] `make build` → exit 0 (기존 빌드 재확인)

**Verify**:
```yaml
acceptance:
  - given: ["project.yml 수정 후"]
    when: "xcodegen generate 실행"
    then: ["생성된 Info.plist 에 NSMicrophoneUsageDescription 존재", "문구가 NOTES.md와 동일"]
  - given: ["PrivacyInfo.xcprivacy 수정 후"]
    when: "plutil -lint 실행"
    then: ["OK 반환"]
commands:
  - run: "cd /Users/roque/BabyCare && xcodegen generate"
    expect: "exit 0"
  - run: "plutil -lint /Users/roque/BabyCare/BabyCare/PrivacyInfo.xcprivacy"
    expect: "exit 0"
  - run: "grep -q NSMicrophoneUsageDescription /Users/roque/BabyCare/project.yml"
    expect: "exit 0"
  - run: "grep -q NSPrivacyCollectedDataTypeAudioData /Users/roque/BabyCare/BabyCare/PrivacyInfo.xcprivacy"
    expect: "exit 0"
risk: MEDIUM
```

**Rollback** (if verification fails):
- `git checkout -- project.yml BabyCare/PrivacyInfo.xcprivacy privacy.html`
- xcodegen 재실행으로 Info.plist 재생성 확인

---

### [x] TODO 2: CryRecord 모델 + CryLabel enum + FeatureFlags + FirestoreCollections 상수

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `cry_record` (file): `BabyCare/Models/CryRecord.swift` - CryRecord 모델 (Identifiable, Codable, Hashable)
- `cry_label` (file): `BabyCare/Models/CryLabel.swift` - CryLabel enum (5 case + CodingKey)
- `feature_flags` (file): `BabyCare/Utils/FeatureFlags.swift` - FeatureFlags enum
- `constants_updated` (file): `BabyCare/Utils/Constants.swift` - cryRecords 상수 추가

**Steps**:
- [ ] `BabyCare/Models/CryLabel.swift` 생성:
  ```swift
  enum CryLabel: String, Codable, CaseIterable, Hashable {
      case hungry, burping, bellyPain, discomfort, tired
      var localizedDescription: String { /* Korean label, "...신호와 유사해요" style */ }
  }
  ```
- [ ] `BabyCare/Models/CryRecord.swift` 생성:
  ```swift
  struct CryRecord: Identifiable, Codable, Hashable {
      let id: String
      let babyId: String
      let recordedAt: Date
      let durationSeconds: Double
      let probabilities: [CryLabel: Double]
      let topLabel: CryLabel?
      let isStub: Bool
      let note: String?
  }
  ```
  - `[CryLabel: Double]` Codable 을 위해 `DictionaryCoder` 혹은 `CodingKeys` 커스텀
  - 신규 필드는 optional 원칙 (note 는 optional)
- [ ] `BabyCare/Utils/FeatureFlags.swift` 생성:
  ```swift
  enum FeatureFlags {
      static let cryAnalysisEnabled: Bool = false
  }
  ```
- [ ] `BabyCare/Utils/Constants.swift` 의 `FirestoreCollections` 에 `static let cryRecords = "cryRecords"` 추가 (기존 21개 상수 사이, 알파벳 순 또는 기능 그룹)

**Must NOT do**:
- `Activity.swift` 또는 `ActivityType` 수정 금지
- `CryRecord` 를 다른 파일에 중첩/extension 으로 추가 금지
- 외부 라이브러리 import 금지 (Foundation 만)
- `CryLabel` 에 6개 이상 케이스 추가 금지 (NOTES.md 5개 고정)
- Git commands 실행 금지

**References**:
- `BabyCare/Models/Activity.swift:29-124` - Identifiable/Codable 패턴 (하지만 수정 금지)
- `BabyCare/Utils/Constants.swift:65-87` - FirestoreCollections 상수 패턴
- `BabyCare/Models/*.swift` - 기존 모델 Codable 패턴

**Acceptance Criteria**:

*Functional:*
- [ ] 4개 신규/수정 파일 존재
- [ ] `CryLabel` 은 정확히 5개 case
- [ ] `CryRecord.isStub` 필드 존재
- [ ] `FeatureFlags.cryAnalysisEnabled == false`
- [ ] `FirestoreCollections.cryRecords` 상수 존재, 값 `"cryRecords"`

*Static:*
- [ ] `make build` → exit 0 (Swift 6 strict concurrency 통과)
- [ ] 경고 0 추가

*Runtime:*
- [ ] (TODO 7에서 테스트 추가)

**Verify**:
```yaml
acceptance:
  - given: ["신규 파일 생성"]
    when: "make build"
    then: ["exit 0", "Sendable conformance warnings 없음"]
commands:
  - run: "test -f /Users/roque/BabyCare/BabyCare/Models/CryRecord.swift"
    expect: "exit 0"
  - run: "test -f /Users/roque/BabyCare/BabyCare/Models/CryLabel.swift"
    expect: "exit 0"
  - run: "test -f /Users/roque/BabyCare/BabyCare/Utils/FeatureFlags.swift"
    expect: "exit 0"
  - run: "grep -q 'static let cryRecords' /Users/roque/BabyCare/BabyCare/Utils/Constants.swift"
    expect: "exit 0"
  - run: "cd /Users/roque/BabyCare && make build"
    expect: "exit 0"
risk: LOW
```

---

### [x] TODO 3: CryAnalysisService (@MainActor final class, stub)

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `cry_record` (file): `${todo-2.outputs.cry_record}`
- `cry_label` (file): `${todo-2.outputs.cry_label}`

**Outputs**:
- `cry_service` (file): `BabyCare/Services/CryAnalysisService.swift`

**Steps**:
- [ ] `BabyCare/Services/CryAnalysisService.swift` 생성:
  ```swift
  import AVFoundation
  import Observation

  @MainActor
  final class CryAnalysisService {
      enum ServiceError: Error {
          case permissionDenied
          case sessionConfigurationFailed
          case notAvailable
      }
      
      static let recordingDuration: TimeInterval = 5.0
      
      // MARK: - Permission
      func requestPermission() async -> Bool { /* AVAudioApplication.requestRecordPermission */ }
      func permissionStatus() -> AVAudioApplication.recordPermission { /* ... */ }
      
      // MARK: - Session coordination
      func configureForRecording() throws { 
          // .playAndRecord, defaultToSpeaker, save previous state
      }
      func restoreAfterRecording() { 
          // restore .playback
      }
      
      // MARK: - Stub analysis
      func analyzeStub(babyId: String) -> CryRecord {
          let equal: [CryLabel: Double] = Dictionary(uniqueKeysWithValues: CryLabel.allCases.map { ($0, 0.2) })
          return CryRecord(
              id: UUID().uuidString,
              babyId: babyId,
              recordedAt: Date(),
              durationSeconds: Self.recordingDuration,
              probabilities: equal,
              topLabel: nil, // stub 상태에서는 topLabel 없음 (단정적 라벨 금지)
              isStub: true,
              note: nil
          )
      }
      
      // MARK: - Real analysis (TODO next sprint)
      // func analyze(audioSamples: [Float]) async throws -> CryRecord { 
      //     // TODO: Load .mlmodel, SNClassifySoundRequest, return real probabilities
      //     throw ServiceError.notAvailable
      // }
  }
  ```
- [ ] TODO 주석으로 실제 구현 지점 명시 (`// TODO: v2.7 - Load CreateML .mlmodel`)
- [ ] `@unchecked Sendable` 사용 금지 확인
- [ ] `AVAudioPCMBuffer` 타입 직접 노출 금지 — 실제 analyze 시그니처는 `[Float]` 로만 정의

**Must NOT do**:
- `SoundAnalysis.framework` import 금지 (stub 이므로)
- `CoreML.framework` import 금지
- `@unchecked Sendable` 사용 금지
- `AVAudioPCMBuffer` 를 인터페이스에 노출 금지
- `Float.random()` 등 랜덤값 사용 금지
- `actor` 키워드 사용 금지 (`@MainActor final class`)
- 새 SPM 의존성 추가 금지
- Git commands 실행 금지

**References**:
- `BabyCare/Services/SoundPlayerService.swift` - `@MainActor final class` + AVFoundation 패턴
- `BabyCare/Models/CryRecord.swift` - 방금 생성된 모델
- `BabyCare/Models/CryLabel.swift` - 방금 생성된 enum

**Acceptance Criteria**:

*Functional:*
- [ ] `CryAnalysisService.swift` 파일 존재
- [ ] `@MainActor final class CryAnalysisService` 선언
- [ ] `analyzeStub(babyId:)` 메서드가 `CryRecord` 반환, `isStub == true`, 5개 확률 합 1.0
- [ ] `requestPermission() async -> Bool` 존재
- [ ] `configureForRecording()`, `restoreAfterRecording()` 존재
- [ ] `import SoundAnalysis` 없음, `import CoreML` 없음
- [ ] `Float.random` 미사용
- [ ] `@unchecked Sendable` 미사용

*Static:*
- [ ] `make build` → exit 0 (Swift 6 strict concurrency 통과)
- [ ] 경고 0 추가

*Runtime:*
- [ ] (TODO 7에서 테스트 추가)

**Verify**:
```yaml
acceptance:
  - given: ["CryAnalysisService 구현"]
    when: "analyzeStub(babyId: \"test\") 호출"
    then: ["반환값 probabilities 합 ≈ 1.0", "isStub == true", "topLabel == nil"]
commands:
  - run: "test -f /Users/roque/BabyCare/BabyCare/Services/CryAnalysisService.swift"
    expect: "exit 0"
  - run: "grep -q '@MainActor' /Users/roque/BabyCare/BabyCare/Services/CryAnalysisService.swift && grep -q 'final class CryAnalysisService' /Users/roque/BabyCare/BabyCare/Services/CryAnalysisService.swift"
    expect: "exit 0"
  - run: "! grep -q '@unchecked Sendable' /Users/roque/BabyCare/BabyCare/Services/CryAnalysisService.swift"
    expect: "exit 0"
  - run: "! grep -q 'Float.random' /Users/roque/BabyCare/BabyCare/Services/CryAnalysisService.swift"
    expect: "exit 0"
  - run: "! grep -q 'import SoundAnalysis' /Users/roque/BabyCare/BabyCare/Services/CryAnalysisService.swift"
    expect: "exit 0"
  - run: "cd /Users/roque/BabyCare && make build"
    expect: "exit 0"
risk: MEDIUM
```

**Rollback**:
- `rm BabyCare/Services/CryAnalysisService.swift`
- `xcodegen generate && make build`

---

### [x] TODO 4: CryAnalysisViewModel (@MainActor @Observable, 상태 머신)

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `cry_service` (file): `${todo-3.outputs.cry_service}`
- `cry_record` (file): `${todo-2.outputs.cry_record}`
- `cry_label` (file): `${todo-2.outputs.cry_label}`
- `constants_updated` (file): `${todo-2.outputs.constants_updated}`

**Outputs**:
- `cry_vm` (file): `BabyCare/ViewModels/CryAnalysisViewModel.swift`

**Steps**:
- [ ] `BabyCare/ViewModels/CryAnalysisViewModel.swift` 생성:
  ```swift
  import Observation
  import FirebaseFirestore

  @MainActor
  @Observable
  final class CryAnalysisViewModel {
      enum Phase: Equatable {
          case idle
          case permissionRequired
          case permissionDenied  
          case recording(progress: Double)
          case analyzing
          case result(CryRecord)
          case error(String)
      }
      
      var phase: Phase = .idle
      var history: [CryRecord] = []
      
      private let service: CryAnalysisService
      
      init(service: CryAnalysisService = CryAnalysisService()) { self.service = service }
      
      func start(babyId: String) async { /* 권한 체크 → configureForRecording → 5초 타이머 → analyzeStub → phase 전환 */ }
      func cancel() { /* restoreAfterRecording → phase = .idle */ }
      func save(babyId: String, dataUserId: String, record: CryRecord) async throws { 
          // Firestore: users/{dataUserId}/babies/{babyId}/cryRecords/{record.id}
          // 반드시 FirestoreCollections.cryRecords 사용
      }
      func loadHistory(babyId: String, dataUserId: String) async throws { 
          // 최근 20건, recordedAt desc
      }
  }
  ```
- [ ] Firestore 쓰기 경로: `users/{dataUserId}/babies/{babyId}/cryRecords/{recordId}` — `FirestoreCollections.cryRecords` 상수로만 구성
- [ ] 하드코딩된 `"cryRecords"` 문자열 금지 (상수만 사용)
- [ ] `authVM.currentUserId` 직접 사용 금지 (dataUserId는 View 에서 `babyVM.dataUserId()` 경유로 넘겨받음)
- [ ] Phase 전환 상태 머신 구현 (.idle → .recording → .analyzing → .result)
- [ ] 녹음 5초는 `Task.sleep(nanoseconds:)` 기반 progress 업데이트 (AVAudioEngine 없이 가짜 타이머)

**Must NOT do**:
- `AppState` 에 VM 등록 금지 (View 로컬 `@State` 로만 사용)
- `authVM.currentUserId` 직접 참조 금지
- Firestore 컬렉션명 하드코딩 금지 (`FirestoreCollections.cryRecords` 만 사용)
- 새 SPM 의존성 추가 금지
- `Activity` 모델 저장 금지
- `ObservableObject` + `@Published` 패턴 사용 금지 (`@Observable` 만)
- Git commands 실행 금지

**References**:
- `BabyCare/Services/CryAnalysisService.swift` - 방금 생성
- `BabyCare/ViewModels/` 내 기존 `@MainActor @Observable` 패턴 (예: `ActivityViewModel`, `FeedingViewModel`)
- `BabyCare/Utils/Constants.swift:65-87` - `FirestoreCollections.cryRecords`
- `BabyCare/ViewModels/BabyViewModel.swift` - `dataUserId()` 가족 공유 라우팅

**Acceptance Criteria**:

*Functional:*
- [ ] `CryAnalysisViewModel.swift` 존재
- [ ] `@MainActor @Observable final class CryAnalysisViewModel`
- [ ] `Phase` enum 6개 이상 case
- [ ] `save()` 메서드가 `FirestoreCollections.cryRecords` 사용 (하드코딩 없음)
- [ ] `save()` 서명이 `dataUserId: String` 파라미터 받음 (authVM 직접 사용 금지)

*Static:*
- [ ] `make build` → exit 0
- [ ] 경고 0 추가

*Runtime:*
- [ ] (TODO 7 에서 phase 초기값 테스트)

**Verify**:
```yaml
acceptance:
  - given: ["CryAnalysisViewModel 구현"]
    when: "코드 스캔"
    then: ["FirestoreCollections.cryRecords 사용", "하드코딩 'cryRecords' 문자열 없음", "authVM.currentUserId 직접 참조 없음"]
commands:
  - run: "test -f /Users/roque/BabyCare/BabyCare/ViewModels/CryAnalysisViewModel.swift"
    expect: "exit 0"
  - run: "grep -q 'FirestoreCollections.cryRecords' /Users/roque/BabyCare/BabyCare/ViewModels/CryAnalysisViewModel.swift"
    expect: "exit 0"
  - run: "! grep -nE '\"cryRecords\"' /Users/roque/BabyCare/BabyCare/ViewModels/CryAnalysisViewModel.swift"
    expect: "exit 0"
  - run: "! grep -q 'authVM.currentUserId' /Users/roque/BabyCare/BabyCare/ViewModels/CryAnalysisViewModel.swift"
    expect: "exit 0"
  - run: "grep -q '@Observable' /Users/roque/BabyCare/BabyCare/ViewModels/CryAnalysisViewModel.swift"
    expect: "exit 0"
  - run: "cd /Users/roque/BabyCare && make build"
    expect: "exit 0"
risk: MEDIUM
```

---

### [x] TODO 5: CryAnalysisView (녹음 UI + 면책 배너 + 확률 바 + 히스토리 + onboarding)

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `cry_vm` (file): `${todo-4.outputs.cry_vm}`
- `feature_flags` (file): `${todo-2.outputs.feature_flags}`

**Outputs**:
- `cry_view` (file): `BabyCare/Views/Health/CryAnalysisView.swift`

**Steps**:
- [ ] `BabyCare/Views/Health/CryAnalysisView.swift` 생성:
  ```swift
  import SwiftUI
  import Charts
  
  struct CryAnalysisView: View {
      @State private var vm = CryAnalysisViewModel()
      @Environment(BabyViewModel.self) private var babyVM
      @Environment(AuthViewModel.self) private var authVM
      @AppStorage("cryAnalysisOnboardingShown") private var onboardingShown = false
      
      var body: some View {
          // 상단 고정 면책 배너
          // onboarding sheet (최초 1회)
          // Phase 분기:
          //   .idle: 44pt+ 녹음 버튼 + 설명
          //   .permissionRequired: 권한 요청 버튼
          //   .permissionDenied: "설정 열기" 딥링크
          //   .recording: progress ring + 취소 버튼 + 진동 피드백
          //   .analyzing: 로딩 스피너
          //   .result: 확률 바 차트 + 저장 버튼
          //   .error: 재시도 버튼
          // 하단: 히스토리 목록 (최근 20건, 라벨 + 타임스탬프)
      }
  }
  ```
- [ ] 면책 배너: **결과 카드 상단 고정** — caption 크기 숨김 금지
- [ ] 면책 문구: "본 기능은 의료 진단이 아닌 참고 정보입니다. AI 추정이며 정확도가 제한적입니다." (AIGuardrailService 금지어 회피)
- [ ] Onboarding: 최초 1회 `@AppStorage("cryAnalysisOnboardingShown")` sheet
- [ ] 녹음 버튼: 최소 `88×88` frame (44pt 이상 + 여유), SF Symbol `mic.circle.fill`
- [ ] 진동 피드백: 녹음 시작 `UIImpactFeedbackGenerator(style: .medium).impactOccurred()`, 종료 동일
- [ ] VoiceOver: `.accessibilityLabel("녹음 시작"), .accessibilityValue(phase)`, 상태 변경 시 `UIAccessibility.post(notification: .announcement, argument: ...)`
- [ ] 확률 바: Apple Charts `BarMark(x: probability, y: label)` — 5개 라벨
- [ ] 결과 라벨 문구: `"\(label.localizedDescription) 신호와 유사해요"` (단정적 라벨 금지)
- [ ] 저장 버튼: tap 시 `vm.save(babyId:, dataUserId: babyVM.dataUserId(currentUserId: authVM.currentUserId), record:)` 호출
- [ ] 권한 거부 UI: "설정 > BabyCare > 마이크" 안내 + `openURL(URL(string: UIApplication.openSettingsURLString)!)` 버튼

**Must NOT do**:
- 전체화면 alert 로 면책 남발 금지 (배너 고정만)
- 단정적 라벨 단독 표시 금지 (`"배고픔"` X → `"배고픔 신호와 유사해요"` O)
- "가능성이 높습니다" AI 금지어 사용 금지
- 면책 문구를 caption 크기로 숨기기 금지
- `authVM.currentUserId` 를 Firestore 경로에 직접 넘김 금지 (반드시 `babyVM.dataUserId()` 경유)
- 외부 차트 라이브러리 import 금지 (Apple Charts 만)
- `RecordingView` 또는 `HealthType` 에 의존 금지
- Git commands 실행 금지

**References**:
- `BabyCare/ViewModels/CryAnalysisViewModel.swift` - 방금 생성
- `BabyCare/Utils/FeatureFlags.swift`
- `BabyCare/Views/Health/` 기존 뷰들 - 레이아웃/spacing 패턴
- `BabyCare/Services/AIGuardrailService.swift` - 금지어 목록 (수정 금지, 참조만)
- `BabyCare/ViewModels/BabyViewModel.swift:dataUserId()` - 가족 공유 라우팅

**Acceptance Criteria**:

*Functional:*
- [ ] `CryAnalysisView.swift` 존재
- [ ] 면책 배너가 body 최상단 view hierarchy
- [ ] `@AppStorage("cryAnalysisOnboardingShown")` 존재
- [ ] 녹음 버튼 frame ≥ 44pt
- [ ] `babyVM.dataUserId(currentUserId:)` 호출 존재
- [ ] "신호와 유사해요" 문자열 존재
- [ ] `UIImpactFeedbackGenerator` 호출 존재
- [ ] `UIApplication.openSettingsURLString` 존재

*Static:*
- [ ] `make build` → exit 0
- [ ] 경고 0 추가

*Runtime:*
- [ ] (UI 동작은 H-items + S-items 검증)

**Verify**:
```yaml
acceptance:
  - given: ["CryAnalysisView 구현"]
    when: "코드 스캔"
    then: ["면책 배너 상단 고정", "단정적 라벨 미사용", "dataUserId 경유"]
commands:
  - run: "test -f /Users/roque/BabyCare/BabyCare/Views/Health/CryAnalysisView.swift"
    expect: "exit 0"
  - run: "grep -q 'cryAnalysisOnboardingShown' /Users/roque/BabyCare/BabyCare/Views/Health/CryAnalysisView.swift"
    expect: "exit 0"
  - run: "grep -q 'babyVM.dataUserId' /Users/roque/BabyCare/BabyCare/Views/Health/CryAnalysisView.swift"
    expect: "exit 0"
  - run: "grep -q 'UIImpactFeedbackGenerator' /Users/roque/BabyCare/BabyCare/Views/Health/CryAnalysisView.swift"
    expect: "exit 0"
  - run: "grep -q 'openSettingsURLString' /Users/roque/BabyCare/BabyCare/Views/Health/CryAnalysisView.swift"
    expect: "exit 0"
  - run: "! grep -q '가능성이 높습니다' /Users/roque/BabyCare/BabyCare/Views/Health/CryAnalysisView.swift"
    expect: "exit 0"
  - run: "cd /Users/roque/BabyCare && make build"
    expect: "exit 0"
risk: MEDIUM
```

---

### [x] TODO 6: HealthView 섹션 카드 추가 (feature flag gated)

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `cry_view` (file): `${todo-5.outputs.cry_view}`
- `feature_flags` (file): `${todo-2.outputs.feature_flags}`

**Outputs**:
- `health_view_updated` (file): `BabyCare/Views/Health/HealthView.swift`

**Steps**:
- [ ] `BabyCare/Views/Health/HealthView.swift` 에서 "아기 소리" 섹션 카드 찾기 (line ~170 근처)
- [ ] 그 바로 뒤, "일기" 카드 앞에 아래 형태로 삽입:
  ```swift
  if FeatureFlags.cryAnalysisEnabled {
      NavigationLink { 
          CryAnalysisView()
      } label: {
          HealthSectionCard(
              icon: "waveform.badge.microphone",
              title: "울음 분석",
              subtitle: "아기 울음소리 패턴 분석 (베타)",
              color: .appAccent // 또는 기존 섹션과 조화
          )
      }
  }
  ```
- [ ] feature flag `false` 상태에서 카드 completely 숨김 (Navigation Link 자체 없음)
- [ ] 기존 10개 섹션 카드 순서/레이아웃 유지

**Must NOT do**:
- 기존 섹션 카드 수정 금지
- `HealthType` enum 수정 금지
- `RecordingView` 경로에 추가 금지
- feature flag 없이 카드 노출 금지
- Git commands 실행 금지

**References**:
- `BabyCare/Views/Health/HealthView.swift:12-178` - HealthSectionCard 패턴
- `BabyCare/Utils/FeatureFlags.swift`
- `BabyCare/Views/Health/CryAnalysisView.swift`

**Acceptance Criteria**:

*Functional:*
- [ ] `HealthView.swift` 내 `CryAnalysisView()` 참조 존재
- [ ] `FeatureFlags.cryAnalysisEnabled` gate 존재
- [ ] 기존 섹션 카드 수정 없음 (git diff HealthView.swift 에 추가만 있음)

*Static:*
- [ ] `make build` → exit 0
- [ ] 경고 0 추가

*Runtime:*
- [ ] UI 흐름은 S-items (screenshots) 로 검증

**Verify**:
```yaml
acceptance:
  - given: ["HealthView 수정"]
    when: "FeatureFlags.cryAnalysisEnabled == false"
    then: ["CryAnalysisView navigation link 런타임 미노출"]
commands:
  - run: "grep -q 'FeatureFlags.cryAnalysisEnabled' /Users/roque/BabyCare/BabyCare/Views/Health/HealthView.swift"
    expect: "exit 0"
  - run: "grep -q 'CryAnalysisView' /Users/roque/BabyCare/BabyCare/Views/Health/HealthView.swift"
    expect: "exit 0"
  - run: "cd /Users/roque/BabyCare && make build"
    expect: "exit 0"
risk: LOW
```

---

### [x] TODO 7: 단위 테스트 append (BabyCareTests.swift)

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `cry_record` (file): `${todo-2.outputs.cry_record}`
- `cry_service` (file): `${todo-3.outputs.cry_service}`
- `feature_flags` (file): `${todo-2.outputs.feature_flags}`
- `constants_updated` (file): `${todo-2.outputs.constants_updated}`

**Outputs**:
- `tests_updated` (file): `BabyCareTests/BabyCareTests.swift`

**Steps**:
- [ ] `BabyCareTests/BabyCareTests.swift` 끝부분에 아래 테스트 append (MARK 섹션으로 구분):
  1. `test_cryLabel_allCasesCount_equalsFive`
  2. `test_cryRecord_codableRoundTrip`
  3. `test_cryAnalysisService_analyzeStub_returnsFiveEqualProbabilities`
  4. `test_cryAnalysisService_analyzeStub_isStubTrue`
  5. `test_cryAnalysisService_analyzeStub_probabilitiesSumToOne` (±0.001)
  6. `test_cryAnalysisService_analyzeStub_topLabelIsNil` (단정 라벨 금지 준수)
  7. `test_featureFlags_cryAnalysisEnabled_defaultsFalse`
  8. `test_firestoreCollections_cryRecords_equalsString`
- [ ] 모든 테스트는 `@MainActor` 필요 시 `@MainActor func test...` 어노테이트
- [ ] 기존 38개 테스트 수정 금지 (append only)
- [ ] `import BabyCare` (or `@testable import BabyCare`) 확인

**Must NOT do**:
- 기존 테스트 수정/삭제 금지
- 신규 테스트 파일 생성 금지 (`BabyCareTests.swift` 단일 파일 append)
- Mock Firestore/실제 Firestore 호출 금지 (인터페이스 shape만 검증)
- 테스트 내에서 실제 마이크/AVAudioEngine 사용 금지
- Git commands 실행 금지

**References**:
- `BabyCareTests/BabyCareTests.swift` - 기존 38 tests 패턴

**Acceptance Criteria**:

*Functional:*
- [ ] 신규 테스트 8개 추가됨
- [ ] 기존 테스트 미수정 (`git diff BabyCareTests/BabyCareTests.swift` 에 삭제/수정 라인 없음)

*Static:*
- [ ] `make build` → exit 0

*Runtime:*
- [ ] `make test` → exit 0 (46+ tests PASS, 경고 0)

**Verify**:
```yaml
acceptance:
  - given: ["신규 테스트 append 후"]
    when: "make test"
    then: ["모든 테스트 PASS", "경고 0"]
commands:
  - run: "grep -c 'func test_cry' /Users/roque/BabyCare/BabyCareTests/BabyCareTests.swift"
    expect: "exit 0 (count >= 6)"
  - run: "cd /Users/roque/BabyCare && make test"
    expect: "exit 0"
risk: LOW
```

---

### [x] TODO Final: Verification

**Type**: verification

**Required Tools**: `make`, `xcodebuild`, `xcodegen`

**Inputs**:
- `project_yml` (file): `${todo-1.outputs.project_yml}`
- `privacy_info` (file): `${todo-1.outputs.privacy_info}`
- `privacy_html` (file): `${todo-1.outputs.privacy_html}`
- `cry_record` (file): `${todo-2.outputs.cry_record}`
- `cry_label` (file): `${todo-2.outputs.cry_label}`
- `feature_flags` (file): `${todo-2.outputs.feature_flags}`
- `constants_updated` (file): `${todo-2.outputs.constants_updated}`
- `cry_service` (file): `${todo-3.outputs.cry_service}`
- `cry_vm` (file): `${todo-4.outputs.cry_vm}`
- `cry_view` (file): `${todo-5.outputs.cry_view}`
- `health_view_updated` (file): `${todo-6.outputs.health_view_updated}`
- `tests_updated` (file): `${todo-7.outputs.tests_updated}`

**Outputs**: (none)

**Steps**:
- [ ] `make verify` 실행 (빌드 + 테스트 + 디자인 토큰)
- [ ] 경고 개수 0 확인
- [ ] A-1 ~ A-15 모든 항목 재검증
- [ ] `Activity.swift` 및 `AIGuardrailService.swift` 미변경 확인 (`git diff`)
- [ ] `FeatureFlags.cryAnalysisEnabled == false` 재확인 (production 기본)
- [ ] S-items 는 본 단계에서 실행하지 않음 (Post-work 로 분리, flag override 필요)

**Must NOT do**:
- Edit/Write 도구 사용 금지
- 새 기능 추가/에러 수정 금지 (report only)
- Git commands 실행 금지
- Bash 로 repo 파일 수정 금지 (`sed -i`, `echo >` 등)

**Acceptance Criteria**:

*Functional:*
- [ ] 모든 배포물(TODO 1~7 outputs) 존재
- [ ] `Activity.swift` unchanged
- [ ] `AIGuardrailService.swift` prohibitedRules 부분 unchanged
- [ ] `FeatureFlags.cryAnalysisEnabled` source value == `false`

*Static:*
- [ ] `xcodegen generate` → exit 0
- [ ] `plutil -lint BabyCare/PrivacyInfo.xcprivacy` → OK
- [ ] `make design-verify` → exit 0

*Runtime:*
- [ ] `make verify` → exit 0 (build + test + design-verify)
- [ ] 테스트 개수 ≥ 46 (기존 38 + 신규 8)
- [ ] Warning count == 0

**Verify**:
```yaml
commands:
  - run: "cd /Users/roque/BabyCare && make verify"
    expect: "exit 0"
  - run: "cd /Users/roque/BabyCare && git diff --quiet -- BabyCare/Models/Activity.swift"
    expect: "exit 0"
  - run: "cd /Users/roque/BabyCare && git diff BabyCare/Services/AIGuardrailService.swift | grep -c 'prohibitedRules' || true"
    expect: "exit 0 (count 0)"
  - run: "grep -q 'cryAnalysisEnabled: Bool = false' /Users/roque/BabyCare/BabyCare/Utils/FeatureFlags.swift"
    expect: "exit 0"
risk: LOW
```
