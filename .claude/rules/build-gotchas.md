---
globs: "**/project.yml,**/Package.*"
---

# Build Gotchas

## GoogleService-Info.plist 누락으로 인한 즉시 crash (worktree)

- **`.gitignore`에 등재된 plist는 worktree 생성 시 자동 복사 X** → `FirebaseApp.configure()` 호출 시 'com.firebase.core' 예외로 앱 실행 즉시 crash
- 증상: `make build` 통과 → `make smoke-test` / 실기기 / 시뮬레이터 launch 시점에 'could not find a valid GoogleService-Info.plist' 예외
- 해결:
  1. `.dev/config.yml` `worktree.copy_files`에 `BabyCare/GoogleService-Info.plist` 명시 → 이후 `hy create` 자동 복사
  2. 기존 worktree에 누락 시: `cp /Users/roque/BabyCare/BabyCare/GoogleService-Info.plist <worktree>/BabyCare/`
  3. 복사 후 `xcodegen generate` 재실행 → .app 번들 재포함
- **archive (TestFlight upload)도 동일 영향**: archive 빌드는 시뮬레이터 launch step이 없어 빌드 통과해도 실행 시 crash. archive 전 plist 존재 확인 필수 — TestFlight v2.8.3 빌드 67 미포함 사례.
- `Info.plist`는 별개 (project.yml에 명시 등재, 자동 생성). 혼동 금지.

## Firebase SDK cross-branch merge

- **main ← feat/... merge로 Firebase 버전 변경 시 DerivedData clean 필수**.
- 증상: `missing submodule 'FirebaseFirestoreInternal.FIRVectorValue'` / `module 'Foundation' is needed` / `database is locked`
- 해결: `rm -rf ~/Library/Developer/Xcode/DerivedData/BabyCare-* && xcodegen generate && make build`
- pregnancy-mode-v2 `caeb7fe` (main merge로 11.0 → 11.9 동기화) 시 발생.

## `make deploy-rules` idempotent

- 재실행 시 "latest version already up to date" exit 0 — 에러 아님.
- 머지 전 항상 실행 가능한 안전망으로 활용.

## make deploy chain 병렬 금지

- `make deploy` 는 `plan-verify → verify → ui-test → smoke → qa-check → deploy-rules → bump → archive → export → upload` 순차 체인.
- 이 중 `verify`/`ui-test`/`smoke` 가 시뮬레이터 사용 — 병렬 실행 시 `signal kill` 경합. 단일 make 호출 내에서는 순차 보장되지만, 다른 프로세스의 xcodebuild와 동시 시 충돌 가능.

## CURRENT_PROJECT_VERSION 두 곳 동기화

- `project.yml` 에 `CURRENT_PROJECT_VERSION` 이 base settings + Widget target 2 곳에 있음.
- `make bump`는 둘 다 증가. 수동 편집 시 양쪽 모두 수정 필수 (불일치 시 빌드 실패 또는 위젯 버전 mismatch).

## altool 업로드 이후

- `xcrun altool --upload-app` UPLOAD SUCCEEDED 이후 Apple 처리 (~5-30분).
- 처리 완료 확인: App Store Connect 또는 ASC API `/v1/builds?filter[app]=<APP_ID>&sort=-uploadedDate`.
- 업로드된 빌드는 무효화 불가 — Build Number는 monotonic.

## ASC train closed (code 90186 / 90062)

- `WAITING_FOR_REVIEW` 빌드가 자동 승인되면 해당 marketing version train이 닫힘.
- 동일 버전으로 새 빌드 제출 시 `code 90186` ("Invalid Pre-Release Train") 또는 `code 90062` ("must contain higher version than previously approved").
- 해결: `MARKETING_VERSION` bump (예: 2.8.1 → 2.8.2) 후 새 train 생성.
- **예방**: 심사 제출 전 빌드 충분히 검증. 긴급 fix 가능성 있으면 multiple builds 미리 업로드.

## PLAN.md 파일 경로는 brace glob 금지

- `make plan-verify`는 PLAN.md 내 파일 경로를 literal로 검증 — shell glob expansion 미지원.
- 금지: `BabyCare/Services/Insights/{Feeding,Diaper,Sleep,Health}InsightProvider.swift`
- 허용: 4개 path를 명시적 분리 (각 줄에 한 파일씩).
- 증상: 실제 파일이 존재해도 "파일 없음" false fail. v2.8.2 deploy 시 발생.

## 통계 모델 첫 주 빈 dict 버그

- Provider/Service에서 `prev > 0` 가드를 두면 첫 주(이전 데이터 없음) 모든 metric이 dict에서 제외됨.
- 원인: "데이터 없음"과 "실제값 0"이 동일하게 처리됨.
- 해결: snapshotMetrics 같은 추출 함수는 Provider 우회하여 직접 PatternReport에서 값 추출.
- Phase 1 ML WeeklyMetricSnapshot 도입 시 발견.

## Provider/Service 시그니처 변경 시 grep 필수

- `InsightProvider.candidates(_:)` 같은 시그니처 변경 시 호출처 + 테스트 파일까지 전수 확인.
- 단일 `BabyCareTests/BabyCareTests.swift`에 모든 단위 테스트 집중 — grep 누락 시 컴파일 fail.
- 명령: `grep -rn "<메서드명>" BabyCare/ BabyCareTests/`

## 참조

- pregnancy-mode-v2 `.dev/specs/pregnancy-mode-v2/context/learnings.md` P0-2b / P4-2.
- insights-ml-phase1 `.dev/specs/insights-ml-phase1/PLAN.md`.
