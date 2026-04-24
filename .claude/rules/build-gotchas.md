---
globs: "**/project.yml,**/Package.*"
---

# Build Gotchas

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

## 참조

- pregnancy-mode-v2 `.dev/specs/pregnancy-mode-v2/context/learnings.md` P0-2b / P4-2.
