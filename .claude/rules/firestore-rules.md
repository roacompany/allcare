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
- **규칙이 거부할 수 있는 쓰기는 서버 확인 쓰기로.** `ref.setData(from:)`(Codable 판)는 Firebase 11.9 에서 **동기 함수**라 `try await` 를 붙여도 서버를 기다리지 않고 PERMISSION_DENIED 도 던지지 않는다(SDK `DocumentReference+WriteEncodable.swift` · 컴파일러 경고 「no 'async' operations occur within 'await' expression」가 그 표시). 🩸 2026-11-14: #88 이 「await 로 거부를 받는다」던 초대·공유·레거시 이전 3곳이 전부 거부를 삼키고 있었다. → `setDataConfirmed(_:at:)` · `updateDataConfirmed(_:at:)`(FirestoreService+ConfirmedWrite — 서버 답을 기다리고 거부를 던지고 15초면 `.timedOut`)를 쓴다. 쓰기 뒤 삭제(setData → delete)는 확인 쓰기가 성공한 뒤에만 삭제한다.
  ⚠️ **시간 초과는 「안 들어갔다」가 아니다** — Firestore 는 그 쓰기를 기기에 남겼다가 망이 돌아오면 보낸다. 「실패」라고 알릴 **새 문서**(초대·공유)는 `createConfirmed`(시간 초과면 지우기를 뒤에 세워 거둔다)로 쓴다 — 있던 문서를 덮어쓰는 데는 쓰지 말 것(거두면 있던 것까지 지운다). 지우기 묶음·문서 지우기는 `commitConfirmed`·`deleteConfirmed`(async 판 commit/delete 는 망이 끊기면 끝없이 기다린다 · 2026-11-14 검토).
- **개인정보 담은 임시 문서(초대·토큰)는 TTL 을 같이 건다.** 만료(`expiresAt`) 필드는 규칙으로 "사용 불가"만 만들 뿐 문서를 **지우지 않는다**. 클라이언트 삭제는 계정 삭제·앱 종료 때 빠진다(이번엔 `invites` 에 `babyName` 영구 잔존). TTL 명령은 `gcloud firestore fields ttls update expiresAt --collection-group=invites --enable-ttl`(`ttl` 아님) — ⚠️ **결제(Blaze)가 켜진 프로젝트만** 된다. 베이비케어는 무료라 막혔다(2026-11-10 「billing disabled」) → 대신 앱이 아기·계정 삭제 때 「내 초대」를 지운다(`deleteMyInvites` · 소유자 목록 규칙 2026-11-14).
- **규칙은 에뮬레이터 테스트로 RED(침입)를 먼저.** `firestore-tests/rules.test.mjs` 에 막혀야 하는 침입(`assertFails`)과 통과해야 하는 정상·하위호환(`assertSucceeds`)을 함께 — 막는 것만 재면 「전부 막는」 규칙도 초록이다. 실행 = `make rules-test`(Java 21 필요). 변경 후 RED→GREEN 확인하고 `make deploy-rules`.
- **배포 순서:** ① 레거시 데이터 서버 변환 → ② TTL 정책 → ③ 규칙 + 앱. 「규칙 + 앱」은 동시에 못 나간다(앱은 심사·업데이트를 거친다) — **조이는 규칙은 맞춘 앱이 손님에게 퍼진 뒤**, 푸는 규칙은 먼저 나가도 된다. 🩸 2026-11-11: 「규칙 먼저 금지」를 「①②보다 먼저」로 읽고 조이는 규칙을 앱보다 먼저 배포해, 손님 판(2.8.13)의 초대 만들기·받기와 아기·계정 삭제 끝 정리가 막혔다.
- **조이기 전에 옛 판 요청 시험부터.** `firestore-tests/rules.app-<판>.test.mjs` = 손님 기기에 남은 판이 보내는 요청(그 판 출시 커밋 코드에서 옮김)과 「그 판 손님에게 맞는 동작」. 바꾼 규칙에서 이게 빨강이면 옛 판이 깨진다. 새 판이 나가면 같은 꼴로 더한다.
- **실제 Swift 코드는 `make emulator-test`** — 아이폰 SDK 를 레포 규칙이 걸린 에뮬레이터에 태운다(웹 SDK 규칙 시험이 못 보는 Codable 칸·서버 확인 쓰기·지우기 범위를 본다).
- **새 컬렉션은 지우기 범위에 선언.** `FirestoreCollections` 의 `userChildren`·`babyChildren`·`pregnancyChildren`(+`topLevel`·`scopeParents`·`unreachableLegacy`) — 아기·계정 삭제가 이 목록만 본다. `make data-layout-check` 가 코드의 `.collection(...)` 을 **부모에 맞는 목록**(users→userChildren · babies→babyChildren · pregnancies→pregnancyChildren · 최상위→topLevel)과 대조한다 — 「어느 목록에든 있으면 통과」는 아기 밑 이름을 사용자 목록에 적어도 초록이었다(2026-11-14). 끝 줄의 「부모까지 N · 이름만 M」으로 무엇을 쟀는지 본다.
