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

## 2026-04-19 — 5빌드 회귀 + disable 결정

### "문서 정리" = 데이터 삭제 아님 (NEXT_SESSION 해석 사고)
NEXT_SESSION의 "pregnancy 문서 정리" 항목을 Firestore 데이터 삭제로 해석 →
cleanup 스크립트까지 제안. 사용자 피드백: "왜 삭제를 해". 진짜 fix는 빌드 60
gating (`babies.isEmpty && activePregnancy != nil`). 모호 항목은 파괴적 행동
전에 의도 재확인 필수. → `feedback_no_data_deletion.md`

### XCUITest @MainActor async → ObjC runtime 비가시
`@MainActor async` 표시 XCUITest 메서드는 ObjC runtime이 discovery 못 함 →
조용히 skip. 회피 패턴: `XCTestExpectation` + `Task { @MainActor in ... fulfill() }`.
빌드 61 BadgeEvaluator/CryAnalysisViewModel 통합 테스트에 적용.

### Badge가 babyVM.dataUserId() 받으면 가족 공유 격리 깨짐 (H-4)
`saveActivity(userId: dataUserId)` → `BadgeEvaluator(userId)` → owner path에
배지 저장. 파트너가 owner 배지 봄 (spec H-4 위반). fix: ActivityViewModel/
GrowthViewModel에 `currentUserId` 별도 파라미터 추가, 배지 부여만 본인 path
강제. 호출처 7곳 (Recording 5 + Dashboard 1 + ContentView 1) 일괄 수정.
"데이터 path vs 부여 대상" 분리는 모델 레벨 invariant로 spec에 명시 필요.

### XcodeGen 파일 공유: main app glob + widget 명시 둘 다 필요
`PregnancyDateMath.swift`을 widget extension에서도 import하려면 main app
sources(`path: BabyCare`) 외에 widget sources에도 명시(`path: BabyCare/Utils/
PregnancyDateMath.swift`) 필수. FeedingTimerAttributes 패턴 참조.
한쪽만 추가 시 widget target에서 "Cannot find 'X' in scope" 빌드 실패.

### a11y XXXL XCUITest가 실제 회귀 발견 (H-8)
test_a11y_extraLarge_pregnancyEntry_stillTappable 추가 시 fail → AddBabyView
진입점이 큰 글자에서 layout 밀려 hit 불가. fix: ViewThatFits(in: .horizontal)
로 horizontal/vertical 자동 분기. 자동 검증 layer가 시뮬레이터 cold start
이슈로 첫 시도 fail 가능 — deploy chain ui-test는 단독 실행 후 chain 재시도.

### 5빌드 회귀의 공통 원인: 자동 검증 layer가 빌드 60 후에야 추가됨
빌드 56/58/59/60/61 회귀 5건 모두 사후 manual fix. 자동 검증 layer (XCUITest +
sanity script + pre_merge_check)는 빌드 60 이후 도입 — 그 layer가 H-4/H-8
회귀 자동 발견은 자랑이 아니라 "처음부터 spec/검증 부실"의 증거. 사용자
피드백 "쓰레기 같다" → b 옵션(FeatureFlag=false + 재설계). 임신 모드 v2는
회귀 invariant + 검증 공백을 spec에 처음부터 첨부.
