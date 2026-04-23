# App Store 심사 상태 + Firebase 11.8.0 Hotfix 계획

**확인 일자**: 2026-04-23  
**데이터 출처**: App Store Connect API `/v1/apps/6759935352/appStoreVersions?limit=10`

---

## 심사 상태

| 버전 | 빌드 | 상태 | releaseType | 비고 |
|------|------|------|-------------|------|
| v2.6.2 | 52 | **APPROVED (READY_FOR_SALE)** | AFTER_APPROVAL | 승인 후 자동 출시됨 |
| v2.7.0 | — | READY_FOR_SALE | — | 이미 출시됨 |
| v2.6.1 | — | READY_FOR_SALE | — | 이전 버전 |
| TestFlight 빌드 55-62 | — | processingState=VALID | — | 모두 유효 |

### 분기 판단

**v2.6.2 = APPROVED** → Firebase 11.8.0 hotfix (P0-2b) 및 Phase 1 (P1-1 AppContext 등) **즉시 진행 가능**.

- APPROVED이므로 main 머지 블로커 없음
- v2.7.0이 이미 READY_FOR_SALE이므로 v2.7.1/v2.7.2 버전 bump는 심사에 영향 없음

---

## Firebase 11.8.0 Hotfix 계획 (P0-2b)

### 현황

- **현재 버전**: Firebase SDK `11.0.0` (project.yml 확인 — `.worktrees/pregnancy-mode/project.yml` line 25)
- **목표 버전**: `11.8.0` 이상
- **이슈 근거**: Firebase iOS SDK Issue #14257 — Swift 6 strict concurrency 경고/에러 fix

### 브랜치 전략

```
main
 └── feat/firebase-11.8.0-compat   (pregnancy-mode-v2와 완전 분리, main 기준 분기)
```

- pregnancy-mode-v2 worktree 직접 수정 금지
- 단독 PR — pregnancy 코드 변경 없음
- PR → CI(make verify) → main merge 순서

### 영향 범위

| 대상 | 파일/모듈 수 | 주요 변경 내용 |
|------|-------------|----------------|
| ViewModel (VM) | 12개 VM | `@MainActor`, `async/await`, `Sendable` 적합성 재검토 |
| 위젯 타겟 | BabyCareWidgetExtension | Firebase import 없으면 무영향, PregnancyWidgetDataStore 확인 필요 |
| Test infra | BabyCareTests.swift | MockFirestore/Mock 패턴 Sendable 준수 확인 |
| FirestoreService | FirestoreService+*.swift | actor isolation 경고 → 수정 or @preconcurrency |

### 타임라인

```
[P0-2b 시작]
  1. feat/firebase-11.8.0-compat 브랜치 생성 (main 기준)
  2. project.yml Firebase version "11.0.0" → "11.8.0" 변경
  3. xcodegen generate + make build
  4. Swift 6 concurrency 경고/에러 수정 (12 VM + test infra)
  5. make verify PASS (빌드 + 린트 + 아키텍처 + 테스트)
  6. PR 오픈 → CI 통과
  7. main merge
  8. make deploy → TestFlight v2.7.2 빌드 업로드

[Phase 1 시작 (P1-1 AppContext 등)]
  → P0-2b 완료 즉시 unblocked
```

### Blocker

**없음.** v2.6.2 APPROVED 확인으로 모든 블로커 해제.

---

## v2.8 시작 예상일

- P0-2b (Firebase hotfix) 완료 후 즉시 Phase 1 진행 가능
- Phase 1: P1-1 AppContext 설계 포함 pregnancy-mode-v2 재설계 대기 중
- 예상 순서: P0-2b 완료 → P1-1 AppContext → P1-2 이후 순차 진행

---

## 리스크 노트

| 리스크 | 수준 | 대응 |
|--------|------|------|
| v2.7.0이 이미 READY_FOR_SALE | 낮음 | v2.7.2 bump는 TestFlight 전용이므로 심사 재제출 영향 없음 |
| Firebase 11.8.0 Swift 6 concurrency 수정 범위 미파악 | 중간 | `make verify` 루프로 조기 포착. Issue #14257 패치 노트 참조 |
| pregnancy-mode-v2 worktree와 hotfix 충돌 | 낮음 | 브랜치 완전 분리 (main 기준) + pregnancy 코드 미수정 |
| TestFlight v2.7.2 처리 지연 | 낮음 | processingState 확인 후 Phase 1 착수 가능 (TestFlight 완료 대기 불필요) |

---

## 참조

- PLAN.md: P0-2b `feat/firebase-11.8.0-compat` 브랜치 실행 계획
- project.yml: `/Users/roque/BabyCare/.worktrees/pregnancy-mode/project.yml` — Firebase `11.0.0` (현재)
- Firebase Issue: https://github.com/firebase/firebase-ios-sdk/issues/14257 (Swift 6 concurrency fix)
- ASC API: `GET /v1/apps/6759935352/appStoreVersions?limit=10` (2026-04-23 확인)
