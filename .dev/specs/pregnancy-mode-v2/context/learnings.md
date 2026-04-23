# pregnancy-mode-v2 Learnings

## P0-1
- v1 빌드 56-61 회귀 원인 3카테고리: (a) 구조(gating 분산) 4건 / (b) 프로세스(테스트 부족) 2건 / (c) external(Firestore index) 1건.
- 빌드 60 CRITICAL은 빌드 58 ContentView 부분 fix 후 하위 3-View 불일치가 드러난 전형적 single-source-of-truth 부재 패턴 → v2 AppContext 단일 분기로 구조적 제거.
- git log + CLAUDE.md "회귀 이력" + learnings.md 3중 교차 확인으로 빌드별 유발 커밋 특정 가능.

## P0-2
- v2.6.2 (빌드 52) **APPROVED** (READY_FOR_SALE) 확인 — ASC API `/v1/apps/6759935352/appStoreVersions` 2026-04-23 조회. releaseType=AFTER_APPROVAL 자동 출시.
- v2.7.0도 READY_FOR_SALE → v2.7.1/v2.7.2 bump 시 심사 영향 없음.
- project.yml Firebase 버전은 11.0.0 (v1 worktree 기준, v2도 동일 소스) — P0-2b에서 11.8+ 업그레이드.

## P0-5
- collectionGroup 규칙은 `match /databases/{database}/documents` 최상위 scope 필수 — `match /users/{userId}` 중첩 내부 배치 금지 (silent fail).
- Makefile `deploy-rules` 타겟은 `firebase deploy --only firestore:rules`만 실행 (indexes 별도) → indexes 변경 시 별도 `make deploy-indexes` 또는 `make deploy-rules` 스크립트 확장 필요.
- 하위 컬렉션(kickSessions/prenatalVisits/etc.)은 Partner 접근 시 부모 pregnancy의 sharedWith를 nested `get()`으로 확인 — 현재 구현 안전, 향후 collectionGroup 쿼리 추가 시 규칙 확장 필요.
- `sharedWith is list` 타입 가드 + `uid in resource.data.sharedWith` 조합이 Swift `arrayContains` 쿼리와 정확히 매칭.

## P1-1
- `AppContext` 4-state enum 독립 Utils 파일 + Equatable + tuple exhaustive switch (no default:) 패턴 확정. 향후 P1-2~P2-2 gating에서 `AppContext.resolve(babies:pregnancy:)` 호출.
- `project.yml`의 `path: BabyCare` recursive glob 덕분에 `BabyCare/Utils/` 신규 파일은 자동 포함 — xcodegen 재실행만으로 충분.
- BabyCareTests.swift 여러 동일 closing brace 블록 주의 — Edit 경계에 unique context(전체 함수 몸체) 필수.
- Orchestrator prompt 시 PLAN signature 그대로 인용 (`from` vs `resolve` drift 방지).

## P1-2
- ContentView 온보딩: 2버튼 패턴 (아기 등록 / 임신 중이에요). FeatureFlags.pregnancyModeEnabled gate 유지 (P2-4에서 FeatureFlagService로 대체 예정).
- NOT 로직 완전 제거 — `switch AppContext.resolve(...)` 4-state 분기로 대체, `default:` 없음.
- Nested sheet 제거 완료 (빌드 56 orphan UI 회귀 근본 원인 제거).
- AddBabyView.swift는 P1-2에서 미수정 — 기존 임신 진입점을 XCUITest backward compat용으로 보존. P1-4/P3-1에서 AppContext 정합 확인 필요.

## P1-5
- DashboardPregnancyView 최소 수정 (15줄 diff) 성공 — Codex Rec-5 "전면 재작성 금지" invariant 준수.
- Milestone nil-check는 optional chaining (`info?.milestone`) + if-let로 이미 적용되어 있음 — P1-5는 D-7 제거만 실질 변경.
- git stash + pop은 pre-existing 변경과 conflict 발생 시 실패 — 선호: `git checkout -- <file>` + 수동 재적용.
- xcodebuild "BUILD FAILED / database is locked" 은 DerivedData 동시 접근 경합 — 병렬 make verify 회피 필요.

## P1-3
- DashboardPregnancyHomeCard additive 패턴 — NavigationLink to DashboardPregnancyView, AppColors(.primaryAccent, .warmOrangeColor, .indigoColor) 사용, 0 raw hex.
- `pregnancyHomeCardIfNeeded` @ViewBuilder로 AppContext.both 시에만 카드 삽입, 다른 case는 EmptyView — 단일 진실 소스 유지.
- Verify worker의 Read tool이 session 초반에 stale 내용을 반환할 수 있음 — `git diff HEAD`로 확인 필수 (Orchestrator가 override).

## P2-3
- Swift 6 strict concurrency: 동일 optional inout 프로퍼티를 한 줄에서 read+write 시 exclusive access 위반 — `if p?.x == nil { p?.x = y }` 분리 필수.
- Protocol은 기본 파라미터 불가 — protocol extension의 편의 오버로드로 우회 (default 값으로 required method 호출).
- `FirestoreService+Pregnancy.swift`에서 `collectionGroup` 쿼리는 `private pregnancyRef` 헬퍼 우회하고 `db.collectionGroup` 직접 호출 필요.
- `index_check.py`는 `.whereField + .order` 조합만 스캔 — `arrayContains + whereField` (no order) 패턴은 수동 COLLECTION_GROUP 인덱스 추가가 정답.
- BadgeFirestoreProviding 패턴(narrow + Mock) 재사용성 확인 — 다른 도메인으로 확장 가능.

## P0-3
- gap-analyzer의 `markTransitionPending 0건 호출` 분석은 오류. 실제 호출은 `PregnancyViewModel.swift:365`에 존재. Scenario (c) 채택 → `pending_is_valid=valid`, P2-2 Resume UI 유효.
- v1은 이미 2단계 commit 패턴(markTransitionPending → WriteBatch)을 올바르게 구현. v2에서도 동일 패턴 보존 권장.
- Scenario 분류 전 실제 코드 grep 필수 — 분석 전제 오류 가능.

## P0-4
- PLAN.md Verification Summary에 H-item이 10개가 아닌 12개(H-1~H-12) — Spec 내 숫자 표기(`H-items 10개`)와 실제 데이터 불일치. 실제는 12개 채택.
- v2.7.1 QA evidence 포맷(`H | 영역 | 자동검증 | 결과 | 비고`)에서 v2는 `평가자`, `기준`, `Evidence 포맷`, `기한` 4컬럼 확장.
- H-4/H-10 외부 의존은 평가자 셀에 "AI 에이전트 불가" 태그로 명시 필요 — 할당 혼동 방지.

