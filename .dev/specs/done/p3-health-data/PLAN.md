# P3: 의료/건강 데이터 강화 — 성장 백분위, 체온 추세 알림, 알레르기 추적

> BabyCare iOS 앱에 성장 백분위 차트(WHO/한국), 체온 추세 알림, 알레르기 추적 기능 추가
> Mode: standard/autopilot

## Assumptions

> Decisions made autonomously without explicit user confirmation.

| Decision Point | Assumed Choice | Rationale | Source |
|----------------|----------------|-----------|--------|
| 백분위 표시 방식 | 텍스트 뱃지("75th") + 선택적 확장 차트 | UX 리뷰: 180px에 5개 밴드 오버레이 불가 | ux-reviewer |
| 성장 기준 데이터 | 한국 NHIS LMS 기본 (0-35개월 = WHO 동일) | 한국 소아과 표준, data.go.kr 공개 | external-research + tradeoff DP-02 |
| 체온 알림 임계값 | 38.0°C (AAP 발열 기준) 24h 내 2회 | ReferenceTable.feverThreshold과 일치, false positive 최소화 | tradeoff DP-01 |
| LMS 데이터 형식 | Swift 하드코딩 테이블 (static enum) | JSON 파싱 실패 경로 불필요, 데이터 고정 | tradeoff-analyzer |
| 체온 추세 감지 | ActivityViewModel computed property | 별도 서비스 클래스 과잉, 5줄 filter+count로 충분 | tradeoff-analyzer |
| GrowthViewModel | 미생성 — PercentileCalculator static enum | GrowthView가 @State+직접호출로 완결, VM 추가 불필요 | tradeoff-analyzer + codex |
| 알레르기 UI 위치 | 건강 탭 내 새 카드 | 독립 탭 추가는 네비게이션 파괴 | ux-reviewer |
| 알레르기 Firestore 경로 | babies/{babyId}/allergies/{docId} | 기존 패턴 일관성, 가족 공유 호환 | codebase pattern |
| 프리미엄 게이트 | 없음 (모든 사용자 무료) | 구독 제거됨 (StoreKit Sandbox 리젝) | project-context |
| 미숙아 교정 연령 | P3 범위 외 (향후 스프린트) | gestationalWeeks 필드 추가는 Baby 모델 스키마 변경 수반 | scope-narrow |
| 알레르기 카테고리 | 한국 공통 알레르겐 10종 기본 제공 + 자유입력 | MVP 범위 적절 | gap-analyzer |

> **Note**: These assumptions were NOT confirmed by the user. If any assumption is incorrect, re-run with `--interactive` to get explicit confirmation.

## Verification Summary

### Agent-Verifiable (A-items)
| ID | Criterion | Method | Related TODO |
|----|-----------|--------|-------------|
| A-1 | XcodeGen 프로젝트 재생성 | `cd /Users/roque/BabyCare && xcodegen generate` exit 0 | TODO Final |
| A-2 | 전체 빌드 성공 | `xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet` | TODO Final |
| A-3 | PercentileCalculator 정확도 — 남아 3mo 6.0kg → ~50th | 신규 단위 테스트 `testPercentileCalculator` | TODO 1 |
| A-4 | PercentileCalculator 경계값 — ageMonths=0, =24 | 신규 단위 테스트 | TODO 1 |
| A-5 | PercentileCalculator 방어 — 음수/nil → nil | 신규 단위 테스트 | TODO 1 |
| A-6 | AllergyRecord Codable 왕복 직렬화 | 신규 단위 테스트 `testAllergyRecordCodable` | TODO 4 |
| A-7 | 기존 12개 단위 테스트 회귀 보호 | `xcodebuild test -only-testing:BabyCareTests` all pass | TODO Final |
| A-8 | Temperature trend false negative — 정상 범위 변동 시 미감지 | 신규 단위 테스트 | TODO 3 |

### Human-Required (H-items)
| ID | Criterion | Reason | Review Material |
|----|-----------|--------|----------------|
| H-1 | 성장 백분위 차트 시각적 품질 | 차트 오버레이 색상 대비, 뱃지 가독성 코드 assert 불가 | GrowthView 시뮬레이터 스크린샷 |
| H-2 | 체온 추세 알림 실디바이스 수신 | UNUserNotificationCenter background delivery 시뮬레이터 제한 | 실 iPhone TestFlight |
| H-3 | 알레르기 추적 UX 흐름 | 심각도 선택 UI, 알레르겐 목록 적합성 도메인 판단 | 알레르기 UI 시뮬레이터 |
| H-4 | LMS 데이터 정확도 최종 검토 | 하드코딩된 L/M/S 값이 WHO 2006 원본과 일치하는지 | PercentileCalculator.swift |
| H-5 | Firestore CRUD 실서버 검증 | Tier 2 인프라 없음 — allergies 컬렉션 rules 통과 확인 | 실기기 TestFlight |
| H-6 | firestore.rules 알레르기 컬렉션 접근 | 기존 와일드카드 규칙 커버 여부 실서버 확인 | Firebase Console |

### Sandbox Agent Testing (S-items)
없음 — iOS native app, sandbox 인프라 없음.

### Verification Gaps
- Tier 2 부재: Firestore 에뮬레이터 미구성 — AllergyService/GrowthService 통합 테스트 불가. 대안: Mock 프로토콜 주입으로 Unit Test 커버
- Tier 4 부재: BDD/sandbox 인프라 없음 — 사용자 시나리오는 H-items로만 처리

## External Dependencies Strategy

### Pre-work (user prepares before AI work)
| Dependency | Action | Command/Step | Blocking? |
|------------|--------|-------------|-----------|
| (none) | — | — | — |

### During (AI work strategy)
| Dependency | Dev Strategy | Rationale |
|------------|-------------|-----------|
| Firebase Firestore | 실서버 호출 없이 모델/서비스 구현, Mock 불필요 (CRUD 패턴 복제) | 기존 FirestoreService+Growth.swift 패턴 그대로 |
| WHO LMS Data | Swift static 테이블로 하드코딩 (CDC FTP CSV 기준값 사용) | 외부 네트워크 불필요, 오프라인 동작 |

### Post-work (user actions after completion)
| Task | Related Dependency | Action | Command/Step |
|------|--------------------|--------|-------------|
| Firestore Rules 확인 | Firebase | allergies 컬렉션 접근 가능 여부 실서버 확인 | Firebase Console → Rules 탭 |
| TestFlight 빌드 | Xcode | 실기기 테스트용 빌드 배포 | Archive → Upload → TestFlight |
| LMS 데이터 검증 | WHO 2006 | 하드코딩 값 vs 원본 CSV 대조 | 수동 스팟체크 |

## Context

### Original Request
P3 의료/건강 데이터 강화: 성장 백분위 차트(WHO+한국), 체온 추세 알림, 알레르기 추적

### Interview Summary
**Key Discussions** (autopilot — no interview, see Assumptions):
- 성장 기준: 한국 NHIS LMS 사용 (0-35개월은 WHO와 동일)
- 체온 임계값: 38.0°C AAP 발열 기준
- UI 접근: 텍스트 뱃지 백분위 + 확장 차트, 알레르기는 건강 탭 카드

**Research Findings**:
- WHO CSV (CDC FTP): L, M, S 컬럼 포함, 남아/여아 × 체중/신장/두위, 0-24개월
- 한국 NHIS LMS: data.go.kr 공개 (0-35개월 = WHO 동일)
- Z-score→백분위: `import Darwin` + `erf()` (외부 의존성 불필요)
- 권장 밴드: 3rd, 15th, 50th, 85th, 97th (WHO/AAP 표준)
- 면책 문구 필수: "참고용이며 의학적 진단을 대체하지 않습니다"

## Work Objectives

### Core Objective
부모가 아이의 성장 상태를 WHO/한국 표준 대비 백분위로 한눈에 확인하고, 발열 추세를 자동 감지받으며, 알레르기 반응 이력을 체계적으로 관리할 수 있게 한다.

### Concrete Deliverables
- `PercentileCalculator.swift` — WHO LMS 데이터 + Z-score→백분위 계산 (static enum)
- GrowthView 확장 — 백분위 텍스트 뱃지 + 확장 차트 (3/15/50/85/97th 참조선)
- `ActivityViewModel` 체온 추세 감지 — `isFeverTrendDetected` computed property
- `NotificationService` 체온 추세 알림 — scheduleTemperatureTrendAlert()
- `NotificationSettingsView` 체온 추세 섹션 추가
- `AllergyRecord.swift` — 모델 (Identifiable, Codable, Hashable)
- `FirestoreService+Allergy.swift` — CRUD
- `AllergyListView.swift` + `AddAllergyView.swift` — 알레르기 UI
- HealthView에 알레르기 카드 추가
- `FirestoreCollections.allergies` 상수 추가
- 면책 문구 표시 (성장 백분위 차트)

### Definition of Done
- [ ] 성장 기록 조회 시 각 측정값 옆에 백분위 텍스트 뱃지 표시 (남아/여아 구분)
- [ ] 확장 차트에 WHO 3/15/50/85/97th 참조선 표시
- [ ] 24시간 내 38.0°C 이상 2회 이상 기록 시 추세 알림 트리거
- [ ] 알림 설정에서 체온 추세 알림 활성화/비활성화 가능
- [ ] 알레르기 반응 CRUD (추가/조회/삭제)
- [ ] 건강 탭에 알레르기 카드 표시
- [ ] 면책 문구 "참고용이며 의학적 진단을 대체하지 않습니다" 표시
- [ ] 빌드 성공 + 기존 테스트 통과

### Must NOT Do (Guardrails)
- AIGuardrailService.prohibitedRules 수정 금지
- Baby.gender를 Optional로 변경 금지 (Firestore Codable 호환성)
- 백분위 결과를 "정상"/"비정상"/"주의 필요" 등 의학적 판단 텍스트로 표시 금지
- 체온 알림에 "발열이 의심됩니다" 같은 진단성 문구 금지
- FirestoreService+Growth.swift 기존 메서드 시그니처 변경 금지
- WHO/한국 LMS 값 추정 또는 근사값 사용 금지 — 공식 출처 데이터만 사용
- 외부 차트 라이브러리 도입 금지 (Apple Charts만)
- 새 패키지/의존성 추가 금지
- git 명령 실행 금지 (Orchestrator가 처리)

---

## Task Flow

```
TODO-1 ──→ TODO-2
TODO-3 (independent)
TODO-4 ──→ TODO-5
All ──→ TODO-Final
```

## Dependency Graph

| TODO | Requires (Inputs) | Produces (Outputs) | Type |
|------|-------------------|-------------------|------|
| 1 | - | `calculator_path` (file) | work |
| 2 | `todo-1.calculator_path` | `growth_view_updated` (string) | work |
| 3 | - | `trend_detection_path` (string) | work |
| 4 | - | `allergy_model_path` (file), `allergy_service_path` (file) | work |
| 5 | `todo-4.allergy_model_path`, `todo-4.allergy_service_path` | `allergy_views` (list) | work |
| Final | all outputs | - | verification |

## Parallelization

| Group | TODOs | Reason |
|-------|-------|--------|
| A | 1, 3, 4 | 독립적 — 서로 다른 모듈/파일 |
| B | 2, 5 | 각각 1, 4에 의존 |

## Commit Strategy

| After TODO | Message | Files | Condition |
|------------|---------|-------|-----------|
| 1 | `feat(growth): add PercentileCalculator with WHO LMS data` | `Services/PercentileCalculator.swift`, `Tests/*` | always |
| 2 | `feat(growth): add percentile display to GrowthView` | `Views/Growth/*` | always |
| 3 | `feat(health): add temperature trend detection and alert` | `ViewModels/ActivityViewModel*.swift`, `Services/NotificationService.swift`, `Views/Settings/NotificationSettingsView.swift`, `Services/NotificationSettings.swift` | always |
| 4 | `feat(allergy): add AllergyRecord model and Firestore service` | `Models/AllergyRecord.swift`, `Services/FirestoreService+Allergy.swift`, `Utils/Constants.swift`, `Tests/*` | always |
| 5 | `feat(allergy): add allergy tracking UI` | `Views/Health/Allergy*.swift`, `Views/Health/HealthView.swift` | always |

## Error Handling

### Failure Categories

| Category | Examples | Detection Pattern |
|----------|----------|-------------------|
| `env_error` | Xcode build tool missing, simulator unavailable | `xcodebuild` exit ≠ 0 with env message |
| `code_error` | Swift compile error, type mismatch, test failure | `error:`, `failed`, test exit ≠ 0 |
| `scope_internal` | Missing prerequisite, Firestore schema mismatch | Verify Worker `suggested_adaptation` |
| `unknown` | Unclassifiable | Default |

### Failure Handling Flow

| Scenario | Action |
|----------|--------|
| work fails | Retry up to 2 times → Analyze |
| verification fails | Analyze immediately (no retry) |
| Worker times out | Halt and report |
| Missing Input | Skip dependent TODOs, halt |

### After Analyze

| Category | Action |
|----------|--------|
| `env_error` | Halt + log to `issues.md` |
| `code_error` | Create Fix Task (depth=1 limit) |
| `scope_internal` | Adapt → Dynamic TODO (depth=1) |
| `unknown` | Halt + log to `issues.md` |

## Runtime Contract

| Aspect | Specification |
|--------|---------------|
| Working Directory | `/Users/roque/BabyCare` |
| Network Access | Denied (all data bundled) |
| Package Install | Denied |
| File Access | Repository only |
| Max Execution Time | 10 minutes per TODO |
| Git Operations | Denied (Orchestrator handles) |

---

## TODOs

### [x] TODO 1: WHO LMS 데이터 + PercentileCalculator 구현

**Type**: work

**Required Tools**: (none)

**Inputs**: (none — first task)

**Outputs**:
- `calculator_path` (file): `BabyCare/Services/PercentileCalculator.swift` — 백분위 계산 static enum

**Steps**:
- [ ] `BabyCare/Services/PercentileCalculator.swift` 생성 — static enum
- [ ] WHO 2006 LMS 테이블 하드코딩 (0-24개월, 남아/여아, 체중/신장/두위 — CDC FTP CSV 기준)
- [ ] `lmsZScore(value:L:M:S:)` 함수 구현 (L=0 특수 케이스 포함)
- [ ] `zScoreToPercentile(_:)` 함수 구현 (`import Darwin` + `erf()`)
- [ ] `percentile(value:ageMonths:gender:metric:)` 공개 API 구현
- [ ] 극단값 클램핑: Z-score ±6 범위 제한
- [ ] `GrowthMetric` enum 정의: weight, height, headCircumference
- [ ] 단위 테스트 3개 추가: 정확도(남아 3mo 6.0kg → ~50th), 경계값(0mo, 24mo), 방어(음수 → nil)

**Must NOT do**:
- WHO/한국 LMS 값 추정 또는 근사값 사용 금지 — 공식 출처만
- JSON 파일 번들링 금지 — Swift static 테이블 사용
- 외부 패키지 추가 금지
- GrowthView 수정 금지 (TODO 2에서 처리)
- Do not run git commands

**References**:
- `BabyCare/Services/Analysis/ReferenceTable.swift:70-72` — 기존 lmsZScore 함수 (참고용)
- `BabyCare/Models/GrowthRecord.swift:1-32` — GrowthRecord 모델 (height?, weight?, headCircumference?)
- `BabyCare/Models/Baby.swift` — Baby.Gender enum (male/female)
- WHO Z-score 공식: Z = [(X/M)^L - 1] / (L × S), L=0이면 Z = ln(X/M) / S
- 백분위 변환: percentile = 0.5 × (1 + erf(z / √2)) × 100

**Acceptance Criteria**:

*Functional:*
- [ ] 파일 존재: `BabyCare/Services/PercentileCalculator.swift`
- [ ] `PercentileCalculator.percentile(value: 6.0, ageMonths: 3, gender: .male, metric: .weight)` → 45~55 범위
- [ ] `PercentileCalculator.percentile(value: -1.0, ...)` → nil 반환
- [ ] L=0 케이스 정상 처리 (ln 사용)

*Static:*
- [ ] `xcodebuild build` 성공 (새 파일 포함)

*Runtime:*
- [ ] 신규 단위 테스트 3개 통과

**Verify**:
```yaml
acceptance:
  - given: ["PercentileCalculator.swift 존재"]
    when: "남아 3개월 체중 6.0kg 입력"
    then: ["백분위 45~55 반환"]
  - given: ["음수 입력"]
    when: "value=-1.0 입력"
    then: ["nil 반환"]
commands:
  - run: "cd /Users/roque/BabyCare && xcodegen generate && xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet"
    expect: "exit 0"
  - run: "cd /Users/roque/BabyCare && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BabyCareTests -quiet 2>&1 | tail -5"
    expect: "exit 0"
risk: LOW
```

---

### [x] TODO 2: GrowthView 백분위 표시 (텍스트 뱃지 + 확장 차트)

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `calculator_path` (file): `${todo-1.outputs.calculator_path}` — PercentileCalculator

**Outputs**:
- `growth_view_updated` (string): "GrowthView percentile display added"

**Steps**:
- [ ] GrowthView `chartSection()` 수정: 차트 타이틀 옆에 최신 기록의 백분위 텍스트 뱃지 표시 (예: "몸무게 (kg) · 75th")
- [ ] 백분위 뱃지 스타일: `.font(.caption)`, `.padding(.horizontal, 8)`, `.background(Capsule().fill(.blue.opacity(0.1)))`, `.foregroundStyle(.blue)`
- [ ] "백분위 차트 보기" 확장 버튼 추가 → 탭 시 280px 높이 확장 차트 표시
- [ ] 확장 차트: WHO 3/15/50/85/97th 참조선 (`RuleMark` + dashed line)
- [ ] 아이 데이터 포인트는 기존 `LineMark` + `PointMark` 패턴 유지
- [ ] 참조선 색상: `.secondary.opacity(0.3)`, 50th만 `.secondary.opacity(0.5)`
- [ ] 성별에 따라 남아/여아 LMS 테이블 자동 분기 (`baby.gender`)
- [ ] 면책 문구 추가: 차트 하단 `.font(.caption2)`, `.foregroundStyle(.secondary)`
- [ ] 기록 목록의 각 행에도 백분위 표시 (체중/키/두위 각각)

**Must NOT do**:
- 180px 차트에 백분위 밴드(AreaMark) 오버레이 금지 — 텍스트 뱃지 + 확장 차트만
- 백분위를 "정상"/"비정상" 텍스트로 변환 금지
- FirestoreService+Growth.swift 기존 메서드 시그니처 변경 금지
- GrowthRecord 모델 변경 금지
- Do not run git commands

**References**:
- `BabyCare/Views/Growth/GrowthView.swift:157-183` — chartSection() 패턴
- `BabyCare/Views/Stats/PatternReport+Health.swift:41-43` — RuleMark 참조선 패턴
- `BabyCare/Utils/Constants.swift:3-42` — AppColors
- `BabyCare/Services/PercentileCalculator.swift` — TODO 1에서 생성

**Acceptance Criteria**:

*Functional:*
- [ ] 성장 차트 타이틀 옆에 백분위 뱃지 표시됨
- [ ] "백분위 차트 보기" 버튼 탭 시 확장 차트 표시
- [ ] 확장 차트에 5개 참조선(3/15/50/85/97th) 렌더링
- [ ] 면책 문구 차트 하단에 표시
- [ ] 기록 목록 각 행에 백분위 표시

*Static:*
- [ ] `xcodebuild build` 성공

*Runtime:*
- [ ] 기존 단위 테스트 통과 (회귀 없음)

**Verify**:
```yaml
acceptance:
  - given: ["GrowthView에 성장 기록 있음"]
    when: "성장기록 화면 진입"
    then: ["차트 타이틀 옆 백분위 뱃지 표시", "면책 문구 표시"]
  - given: ["확장 차트 버튼 탭"]
    when: "백분위 차트 보기 탭"
    then: ["280px 차트에 5개 참조선 표시"]
commands:
  - run: "cd /Users/roque/BabyCare && xcodegen generate && xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet"
    expect: "exit 0"
risk: MEDIUM
```

---

### [x] TODO 3: 체온 추세 감지 + 알림

**Type**: work

**Required Tools**: (none)

**Inputs**: (none — independent)

**Outputs**:
- `trend_detection_path` (string): "Temperature trend detection added to ActivityViewModel + NotificationService + NotificationSettingsView"

**Steps**:
- [ ] `ActivityViewModel`에 `isFeverTrendDetected: Bool` computed property 추가 — 24시간 내 38.0°C 이상 체온 기록 2회 이상
- [ ] `ActivityViewModel`에 `recentHighTemperatureCount: Int` computed property 추가
- [ ] `NotificationService`에 `scheduleTemperatureTrendAlert(babyName:)` 메서드 추가
- [ ] Activity 저장 시점(`performSaveActivity`)에서 체온 타입일 때 추세 체크 → 감지 시 알림 스케줄
- [ ] `NotificationSettings`에 `temperatureTrendEnabled: Bool` 키 추가 (기본값: true)
- [ ] `NotificationSettingsView`에 "체온 추세" 섹션 추가 — Toggle 1개 (기존 접종 섹션 패턴 복제)
- [ ] 알림 본문: "체온 확인이 필요해요. 최근 24시간 내 발열이 2회 이상 기록되었습니다." (진단 문구 아님)
- [ ] 단위 테스트 추가: 정상 범위 → false, 38.0°C 2회 → true, 데이터 5개 미만 → false

**Must NOT do**:
- 체온 알림에 "발열이 의심됩니다" 같은 진단성 문구 금지
- BaselineDetector EWMA/CUSUM 사용 금지 (단순 threshold로 충분)
- 별도 서비스 클래스 생성 금지 (ActivityViewModel + NotificationService 확장)
- AIGuardrailService 수정 금지
- Do not run git commands

**References**:
- `BabyCare/ViewModels/ActivityViewModel.swift:299-319` — 기존 temperatureWarning 패턴
- `BabyCare/ViewModels/ActivityViewModel+Save.swift` — performSaveActivity 저장 시점
- `BabyCare/Services/NotificationService.swift:1-210` — 알림 스케줄 패턴
- `BabyCare/Views/Settings/NotificationSettingsView.swift:84-121` — 접종 섹션 패턴
- `BabyCare/Utils/Constants.swift` — ReferenceTable.feverThreshold = 38.0
- `BabyCare/Services/Analysis/ReferenceTable.swift:64` — normalTemperature, feverThreshold

**Acceptance Criteria**:

*Functional:*
- [ ] 38.0°C 이상 2회 기록 시 `isFeverTrendDetected == true`
- [ ] 정상 체온만 기록 시 `isFeverTrendDetected == false`
- [ ] NotificationSettingsView에 "체온 추세" 섹션 표시
- [ ] 알림 본문에 진단성 문구 미포함

*Static:*
- [ ] `xcodebuild build` 성공

*Runtime:*
- [ ] 신규 단위 테스트 통과
- [ ] 기존 단위 테스트 회귀 없음

**Verify**:
```yaml
acceptance:
  - given: ["24시간 내 38.0°C 기록 2회"]
    when: "isFeverTrendDetected 접근"
    then: ["true 반환"]
  - given: ["정상 체온만"]
    when: "isFeverTrendDetected 접근"
    then: ["false 반환"]
commands:
  - run: "cd /Users/roque/BabyCare && xcodegen generate && xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet"
    expect: "exit 0"
  - run: "cd /Users/roque/BabyCare && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BabyCareTests -quiet 2>&1 | tail -5"
    expect: "exit 0"
risk: MEDIUM
```

---

### [x] TODO 4: AllergyRecord 모델 + Firestore 서비스

**Type**: work

**Required Tools**: (none)

**Inputs**: (none — independent)

**Outputs**:
- `allergy_model_path` (file): `BabyCare/Models/AllergyRecord.swift`
- `allergy_service_path` (file): `BabyCare/Services/FirestoreService+Allergy.swift`

**Steps**:
- [ ] `BabyCare/Models/AllergyRecord.swift` 생성 — `Identifiable, Codable, Hashable`
  - 필드: id, babyId, allergenName (String), reactionType (AllergyReactionType enum), severity (AllergySeverity enum), date, symptoms ([String]), note?, createdAt
  - `AllergyReactionType`: skin(피부), digestive(소화기), respiratory(호흡기), other(기타)
  - `AllergySeverity`: mild(경증), moderate(중등), severe(중증)
  - `CommonAllergen` enum: dairy(우유), egg(계란), peanut(땅콩), wheat(밀), soy(대두), shrimp(새우), crab(게), peach(복숭아), walnut(호두), other(기타) — 한국 공통 알레르겐 10종
- [ ] `BabyCare/Services/FirestoreService+Allergy.swift` 생성 — CRUD
  - `saveAllergyRecord(_:userId:babyId:)` / `fetchAllergyRecords(userId:babyId:)` / `deleteAllergyRecord(_:userId:babyId:)`
  - Firestore 경로: `users/{userId}/babies/{babyId}/allergies/{recordId}`
- [ ] `FirestoreCollections`에 `static let allergies = "allergies"` 추가
- [ ] 단위 테스트: AllergyRecord Codable 왕복 직렬화

**Must NOT do**:
- 교차 반응 그래프, 가족력 트리, RAST 점수 등 EHR 수준 설계 금지
- firestore.rules 직접 수정 금지 (post-work에서 확인)
- Baby 모델 변경 금지
- Do not run git commands

**References**:
- `BabyCare/Models/GrowthRecord.swift:1-32` — 모델 패턴 (Identifiable, Codable, Hashable)
- `BabyCare/Services/FirestoreService+Growth.swift:1-47` — Firestore CRUD 패턴
- `BabyCare/Utils/Constants.swift:65-83` — FirestoreCollections enum
- `BabyCare/Models/Activity.swift:18-27` — foodReaction, hasRash 필드 (참고)

**Acceptance Criteria**:

*Functional:*
- [ ] 파일 존재: `BabyCare/Models/AllergyRecord.swift`
- [ ] 파일 존재: `BabyCare/Services/FirestoreService+Allergy.swift`
- [ ] AllergyRecord가 Identifiable, Codable, Hashable 프로토콜 채택
- [ ] CommonAllergen enum 10종 정의
- [ ] FirestoreCollections.allergies 상수 존재
- [ ] CRUD 3개 메서드 구현 (save/fetch/delete)

*Static:*
- [ ] `xcodebuild build` 성공

*Runtime:*
- [ ] Codable 왕복 직렬화 단위 테스트 통과

**Verify**:
```yaml
acceptance:
  - given: ["AllergyRecord 인스턴스 생성"]
    when: "JSON encode → decode"
    then: ["원본과 동일"]
commands:
  - run: "cd /Users/roque/BabyCare && xcodegen generate && xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet"
    expect: "exit 0"
  - run: "cd /Users/roque/BabyCare && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BabyCareTests -quiet 2>&1 | tail -5"
    expect: "exit 0"
risk: MEDIUM
```

---

### [x] TODO 5: 알레르기 추적 UI

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `allergy_model_path` (file): `${todo-4.outputs.allergy_model_path}` — AllergyRecord 모델
- `allergy_service_path` (file): `${todo-4.outputs.allergy_service_path}` — Firestore 서비스

**Outputs**:
- `allergy_views` (list): `["BabyCare/Views/Health/AllergyListView.swift", "BabyCare/Views/Health/AddAllergyView.swift"]`

**Steps**:
- [ ] `BabyCare/Views/Health/AllergyListView.swift` 생성
  - NavigationStack + List: 알레르기 기록 목록 (알레르겐명, 날짜, 심각도 뱃지)
  - 심각도 뱃지: mild(초록), moderate(주황), severe(빨강)
  - swipeActions: 삭제
  - EmptyStateView 패턴 사용 (용품 관리와 동일)
  - toolbar "+" 버튼 → AddAllergyView sheet
- [ ] `BabyCare/Views/Health/AddAllergyView.swift` 생성
  - CommonAllergen 칩 선택 (ScrollView horizontal) + 자유입력 TextField
  - 반응유형 Picker (피부/소화기/호흡기/기타)
  - 심각도 세그먼트 (경증/중등/중증)
  - 증상 체크리스트: ["발진", "두드러기", "구토", "설사", "호흡곤란", "부종", "기타"]
  - 날짜 DatePicker + 메모 TextField
  - 저장 시 Firestore에 기록
- [ ] `HealthView`에 알레르기 카드 추가 — 기존 HealthSectionCard 패턴
  - 아이콘: `"leaf.circle.fill"` (SF Symbol), 색상: `AppColors.coralColor`
  - 제목: "알레르기 기록"
  - NavigationLink → AllergyListView
- [ ] AllergyListView에 면책 문구 추가 (선택사항)

**Must NOT do**:
- 새 TabBar 항목 추가 금지
- 이유식가이드(BabyFoodGuideView) 수정 금지 (별도 화면)
- HealthView 기존 카드 순서 변경 금지 (마지막에 추가)
- Do not run git commands

**References**:
- `BabyCare/Views/Products/ProductListView.swift:1-196` — EmptyStateView, 리스트, swipeActions 패턴
- `BabyCare/Views/Health/VaccinationListView.swift:14-84` — HealthSectionCard, Section 패턴
- `BabyCare/Views/Recording/SolidFoodSection.swift:94-135` — 알레르기 반응 버튼 + 경고 배너
- `BabyCare/Views/Health/HealthView.swift` — 기존 8개 카드 목록
- `BabyCare/Views/Products/AddProductView.swift` — 카탈로그 칩 선택 UI 패턴

**Acceptance Criteria**:

*Functional:*
- [ ] 파일 존재: `BabyCare/Views/Health/AllergyListView.swift`
- [ ] 파일 존재: `BabyCare/Views/Health/AddAllergyView.swift`
- [ ] HealthView에 "알레르기 기록" 카드 존재
- [ ] 알레르겐 칩 10종 + 자유입력 가능
- [ ] 심각도 뱃지 색상 구분 (mild/moderate/severe)
- [ ] swipeActions 삭제 동작

*Static:*
- [ ] `xcodebuild build` 성공

*Runtime:*
- [ ] 기존 단위 테스트 회귀 없음

**Verify**:
```yaml
acceptance:
  - given: ["건강 탭 진입"]
    when: "카드 목록 확인"
    then: ["'알레르기 기록' 카드 존재"]
  - given: ["알레르기 추가 화면"]
    when: "CommonAllergen 칩 표시"
    then: ["10종 알레르겐 칩 표시 + 자유입력"]
commands:
  - run: "cd /Users/roque/BabyCare && xcodegen generate && xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet"
    expect: "exit 0"
risk: MEDIUM
```

---

### [x] TODO Final: Verification

**Type**: verification

**Required Tools**: `xcodegen`, `xcodebuild`

**Inputs**:
- `calculator_path` (file): `${todo-1.outputs.calculator_path}`
- `growth_view_updated` (string): `${todo-2.outputs.growth_view_updated}`
- `trend_detection_path` (string): `${todo-3.outputs.trend_detection_path}`
- `allergy_model_path` (file): `${todo-4.outputs.allergy_model_path}`
- `allergy_service_path` (file): `${todo-4.outputs.allergy_service_path}`
- `allergy_views` (list): `${todo-5.outputs.allergy_views}`

**Outputs**: (none)

**Steps**:
- [ ] XcodeGen 프로젝트 재생성
- [ ] 전체 빌드 검증
- [ ] 전체 단위 테스트 실행 (기존 + 신규)
- [ ] PercentileCalculator 파일 존재 및 public API 확인
- [ ] AllergyRecord 파일 존재 및 프로토콜 채택 확인
- [ ] GrowthView에 백분위 뱃지 코드 존재 확인
- [ ] NotificationSettingsView에 체온 추세 섹션 존재 확인
- [ ] HealthView에 알레르기 카드 존재 확인
- [ ] 면책 문구 존재 확인
- [ ] FirestoreCollections.allergies 상수 존재 확인
- [ ] Must NOT Do 위반 점검: AIGuardrailService 미수정, Baby.gender 미변경

**Must NOT do**:
- Do not use Edit or Write tools (source code modification forbidden)
- Do not add new features or fix errors (report only)
- Do not run git commands
- Bash is allowed for: running tests, builds, type checks
- Do not modify repo files via Bash (no `sed -i`, `echo >`, etc.)

**Acceptance Criteria**:

*Functional:*
- [ ] 모든 deliverable 파일 존재 (PercentileCalculator, AllergyRecord, FirestoreService+Allergy, AllergyListView, AddAllergyView)
- [ ] GrowthView에 백분위 텍스트 뱃지 코드 포함
- [ ] NotificationSettingsView에 "체온 추세" 섹션 코드 포함
- [ ] HealthView에 알레르기 카드 코드 포함
- [ ] 면책 문구 "참고용" 또는 "의학적 진단을 대체하지 않습니다" 포함
- [ ] FirestoreCollections.allergies 상수 존재
- [ ] AIGuardrailService 파일 미수정 (git diff 확인)

*Static:*
- [ ] `xcodegen generate` → exit 0
- [ ] `xcodebuild build -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet` → exit 0

*Runtime:*
- [ ] `xcodebuild test -only-testing:BabyCareTests -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet` → all pass

**Verify**:
```yaml
acceptance:
  - given: ["모든 TODO 완료"]
    when: "전체 빌드 + 테스트"
    then: ["빌드 성공", "모든 테스트 통과", "모든 deliverable 존재"]
commands:
  - run: "cd /Users/roque/BabyCare && xcodegen generate"
    expect: "exit 0"
  - run: "cd /Users/roque/BabyCare && xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet"
    expect: "exit 0"
  - run: "cd /Users/roque/BabyCare && xcodebuild test -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:BabyCareTests -quiet 2>&1 | tail -5"
    expect: "exit 0"
  - run: "grep -l 'allergies' /Users/roque/BabyCare/BabyCare/Utils/Constants.swift"
    expect: "exit 0"
  - run: "grep -l '의학적 진단' /Users/roque/BabyCare/BabyCare/Views/Growth/GrowthView.swift || grep -l '참고용' /Users/roque/BabyCare/BabyCare/Views/Growth/GrowthView.swift"
    expect: "exit 0"
  - run: "grep -c 'lmsData' /Users/roque/BabyCare/BabyCare/Services/PercentileCalculator.swift"
    expect: "exit 0 with count > 0"
risk: LOW
```
