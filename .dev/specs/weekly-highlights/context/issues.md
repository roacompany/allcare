# Issues — weekly-highlights

## TODO 1
- [ ] Makefile DEST UDID `E8CF2728-...` (iOS 26.4 Shutdown)는 build 시 자동 시뮬레이터 起動 X — make test 실행 시 booted 시뮬레이터(`357AC55D-...` iOS 26.2)와 mismatch로 signal abrt 가능. CI/원격 시 `DEST` 환경변수 override 필요.
- [x] BabyCareTests.swift:479-502 AdExperimentVariant orphan 테스트 3개 제거 (AdMob 폐기 ddb63d1 후속 cleanup) — TODO 1 스코프 외이나 `make test` 컴파일 통과 위해 필수

## TODO 4
- [ ] PLAN.md 라인 643 `.paused(isPaused)` modifier 스펙이 PeriodicTimelineSchedule에 실재 X → 정적 카드 분기로 대체. TODO 10 XCUITest 작성 시 `isPaused` toggle 검증을 시뮬레이터 일시정지 후 카드 정적 표시 확인으로 작성 필요
