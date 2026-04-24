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
