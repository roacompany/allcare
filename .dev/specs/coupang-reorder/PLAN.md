# 쿠팡 파트너스 재주문 시스템 재설계

> 카탈로그 기반 용품 등록 + 쿠팡 파트너스 1:1 매칭 재주문 + Admin 카탈로그 관리
> Mode: standard/interactive

## Assumptions

| Decision Point | Assumed Choice | Rationale | Source |
|---------------|---------------|-----------|--------|
| productRequests | MVP에서 별도 컬렉션 없음, Admin에서 기존 products 쿼리 | 쓰기 오버헤드 제거, 10K 이하 사용자 기준 | tradeoff-analyzer |
| Rules 배포 | iOS 릴리즈 전에 rules 별도 배포 | 규칙 오류 시 기존 사용자 영향 방지 | tradeoff-analyzer DP-02 |
| 카탈로그 검색 | 전체 1회 fetch + 로컬 필터 | 카탈로그 수백 개 이하, Firestore 검색 불필요 | tradeoff-analyzer |
| 태그 매칭 | AddProductView 인라인 제안만 | retroactive 알림 불필요, 복잡도 감소 | tradeoff-analyzer |
| AFFTDP URL | fallback 유지 | 기존 상품 호환성 | tradeoff-analyzer |

## Verification Summary

### Agent-Verifiable (A-items)
| ID | Criterion | Method | Related TODO |
|----|-----------|--------|-------------|
| A-1 | iPhone 빌드 성공 | xcodebuild | TODO Final |
| A-2 | iPad 빌드 성공 | xcodebuild | TODO Final |
| A-3 | Admin 빌드 성공 | npm run build | TODO Final |
| A-4 | Firestore rules 문법 정상 | firebase deploy --only firestore:rules --dry-run | TODO 1 |

### Human-Required (H-items)
| ID | Criterion | Reason |
|----|-----------|--------|
| H-1 | 카탈로그에서 상품 선택 후 재주문 버튼 작동 | 쿠팡 파트너스 URL 실기기 테스트 |
| H-2 | Admin 카탈로그 CRUD 정상 작동 | 웹 UI 수동 테스트 |
| H-3 | 직접 입력 상품에 "이 상품인가요?" 제안 표시 | UX 시나리오 테스트 |

### Verification Gaps
- 쿠팡 파트너스 URL 유효성은 실기기에서만 확인 가능

## External Dependencies Strategy

### Pre-work
| Dependency | Action | Command/Step | Blocking? |
|------------|--------|-------------|-----------|
| Firebase CLI | 이미 설치됨 | firebase --version | No |
| Admin 로컬 실행 | npm install | cd /Users/roque/babycare-admin && npm install | Yes |

### Post-work
| Task | Action | Command/Step |
|------|--------|-------------|
| Firestore rules 배포 | 프로덕션 규칙 배포 | firebase deploy --only firestore:rules |
| Admin 배포 | Vercel 배포 | cd /Users/roque/babycare-admin && vercel --prod |
| 카탈로그 초기 데이터 | Admin에서 30~40개 인기 용품 등록 | 수동 |

## Context

### Original Request
쿠팡 파트너스 링크가 작동하지 않는 문제 해결 + 재주문 자동화 재설계

### Interview Summary (Discussion Insights)
- **카탈로그 기반**: Admin이 인기 용품 + 쿠팡 파트너스 링크 사전 등록
- **두 가지 등록**: 카탈로그 선택 (재주문 O) + 직접 입력 (재주문 X)
- **크라우드소싱**: 직접 입력 → Admin에서 인기순 확인 → 카탈로그 등록
- **자동 제안**: 태그 기반 "이 상품인가요?" 인라인 제안
- **사용자 부담 제로**: URL 복사, 검색 없음

### Research Findings
- AFFTDP URL → 500 에러 (쿠팡 서버 변경)
- BabyProduct 모델에 catalogId/coupangURL 필드 없음
- Admin에 용품 관리 페이지 없음
- RecommendedProduct.swift의 matchScore 로직 재활용 가능

## Work Objectives

### Core Objective
재고 부족 시 쿠팡 파트너스 링크로 동일 상품 1:1 재주문이 가능한 시스템 구축

### Concrete Deliverables
- Firestore `productCatalog` 컬렉션 + rules
- iOS `CatalogProduct` 모델
- iOS `CatalogService` (fetch + 로컬 필터 + 태그 매칭)
- iOS `AddProductView` 재설계 (카탈로그 검색/선택 + 직접 입력)
- iOS 재주문 버튼 (coupangURL 기반)
- Admin `/catalog` 페이지 (CRUD)
- Admin `/catalog/requests` 페이지 (직접 입력 상품 인기순)
- Dead code 삭제 (RecommendedProduct, AFFTDP)

### Definition of Done
- [ ] 카탈로그 상품 선택 → 재주문 버튼 → 쿠팡 열림
- [ ] 직접 입력 상품 → 재주문 버튼 없음
- [ ] Admin에서 카탈로그 CRUD 가능
- [ ] Admin에서 직접 입력 상품 인기순 조회 가능
- [ ] xcodebuild iPhone + iPad 성공

### Must NOT Do
- Cloud Functions 사용하지 않을 것
- 사용자에게 URL 입력 요구하지 않을 것
- 기존 BabyProduct 데이터를 삭제하거나 마이그레이션하지 않을 것 (optional 필드 추가만)
- git 명령 실행하지 않을 것

---

## Task Flow

```
TODO-1 (Firestore) ─┐
TODO-2 (iOS 모델)  ──┼── TODO-3 (iOS UI) → TODO-Final
TODO-4 (Admin)    ───┘
```

## Dependency Graph

| TODO | Requires | Produces | Type |
|------|----------|----------|------|
| 1 | - | rules_file | work |
| 2 | - | catalog_model, catalog_service, baby_product, constants | work |
| 3 | TODO-2 outputs | add_product_view, purchase_sections, product_viewmodel, product_viewmodel_crud | work |
| 4 | - | catalog_page, requests_page | work |
| Final | all outputs | - | verification |

## Parallelization

| Group | TODOs | Reason |
|-------|-------|--------|
| A | TODO-1, TODO-2, TODO-4 | Rules, 모델/서비스, Admin 병렬 가능 |
| B | TODO-3 | TODO-2에 의존 |

## Commit Strategy

| After TODO | Message | Files |
|------------|---------|-------|
| 1 | `feat: Firestore productCatalog 컬렉션 + rules` | firestore.rules |
| 2 | `feat: CatalogProduct 모델 + CatalogService + BabyProduct 확장` | Models/, Services/ |
| 3 | `feat: AddProductView 카탈로그 선택 + 재주문 버튼 개선` | Views/Products/ |
| 4 | `feat: Admin 카탈로그 관리 + 요청 목록 페이지` | babycare-admin/ |

## Error Handling

| Scenario | Action |
|----------|--------|
| work fails | Retry up to 2x → Analyze → Fix or halt |
| verification fails | Analyze → Fix or halt |

## Runtime Contract

| Aspect | Specification |
|--------|---------------|
| Working Directory | /Users/roque/BabyCare (iOS), /Users/roque/babycare-admin (Admin) |
| Network Access | Denied (iOS), Allowed (Admin npm install) |
| Package Install | Denied (iOS), Allowed (Admin) |
| Git Operations | Denied |

---

## TODOs

### [x] TODO 1: Firestore 스키마 + Rules

**Type**: work

**Inputs**: (none)

**Outputs**:
- `rules_file` (file): `firestore.rules`

**Steps**:
- [ ] firestore.rules에 `productCatalog` 컬렉션 규칙 추가 (인증 사용자 read, admin만 write)
- [ ] Firestore 컬렉션 스키마 정의:
  ```
  productCatalog/{id}:
    name: String
    brand: String
    category: String (ProductCategory rawValue)
    coupangURL: String
    imageURL: String?
    tags: [String]  // 매칭용 키워드
    createdAt: Timestamp
    updatedAt: Timestamp
  ```

**Must NOT do**:
- 기존 rules의 다른 컬렉션 규칙 변경하지 않을 것
- git 명령 실행하지 않을 것

**References**:
- `firestore.rules` 전체
- `BabyCare/Utils/Constants.swift:65-82` — FirestoreCollections

**Acceptance Criteria**:

*Functional:*
- [ ] productCatalog: 인증 사용자 read 허용
- [ ] productCatalog: admin UID만 write 허용

*Static:*
- [ ] `cat firestore.rules | python3 -c "import sys; print('OK' if 'productCatalog' in sys.stdin.read() else 'FAIL')"` → OK

*Runtime:*
- [ ] `firebase deploy --only firestore:rules --dry-run 2>&1 | grep -q 'compiled successfully'` → exit 0

---

### [x] TODO 2: iOS 모델 + 서비스

**Type**: work

**Inputs**: (none)

**Outputs**:
- `catalog_model` (file): `BabyCare/Models/CatalogProduct.swift`
- `catalog_service` (file): `BabyCare/Services/CatalogService.swift`
- `baby_product` (file): `BabyCare/Models/BabyProduct.swift`
- `constants` (file): `BabyCare/Utils/Constants.swift`

**Steps**:
- [ ] `CatalogProduct` 모델 생성: id, name, brand, category, coupangURL, imageURL, tags[], createdAt
- [ ] `CatalogService` 생성:
  - `fetchCatalog() async throws -> [CatalogProduct]` — productCatalog 전체 fetch
  - `findMatches(userText: String, category: ProductCategory, catalog: [CatalogProduct]) -> [CatalogProduct]` — 태그 2개+ 매칭
- [ ] `BabyProduct`에 optional 필드 추가: `catalogId: String?`, `coupangURL: String?`
- [ ] `Constants.swift` FirestoreCollections에 `productCatalog` 추가
- [ ] Dead code 삭제: `RecommendedProduct.swift`, `RecommendedProductsSection.swift` + 이 파일을 import/참조하는 코드가 있으면 해당 참조도 제거
- [ ] `CoupangAffiliateService.swift` 수정: `reorderURL(for product: BabyProduct) -> URL?` — coupangURL 우선, 없으면 searchURL fallback

**Must NOT do**:
- 기존 BabyProduct의 다른 필드 변경하지 않을 것
- git 명령 실행하지 않을 것

**References**:
- `BabyCare/Models/BabyProduct.swift`
- `BabyCare/Models/RecommendedProduct.swift` (삭제 대상, matchScore 로직 참고)
- `BabyCare/Services/CoupangAffiliateService.swift`

**Acceptance Criteria**:

*Functional:*
- [ ] CatalogProduct 모델 존재, Codable
- [ ] CatalogService.fetchCatalog() 존재
- [ ] CatalogService.findMatches() 태그 매칭 동작
- [ ] BabyProduct에 catalogId, coupangURL optional 필드
- [ ] RecommendedProduct.swift 삭제됨
- [ ] reorderURL: coupangURL 우선, searchURL fallback

*Static:*
- [ ] `cd /Users/roque/BabyCare && xcodegen generate && xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1; test $? -eq 0` → exit 0

*Runtime:*
- [ ] SKIP — iOS 단위 테스트 미구성; H-1, H-3 수동 검증으로 대체

---

### [x] TODO 3: iOS UI 재설계

**Type**: work

**Inputs**:
- `catalog_model` (file): `${todo-2.outputs.catalog_model}`
- `catalog_service` (file): `${todo-2.outputs.catalog_service}`

**Outputs**:
- `add_product_view` (file): `BabyCare/Views/Products/AddProductView.swift`
- `purchase_sections` (file): `BabyCare/Views/Products/ProductDetail+PurchaseSections.swift`
- `product_viewmodel` (file): `BabyCare/ViewModels/ProductViewModel.swift`
- `product_viewmodel_crud` (file): `BabyCare/ViewModels/ProductViewModel+CRUD.swift`

**Steps**:
- [ ] `AddProductView` 재설계:
  - 상단: 검색바 (카탈로그 내 로컬 필터)
  - 카테고리 탭 필터
  - 카탈로그 상품 목록 (탭하면 선택 → 이름/브랜드/카테고리 자동 채움 + catalogId/coupangURL 저장)
  - 하단: "찾는 상품이 없나요? 직접 입력하기" 버튼 → 기존 폼으로 전환
  - 직접 입력 시: 카탈로그에서 태그 매칭 → "이 상품인가요?" 인라인 제안
- [ ] `ProductDetail+PurchaseSections` 수정:
  - "쿠팡에서 검색" → "재주문" (coupangURL 있을 때만)
  - coupangURL 없으면 기존 searchURL fallback 버튼 유지
  - 저재고 배너에서 "재주문" 버튼 강조
- [ ] `ProductViewModel` 수정:
  - `catalog: [CatalogProduct]` 캐시
  - `loadCatalog()` — 앱 시작 시 1회 fetch
  - `selectedCatalogProduct: CatalogProduct?` — 카탈로그 선택 상태
  - `addProduct()` 수정: selectedCatalogProduct 있으면 catalogId/coupangURL 자동 설정
- [ ] 파트너스 수수료 고지: 재주문 버튼 아래 caption2로 "쿠팡 파트너스 활동의 일환으로 일정액의 수수료를 제공받습니다."

**Must NOT do**:
- 기존 상품 데이터 마이그레이션하지 않을 것
- 카탈로그에 없는 상품의 기존 기능을 제거하지 않을 것
- git 명령 실행하지 않을 것

**References**:
- `BabyCare/Views/Products/AddProductView.swift`
- `BabyCare/Views/Products/ProductDetail+PurchaseSections.swift`
- `BabyCare/ViewModels/ProductViewModel.swift`
- `BabyCare/ViewModels/ProductViewModel+CRUD.swift`

**Acceptance Criteria**:

*Functional:*
- [ ] AddProductView에 검색바 + 카탈로그 목록 표시
- [ ] 카탈로그 상품 탭 → 이름/브랜드/카테고리 자동 채움
- [ ] 직접 입력 시 "이 상품인가요?" 제안 표시
- [ ] 재주문 버튼: coupangURL 있으면 활성, 없으면 fallback
- [ ] 파트너스 수수료 고지 텍스트 표시

*Static:*
- [ ] `cd /Users/roque/BabyCare && xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1; test $? -eq 0` → exit 0

*Runtime:*
- [ ] SKIP — iOS 단위 테스트 미구성; H-1, H-3 수동 검증으로 대체

---

### [x] TODO 4: Admin 카탈로그 관리

**Type**: work

**Inputs**: (none — Admin은 독립 프로젝트)

**Outputs**:
- `catalog_page` (file): `babycare-admin/app/(admin)/catalog/page.tsx`
- `requests_page` (file): `babycare-admin/app/(admin)/catalog/requests/page.tsx`

**Steps**:
- [ ] `/catalog` 페이지:
  - 카탈로그 상품 목록 (테이블: 이름, 브랜드, 카테고리, 쿠팡 링크, 태그)
  - 상품 추가 다이얼로그 (이름*, 브랜드*, 카테고리*, 쿠팡 URL*, 이미지 URL, 태그 입력)
  - 상품 수정/삭제
  - Firestore `productCatalog` CRUD
- [ ] `/catalog/requests` 페이지:
  - 사용자가 직접 입력한 상품 목록 (Firestore `users/*/products` where catalogId == null 쿼리)
  - 상품명 기준 그룹핑 + 카운트 (인기순 정렬)
  - "카탈로그에 추가" 버튼 → /catalog 추가 폼으로 이동
- [ ] 사이드바에 "카탈로그" 메뉴 추가 (하위: "상품 관리", "요청 목록")

**Must NOT do**:
- Admin의 기존 기능 (공지, 푸시, 사용자) 변경하지 않을 것
- git 명령 실행하지 않을 것

**References**:
- `/Users/roque/babycare-admin/app/(admin)/announcements/page.tsx` — CRUD 패턴 참고
- `/Users/roque/babycare-admin/lib/firebase.ts` — Firestore 클라이언트

**Acceptance Criteria**:

*Functional:*
- [ ] /catalog: 상품 추가/수정/삭제 가능
- [ ] /catalog/requests: 직접 입력 상품 인기순 표시
- [ ] 사이드바에 카탈로그 메뉴 표시

*Static:*
- [ ] `cd /Users/roque/babycare-admin && npm run build 2>&1 | tail -5` → exit 0

*Runtime:*
- [ ] SKIP — Admin E2E 테스트 없음; H-2 수동 검증으로 대체

---

### [x] TODO Final: Verification

**Type**: verification

**Inputs**:
- all TODO outputs

**Outputs**: (none)

**Steps**:
- [ ] iOS iPhone 빌드 확인
- [ ] iOS iPad 빌드 확인
- [ ] Firestore rules 문법 확인
- [ ] Admin 빌드 확인
- [ ] 전체 파일 대조 (dead code 삭제 확인)

**Must NOT do**:
- Edit/Write 도구 사용 금지
- git 명령 실행 금지

**Acceptance Criteria**:

*Functional:*
- [ ] CatalogProduct 모델 존재
- [ ] CatalogService 존재
- [ ] BabyProduct에 catalogId/coupangURL 필드
- [ ] RecommendedProduct.swift 삭제됨
- [ ] AddProductView에 카탈로그 검색 UI
- [ ] 재주문 버튼 coupangURL 기반
- [ ] Admin /catalog 페이지 존재
- [ ] firestore.rules에 productCatalog 규칙

*Static:*
- [ ] `cd /Users/roque/BabyCare && xcodegen generate && xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet 2>&1 | grep -E 'error:'` → exit 0
- [ ] `xcodebuild build -project BabyCare.xcodeproj -scheme BabyCare -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M3)' -quiet 2>&1; test $? -eq 0` → exit 0
- [ ] `cd /Users/roque/babycare-admin && npm run build 2>&1 | tail -5` → exit 0

*Runtime:*
- [ ] (실기기 + Admin 웹 테스트 — H-1, H-2, H-3)
