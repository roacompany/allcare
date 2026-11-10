---
globs: "**/Services/**,**/ViewModels/**,**/firestore.rules,**/firestore-tests/**"
---

# Firestore Rules

- 컬렉션명: 반드시 `FirestoreCollections.*` 상수 사용 (하드코딩 금지)
- 공유 아기 데이터: `babyVM.dataUserId()` 사용 필수 (authVM.currentUserId 직접 사용 금지)
- Firestore: 200MB persistent cache, 30개 컬렉션 상수 (24기본 + 6 pregnancy 코드 보존, UI hidden)
- 증분 카운터 필드 (FieldValue.increment + merge:true)는 반드시 `Int?` + `?? 0` 패턴 사용 — fresh user fetchStats decode 실패 방지
- 페이지네이션: 일기 커서/구매 limit/할일 필터

## collectionGroup 규칙

- **collectionGroup match는 top-level `match /databases/{database}/documents` scope 필수**. `match /users/{uid}` 중첩 내부 배치 시 silent fail (배포는 되지만 매칭 안 됨). pregnancy-mode-v2 P0-5 확인.
  ```
  match /databases/{db}/documents {
    match /{path=**}/pregnancies/{pid} {
      allow read: if request.auth != null
        && resource.data.sharedWith is list
        && request.auth.uid in resource.data.sharedWith;
    }
  }
  ```
- **`arrayContains + whereField` (no order) 쿼리는 COLLECTION_GROUP index 수동 추가**. `scripts/index_check.py`는 `.whereField + .order` 조합만 스캔 — arrayContains-only는 못 잡음. `firestore.indexes.json`에 `{collectionGroup: "...", queryScope: "COLLECTION_GROUP", fields: [arrayContains, whereField]}` 수동 등록 필수.
- **`FieldValue.delete()`는 FIELD 제거, 문서 보존**. rollback 패턴 (예: transitionState 필드만 제거)에 안전. 문서 삭제는 `ref.delete()` (다른 API). 혼동 금지.
- **`make deploy-rules`는 idempotent**: 배포된 상태에서 재실행 exit 0. 머지 전 안전망으로 항상 실행 가능.

## Narrow Protocol 5단계 패턴 (ISP)

신규 Firestore 컬렉션 추가 또는 기존 호출의 의존성 역전 시 반드시 5단계 완료:

1. **`FirestoreCollections.X`** 상수 추가 (`Utils/Constants.swift`) — 컬렉션명 하드코딩 금지
2. **`FirestoreService+X.swift`** 확장 파일 생성 (`Services/`) — 내부에서만 `Firestore.firestore()` 호출, `db` 프로퍼티 사용
3. **`XFirestoreProviding`** narrow protocol 정의 (같은 파일 상단) — VM이 의존할 메서드만 선언, `Sendable` 채택
4. **`extension FirestoreService: XFirestoreProviding {}`** 채택 선언 — 동일 파일 내
5. **`BabyCareTests/MockXFirestore.swift`** 생성 — `@unchecked Sendable`, in-memory 스토어 + 호출 카운터 + 에러 주입

ViewModel / Service init 에 `provider: XFirestoreProviding = FirestoreService.shared` default 주입.

완성 11종 참고: PregnancyFirestoreProviding / BadgeFirestoreProviding / HighlightFirestoreProviding / CryFirestoreProviding / AuthMigrationProviding / StorageServiceProviding / FCMTokenFirestoreProviding / CatalogFirestoreProviding / SoundFirestoreProviding / AnalysisFirestoreProviding / OfflineQueueFirestoreProviding.

**arch-test Rule 3 baseline = 0**: 단계 누락 시 `bash scripts/arch_test.sh` FAIL. `Firestore.firestore()` 직접 호출은 `Services/FirestoreService*.swift` + `App/BabyCareApp.swift` (앱 초기화 settings) 외 금지.

**`[String: Any]` Sendable 차단**: protocol 시그니처에 `[String: Any]` 노출 금지 (Swift 6 Sendable 위반). 직렬화 로직은 FirestoreService extension 내부에 격리 (OfflineQueue 의 PendingOperation 패턴 참조).

## 보안 규칙(firestore.rules)을 조일 때 — 기존 데이터·기존 쓰기 경로부터 센다 (2026-11-08, 가족 공유)

규칙을 조이면 **새 규칙이 거부하는 옛 문서·옛 쓰기 코드**가 조용히 깨진다. 배포 전에 아래를 확인한다. (상세 사례 = 홈 메모리 `learning_tighten_rules_check_migration_paths`)

- **라이브 규칙을 먼저 받아 대조한다.** 저장소 `firestore.rules` 가 아니라 배포본 기준으로 결함을 확정한다 (`gcloud auth print-access-token` + Rules REST API `firebaserules.googleapis.com/v1/projects/<id>/releases/cloud.firestore` → rulesetName → `/rulesets/<name>`, 또는 `make rules-drift`). 파일이 프로덕션보다 낡았을 수 있다.
- **옛 형식 데이터를 새 규칙으로 쓰는 코드를 전수 grep.** Critical 사례(2026-11-08): 레거시 UUID-문서ID `sharedAccess` 를 복합ID 로 옮기는 마이그레이션(`fetchSharedAccess`)이 강화된 create 규칙에 거부됐다. 쓰기가 **비대기**였고 뒤이은 `delete` 는 성공해 **공유가 소멸**했다. 옛 데이터가 라이브에 있으면 **규칙 배포 전에 서버(Admin SDK)에서 변환**한다(`firestore-tests/migrate-sharedaccess-composite.mjs`, 멱등·dry-run).
- **쓰기 뒤 삭제 순서(setData → delete)는 쓰기를 `await` 한다.** 규칙 거부가 한 번이라도 가능한 경로에서 비대기 `try ref.setData(from:)`(completion 없이 던지기)는 PERMISSION_DENIED 를 안 던진다 — 서버 거부가 화면·로그 어디에도 안 보인다. `try await ref.setData(from:)`(async 오버로드, 선례 `FirestoreService+Allergy`)로 거부를 받고, 실패하면 삭제 단계로 넘어가지 말 것.
- **개인정보 담은 임시 문서(초대·토큰)는 TTL 을 같이 건다.** 만료(`expiresAt`) 필드는 규칙으로 "사용 불가"만 만들 뿐 문서를 **지우지 않는다**. 클라이언트 삭제는 계정 삭제·앱 종료 때 빠진다(이번엔 `invites` 에 `babyName` 영구 잔존). `gcloud firestore fields ttl update expiresAt --collection-group=invites --enable-ttl` 를 배포 순서에 넣는다.
- **규칙은 에뮬레이터 테스트로 RED(침입)를 먼저.** `firestore-tests/rules.test.mjs` 에 막혀야 하는 침입(`assertFails`)과 통과해야 하는 정상·하위호환(`assertSucceeds`)을 함께 — 막는 것만 재면 「전부 막는」 규칙도 초록이다. 실행 = `make rules-test`(Java 21 필요). 변경 후 RED→GREEN 확인하고 `make deploy-rules`.
- **배포 순서:** ① 레거시 데이터 서버 변환 → ② TTL 정책 → ③ 규칙 + 앱. 규칙이 먼저 나가면 **옛 앱 버전의 가족 공유가 끊긴다**(앱 최소 지원 버전 확인).
