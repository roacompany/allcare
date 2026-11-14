# 가족 공유 규칙 구멍 닫기 — 설계

2026-11-08 · 상태: 구현 중(배포는 PO 승인) · 관련: firestore.rules, FamilySharing*

## 왜

라이브 배포본(2026-09-05, ruleset `fc1d73ac`)을 직접 받아 레포 `firestore.rules`와 대조 → **한 글자도 다르지 않음**. 아래 결함이 지금 손님에게 열려 있다.

**공격 (초대코드 불필요):**
1. 아무 계정으로 로그인.
2. `invites` read 규칙이 `auth != null` 뿐 → **컬렉션 전체를 list** 할 수 있다. 모든 미사용 초대의 `ownerUserId`·`babyId`·`babyName` 수집.
3. `users/{나}/sharedAccess/{docId}` write 규칙이 `auth.uid == userId`(본인 경로)뿐 → 수집한 `{ownerUserId}_{babyId}` 이름으로 **아무 내용의 sharedAccess 문서를 스스로 생성**.
4. 아기 공유 규칙(`match /babies/{babyId}`, 공유 블록)이 그 sharedAccess 문서의 `exists()`만 확인 → 통과.
5. → **남의 아기 activities/growth/diary… 전부 read+write.**

핵심: 초대코드(`code`)가 보안에 전혀 기여하지 못한다. 규칙이 code 소지를 강제하지 않기 때문.

## 목표 / 비목표

- **목표**: code를 가진 사람만 공유에 들어오게. 정상 가족·기존 공유는 그대로.
- **비목표**: 서버(Cloud Function) 도입(규칙만으로 충분). 초대 UX·code 길이 변경. FamilySharing의 narrow-protocol 리팩토링(별도).
- **안티골**: 이미 공유 중인 가족(기존 `sharedAccess`, `inviteCode` 필드 없음)이 깨지는 것.

## TO-BE — 규칙 (`firestore.rules`)

### 1. `match /invites/{code}` — 문서 ID = code
- `allow get: if request.auth != null;` (단건 — code를 알아야 조회)
- `allow list: if false;` **(신규 — 열거 차단)**
- `allow create: if auth != null && request.resource.data.ownerUserId == auth.uid && request.resource.data.code == code;` (문서ID=code 일관성)
- `allow update`: 기존 유지(owner, 또는 `isUsed`만 false→true)
- `allow delete: if auth != null && resource.data.ownerUserId == auth.uid;`

### 2. `match /sharedAccess/{docId}` (users/{userId} 하위) — 생성 시 교차검증
- `allow read, update, delete: if auth != null && auth.uid == userId;` (본인 공유 관리)
- `allow create: if auth != null && auth.uid == userId`
  - `&& docId == data.ownerUserId + "_" + data.babyId` (경로 위조 차단)
  - `&& data.inviteCode is string`
  - `&& exists(invites/$(data.inviteCode))`
  - `&& get(invites/$(data.inviteCode)).data.ownerUserId == data.ownerUserId`
  - `&& get(invites/$(data.inviteCode)).data.babyId == data.babyId`
  - `&& get(invites/$(data.inviteCode)).data.isUsed == false`
  - `&& get(invites/$(data.inviteCode)).data.expiresAt > request.time`
  - (document access 합계 5 < 10 한도)

### 3. `match /babies/{babyId}` 공유 블록 — **변경 없음**
`exists(sharedAccess/{owner}_{baby})` 그대로. 이제 sharedAccess가 위조 불가라 안전. 기존 공유(필드 없는 sharedAccess)도 `exists`는 참 → 유지.

## TO-BE — 앱 코드

- `SharedBabyAccess`: `var inviteCode: String?` 추가(optional·하위호환). 생성 시 항상 채움.
- `FirestoreService+Family.swift`:
  - `saveInvite` → `document(invite.code).setData(...)` (문서ID=code)
  - `findInviteByCode` → `document(code).getDocument()` + 존재·`isUsed==false` 검사(쿼리 → 단건 조회, list 안 씀)
  - `markInviteUsed(code:)` → `document(code)`
- `FamilySharingViewModel.joinFamily`: `SharedBabyAccess(..., inviteCode: code)` + `markInviteUsed(invite.code)`
- `FirestoreService+User.swift deleteAllUserData`: invites 정리(whereField list) **제거** — list 차단됨. 떠도는 초대는 owner 데이터 삭제 + 7일 만료로 무해.
- `FirestoreService+Baby.swift deleteBaby`: 같은 이유로 invites 정리 제거.

## 손님 영향

- 정상 수락(code 받아 입력): 동일. 수락 시 규칙이 code를 교차검증하는 것만 추가.
- 기존 공유 가족: 안 깨짐.
- **옛 미사용 초대(문서ID=UUID)**: 새 규칙에선 `document(code)` 경로로 안 찾혀 수락 불가 → 재발급 필요. 라이브 미사용 수는 구현 전 서비스계정으로 count(읽기만). 메모리 추정 ~1건.

## 테스트

- **Firestore rules 테스트**(`firestore-tests/`, @firebase/rules-unit-testing + 에뮬레이터): RED→GREEN.
  1. 침입자가 inviteCode 없이 sharedAccess create → `assertFails`
  2. 침입자가 틀린/없는 inviteCode로 create → `assertFails`
  3. `invites` list → `assertFails`
  4. 유효 초대로 가족이 sharedAccess create → `assertSucceeds`
  5. 소유자가 초대 create(docId==code) → `assertSucceeds`; 남의 ownerUserId로 create → `assertFails`
  6. 만료 초대로 create → `assertFails`
  7. isUsed=true 초대로 create → `assertFails`
  8. 기존 공유(inviteCode 없는 sharedAccess)로 아기 데이터 read → `assertSucceeds`(하위호환)
- **앱**: `make verify`(컴파일 + 기존 단위 + arch R1-4=0 + lint + design).

## 코드 리뷰 반영 (2026-11-08, 독립 리뷰어)

- **C1 (Critical) — 레거시 UUID sharedAccess 마이그레이션 소멸**: `fetchSharedAccess`(FirestoreService+Family.swift)가 2026-03-23(313e01c) 이전 UUID-keyed 공유를 composite 로 옮길 때 비대기 `setData(from:)` 를 썼다. 강화된 create 규칙이 inviteCode 없는 composite 를 거부하는데 비대기라 catch 가 안 돌고, 바로 뒤 `await delete()` 로 원본만 지워져 **공유가 소멸**. → `await` 로 고쳐 거부를 잡고 원본 보존(소멸 방지). ⚠️ 2026-11-14 정정: `setData(from:)`(Codable 판)는 동기라 `await` 가 아무것도 기다리지 않았다 — 거부는 계속 삼켜졌다. 서버 확인 쓰기(`setDataConfirmed`)로 다시 고침. 레거시 가족을 **되살리는 것**은 아래 배포 절차 ①(서버 마이그레이션).
- **I1 (Important) — 삭제 시 invites 잔존**: 만료(`expiresAt`)는 사용 불가일 뿐 문서 삭제가 아니다(TTL 정책 부재 확인). 계정/아기 삭제 시 babyName 이 영구 잔존. → 배포 절차 ②(TTL 정책)로 해소.
- **I2 (Important) — create 거부 안 보임**: `saveSharedAccess`·`saveInvite` 가 비대기 `setData` 라 서버 거부를 앱이 성공으로 오인. → `await` 로 고침.
- Minor: code 충돌 재시도 없음(M1, await 로 표면화됨) · get 단건 brute-force(M2, 비범위) · markInviteUsed best-effort(M3) · owner 취소 불가(M4, 기존) · 테스트 갭(M5, 하위호환 update/delete 테스트 추가).

## 배포 절차 (PO 승인 · 순서 중요)

**① (C1) 레거시 sharedAccess 서버 마이그레이션 — 규칙 배포 "전"**
```bash
cd firestore-tests && npm install   # firebase-admin 포함
SA="$(grep '^FIREBASE_SERVICE_ACCOUNT=' /Users/roque/babycare-admin/.env.local | cut -d= -f2-)"
FIREBASE_SERVICE_ACCOUNT="$SA" node migrate-sharedaccess-composite.mjs            # dry-run: 몇 건인지 확인
FIREBASE_SERVICE_ACCOUNT="$SA" node migrate-sharedaccess-composite.mjs --apply     # 실제 변환(멱등)
```
`legacyUuidFound` 가 0이면 휴면 레거시 없음(무해). 0이 아니면 그 수만큼 구제됨.

**② (I1) invites TTL 정책 — 만료 초대 자동 삭제**
```bash
gcloud firestore fields ttls update expiresAt --collection-group=invites --enable-ttl --project=babycare-allcare   # ⚠️ `ttls`(복수) · 결제(Blaze) 켜진 프로젝트만 — 2026-11-10 「billing disabled」로 막힘 → 앱의 deleteMyInvites 로 대신(2026-11-14)
```
(또는 Firebase 콘솔 › Firestore › TTL 에서 `invites.expiresAt` 등록.)

**③ 규칙 + 앱 배포**
```bash
make deploy-rules   # firestore.rules (idempotent)
```
앱은 다음 TF/스토어 판에 포함. ⚠️ ①②를 건너뛰고 규칙만 배포하면 C1(휴면 가족 공유 소멸 방지는 코드로 되지만 되살리기 안 됨)·I1 미해소.

**참고**: 옛 미사용 초대(문서ID=UUID)는 새 규칙에서 수락 불가 → 재발급 필요. 라이브 미사용 수는 ①의 dry-run 출력(`invites` 아님 — 별도 확인 시 count 스크립트)으로 파악.

승인 전까지 로컬만. push·커밋·배포 모두 PO 승인.

## 2026-11-14 보완 — 소유자는 「자기 초대」만 목록으로 (미배포 · 배포는 PO 승인)

- 사실(11/14 에뮬레이터): 11/11 배포 뒤 2.8.13(손님 판)의 **아기 삭제 끝 초대 정리 조회**(ownerUserId·babyId 조건 목록)가
  `allow list: if false` 에 막혀 던졌다 → 아기는 지워졌는데 「아기 삭제에 실패했습니다.」 + 목록에 다시 뜸 + 사진 정리 건너뜀.
  계정 삭제 끝의 같은 조회도 막혔다(계정 삭제는 그와 별개로 3월부터 기록을 못 지운다 — 앱 고침은 2.8.14).
- 고침: `allow list: if request.auth != null && resource.data.ownerUserId == request.auth.uid;`
  조건이 「나」인 목록만 열린다 — 남의 초대 열거(원래 구멍)는 계속 막힌다(시험 3·O3·O4·O5).
- 시험: firestore-tests O1~O5 · 규칙을 일부러 느슨하게 바꾼 두 판(로그인만 하면 전부 · 로그인 없이)에서 각각 빨강 확인.
- 배포 순서: 규칙을 **푸는** 쪽이라 앱보다 먼저 나가도 어느 판에도 해가 없다(2.8.13 아기 삭제가 바로 살아난다).
