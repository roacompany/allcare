---
name: asc-submit
description: App Store Connect API 5-step 자동 제출 (버전 생성 → 빌드 링크 → release notes → 심사 제출 → submitted=true). "ASC 제출", "App Store 심사 제출", "v{X.Y.Z} 제출" 요청 시 사용.
---

# ASC Submit — App Store Connect API 5-step 자동화

`make deploy`로 TestFlight 업로드 완료 후 App Store 심사에 제출하는 5단계 (`reviewSubmissions` 신 API)를 한 번에 실행한다. 매 릴리스마다 인라인 Python 스크립트 재작성 30~40분 → 2분.

## 전제

- `make deploy` 완료 (TestFlight 업로드 + Apple processing → VALID)
- ASC API Key 셋업: `~/.appstoreconnect/private_keys/AuthKey_2LSXRAHPW7.p8`
- `python3 -c "import jwt, requests"` 가능

## 사용법

```
/asc-submit <version> <build_number> [release_notes_file]
```

예시:
```
/asc-submit 2.8.2 66
/asc-submit 2.8.2 66 .dev/release-notes/v2.8.2.md
```

`release_notes_file` 생략 시 인터랙티브 입력 (한국어 4000자 이내).

## 워크플로

### 0. 빌드 VALID 확인

먼저 빌드가 Apple processing 완료(VALID)됐는지 확인. 미완료 시 `wait-for-build` 명령 또는 polling 안내.

```python
GET /v1/builds?filter[app]={APP_ID}&limit=5&sort=-uploadedDate
# version=build_number, processingState=VALID 확인
```

### 1. AppStoreVersion 생성

```python
POST /v1/appStoreVersions
{
  "data": {
    "type": "appStoreVersions",
    "attributes": {
      "platform": "IOS",
      "versionString": "{version}",
      "releaseType": "AFTER_APPROVAL"
    },
    "relationships": {"app": {"data": {"type": "apps", "id": "{APP_ID}"}}}
  }
}
```

이미 같은 versionString이 존재하면 `409 conflict` → train closed (code 90186)이거나 이미 제출됨. 사용자에게 marketing version bump 안내.

### 2. Build Link

```python
PATCH /v1/appStoreVersions/{version_id}/relationships/build
{"data": {"type": "builds", "id": "{build_id}"}}
```

### 3. Release Notes (ko)

```python
GET /v1/appStoreVersions/{version_id}/appStoreVersionLocalizations
# locale=ko-KR 또는 ko로 시작하는 항목 찾기

PATCH /v1/appStoreVersionLocalizations/{loc_id}
{"data": {"type": "appStoreVersionLocalizations", "id": "{loc_id}",
  "attributes": {"whatsNew": "{ko 릴리스 노트}"}}}
```

### 4. Review Submission 생성 + Item 추가

```python
POST /v1/reviewSubmissions
{"data": {"type": "reviewSubmissions",
  "attributes": {"platform": "IOS"},
  "relationships": {"app": {"data": {"type": "apps", "id": "{APP_ID}"}}}}}

POST /v1/reviewSubmissionItems
{"data": {"type": "reviewSubmissionItems",
  "relationships": {
    "reviewSubmission": {"data": {"type": "reviewSubmissions", "id": "{sub_id}"}},
    "appStoreVersion": {"data": {"type": "appStoreVersions", "id": "{version_id}"}}
  }}}
```

### 5. Submit

```python
PATCH /v1/reviewSubmissions/{sub_id}
{"data": {"type": "reviewSubmissions", "id": "{sub_id}",
  "attributes": {"submitted": true}}}
```

성공 시 state = `WAITING_FOR_REVIEW`.

### 6. 검증 + 사용자 보고

```python
GET /v1/appStoreVersions/{version_id}
# attributes: appStoreState=WAITING_FOR_REVIEW, releaseType=AFTER_APPROVAL 확인
```

다음 정보 출력:
- ✅ versionId / submissionId / buildId
- ✅ state
- ✅ releaseType (대부분 AFTER_APPROVAL)
- 다음 단계: 12~48h 심사, 통과 시 자동 출시

## 인증 (JWT 생성)

```python
import jwt, time
from pathlib import Path

KEY_ID = '2LSXRAHPW7'
ISSUER = 'b70eb6de-e25a-47a1-8021-28872df65d61'
APP_ID = '6759935352'  # com.roacompany.allcare

def make_token():
    key = Path.home() / '.appstoreconnect/private_keys/AuthKey_2LSXRAHPW7.p8'
    return jwt.encode(
        {'iss': ISSUER, 'exp': int(time.time()) + 1200, 'aud': 'appstoreconnect-v1'},
        key.read_text(),
        algorithm='ES256',
        headers={'kid': KEY_ID, 'typ': 'JWT'}
    )

def headers():
    return {'Authorization': f'Bearer {make_token()}', 'Content-Type': 'application/json'}
```

각 단계마다 `headers()` 새로 호출 — 토큰 expire 방지.

## 에러 처리

| 응답 | 의미 | 조치 |
|---|---|---|
| `409 conflict` (versionString 중복) | 이미 같은 버전 존재 | marketing version bump 안내 |
| `code 90062` | "must contain a higher version than previously approved" | 같음. 최신 release 확인 후 bump |
| `code 90186` | "train closed for new submissions" | 같음. v{x.y.z+1}로 bump |
| `400 PARAMETER_ERROR` `sort` | sort 파라미터 미지원 엔드포인트 | sort 제거 |
| build still PROCESSING | Apple 처리 미완료 | `wait-for-build` 사용 또는 5분 후 재시도 |

## 참조

- ASC API docs: https://developer.apple.com/documentation/appstoreconnectapi/app_store/managing_app_store_versions/creating_a_version
- 메모리: BabyCare API Key (`~/.appstoreconnect/private_keys/AuthKey_2LSXRAHPW7.p8`, KEY_ID=2LSXRAHPW7, ISSUER=b70eb6de-...)
- 이전 사례: v2.8.0/v2.8.1/v2.8.2 모두 이 패턴으로 제출됨

## Out of Scope

- 처음 ASC App 등록은 별도 (이 skill은 기존 앱의 새 버전 제출만)
- 제출 취소(removeFromReview)는 별도 — 필요 시 ASC Console UI 권장
- 가격/카테고리/스크린샷 등 메타데이터 변경은 별도 (release notes만 갱신)
