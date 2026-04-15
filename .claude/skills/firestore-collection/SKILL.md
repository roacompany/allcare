---
name: firestore-collection
description: BabyCare iOS 프로젝트에 새 Firestore 컬렉션을 추가하는 3파일 스캐폴딩 (Constants.swift 상수, FirestoreService+X.swift 확장, Model X.swift). "새 Firestore 컬렉션 추가", "firestore collection scaffold", "Firestore CRUD 생성" 요청 시 사용.
---

# Firestore Collection Scaffolding

BabyCare 프로젝트에서 새 Firestore 컬렉션을 추가할 때 필요한 3개 파일을 표준 패턴으로 생성합니다. CryRecord/Badge/UserStats 패턴 준수.

## 사용법

```
/firestore-collection <CollectionName> [--subcollection=babies|users] [--shared]
```

- **CollectionName**: PascalCase (예: `DiaryTag`, `Achievement`). 컬렉션 문자열은 camelCase 복수형 자동 변환 (`diaryTags`, `achievements`).
- **--subcollection**: `babies`(기본) = `users/{uid}/babies/{babyId}/X`, `users` = `users/{uid}/X`
- **--shared**: 가족 공유 필요 시 `babyVM.dataUserId()` 사용. 생략 시 사용자별 private.

## 워크플로

### 1. Ask for Details (대화형)

사용자에게 확인:
- 컬렉션 이름 (PascalCase)
- 저장 경로 (아기별 vs 사용자별)
- 주요 필드 목록 (id, createdAt 제외)
- 가족 공유 여부
- 중복 방지 필요 여부 (badge 패턴처럼 dedup)

### 2. Constants.swift 수정

`BabyCare/Utils/Constants.swift`의 `FirestoreCollections` enum 끝에 추가:

```swift
static let {camelCase복수형} = "{camelCase복수형}"
```

⚠️ 하드코딩 문자열 금지. 반드시 상수.

### 3. Model 파일 생성

`BabyCare/Models/{Name}.swift`:

```swift
import Foundation

struct {Name}: Identifiable, Codable, Hashable {
    var id: String              // optional 권장 (Firestore merge 대응)
    var createdAt: Date
    // ... 사용자 지정 필드 (모두 optional 권장)

    // 증분 카운터 필드는 반드시 Int? + default 0 패턴
}
```

### 4. FirestoreService+{Name}.swift 생성

`BabyCare/Services/FirestoreService+{Name}.swift`:

**아기별 경로 (subcollection=babies)**:
```swift
import Foundation
import FirebaseFirestore

extension FirestoreService {
    func save{Name}(_ item: {Name}, userId: String, babyId: String) async throws {
        let ref = db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.{camelCase복수형})
            .document(item.id)
        try ref.setData(from: item)
    }

    func fetch{Name}s(userId: String, babyId: String) async throws -> [{Name}] {
        let snapshot = try await db.collection(FirestoreCollections.users)
            .document(userId)
            .collection(FirestoreCollections.babies)
            .document(babyId)
            .collection(FirestoreCollections.{camelCase복수형})
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: {Name}.self) }
    }
}
```

**사용자별 경로 (subcollection=users)**:
```swift
// 동일 패턴, babies/babyId 생략
// users/{uid}/{camelCase복수형}/{id}
```

**중복 방지 옵션 (--dedup)**:
```swift
@discardableResult
func save{Name}(_ item: {Name}, userId: String) async throws -> Bool {
    let ref = ...
    let snapshot = try await ref.getDocument()
    guard !snapshot.exists else { return false }
    try ref.setData(from: item)
    return true
}
```

### 5. XcodeGen 자동 인식 확인

`project.yml`은 `BabyCare/` 하위 `.swift` 파일 glob — 별도 등록 불필요. `make build` 통과 확인.

### 6. 테스트 append (선택)

`BabyCareTests/BabyCareTests.swift` 끝에 `// MARK: - {Name} Tests`:
- Codable round-trip
- FirestoreCollections 상수 문자열 검증

### 7. 규칙 준수 체크리스트

- ✅ `FirestoreCollections.*` 상수 사용 (하드코딩 금지)
- ✅ `babyVM.dataUserId()` 권장 (공유 아기 시) — `authVM.currentUserId` 직접 사용 금지
- ✅ 신규 필드 모두 optional (`var field: Type?`)
- ✅ 증분 카운터 `Int?` + `?? 0` (CR-001 교훈)
- ✅ `Identifiable, Codable, Hashable` 3 프로토콜 동시 채택
- ✅ `Milestone` 모델 혼동 금지 (별개 도메인)
- ✅ Firestore 스키마 변경 시 `/review` 필수 (`.claude/rules/review.md`)
- ✅ Firestore 보안 규칙 업데이트 필요 안내 (사용자 수동 작업)

### 8. Post-work 안내

- 🔴 **Firestore 보안 규칙** 업데이트 필수 (Firebase 콘솔 또는 `firestore.rules`):
  ```
  match /users/{uid}/.../{camelCase복수형}/{doc} {
      allow read, write: if request.auth.uid == uid;
  }
  ```
- `make verify` 통과 확인
- 기존 Firestore 문서 backward compat 확인 (optional 필드만 추가 시 자동 OK)

## 예시

```
User: "/firestore-collection Achievement --subcollection=users"

Skill 동작:
1. 필드 목록 질문
2. Constants.swift에 `static let achievements = "achievements"` 추가
3. Models/Achievement.swift 생성
4. Services/FirestoreService+Achievement.swift 생성 (users/{uid}/achievements 경로)
5. make build 검증
6. Firestore rules 업데이트 안내
```

## Reference

이 skill은 이번 세션(2026-04-15)의 sleep-location + badges Phase 1 경험에서 추출된 패턴입니다.
선례: `BabyCare/Models/CryRecord.swift`, `BabyCare/Services/FirestoreService+Badge.swift`, `BabyCare/Services/FirestoreService+Stats.swift`
