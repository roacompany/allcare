# PLAN: Pregnancy Mode (임신 모드)

## Context

### Original Request
BabyCare iOS 앱에 출산 전 임산부를 위한 모드 추가. 현재 앱은 출산 후 육아 기록 중심. 임신 모드 활성화 시 주차별 정보, D-day 카운터, 산전 체크리스트, 태동 기록, 병원 방문 일정 등 제공. 기존 Baby 모델과의 관계(임신 중 → 출산 후 전환 플로우) 설계 필요. CLAUDE.md 로드맵 P0 최우선 항목.

### Interview Summary — Key Discussions
| Question | Decision | Rationale |
|---|---|---|
| 데이터 모델 | 하이브리드 | Pregnancy 모델·컬렉션 분리. 출산 시 name/gestationalWeeks/gender prefill로 Baby 생성, Pregnancy.outcomeType=born + archivedAt 기록. Baby.gender required와의 충돌 회피 + 일부 필드 승계로 UX 부드러움 |
| 온보딩 진입점 | 서브링크 | AddBabyView 유지 + "아직 태어나지 않았나요?" 링크. 기존 사용자 zero regression |
| 스코프 | Full | D-day, 주차별 정보, 산전 체크리스트, 태동 기록, 산전 방문, 체중 기록, D-day 위젯, HealthKit 연동, 파트너 공유, 이전 임신 이력 UI |
| outcomeType | 전체 enum | `ongoing\|born\|miscarriage\|stillbirth\|terminated` — archivedAt만으론 구분 불가. v1 UI는 ongoing→born만 완성, 나머지는 모델/데이터 준비 |
| 배포 전략 | FeatureFlag 게이팅 | `FeatureFlags.pregnancyModeEnabled` TestFlight 베타 → App Store flip |
| HIGH risk 3건 | 모두 수용 | DP-01 append 선배포 / DP-02 WriteBatch+transitionState / DP-03 PregnancyWidgetDataStore 별도 구조체 |
| 다중 임신 | fetusCount Int? | default=1, 주차 JSON은 단태아 기준 + 면책 강화 |
| EDD 이력 | eddHistory 배열 | 덮어쓰기 금지, append-only |

### Research Findings
- **Baby 모델** (`BabyCare/Models/Baby.swift:1-87`): Identifiable/Codable/Hashable, `ownerUserId` runtime-only (CodingKeys 제외)
- **BabyViewModel** (`BabyCare/ViewModels/BabyViewModel.swift`): `dataUserId(currentUserId:)` 공유 아기 경로 라우팅
- **FirestoreCollections** (`BabyCare/Utils/Constants.swift:65-90`): 23개 상수, 서브컬렉션 패턴 `users/{uid}/babies/{bid}/{sub}/{id}`
- **예방접종 D-day 패턴** (`BabyCare/Models/Vaccination.swift:1-156`): `daysUntilScheduled`, `isDueSoon(14일)`, D-14/7/1 단계별 푸시
- **TodoItem 체크리스트** (`BabyCare/Models/TodoItem.swift:1-94`): category/isCompleted/isRecurring
- **ActivityTimerManager** — 세션 타이머 재사용 가능
- **Preprocessor.correctedAgeInDays** (`BabyCare/Services/Analysis/Preprocessor.swift:45`): `gestationalWeeks` 인자 이미 존재
- **FeatureFlags** (`BabyCare/Utils/FeatureFlags.swift:1-5`): `enum FeatureFlags { static let cryAnalysisEnabled: Bool = true }`
- **AIGuardrailService.disclaimer** (`BabyCare/Services/AIGuardrailService.swift:11`): 재사용 문구
- **Widget pattern** (`BabyCareWidget/`): HomeScreen 4종 + Lock Screen 3종 (accessoryCircular/Rectangular/Inline), App Groups `group.com.roacompany.allcare`
- **ACOG Count the Kicks**: 28주+, 2시간 내 10회, 패턴 변화 경보 필요
- **iOS HealthKit**: `.pregnancy`(iOS 14.3+), `.pregnancyTestResult`(iOS 15.0+), NSHealthShareUsageDescription 필수, 광고 활용 금지 (Review 5.1.1)
- **주차 계산 표준** (ACOG): LMP + 280일 기본, <9주 초음파 5일差 / 9~13+6주 7일差 / 14주+ LMP 유지. 40% 여성이 1분기 초음파로 EDD 수정

### Assumptions
- **Firebase Firestore Emulator 없음** → Tier 2 통합 테스트는 mock 기반 XCTest로 대체, 실검증은 TestFlight QA
- **XCUITest E2E**: ScreenshotTests만 존재, 기능 E2E는 없음 → S-items는 `make screenshots` + 3-Agent QA로 대체
- **주차별 콘텐츠 JSON 40주치**: 이 스펙 실행 범위에서 schema 제작 + 최소 1주차 샘플 데이터 생성. 완전한 40주 콘텐츠는 post-work로 의료 리뷰어가 채움
- **산전 체크리스트 기본 템플릿**: ACOG + 대한산부인과학회 가이드 기반 10-15개 항목, 면책 배너 필수
- **ATT/Privacy Policy 갱신**: 이 스펙 범위 밖 (post-work로 분리). 다만 코드에서 Analytics payload에 임신 데이터 포함 금지 원칙 엄수

---

## Work Objectives

### Concrete Deliverables
1. `Pregnancy`, `KickSession`, `PrenatalVisit`, `PregnancyChecklistItem`, `PregnancyWeightEntry` 모델 (Codable, optional 필드)
2. `PregnancyOutcome` enum (`ongoing|born|miscarriage|stillbirth|terminated`)
3. `FirestoreCollections` 확장 + `firestore.rules` 배포 (append)
4. `FirestoreService+Pregnancy` 확장 (CRUD + WriteBatch 전환)
5. `PregnancyViewModel` @Observable + AppState 주입 + lazy init 가드
6. `BabyCare/Resources/pregnancy-weeks.json` (schema + 샘플 1-3주치) + `prenatal-checklist.json` (10-15 항목)
7. 온보딩 서브링크 + `PregnancyRegistrationView`
8. 홈 탭 임신 모드 (`DashboardPregnancyView` — D-day 카드, 주차 카드, 오늘의 팁, 체크리스트 프리뷰)
9. 건강 탭 임신 모드 (`HealthPregnancyView` — 태동 세션, 산전 방문, 체중 차트)
10. `+` 버튼 시트 임신 모드 분기 (태동/방문/체중/증상 기록)
11. 산전 체크리스트 전용 화면 (`PregnancyChecklistView`)
12. 출산 전환 플로우 (`PregnancyTransitionSheet`, WriteBatch + transitionState)
13. `FeatureFlags.pregnancyModeEnabled` + `DisclaimerBanner` 재사용 + Localizable 키
14. `PregnancyDDayWidget` (HomeScreen + Lock Screen accessoryCircular) + `PregnancyWidgetDataStore`
15. HealthKit 연동 (`HealthKitPregnancyService`, NSHealthShareUsageDescription)
16. 파트너 공유 (Pregnancy.ownerUserId + PregnancyViewModel.dataUserId() 유사 패턴)
17. 이전 임신 이력 UI (설정 탭 "이전 임신" 메뉴 → `PregnancyArchiveView`)
18. 테스트 30개+ 추가 (195 → 225+)

### Definition of Done
- `make verify` 전체 통과 (build + lint + arch-test + test + design-verify)
- arch-test 0 violations 유지
- SwiftLint 신규 경고 0건
- XCTest 신규 30개+ PASS (모델 Codable, 주차 계산, 태동 세션, 전환 트랜잭션, 체크리스트 토글, D-day 계산)
- `firestore.rules`에 `pregnancies` + 하위 컬렉션 규칙 배포 완료
- FeatureFlag=false일 때 일반 사용자 UI에 임신 모드 흔적 0
- 3-Agent QA (Visual/UX + Code Quality + Mobile Responsive) ALL PASS
- H-items 8개 사용자 확인 완료 (TestFlight 실기기 포함)

### Must NOT Do
- ❌ `Baby.gender` Optional 변경 (safety rule)
- ❌ `Baby` 모델 기존 필드 의미 변경 (birthDate를 임신 예정일로 재사용 금지)
- ❌ `AIGuardrailService.prohibitedRules` 수정
- ❌ 임신 데이터를 Firebase Analytics/Crashlytics custom params에 포함 (민감 건강정보)
- ❌ 백분위/체중/태아 크기에 의학적 판단 텍스트("정상/주의/위험") 또는 빨강 강조
- ❌ 외부 차트 라이브러리 도입 (Apple Charts만)
- ❌ `authVM.currentUserId` 직접 사용 (Pregnancy도 `pregnancyVM.dataUserId()` 패턴)
- ❌ KickEvent 별도 서브컬렉션 생성 (KickSession 배열 임베딩 강제)
- ❌ 주차 계산에 Date 산술 직접 사용 (`Calendar.current.dateComponents` 강제)
- ❌ FeatureFlag 분기를 View body 중간에 산발적으로 삽입 (ViewModel/Router 한 곳에서 분기)
- ❌ EDD 덮어쓰기 (eddHistory append 강제)
- ❌ `outcomeType` 없이 임신 종료 처리 (archivedAt 단독 사용 금지)
- ❌ 출산 전환을 단일 쓰기로 (WriteBatch + transitionState 필수)
- ❌ Pregnancy 데이터를 기존 `WidgetDataStore`에 직접 병합 (`PregnancyWidgetDataStore` 분리)
- ❌ pregnancy-weeks.json에 특정 브랜드/의약품/시술 명시 (App Store 4.2)
- ❌ 위젯 타임라인 시간 단위 갱신 (일 단위로 충분)
- ❌ Firestore Rules 배포 전 클라이언트 코드 머지 (feedback_firestore_rules_first.md)
- ❌ 심사 중인 v2.6.2와 동시 배포 (v2.6.2 심사 완료 이후 진행)
- ❌ HealthKit 데이터를 광고 활용 (Review 5.1.1)
- ❌ 임신 종료/출산 CTA를 확인 없이 즉시 실행 (감정 민감, 명시적 확인 + 되돌리기 필수)

---

## Orchestrator Section

### Task Flow
```
TODO 1-3: Data Layer (Models + Collections + Rules)      [BLOCKER]
  ↓
TODO 4-5: Service + ViewModel
  ↓
TODO 6: Static Resources (JSON)
  ↓
TODO 7-11: UI Layer (Onboarding, Home, Health, +, Checklist) ← 병렬 가능
  ↓
TODO 12: Transition Flow (WriteBatch + transitionState)
  ↓
TODO 13: FeatureFlag + Disclaimer + Localizable
  ↓
TODO 14-17: Extensions (Widget, HealthKit, Partner Share, Archive UI) ← 병렬 가능
  ↓
TODO 18: Tests
  ↓
TODO Final: Verification
```

### Dependency Graph
```
[1 Models] → [2 Collections/Rules] → [3 FirestoreService+Pregnancy] → [4 PregnancyViewModel]
                                                                       ↓
                                                [6 JSON] ← [5 Onboarding+Registration]
                                                                       ↓
                                    ┌──────────────┬────────────┬──────┴──────┐
                                [7 Home] [8 Health] [9 + Sheet] [10 Checklist]
                                    └──────────────┴────────────┴─────────────┘
                                                                       ↓
                                                              [11 Transition]
                                                                       ↓
                                                      [12 Flag+Disclaimer+L10n]
                                                                       ↓
                                           ┌─────────┬─────────┬──────┴──────┐
                                     [13 Widget] [14 HealthKit] [15 Share] [16 Archive]
                                           └─────────┴─────────┴─────────────┘
                                                                       ↓
                                                              [17 Tests]
                                                                       ↓
                                                              [TODO Final]
```

### Parallelization
- **Parallel Group A** (UI surfaces): TODO 7, 8, 9, 10 — 동일 VM 소비만, 독립 파일
- **Parallel Group B** (extensions): TODO 13, 14, 15, 16

### Commit Strategy
- **Atomic commit per TODO** (orchestrator only)
- 메시지 프리픽스: `feat(pregnancy):` · `chore(pregnancy):` · `test(pregnancy):`
- TODO 2는 별도 `chore(firestore): add pregnancy rules` 선행 커밋 + **로컬 머지 전에 `firebase deploy --only firestore:rules` 실행**
- TODO 12 커밋 전 TODO 11까지 `make verify` PASS 필수
- TODO Final 커밋 전 3-Agent QA PASS 확인

### Error Handling
- `work` TODO 실패: 최대 2회 재시도 → Fix Task 생성
- `verification` TODO 실패: 재시도 없이 Fix Task
- Pre-work(Firestore Rules) 누락 감지 시 HALT + 사용자 개입
- HIGH risk TODO(2, 11, 13) 실패 시 즉시 롤백 + 원인 분석

### Runtime Contract
- Swift 6.0 strict concurrency
- `@MainActor @Observable` 모든 VM
- Firestore I/O는 `async/await`
- `PregnancyViewModel.dataUserId(currentUserId:)` 필수 사용

---

## TODOs

### TODO 1: Pregnancy Data Models
**Type**: work
**Required Tools**: Read, Edit, Write, Bash
**Risk**: LOW

**Inputs**: (none — foundation layer)

**Outputs**:
- `BabyCare/Models/Pregnancy.swift` — struct Pregnancy
- `BabyCare/Models/PregnancyOutcome.swift` — enum (String raw value, Codable)
- `BabyCare/Models/KickSession.swift` — struct with embedded `kicks: [KickEvent]`
- `BabyCare/Models/PrenatalVisit.swift`
- `BabyCare/Models/PregnancyChecklistItem.swift`
- `BabyCare/Models/PregnancyWeightEntry.swift`

**Steps**:
- [ ] `Pregnancy`: id, ownerUserId(runtime, CodingKeys 제외), lmpDate?, dueDate?, edd?, eddHistory: [Date]?, fetusCount: Int? (default 1), babyNickname: String?, ultrasoundGender: Gender?, transitionState: String? (pending|completed), outcome: PregnancyOutcome? (default ongoing), archivedAt: Date?, prePregnancyWeight: Double?, weightUnit: String? (kg|lb), createdAt: Date, updatedAt: Date
- [ ] `PregnancyOutcome`: String rawValue `ongoing|born|miscarriage|stillbirth|terminated` — raw value는 영구 계약 (주석 명시)
- [ ] `KickSession`: id, pregnancyId, startedAt: Date, endedAt: Date?, kicks: [KickEvent] (embedded), targetCount: Int? (default 10), createdAt
- [ ] `KickEvent`: id, timestamp: Date — Codable struct (서브컬렉션 아님)
- [ ] `PrenatalVisit`: id, pregnancyId, scheduledAt: Date, visitedAt: Date?, hospitalName: String?, notes: String?, isCompleted: Bool, reminderEnabled: Bool?
- [ ] `PregnancyChecklistItem`: id, pregnancyId, title: String, category: String (trimester1|trimester2|trimester3|postpartum_prep|custom), isCompleted: Bool, targetWeek: Int?, source: String (bundle|user)
- [ ] `PregnancyWeightEntry`: id, pregnancyId, weight: Double, unit: String, measuredAt: Date, notes: String?
- [ ] 모든 모델: Identifiable, Codable, Hashable. 신규 필드 optional 원칙
- [ ] CodingKeys에서 `ownerUserId` 제외 (Baby 패턴 준수)

**Must NOT do**:
- ❌ Baby 모델 수정
- ❌ KickEvent를 별도 Firestore 서브컬렉션으로 설계
- ❌ PregnancyOutcome rawValue를 나중에 변경 (영구 계약 주석 필수)
- ❌ git 커밋 (Orchestrator만)

**References**:
- `BabyCare/Models/Baby.swift:1-87` (Codable + ownerUserId 런타임 패턴)
- `BabyCare/Models/Vaccination.swift:1-156` (D-day 계산 프로퍼티 패턴)
- `BabyCare/Models/ActivityEnums.swift:84-94` (enum deprecated 패턴)

**Acceptance Criteria**:
- *Functional*: 각 모델 JSON encode/decode 라운드트립 성공
- *Static*: 타입체크 통과, SwiftLint 0 경고
- *Runtime*: `test_pregnancy_codable_roundtrip`, `test_kickSession_embeddedKicks`, `test_pregnancyOutcome_rawValues` PASS

**Verify**:
```yaml
acceptance:
  - given: ["Pregnancy 구조체에 dueDate=nil, eddHistory=[]"]
    when: "JSONEncoder/Decoder 라운드트립"
    then: ["모든 필드 복원", "CodingKeys에 ownerUserId 없음"]
  - given: ["PregnancyOutcome 모든 case"]
    when: "rawValue 확인"
    then: ["문자열 일치: ongoing|born|miscarriage|stillbirth|terminated"]
integration:
  - "Pregnancy.fetusCount nil이면 UI에서 1로 해석"
commands:
  - run: "make test"
    expect: "exit 0"
  - run: "make lint"
    expect: "exit 0"
risk: LOW
```

---

### TODO 2: FirestoreCollections + firestore.rules Deployment
**Type**: work
**Required Tools**: Edit, Bash
**Risk**: HIGH

**Inputs**: (independent — can run parallel with TODO 1)

**Outputs**:
- `BabyCare/Utils/Constants.swift` — 신규 상수 추가
- `firestore.rules` — 신규 규칙 append
- Firebase 프로덕션에 Rules 배포 완료

**Steps**:
- [ ] `FirestoreCollections` 확장: `pregnancies`, `prenatalVisits`, `pregnancyChecklists`, `pregnancyWeights`, `kickSessions` (총 5개 상수)
- [ ] `firestore.rules`: `match /users/{userId}/pregnancies/{pregnancyId}` + 하위 4개 서브컬렉션 규칙 추가. 읽기/쓰기는 `request.auth.uid == userId` 또는 파트너 공유 시 Pregnancy 문서 `sharedWith` 배열 포함 여부 체크
- [ ] `firestore.indexes.json` 필요시 index 추가 (`pregnancies` where `outcome=='ongoing'`)
- [ ] 기존 Rules 파일 diff 검토 (단순 append, 기존 규칙 수정 금지)
- [ ] `firebase deploy --only firestore:rules` 실행 → 배포 성공 확인
- [ ] `firebase firestore:rules:get` 으로 현재 배포본에 신규 규칙 포함 확인

**Must NOT do**:
- ❌ 기존 Rules 규칙 수정
- ❌ 클라이언트 코드 머지보다 Rules 배포 후행
- ❌ v2.6.2 심사 중 배포를 강행 (심사 완료 확인 후 진행)
- ❌ 하드코딩 컬렉션명 사용 (FirestoreCollections 상수 필수)
- ❌ git 커밋 (Orchestrator만)

**References**:
- `BabyCare/Utils/Constants.swift:65-90` — 기존 상수 23개 패턴
- `firestore.rules` — 기존 `babies/{bid}` 서브컬렉션 와일드카드 패턴
- `.claude/rules/firestore-rules.md` — 규칙 선배포 블로커
- MEMORY.md `feedback_firestore_rules_first.md`

**Acceptance Criteria**:
- *Functional*: `firebase firestore:rules:get` 결과에 pregnancies 규칙 포함
- *Static*: `firebase deploy --only firestore:rules` exit 0
- *Runtime*: `test_firestoreCollections_pregnancyConstants_exist` PASS

**Verify**:
```yaml
acceptance:
  - given: ["FirestoreCollections enum"]
    when: "pregnancies, prenatalVisits, pregnancyChecklists, pregnancyWeights, kickSessions 접근"
    then: ["5개 상수 문자열 반환"]
  - given: ["firestore.rules 최신 배포본"]
    when: "grep 'pregnancies'"
    then: ["매칭 라인 ≥1"]
integration:
  - "Rules 적용 후 익명 쓰기 시도 시 denied"
  - "동일 uid 쓰기는 허용"
commands:
  - run: "make test"
    expect: "exit 0"
  - run: "grep -q 'pregnancies' firestore.rules"
    expect: "exit 0"
  - run: "firebase firestore:rules:get | grep -q pregnancies"
    expect: "exit 0"
rollback:
  - "규칙 배포 실패 시: firebase firestore:rules:release <previous_version>"
  - "이전 배포본 버전 미리 기록 (firebase firestore:rules:list)"
risk: HIGH
```

---

### TODO 3: FirestoreService+Pregnancy Extension
**Type**: work
**Required Tools**: Read, Edit, Write
**Risk**: MEDIUM

**Inputs**: TODO 1 models, TODO 2 collection constants

**Outputs**:
- `BabyCare/Services/FirestoreService+Pregnancy.swift`

**Steps**:
- [ ] `func savePregnancy(_ p: Pregnancy, userId: String) async throws` — merge:true, FieldValue.serverTimestamp
- [ ] `func fetchActivePregnancy(userId: String) async throws -> Pregnancy?` — outcome==ongoing 필터
- [ ] `func fetchArchivedPregnancies(userId: String) async throws -> [Pregnancy]` — archivedAt desc
- [ ] `func saveKickSession(_ s: KickSession, userId: String, pregnancyId: String) async throws`
- [ ] `func fetchKickSessions(userId: String, pregnancyId: String, limit: Int = 30) async throws -> [KickSession]`
- [ ] `func savePrenatalVisit/fetchPrenatalVisits` — scheduled asc
- [ ] `func saveChecklistItem/fetchChecklistItems` — category별 그룹
- [ ] `func saveWeightEntry/fetchWeightEntries` — measuredAt asc
- [ ] `func transitionPregnancyToBaby(pregnancy: Pregnancy, newBaby: Baby, userId: String) async throws` — **WriteBatch**: (1) Pregnancy.transitionState=pending 쓰기, (2) Baby 신규 생성, (3) Pregnancy.outcome=born, archivedAt=now, transitionState=completed. 하나라도 실패 시 전체 rollback
- [ ] 모든 경로에 `FirestoreCollections.*` 상수 사용
- [ ] 기존 FirestoreService 패턴(+Activity, +Vaccination) 참고

**Must NOT do**:
- ❌ 하드코딩 경로
- ❌ 전환 로직을 별도 write 3회로 분할 (WriteBatch 필수)
- ❌ 기존 FirestoreService.swift 본체 수정
- ❌ git 커밋

**References**:
- `BabyCare/Services/FirestoreService+Activity.swift`
- `BabyCare/Services/FirestoreService+Health.swift` (Vaccination CRUD)
- `BabyCare/Services/FirestoreService+Badge.swift` (increment 패턴)

**Acceptance Criteria**:
- *Functional*: 전환 WriteBatch가 하나 실패 시 모두 rollback (mock 기반 테스트)
- *Static*: 컴파일 통과, arch-test 0 violations
- *Runtime*: `test_transitionPregnancyToBaby_atomicity` PASS

**Verify**:
```yaml
acceptance:
  - given: ["Pregnancy ongoing 상태"]
    when: "transitionPregnancyToBaby 호출"
    then: ["Pregnancy.outcome=born", "Pregnancy.archivedAt≠nil", "Pregnancy.transitionState=completed", "Baby 신규 생성"]
  - given: ["WriteBatch 중 Baby 쓰기 실패 simulation"]
    when: "transitionPregnancyToBaby 호출"
    then: ["Pregnancy 상태 변화 없음 (전체 롤백)"]
integration:
  - "WriteBatch에 Pregnancy 쓰기 + Baby 쓰기가 모두 포함"
commands:
  - run: "make test"
    expect: "exit 0"
  - run: "make arch-test"
    expect: "exit 0"
risk: MEDIUM
```

---

### TODO 4: PregnancyViewModel (@Observable) + AppState 주입
**Type**: work
**Required Tools**: Read, Edit, Write
**Risk**: MEDIUM

**Inputs**: TODO 3 service

**Outputs**:
- `BabyCare/ViewModels/PregnancyViewModel.swift`
- `BabyCare/App/AppState.swift` (수정)

**Steps**:
- [ ] `@MainActor @Observable final class PregnancyViewModel`
- [ ] Public state: `activePregnancy: Pregnancy?`, `archivedPregnancies: [Pregnancy]`, `kickSessions: [KickSession]`, `prenatalVisits: [PrenatalVisit]`, `checklistItems: [PregnancyChecklistItem]`, `weightEntries: [PregnancyWeightEntry]`, `currentKickSession: KickSession?`
- [ ] `func dataUserId(currentUserId: String) -> String` — activePregnancy?.ownerUserId ?? currentUserId (Baby 패턴과 동일)
- [ ] `func loadActivePregnancy(userId:)` / `loadArchivedPregnancies(userId:)`
- [ ] `func createPregnancy(lmpDate:, dueDate:, userId:)` — LMP 또는 EDD 필수, 한 쪽에서 다른 쪽 계산
- [ ] `func updateEDD(newDueDate: Date, userId:)` — eddHistory append + dueDate 갱신 (덮어쓰기 금지)
- [ ] `func currentWeek() -> (weeks: Int, days: Int)?` — `Calendar.current.dateComponents([.day], from: lmpDate, to: Date())` 기반, 7로 나누기 + 나머지
- [ ] `func dDay() -> Int?` — dueDate - 오늘 (자정 기준)
- [ ] `func startKickSession()` / `func recordKick()` / `func endKickSession()` — ActivityTimerManager 재사용
- [ ] `func toggleChecklistItem(_ item:)`
- [ ] `func transitionToBaby(babyName:, gender:, birthDate:, userId:, babyVM:)` — FirestoreService.transitionPregnancyToBaby 호출
- [ ] `func archivePregnancy(outcome: PregnancyOutcome, userId:)` — born 이외 (miscarriage/stillbirth/terminated) v1은 모델만 지원 경로
- [ ] AppState에 `pregnancy: PregnancyViewModel = .init()` 추가
- [ ] FeatureFlag 분기: ContentView/탭에서만 `FeatureFlags.pregnancyModeEnabled` 체크, VM은 항상 동작 (테스트 용이성)

**Must NOT do**:
- ❌ `authVM.currentUserId` 직접 사용 (dataUserId() 강제)
- ❌ Date 산술로 주차 계산 (Calendar 강제)
- ❌ EDD 덮어쓰기 (eddHistory 미기록)
- ❌ View 레이어에서 FeatureFlag 산발 분기
- ❌ git 커밋

**References**:
- `BabyCare/ViewModels/BabyViewModel.swift:1-191` (@Observable + dataUserId 패턴)
- `BabyCare/ViewModels/ActivityViewModel.swift` (세션 상태 관리)
- `BabyCare/Utils/ActivityTimerManager.swift`
- `BabyCare/Services/Analysis/Preprocessor.swift:45` (gestationalWeeks 인자)

**Acceptance Criteria**:
- *Functional*: 주차/D-day 계산 시 타임존/DST 안전, EDD 변경 시 이력 보존
- *Static*: arch-test 0 violations (VM은 Service 호출 가능, View는 VM 경유)
- *Runtime*: 8개 테스트 PASS (`test_pregnancyViewModel_*`)

**Verify**:
```yaml
acceptance:
  - given: ["LMP = 2026-01-01, 오늘 = 2026-04-15"]
    when: "currentWeek() 호출"
    then: ["weeks=14, days=6 또는 15,0 범위 (타임존 안전)"]
  - given: ["EDD=2026-10-08 기존"]
    when: "updateEDD(2026-10-15)"
    then: ["dueDate=2026-10-15", "eddHistory에 2026-10-08 포함"]
  - given: ["activePregnancy 없음"]
    when: "loadActivePregnancy(userId:)"
    then: ["activePregnancy=nil", "에러 없이 완료"]
integration:
  - "pregnancyVM.dataUserId() 호출 경로가 FirestoreService+Pregnancy에 일관 전달"
commands:
  - run: "make test"
    expect: "exit 0"
  - run: "make arch-test"
    expect: "exit 0"
risk: MEDIUM
```

---

### TODO 5: Static Resources (JSON)
**Type**: work
**Required Tools**: Write
**Risk**: LOW

**Inputs**: (independent)

**Outputs**:
- `BabyCare/Resources/pregnancy-weeks.json` (schema + 샘플 1-3주치)
- `BabyCare/Resources/prenatal-checklist.json` (10-15개 기본 항목)

**Steps**:
- [ ] `pregnancy-weeks.json` schema: `[{ week: 1..40, fruitSize: String, milestone: String, tip: String, disclaimerKey: String? }]` (40주 슬롯 + 1-3주 샘플 콘텐츠, 나머지 post-work)
- [ ] `prenatal-checklist.json` schema: `[{ id, title, category(trimester1|trimester2|trimester3|postpartum_prep), targetWeek?, source:"bundle" }]`
- [ ] 특정 브랜드/의약품/시술명 금지
- [ ] 의학적 판단 텍스트 금지 ("정상" 등)
- [ ] 모든 파일 UTF-8 + JSON 유효성 확인
- [ ] project.yml resources 섹션에 포함 확인

**Must NOT do**:
- ❌ 특정 브랜드/의약품 포함
- ❌ "정상/위험" 판단 텍스트
- ❌ git 커밋

**References**:
- `BabyCare/Resources/` (기존 사운드 리소스 패턴)
- ACOG 가이드라인

**Acceptance Criteria**:
- *Functional*: JSONDecoder로 로드 성공
- *Static*: 파일 존재, `python3 -m json.tool` 유효성 PASS
- *Runtime*: `test_pregnancyWeeksJson_schema` PASS

**Verify**:
```yaml
acceptance:
  - given: ["번들에 pregnancy-weeks.json 포함"]
    when: "JSONDecoder로 [PregnancyWeekInfo] 디코드"
    then: ["배열 길이 ≥1", "week 필드 1~40 범위"]
commands:
  - run: "python3 -m json.tool BabyCare/Resources/pregnancy-weeks.json > /dev/null"
    expect: "exit 0"
  - run: "python3 -m json.tool BabyCare/Resources/prenatal-checklist.json > /dev/null"
    expect: "exit 0"
  - run: "make test"
    expect: "exit 0"
risk: LOW
```

---

### TODO 6: Onboarding Sublink + PregnancyRegistrationView
**Type**: work
**Required Tools**: Read, Edit, Write
**Risk**: LOW

**Inputs**: TODO 4 VM

**Outputs**:
- `BabyCare/Views/Pregnancy/PregnancyRegistrationView.swift` (신규)
- `BabyCare/App/ContentView.swift` 또는 `BabyCare/Views/Settings/AddBabyView.swift` (서브링크 삽입)

**Steps**:
- [ ] AddBabyView 하단에 "아직 태어나지 않았나요?" Button → sheet로 PregnancyRegistrationView
- [ ] PregnancyRegistrationView Form: LMP 날짜 | 또는 EDD 직접 입력 (상호 계산), fetusCount Picker (1/2/3), 태명(선택), 초음파 성별(선택, undetermined/male/female)
- [ ] 저장 시 `pregnancyVM.createPregnancy`
- [ ] **FeatureFlags.pregnancyModeEnabled == false**일 때 서브링크 완전 숨김
- [ ] DisclaimerBanner 상단 고정 ("의학적 진단을 대체하지 않습니다")
- [ ] arch-test 준수 (View → VM만)

**Must NOT do**:
- ❌ FirestoreService 직접 호출
- ❌ FeatureFlag를 View body 중간에 반복 분기 (진입 지점에서만)
- ❌ git 커밋

**References**:
- `BabyCare/Views/Settings/AddBabyView.swift:1-74`
- `BabyCare/App/ContentView.swift:1-304`
- `BabyCare/Views/Health/CryAnalysisView.swift:31` (DisclaimerBanner 사용)

**Acceptance Criteria**:
- *Functional*: LMP 입력 시 EDD 자동 계산 + 역방향, fetusCount>1 시 면책 강조
- *Static*: arch-test 0 violations
- *Runtime*: `test_pregnancyRegistration_lmpToEdd` PASS

**Verify**:
```yaml
acceptance:
  - given: ["FeatureFlags.pregnancyModeEnabled=false"]
    when: "AddBabyView 렌더"
    then: ["'아직 태어나지 않았나요?' 링크 미표시"]
  - given: ["LMP=2026-01-01 입력"]
    when: "자동 계산"
    then: ["EDD=2026-10-08 (±1일)"]
commands:
  - run: "make build"
    expect: "exit 0"
  - run: "make test"
    expect: "exit 0"
risk: LOW
```

---

### TODO 7: Home Tab Pregnancy Mode (DashboardPregnancyView)
**Type**: work
**Required Tools**: Read, Edit, Write
**Risk**: MEDIUM

**Inputs**: TODO 4 VM, TODO 5 JSON

**Outputs**:
- `BabyCare/Views/Dashboard/DashboardPregnancyView.swift`
- `BabyCare/Views/Dashboard/DashboardView.swift` (mode 분기 수정)

**Steps**:
- [ ] DashboardView 루트에서 `pregnancyVM.activePregnancy != nil && FeatureFlags.pregnancyModeEnabled` 분기로 DashboardPregnancyView 표시
- [ ] 카드 구성: D-day 카드 (큰 숫자, 진행바 40주 중 N주차), 주차 카드 (JSON에서 현재 주차 pull, fruitSize/milestone/tip), 다음 산전 방문, 체크리스트 프리뷰 (상위 3개)
- [ ] DisclaimerBanner 최상단 고정
- [ ] Apple Charts로 주차 진행 프로그레스 렌더링
- [ ] 다중 임신(fetusCount>1) 시 배너에 "단태아 기준" 면책 강화
- [ ] 다크모드 대응 (AppColors 사용)

**Must NOT do**:
- ❌ Service 직접 호출
- ❌ "정상/위험" 판단 텍스트
- ❌ 외부 차트 라이브러리
- ❌ git 커밋

**References**:
- `BabyCare/Views/Dashboard/DashboardView.swift`
- `BabyCare/Views/Dashboard/DashboardInsightCards.swift` (카드 패턴)
- `BabyCare/Views/Dashboard/BadgeHomeStrip.swift`

**Acceptance Criteria**:
- *Functional*: 주차 카드가 JSON의 해당 주차 데이터 반영
- *Static*: arch-test 0 violations
- *Runtime*: `test_dashboardPregnancyView_renders` (snapshot) PASS

**Verify**:
```yaml
acceptance:
  - given: ["activePregnancy, currentWeek=14"]
    when: "DashboardPregnancyView 렌더"
    then: ["D-day 카드 표시", "주차 카드 week=14 표시", "DisclaimerBanner 최상단"]
  - given: ["fetusCount=2"]
    when: "렌더"
    then: ["단태아 기준 면책 배너 강조"]
commands:
  - run: "make build"
    expect: "exit 0"
  - run: "make arch-test"
    expect: "exit 0"
risk: MEDIUM
```

---

### TODO 8: Health Tab Pregnancy Mode (Kick / Visit / Weight)
**Type**: work
**Required Tools**: Read, Edit, Write
**Risk**: MEDIUM

**Inputs**: TODO 4 VM

**Outputs**:
- `BabyCare/Views/Health/HealthPregnancyView.swift`
- `BabyCare/Views/Health/KickSessionView.swift`
- `BabyCare/Views/Health/PrenatalVisitListView.swift`
- `BabyCare/Views/Health/PregnancyWeightView.swift`
- `BabyCare/Views/Health/HealthView.swift` (mode 분기)

**Steps**:
- [ ] HealthView 루트 분기: activePregnancy != nil → HealthPregnancyView
- [ ] HealthPregnancyView: 3섹션 (태동 / 산전 방문 / 체중 추이) + DisclaimerBanner
- [ ] KickSessionView: 시작 버튼 → 실행 중엔 큰 탭 버튼 (88pt) + 카운터 + 경과 시간 + 종료 버튼. ACOG 10회 목표, 2시간 경과 시 자동 종료 + 알림. 탭 시 `UIImpactFeedbackGenerator(.light)`
- [ ] PrenatalVisitListView: 예정 방문 카드 + 추가 버튼, 14일 이내는 D-14/7/1 로컬 푸시 예약
- [ ] PregnancyWeightView: Apple Charts LineMark (pre-pregnancy weight 기준선 포함, 증가 추세만, **권장 범위 밴드 금지** — 의학 판단 회피)
- [ ] 체중 단위 kg/lb 토글 (설정에 저장)

**Must NOT do**:
- ❌ 체중 권장 증가량 "정상/주의" 라벨링
- ❌ 외부 차트 라이브러리
- ❌ FirestoreService 직접 호출
- ❌ git 커밋

**References**:
- `BabyCare/Views/Health/HealthView.swift`
- `BabyCare/Views/Health/CryAnalysisView.swift` (DisclaimerBanner + 녹음 버튼 패턴)
- `BabyCare/Views/Growth/GrowthView.swift` (Apple Charts + 면책 패턴)

**Acceptance Criteria**:
- *Functional*: 태동 세션 2시간 초과 시 자동 종료, 탭 카운트 정확
- *Static*: arch-test 0 violations
- *Runtime*: `test_kickSession_autoTimeout`, `test_kickSession_tapIncrement` PASS

**Verify**:
```yaml
acceptance:
  - given: ["KickSession 시작, startedAt=2시간 전"]
    when: "viewWillAppear 또는 타이머 체크"
    then: ["자동 endedAt 기록", "사용자에게 안내 알림"]
  - given: ["KickSessionView 실행 중, 탭 10회"]
    when: "10번째 탭"
    then: ["완료 햅틱 + 세션 종료 옵션 노출"]
integration:
  - "세션 종료 시 FirestoreService 저장 완료"
commands:
  - run: "make test"
    expect: "exit 0"
  - run: "make arch-test"
    expect: "exit 0"
risk: MEDIUM
```

---

### TODO 9: + Button Sheet — Pregnancy Mode Branch
**Type**: work
**Required Tools**: Read, Edit
**Risk**: LOW

**Inputs**: TODO 4, 8

**Outputs**:
- `BabyCare/Views/Recording/RecordingView.swift` (mode 분기 수정)

**Steps**:
- [ ] RecordingView 루트에서 activePregnancy != nil 시 임신 모드 항목 세트로 스왑
- [ ] 임신 모드 항목: 태동 기록, 산전 방문 추가, 체중 기록, 증상 메모
- [ ] 기존 육아 모드 항목과 탭 위치(2번째 가운데 +) 동일 유지
- [ ] 각 항목 탭 시 해당 sheet 오픈

**Must NOT do**:
- ❌ 탭 위치 변경
- ❌ git 커밋

**References**:
- `BabyCare/Views/Recording/RecordingView.swift`

**Acceptance Criteria**:
- *Functional*: activePregnancy=nil 시 기존 육아 항목 유지
- *Static*: arch-test 0 violations
- *Runtime*: `test_recordingView_pregnancyBranch` PASS

**Verify**:
```yaml
acceptance:
  - given: ["activePregnancy=nil"]
    when: "+ 버튼 탭"
    then: ["수유/수면/기저귀 기존 메뉴 표시"]
  - given: ["activePregnancy≠nil"]
    when: "+ 버튼 탭"
    then: ["태동/방문/체중/증상 메뉴 표시"]
commands:
  - run: "make build"
    expect: "exit 0"
risk: LOW
```

---

### TODO 10: Pregnancy Checklist View
**Type**: work
**Required Tools**: Read, Edit, Write
**Risk**: LOW

**Inputs**: TODO 4, 5

**Outputs**:
- `BabyCare/Views/Pregnancy/PregnancyChecklistView.swift`
- 홈/건강 탭에서 진입점

**Steps**:
- [ ] 카테고리 섹션 (trimester1/2/3/postpartum_prep)
- [ ] 기본 템플릿은 `prenatal-checklist.json`에서 로드 (source=bundle)
- [ ] 사용자 추가(source=user) 가능
- [ ] 완료율 ProgressView
- [ ] DisclaimerBanner 상단

**Must NOT do**:
- ❌ git 커밋

**References**:
- `BabyCare/Views/Todo/TodoListView.swift`

**Acceptance Criteria**:
- *Functional*: bundle 항목 체크 시 isCompleted 저장, 재진입 시 상태 유지
- *Static*: arch-test 0 violations
- *Runtime*: `test_checklistItem_toggle`, `test_checklistItem_bundleLoad` PASS

**Verify**:
```yaml
acceptance:
  - given: ["prenatal-checklist.json 10개 항목"]
    when: "PregnancyChecklistView 초기 로드"
    then: ["10개 항목 렌더", "카테고리별 섹션 분리"]
commands:
  - run: "make build"
    expect: "exit 0"
  - run: "make test"
    expect: "exit 0"
risk: LOW
```

---

### TODO 11: Transition Flow (WriteBatch + transitionState)
**Type**: work
**Required Tools**: Read, Edit, Write
**Risk**: HIGH

**Inputs**: TODO 3 (transitionPregnancyToBaby), TODO 4 VM

**Outputs**:
- `BabyCare/Views/Pregnancy/PregnancyTransitionSheet.swift`
- DashboardPregnancyView에 "출산했어요" 배너 진입점

**Steps**:
- [ ] D-day ≤ 7일부터 홈 배너 "출산했어요" CTA 표시 (일찍 표시 금지)
- [ ] CTA 탭 → PregnancyTransitionSheet (확인 화면)
- [ ] Sheet Form: 아기 이름 (Pregnancy.babyNickname prefill + 편집 가능), 성별 (ultrasoundGender prefill + required), 실제 출생일 (today prefill)
- [ ] 두 단계 확인: 첫 탭 → "정말로 출산 완료로 전환하시겠어요? 되돌리려면 설정 > 이전 임신에서 복구해야 합니다" 경고 시트 → 두 번째 확인
- [ ] `pregnancyVM.transitionToBaby(...)` 호출 → WriteBatch + transitionState
- [ ] 실패 시 재시도 UI ("일시적인 오류, 다시 시도" 버튼, 데이터 손실 없음 안내)
- [ ] 성공 시 축하 화면(과도한 파티클 금지, 담백하게) → 자동으로 육아 모드 홈으로 전환
- [ ] gestationalWeeks 자동 계산하여 Baby.gestationalWeeks에 주입

**Must NOT do**:
- ❌ 단일 write로 처리 (WriteBatch 필수)
- ❌ 즉시 실행 (1회 확인만) — 2단계 확인 필수
- ❌ birthDate 누락 (Baby 생성 차단)
- ❌ transitionState 기록 생략
- ❌ git 커밋

**References**:
- TODO 3 transitionPregnancyToBaby
- `BabyCare/Views/Settings/AddBabyView.swift:1-74`

**Acceptance Criteria**:
- *Functional*: 전환 성공 시 Pregnancy.outcome=born/archivedAt/transitionState=completed + Baby 신규 생성 (gestationalWeeks 포함), 실패 시 원상 복구
- *Static*: arch-test 0 violations
- *Runtime*: `test_transition_successFlow`, `test_transition_failureRecovery` PASS

**Verify**:
```yaml
acceptance:
  - given: ["Pregnancy ongoing, dueDate=오늘-1일, 모든 prefill 입력됨"]
    when: "PregnancyTransitionSheet 2단계 확인 완료"
    then: ["Baby 생성 완료", "Pregnancy.outcome=born", "홈 탭이 육아 모드로 전환"]
  - given: ["전환 중간 네트워크 끊김"]
    when: "재시도 버튼 탭"
    then: ["transitionState=pending 감지 → resume 가능"]
integration:
  - "Pregnancy 쓰기와 Baby 쓰기가 동일 WriteBatch에 포함"
commands:
  - run: "make test"
    expect: "exit 0"
rollback:
  - "WriteBatch 실패 시 Firestore atomic → 자동 롤백 (추가 작업 불필요)"
  - "UI 상 transitionState=pending 감지 시 VM이 재시도 프롬프트 노출"
risk: HIGH
```

---

### TODO 12: FeatureFlag + Disclaimer + Localizable
**Type**: work
**Required Tools**: Read, Edit
**Risk**: LOW

**Inputs**: TODO 6-11

**Outputs**:
- `BabyCare/Utils/FeatureFlags.swift` (수정)
- `BabyCare/ko.lproj/Localizable.strings` (수정)

**Steps**:
- [ ] `FeatureFlags.pregnancyModeEnabled: Bool = true` 추가 (TestFlight용, App Store 빌드 전 flip)
- [ ] 임신 모드 신규 키 `pregnancy.*` prefix, 최소 40개 (D-day/주차/태동/방문/체중/체크리스트/전환/면책 문구)
- [ ] DisclaimerBanner는 기존 재사용 (신규 파일 금지)
- [ ] FeatureFlag 참조 지점 검수: ContentView/DashboardView/HealthView/RecordingView/AddBabyView 5곳만

**Must NOT do**:
- ❌ Localizable 키 영어만 추가 (한국어 필수)
- ❌ 의학적 판단 문구 삽입
- ❌ FeatureFlag를 6곳 이상 분산
- ❌ git 커밋

**References**:
- `BabyCare/Utils/FeatureFlags.swift:1-5`
- `BabyCare/ko.lproj/Localizable.strings`

**Acceptance Criteria**:
- *Functional*: FeatureFlag=false 시 임신 UI 완전 숨김
- *Static*: SwiftLint 0 경고
- *Runtime*: `test_featureFlags_pregnancyModeEnabled_isBool`, `test_localizable_pregnancyKeys_exist` PASS

**Verify**:
```yaml
acceptance:
  - given: ["FeatureFlags.pregnancyModeEnabled=false"]
    when: "앱 시작 → 기존 사용자 플로우"
    then: ["임신 관련 UI 일체 미표시"]
commands:
  - run: "grep -c 'pregnancy\\.' BabyCare/ko.lproj/Localizable.strings | awk '$1>=40 {exit 0}; $1<40 {exit 1}'"
    expect: "exit 0"
  - run: "make test"
    expect: "exit 0"
risk: LOW
```

---

### TODO 13: D-day Widget (HomeScreen + LockScreen) + PregnancyWidgetDataStore
**Type**: work
**Required Tools**: Read, Edit, Write
**Risk**: HIGH

**Inputs**: TODO 4 VM

**Outputs**:
- `BabyCareWidget/PregnancyDDayWidget.swift`
- `BabyCareWidget/Provider/PregnancyWidgetDataStore.swift` (기존 WidgetDataStore와 별도 struct, 같은 App Groups Suite, 키 prefix `pregnancy_`)
- `BabyCareWidget/LockScreenWidgets.swift` (accessoryCircular 케이스 추가)
- `BabyCareWidget/BabyCareWidgetBundle.swift` (엔트리 추가)
- `BabyCare/Services/PregnancyWidgetSyncService.swift` — 앱 측에서 PregnancyWidgetDataStore 쓰기

**Steps**:
- [ ] PregnancyWidgetDataStore: 같은 `group.com.roacompany.allcare` Suite, 키 prefix 분리 — `pregnancy_dueDate`, `pregnancy_currentWeek`, `pregnancy_babyNickname`
- [ ] 기존 WidgetDataStore **미수정**
- [ ] PregnancyDDayWidget timeline: **일 단위** 갱신만 (시간 단위 금지)
- [ ] HomeScreen small/medium 2종 + Lock Screen accessoryCircular 1종
- [ ] 다크모드 WidgetColors 사용
- [ ] 앱에서 activePregnancy 변경 시 PregnancyWidgetSyncService.reload()로 타임라인 재생성
- [ ] FeatureFlag=false 시 위젯 엔트리 placeholder ("임신 모드 비활성")

**Must NOT do**:
- ❌ 기존 WidgetDataStore 수정
- ❌ 시간 단위 타임라인
- ❌ 위젯에 의학 텍스트
- ❌ git 커밋

**References**:
- `BabyCareWidget/NextFeedingWidget.swift`
- `BabyCareWidget/LockScreenWidgets.swift`
- `BabyCareWidget/Provider/WidgetDataStore.swift`

**Acceptance Criteria**:
- *Functional*: 일 단위 타임라인, D-day 숫자 정확, 다크모드 대응
- *Static*: 위젯 타겟 빌드 성공
- *Runtime*: `test_pregnancyWidgetDataStore_keyPrefix`, `test_pregnancyWidgetTimeline_daily` PASS

**Verify**:
```yaml
acceptance:
  - given: ["dueDate=오늘+30일, PregnancyWidgetSyncService.reload()"]
    when: "위젯 타임라인 생성"
    then: ["D-30 표시", "다음 엔트리 24시간 후"]
  - given: ["기존 위젯 타겟"]
    when: "PregnancyWidget 추가 후 빌드"
    then: ["NextFeedingWidget 등 기존 위젯 기능 정상"]
integration:
  - "App Groups 키 prefix 'pregnancy_'로 격리"
commands:
  - run: "make build"
    expect: "exit 0"
  - run: "make test"
    expect: "exit 0"
rollback:
  - "PregnancyDDayWidget 실패 시 BabyCareWidgetBundle에서 widget entry 제거 → 기존 위젯은 영향 없음"
risk: HIGH
```

---

### TODO 14: HealthKit Integration
**Type**: work
**Required Tools**: Read, Edit, Write
**Risk**: MEDIUM

**Inputs**: TODO 4 VM

**Outputs**:
- `BabyCare/Services/HealthKitPregnancyService.swift`
- `project.yml` Info.plist 수정 (NSHealthShareUsageDescription, NSHealthUpdateUsageDescription)
- `BabyCare/Views/Settings/PregnancyHealthKitToggleView.swift`

**Steps**:
- [ ] `HKHealthStore`를 통해 `.pregnancy`, `.pregnancyTestResult` 타입 권한 요청
- [ ] 설정 탭에서 토글 (opt-in 기본 off)
- [ ] 권한 허용 시: Pregnancy 생성/업데이트 시 HealthKit에 동기화
- [ ] Privacy: 광고/Analytics 활용 금지 코멘트 명시
- [ ] iOS 17+ 조건

**Must NOT do**:
- ❌ 권한 요청을 앱 시작 시 강제
- ❌ HealthKit 데이터를 Analytics로 전송
- ❌ git 커밋

**References**:
- Apple Developer HKCategoryTypeIdentifier docs

**Acceptance Criteria**:
- *Functional*: 권한 거부 시 graceful fallback, 재요청 경로 존재
- *Static*: iOS 17 컴파일 통과
- *Runtime*: `test_healthKitPregnancyService_authDenied` PASS (mock)

**Verify**:
```yaml
acceptance:
  - given: ["HealthKit 권한 거부 상태"]
    when: "HealthKitPregnancyService.sync() 호출"
    then: ["throw error(.notAuthorized)", "앱 기능 영향 없음"]
commands:
  - run: "make build"
    expect: "exit 0"
  - run: "make test"
    expect: "exit 0"
risk: MEDIUM
```

---

### TODO 15: Partner Sharing (ownerUserId pattern reuse)
**Type**: work
**Required Tools**: Read, Edit
**Risk**: MEDIUM

**Inputs**: TODO 3, 4

**Outputs**:
- `BabyCare/Services/FirestoreService+Pregnancy.swift` (수정 — sharedWith 필드)
- `BabyCare/Views/Settings/PregnancyShareView.swift`
- `firestore.rules` (수정 — 파트너 read 허용)

**Steps**:
- [ ] `Pregnancy.sharedWith: [String]?` 필드 추가 (uid 배열)
- [ ] `firestore.rules` append: `request.auth.uid == userId || request.auth.uid in resource.data.sharedWith` (읽기만, 쓰기는 owner)
- [ ] **Rules 변경 재배포**: `firebase deploy --only firestore:rules` (TODO 2 선배포 원칙 동일 적용, 이 TODO 머지 전 필수)
- [ ] `PregnancyShareView`: 이메일 초대 → 기존 Baby `sharedAccess` 패턴 재사용
- [ ] `PregnancyViewModel.loadSharedPregnancies(userId:)` — 파트너로 등록된 경우도 활성 임신으로 표시

**Must NOT do**:
- ❌ 파트너에게 쓰기 권한 부여
- ❌ 승인 없이 자동 공유
- ❌ git 커밋

**References**:
- `BabyCare/Services/FirestoreService+FamilySharing.swift`
- `BabyCare/ViewModels/BabyViewModel.swift:dataUserId()`

**Acceptance Criteria**:
- *Functional*: 파트너 초대 수락 후 조회 가능, 쓰기 차단
- *Static*: 컴파일 통과
- *Runtime*: `test_pregnancyShare_readOnly` PASS

**Verify**:
```yaml
acceptance:
  - given: ["partner uid가 sharedWith에 추가됨"]
    when: "partner 앱에서 조회"
    then: ["activePregnancy 로드 성공"]
  - given: ["partner의 수정 시도"]
    when: "savePregnancy 호출"
    then: ["denied"]
commands:
  - run: "make test"
    expect: "exit 0"
risk: MEDIUM
```

---

### TODO 16: Archive View (이전 임신 이력)
**Type**: work
**Required Tools**: Read, Edit, Write
**Risk**: LOW

**Inputs**: TODO 4

**Outputs**:
- `BabyCare/Views/Settings/PregnancyArchiveView.swift`
- SettingsView에 "이전 임신" row 추가

**Steps**:
- [ ] archivedPregnancies 목록 (archivedAt desc)
- [ ] outcome별 아이콘/문구 (born → 🎉, miscarriage/stillbirth/terminated → 담백한 아이콘 + 위로 문구)
- [ ] 탭 시 상세 (기록된 방문/체중/태동 요약)
- [ ] 삭제 불가 (데이터 보존), 숨김 토글만 제공

**Must NOT do**:
- ❌ 삭제 기능 제공 (감정적 리스크 + 데이터 영구 손실)
- ❌ 자극적 문구
- ❌ git 커밋

**References**:
- `BabyCare/Views/Settings/SettingsView.swift`

**Acceptance Criteria**:
- *Functional*: archived 목록 정렬, outcome 필터링
- *Static*: arch-test 0
- *Runtime*: `test_archiveView_sortDesc` PASS

**Verify**:
```yaml
acceptance:
  - given: ["archived 3건, outcomes=[born, miscarriage, born]"]
    when: "PregnancyArchiveView 렌더"
    then: ["archivedAt desc 정렬", "각 outcome별 아이콘 분기"]
commands:
  - run: "make build"
    expect: "exit 0"
risk: LOW
```

---

### TODO 17: Tests (XCTest 30+)
**Type**: work
**Required Tools**: Read, Edit
**Risk**: LOW

**Inputs**: TODO 1-16 전체

**Note**: 각 work TODO의 Runtime Acceptance에서 이미 선언된 테스트 케이스들이 append되어 합계 30+가 됩니다. 이 TODO는 **통합 검증 + 누락 보충** 성격 (이중 작성 금지).

**Outputs**:
- `BabyCareTests/BabyCareTests.swift` (append, 누락 항목 보충)

**Steps**:
- [ ] Models: Codable 라운드트립 6종
- [ ] PregnancyViewModel: currentWeek, dDay, updateEDD 이력 append, kickSession 타임아웃, transitionToBaby flow, fetusCount 기본값
- [ ] FirestoreService+Pregnancy: transitionPregnancyToBaby 원자성 (mock)
- [ ] JSON 리소스 로드 유효성
- [ ] Checklist toggle
- [ ] PregnancyWidgetDataStore 키 prefix 격리
- [ ] FeatureFlags 타입 검증
- [ ] Localizable 키 존재 검사
- [ ] HealthKit 권한 거부 graceful
- [ ] Partner share 읽기 전용 (mock)

**Must NOT do**:
- ❌ 별도 테스트 파일 생성 (BabyCareTests.swift append 원칙)
- ❌ Baby 모델 테스트 수정
- ❌ git 커밋

**References**:
- `BabyCareTests/BabyCareTests.swift`
- CLAUDE.md convention

**Acceptance Criteria**:
- *Functional*: 신규 테스트 30개 이상 PASS
- *Static*: arch-test 0
- *Runtime*: `make test` exit 0, 195→225+

**Verify**:
```yaml
acceptance:
  - given: ["신규 테스트 append 후"]
    when: "make test"
    then: ["exit 0, 통과 테스트 수 ≥225"]
commands:
  - run: "make test"
    expect: "exit 0"
risk: LOW
```

---

### TODO Final: Verification
**Type**: verification
**Required Tools**: Bash (read-only Edit/Write 금지)
**Risk**: N/A

**Inputs**: TODO 1-17 모두 완료

**Outputs**: `.dev/specs/pregnancy-mode/context/audit.md`

**Steps**:
- [ ] `make verify` 전체 실행 + 결과 기록
- [ ] `make arch-test` 0 violations 확인
- [ ] `make lint` 신규 경고 0건 확인
- [ ] `make design-verify` 100% 확인
- [ ] `make screenshots` 실행 + 주요 화면 캡처 존재 확인 (7 S-items routes)
- [ ] `firebase firestore:rules:get | grep pregnancies` 배포 확인
- [ ] Localizable `pregnancy.*` 키 개수 ≥40 확인
- [ ] `BabyCareTests.swift` 테스트 수 ≥225 확인
- [ ] FeatureFlag=false 빌드로 임신 UI 완전 숨김 확인 (수동 리뷰)
- [ ] audit.md 작성 (통과/미통과 항목)

**Must NOT do**:
- ❌ Edit/Write 도구 사용 (audit.md는 Bash heredoc으로 생성)
- ❌ 실패 시 재시도 (Fix Task 생성)
- ❌ 수동 수정으로 통과 위장

**References**: 전체 TODO Verify 블록

**Acceptance Criteria**:
- *Functional*: 전체 통합 테스트 PASS
- *Static*: arch-test 0, lint 0, design-verify 100%
- *Runtime*: make verify exit 0

**Verify**:
```yaml
acceptance:
  - given: ["TODO 1-17 완료"]
    when: "make verify 실행"
    then: ["exit 0", "build + lint + arch-test + test + design-verify 모두 PASS"]
commands:
  - run: "make verify"
    expect: "exit 0"
  - run: "firebase firestore:rules:get | grep -q pregnancies"
    expect: "exit 0"
  - run: "grep -c 'pregnancy\\.' BabyCare/ko.lproj/Localizable.strings | awk '$1>=40 {exit 0}; $1<40 {exit 1}'"
    expect: "exit 0"
manual: false
risk: HIGH
```

---

## Verification Summary

### Agent-Verifiable (A-items): 18
- A-0 `make verify` 게이트
- A-1~6 모델 Codable, JSON 유효성
- A-7 firestore.rules 배포
- A-8 FeatureFlag 존재
- A-9 JSON 번들 파일
- A-10 arch-test 0
- A-11 SwiftLint 0
- A-12 전체 빌드(위젯 포함)
- A-13 design-verify 100%
- A-14 PregnancyDDayWidget 컴파일
- A-15 transitionPregnancyToBaby 원자성 (mock)
- A-16 checklist toggle
- A-17 Localizable 키 40개+
- A-18 make screenshots 산출

### Human-Required (H-items): 8
- H-1 태동 세션 탭 UX/햅틱 실기기 감각
- H-2 출산 전환 감정적 플로우 (문구/애니메이션)
- H-3 의학 면책 법적 충분성 (외부 법무 검토)
- H-4 pregnancy-weeks.json 의학적 정확성 (산부인과 전문가 스팟체크)
- H-5 FeatureFlag=false 시 임신 UI 완전 격리 (실기기 탐색)
- H-6 산전 체크리스트 내용 적절성 (도메인 전문가)
- H-7 D-day 위젯 엣지케이스 (예정일 당일/초과)
- H-8 TestFlight 실기기 QA (iPhone SE + Dynamic Type + 다크모드)

### Sandbox Agent Testing (S-items): 7
- S-1 PregnancyRegistrationView 스크린샷 + Visual/UX
- S-2 홈 임신 모드 카드 레이아웃 + Mobile Responsive
- S-3 건강 탭 태동/방문/체중 서브뷰 + 3-Agent QA
- S-4 + 시트 임신 모드 항목 FeatureFlag gate
- S-5 D-day 위젯 렌더링 (Home + Lock Screen + 다크모드)
- S-6 출산 전환 감정적 플로우 스크린샷
- S-7 면책 배너 문구 위치 검증

### Verification Gaps
- **Tier 2 부재**: Firebase Emulator 미구성 → mock 단위 테스트로 대체, 실검증은 H-8 TestFlight
- **BDD 인프라 부재**: make screenshots + 3-Agent QA 패턴이 Tier 4 역할 (프로젝트 표준)
- **Rules 배포는 Tier 1에 포함**: firebase CLI exit code로 검증, 실제 정책 테스트는 H-8

---

## External Dependencies Strategy

### Pre-work (must complete before /execute)
- 🔴 **[Blocking]** v2.6.2 (빌드 52) 심사 완료 확인 → App Store Connect에서 상태 확인
- 🔴 **[Blocking]** Firebase CLI 로그인 확인 (`firebase login:list`) → TODO 2 배포 전 필수
- ⚪ [Optional] 산전 체크리스트 기본 템플릿 초안 작성 (ACOG + 대한산부인과학회 참고) — Post-work로도 가능

### Post-work (user actions after completion)
- **pregnancy-weeks.json 40주 완성**: 산부인과 전문가 리뷰 → 주차별 콘텐츠 채움 (v1은 샘플 1-3주만 포함)
- **Privacy Policy 갱신**: 건강 데이터 수집 명시 → privacy.html 업데이트 + App Store Connect 문항 갱신
- **ATT 재검토**: 임신 데이터 수집에 따른 ATT prompt 조정 필요 여부
- **FeatureFlag flip**: TestFlight 검증 완료 후 App Store 빌드에서 `pregnancyModeEnabled=true` 유지 (이미 true면 no-op)
- **법무 검토**: 의학 면책 문구 전문가 검토
- **3-Agent QA 재실행**: v2.7 배포 전 전체 회귀
