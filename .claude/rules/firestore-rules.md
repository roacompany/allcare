---
globs: "**/Services/**,**/ViewModels/**"
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
