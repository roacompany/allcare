# 가족 공유 초대 코드 버그 8건 수정

> Firestore 규칙 불일치 + 앱 코드 결함으로 가족 공유 기능 전체가 작동하지 않는 문제 수정
> Mode: quick/autopilot

## Assumptions

| Decision Point | Assumed Choice | Rationale | Source |
|---------------|---------------|-----------|--------|
| SharedBabyAccess ID 전환 | Fallback 읽기 + 인라인 마이그레이션 (DP-01 Option B) | 기존 사용자 무중단 전환 | tradeoff-analyzer |
| familySharing→sharedAccess 전환 | 앱 시작 시 인라인 마이그레이션 (DP-02 Option C) | Cloud Functions 불필요 | tradeoff-analyzer |
| N+1 병렬화 방식 | async let (TaskGroup 대신) | 공유 아기 통상 1~3개, 과도한 추상화 불필요 | tradeoff-analyzer |
| firestore.rules 배포 | firebase deploy --only firestore:rules | CLI 설치 확인됨 (v15.3.0) | codebase |

> **Note**: 이 가정들은 사용자 확인 없이 자동 결정되었습니다. `--interactive`로 재실행하면 직접 확인 가능.

## Verification Summary

### Agent-Verifiable (A-items)
| ID | Criterion | Method | Related TODO |
|----|-----------|--------|-------------|
| A-1 | iPhone 빌드 성공 | `xcodebuild build -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet` | TODO Final |
| A-2 | iPad 빌드 성공 | `xcodebuild build -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M3)' -quiet` | TODO Final |
| A-3 | firestore.rules 문법 검증 | `firebase deploy --only firestore:rules --dry-run` (또는 rules 파일 문법 확인) | TODO 1 |

### Human-Required (H-items)
| ID | Criterion | Reason | Review Material |
|----|-----------|--------|----------------|
| H-1 | 실기기에서 초대 코드 생성→참여→공유 아기 표시 E2E 테스트 | Firestore 규칙은 시뮬레이터에서 테스트 불가 | TestFlight 빌드 |
| H-2 | 기존 공유 관계 마이그레이션 확인 | 프로덕션 데이터 필요 | Firebase Console |

### Verification Gaps
- Firestore 규칙은 로컬 에뮬레이터 없이는 자동 테스트 불가 (H-1으로 대체)
- 프로덕션 DB 마이그레이션은 배포 후 수동 확인 필요

## External Dependencies Strategy

### Pre-work
| Dependency | Action | Command/Step | Blocking? |
|------------|--------|-------------|-----------|
| Firebase CLI | 이미 설치됨 (v15.3.0) | `firebase --version` | No |

### Post-work
| Task | Action | Command/Step |
|------|--------|-------------|
| Firestore 규칙 배포 | 수정된 규칙 프로덕션 적용 | `firebase deploy --only firestore:rules` |
| 마이그레이션 모니터링 | Firebase Console에서 sharedAccess 문서 생성 확인 | Firebase Console |

## Context

### Original Request
가족 공유 초대 코드가 연결되지 않는 오류 수정. 진단 결과 8개 독립 결함 발견.

### Research Findings
- 근본 원인 1: `FamilyInvite.swift:47` — SharedBabyAccess.id가 UUID()로 생성되어 Firestore 규칙의 `exists()` 경로와 불일치
- 근본 원인 2: `firestore.rules:57-58` — invites update 권한이 소유자 전용으로 참여자가 markInviteUsed 불가
- 추가: AuthViewModel.swift:143의 subcollection명 "familySharing" ≠ 실제 "sharedAccess"

## Work Objectives

### Core Objective
가족 공유 기능의 전체 흐름(초대 생성→참여→공유 아기 로드→해제)을 정상 작동하도록 수정

### Concrete Deliverables
- `firestore.rules` — invites update 규칙 수정
- `FamilyInvite.swift` — SharedBabyAccess.id 형식 변경
- `FirestoreService+Family.swift` — document ID 저장 변경 + Fallback 읽기 + removeSharedAccess 추가
- `FamilySharingView.swift` — 에러 핸들링 개선 + 중복 참여 방지 + 공유 해제 UI
- `BabyViewModel.swift` — 개별 try-catch + async let 병렬화
- `AuthViewModel.swift` — subcollection명 수정 + 인라인 마이그레이션

### Definition of Done
- [ ] `xcodebuild build` iPhone + iPad 성공
- [ ] firestore.rules 배포 가능 (문법 정상)
- [ ] 8개 결함 모두 코드 레벨 수정 완료

### Must NOT Do
- 기존 공유 관계 데이터를 삭제하지 않을 것 (마이그레이션으로 보존)
- Firestore 규칙을 과도하게 개방하지 않을 것 (최소 권한 원칙)
- Cloud Functions 사용하지 않을 것 (현재 아키텍처 유지)
- git 명령 실행하지 않을 것

---

## Task Flow

```
TODO-1 (Firestore 규칙) → TODO-2 (모델+서비스) → TODO-3 (ViewModel+View) → TODO-Final
```

## Dependency Graph

| TODO | Requires | Produces | Type |
|------|----------|----------|------|
| 1 | - | `rules_file` (file) | work |
| 2 | - | `model_files`, `service_files` (file) | work |
| 3 | TODO-2 outputs | `viewmodel_files`, `view_files` (file) | work |
| Final | all outputs | - | verification |

## Parallelization

| Group | TODOs | Reason |
|-------|-------|--------|
| A | TODO-1, TODO-2 | 독립적 (규칙 vs 앱 코드) |
| B | TODO-3 | TODO-2 의존 |

## Commit Strategy

| After TODO | Message | Files |
|------------|---------|-------|
| 1+2 | `fix: Firestore 규칙 + 가족 공유 모델/서비스 수정` | firestore.rules, FamilyInvite.swift, FirestoreService+Family.swift |
| 3 | `fix: 가족 공유 ViewModel/View 수정 + 마이그레이션` | BabyViewModel.swift, FamilySharingView.swift, AuthViewModel.swift |

## Error Handling

| Scenario | Action |
|----------|--------|
| work fails | Retry up to 2x → Analyze → Fix Task or halt |
| verification fails | Analyze → Fix Task or halt |
| Missing Input | Skip dependent TODOs, halt |

## Runtime Contract

| Aspect | Specification |
|--------|---------------|
| Working Directory | /Users/roque/BabyCare |
| Network Access | Denied |
| Package Install | Denied |
| File Access | Repository only |
| Max Execution Time | 5 minutes per TODO |
| Git Operations | Denied |

---

## TODOs

### [x] TODO 1: Firestore 규칙 수정

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `rules_file` (file): `firestore.rules` — 수정된 Firestore 보안 규칙

**Steps**:
- [ ] `firestore.rules:57-58` invites update 규칙 수정 — 인증된 사용자가 `isUsed` 필드만 `true`로 변경 가능하도록 조건 추가 (소유자 전용 → 소유자 OR isUsed만 변경하는 인증 사용자)
- [ ] 공유 아기 데이터 read 규칙(`firestore.rules:18-25`)의 `exists()` 경로가 `ownerUserId_babyId` 형식과 일치하는지 확인 (TODO-2에서 ID 형식 변경 후 일관성)

**Must NOT do**:
- 규칙을 `allow read, write: if true` 같이 전면 개방하지 않을 것
- 기존 규칙의 다른 컬렉션 권한을 변경하지 않을 것
- git 명령 실행하지 않을 것

**References**:
- `firestore.rules:49-59` — invites 규칙
- `firestore.rules:14-37` — users 하위 데이터 규칙

**Acceptance Criteria**:

*Functional:*
- [ ] invites update 규칙: 인증 사용자가 isUsed만 true로 변경 가능
- [ ] invites update 규칙: 다른 필드(code, ownerUserId 등) 변경은 여전히 소유자만 가능
- [ ] sharedAccess exists() 경로와 앱 코드의 document ID 형식 일치

*Static:*
- [ ] firestore.rules 파일 문법 오류 없음

*Runtime:*
- [ ] (Firestore 규칙은 로컬 테스트 불가 — H-1으로 대체)

**Verify**:
```yaml
acceptance:
  - given: ["인증된 사용자 B", "사용자 A가 만든 초대"]
    when: "사용자 B가 isUsed: true로 업데이트"
    then: ["업데이트 허용됨"]
  - given: ["인증된 사용자 B", "사용자 A가 만든 초대"]
    when: "사용자 B가 code 필드 변경 시도"
    then: ["거부됨"]
commands:
  - run: "cat firestore.rules | head -60"
    expect: "invites 규칙에 isUsed 조건 포함"
risk: MEDIUM
```

---

### [x] TODO 2: 모델 + 서비스 레이어 수정

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `model_file` (file): `BabyCare/Models/FamilyInvite.swift`
- `service_file` (file): `BabyCare/Services/FirestoreService+Family.swift`

**Steps**:
- [ ] `FamilyInvite.swift:47` — `SharedBabyAccess.id` 기본값을 `UUID().uuidString`에서 `"\(ownerUserId)_\(babyId)"` 형식으로 변경. init에서 ownerUserId와 babyId를 받아 자동 생성
- [ ] `FirestoreService+Family.swift:29-35` — `saveSharedAccess` document ID를 `access.id` (이제 `ownerUserId_babyId` 형식) 사용 확인
- [ ] `FirestoreService+Family.swift` — `fetchSharedAccess`에 Fallback 로직 추가: 신형 ID(`ownerUserId_babyId`)로 조회 후, 구형 UUID 문서도 쿼리로 찾아서 병합. 구형 문서 발견 시 신형 ID로 재저장 + 구형 삭제 (인라인 마이그레이션)
- [ ] `FirestoreService+Family.swift` — `removeSharedAccess(accessId:, userId:)` 메서드 추가
- [ ] `FirestoreService+Family.swift` — `checkDuplicateAccess(userId:, ownerUserId:, babyId:)` 메서드 추가 (중복 참여 방지)

**Must NOT do**:
- 기존 UUID 기반 문서를 직접 삭제하지 않을 것 (Fallback에서 마이그레이션)
- FirestoreService의 다른 메서드를 수정하지 않을 것
- git 명령 실행하지 않을 것

**References**:
- `FamilyInvite.swift:39-62` — SharedBabyAccess 모델
- `FirestoreService+Family.swift:29-43` — saveSharedAccess, fetchSharedAccess
- `firestore.rules:18-25` — exists() 경로 `ownerUserId_babyId`

**Acceptance Criteria**:

*Functional:*
- [ ] SharedBabyAccess.id가 `ownerUserId_babyId` 형식으로 생성됨
- [ ] fetchSharedAccess가 신형 + 구형 문서 모두 반환
- [ ] removeSharedAccess 메서드 존재
- [ ] checkDuplicateAccess 메서드 존재

*Static:*
- [ ] `xcodebuild build` 성공 (수정된 파일 컴파일)

*Runtime:*
- [ ] (Firestore 통합 테스트 불가 — H-1으로 대체)

**Verify**:
```yaml
acceptance:
  - given: ["ownerUserId='abc', babyId='def'"]
    when: "SharedBabyAccess 생성"
    then: ["id == 'abc_def'"]
  - given: ["구형 UUID 문서 + 신형 문서 공존"]
    when: "fetchSharedAccess 호출"
    then: ["양쪽 모두 반환, 구형은 마이그레이션 시작"]
commands:
  - run: "grep -n 'ownerUserId.*_.*babyId' BabyCare/Models/FamilyInvite.swift"
    expect: "exit 0"
  - run: "grep -n 'removeSharedAccess' BabyCare/Services/FirestoreService+Family.swift"
    expect: "exit 0"
risk: HIGH
```

---

### [x] TODO 3: ViewModel + View 수정

**Type**: work

**Required Tools**: (none)

**Inputs**:
- `model_file` (file): `${todo-2.outputs.model_file}`
- `service_file` (file): `${todo-2.outputs.service_file}`

**Outputs**:
- `viewmodel_files` (list): `["BabyCare/ViewModels/BabyViewModel.swift", "BabyCare/ViewModels/AuthViewModel.swift"]`
- `view_file` (file): `BabyCare/Views/Settings/FamilySharingView.swift`

**Steps**:
- [ ] `FamilySharingView.swift` joinFamily() 수정:
  - markInviteUsed를 saveSharedAccess 전이 아닌 후에 호출하되, 실패해도 참여는 성공으로 처리 (try? 사용)
  - 참여 전 checkDuplicateAccess 호출하여 중복 방지
  - 에러 핸들링: saveSharedAccess 실패 시에만 에러, markInviteUsed 실패는 무시
  - 성공 시 onJoin + dismiss 호출 보장
- [ ] `FamilySharingView.swift` — 공유된 아기 목록에 swipeActions(.destructive) 추가 → removeSharedAccess 호출
- [ ] `FamilySharingView.swift` — loadBabies 완료를 await한 후 dismiss (C-2 수정)
- [ ] `BabyViewModel.swift:50-56` — 공유 아기 로드 루프에서 개별 do-catch (1개 실패해도 나머지 계속)
- [ ] `BabyViewModel.swift` — async let으로 병렬화 (최대 3개)
- [ ] `AuthViewModel.swift:143` — subcollections 목록에서 `"familySharing"` → `"sharedAccess"` 수정
- [ ] `AuthViewModel.swift` — 앱 시작 시 `familySharing` 컬렉션 존재 확인 → `sharedAccess`로 복사 후 구형 삭제 (인라인 마이그레이션) 메서드 추가. `deleteAccount()` 에서 양쪽 컬렉션 모두 삭제

**Must NOT do**:
- FamilySharingView의 초대 코드 생성 로직은 변경하지 않을 것
- BabyViewModel의 자기 아기 로드 로직은 변경하지 않을 것
- git 명령 실행하지 않을 것

**References**:
- `FamilySharingView.swift:209-236` — JoinFamilySheet joinFamily()
- `BabyViewModel.swift:30-66` — loadBabies()
- `AuthViewModel.swift:140-161` — deleteUserData()

**Acceptance Criteria**:

*Functional:*
- [ ] joinFamily: markInviteUsed 실패해도 참여 성공 처리
- [ ] joinFamily: 중복 참여 시 에러 메시지 표시
- [ ] 공유 해제: swipeActions로 삭제 가능
- [ ] loadBabies: 1개 공유 아기 실패해도 나머지 정상 로드
- [ ] AuthViewModel: subcollection명 "sharedAccess"로 수정됨
- [ ] AuthViewModel: familySharing→sharedAccess 마이그레이션 메서드 존재

*Static:*
- [ ] `xcodebuild build` 성공

*Runtime:*
- [ ] (실기기 테스트 필요 — H-1으로 대체)

**Verify**:
```yaml
acceptance:
  - given: ["이미 참여한 공유 아기"]
    when: "같은 초대 코드로 재참여 시도"
    then: ["에러 메시지 표시, 중복 문서 생성 안 됨"]
  - given: ["공유된 아기 3개, 2번째 조회 실패"]
    when: "loadBabies 호출"
    then: ["1번째 + 3번째 아기 정상 로드"]
commands:
  - run: "grep -n 'sharedAccess' BabyCare/ViewModels/AuthViewModel.swift | grep -v familySharing"
    expect: "exit 0"
  - run: "grep -n 'removeSharedAccess' BabyCare/Views/Settings/FamilySharingView.swift"
    expect: "exit 0"
  - run: "grep -n 'checkDuplicate' BabyCare/Views/Settings/FamilySharingView.swift"
    expect: "exit 0"
risk: HIGH
```

---

### [x] TODO Final: Verification

**Type**: verification

**Required Tools**: xcodebuild, grep

**Inputs**:
- `rules_file` (file): `${todo-1.outputs.rules_file}`
- `model_file` (file): `${todo-2.outputs.model_file}`
- `service_file` (file): `${todo-2.outputs.service_file}`
- `viewmodel_files` (list): `${todo-3.outputs.viewmodel_files}`
- `view_file` (file): `${todo-3.outputs.view_file}`

**Outputs**: (none)

**Steps**:
- [ ] iPhone 빌드 확인
- [ ] iPad 빌드 확인
- [ ] 8개 결함 수정 확인 (grep으로 코드 패턴 검증)
- [ ] Firestore 규칙 일관성 확인

**Must NOT do**:
- Edit/Write 도구 사용 금지
- git 명령 실행 금지
- Bash로 파일 수정 금지

**Acceptance Criteria**:

*Functional:*
- [ ] firestore.rules에 isUsed 참여자 허용 조건 존재
- [ ] SharedBabyAccess.id가 ownerUserId_babyId 형식
- [ ] removeSharedAccess 메서드 존재
- [ ] checkDuplicateAccess 메서드 존재
- [ ] BabyViewModel loadBabies에 개별 catch 존재
- [ ] AuthViewModel subcollections에 "sharedAccess" 포함
- [ ] AuthViewModel에 familySharing 마이그레이션 로직 존재
- [ ] FamilySharingView에 swipeActions 공유 해제 존재

*Static:*
- [ ] `cd /Users/roque/BabyCare && xcodegen generate && xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet` → exit 0
- [ ] `xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M3)' -quiet` → exit 0

*Runtime:*
- [ ] (실기기 E2E 테스트 필요 — H-1, H-2)

**Verify**:
```yaml
commands:
  - run: "cd /Users/roque/BabyCare && xcodegen generate && xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | tail -5"
    expect: "exit 0"
  - run: "xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M3)' -quiet 2>&1 | tail -5"
    expect: "exit 0"
  - run: "grep -c 'removeSharedAccess\\|checkDuplicate\\|ownerUserId.*_.*babyId\\|sharedAccess\\|swipeActions' BabyCare/Services/FirestoreService+Family.swift BabyCare/Models/FamilyInvite.swift BabyCare/Views/Settings/FamilySharingView.swift BabyCare/ViewModels/AuthViewModel.swift"
    expect: "exit 0, multiple matches"
risk: LOW
```
