# Learnings — Pregnancy Mode (2026-04-16)

## Git Worktree는 gitignored 파일 미포함
- `git worktree add` 후 GoogleService-Info.plist 부재로 테스트 abort
- 해결: `cp /main/BabyCare/GoogleService-Info.plist /worktree/BabyCare/`

## @AppStorage는 SwiftUI 전용 — Service 레이어 금지
- Service에서는 `UserDefaults.standard` 직접 사용

## Swift 6: Timer closure → Task { @MainActor } 래핑 필수

## struct 이름 충돌 방지 — Row/Card 등 generic suffix에 도메인 prefix 필수

## XcodeGen: HealthKit entitlement는 project.yml에 수동 추가 필요

## 3-Worker 병렬 실행: output 파일 겹치지 않으면 안전

## Firestore Rules 배포와 코드 배포 타이밍 분리 가능 (append-only 규칙)

## UIView는 single-parent (2026-04-18)
BannerAdManager shared UIView를 탭 간 공유 → reparent로 blank/refresh 사이클.
per-instance 구조로 해결. 각 placement가 자체 BannerView 소유 + 실패 시 독립
backoff retry. BannerAdManager는 shared state 추적만.

## Firestore composite index 누락은 silent failure (2026-04-18)
fetchActivePregnancy (outcome + createdAt DESC) index 없으면 PERMISSION_DENIED /
FAILED_PRECONDITION. 신규 복합 쿼리 → firestore.indexes.json 즉시 업데이트 +
`make deploy-rules` 필수.

## baby > pregnancy gating 우선순위 (2026-04-18)
`activePregnancy != nil` 단독 체크는 baby 사용자에게 pregnancy UI를 노출시키는
회귀. 항상 `babies.isEmpty && activePregnancy != nil` 패턴. Dashboard/Health/
Recording 3곳 동일 적용.

## Firestore index 배포의 숨겨진 side effect (2026-04-18)
쿼리 실패로 숨어있던 문서가 index 배포 후 갑자기 surface. 배포 전 "기존 데이터가
있으면 어떻게 노출될지" 사이드이펙트 점검 필수.

## make index-check가 기존 gap 3건 탐지 (2026-04-19)
`scripts/index_check.py` 도입 시 announcements/purchases/todos 3개 컬렉션이
복합 쿼리(.whereField + .order(by:))를 사용하지만 firestore.indexes.json에
없음을 발견. Firebase Console에서 자동 빌드된 index가 json에 미동기화된 상태로
추정. 추후 환경 재설정 시 쿼리 실패 가능. 별도 태스크로 추적.
