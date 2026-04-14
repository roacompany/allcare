---
globs: "**/Services/**,**/ViewModels/**"
---

# Firestore Rules

- 컬렉션명: 반드시 `FirestoreCollections.*` 상수 사용 (하드코딩 금지)
- 공유 아기 데이터: `babyVM.dataUserId()` 사용 필수 (authVM.currentUserId 직접 사용 금지)
- Firestore: 200MB persistent cache, 21개 컬렉션 상수
- 페이지네이션: 일기 커서/구매 limit/할일 필터
