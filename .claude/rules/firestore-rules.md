---
globs: "**/Services/**,**/ViewModels/**"
---

# Firestore Rules

- 컬렉션명: 반드시 `FirestoreCollections.*` 상수 사용 (하드코딩 금지)
- 공유 아기 데이터: `babyVM.dataUserId()` 사용 필수 (authVM.currentUserId 직접 사용 금지)
- Firestore: 200MB persistent cache, 23개 컬렉션 상수 (+badges, +stats)
- 증분 카운터 필드 (FieldValue.increment + merge:true)는 반드시 `Int?` + `?? 0` 패턴 사용 — fresh user fetchStats decode 실패 방지
- 페이지네이션: 일기 커서/구매 limit/할일 필터
