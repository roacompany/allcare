# Issues — weekly-highlights

## TODO 1
- [ ] Makefile DEST UDID `E8CF2728-...` (iOS 26.4 Shutdown)는 build 시 자동 시뮬레이터 起動 X — make test 실행 시 booted 시뮬레이터(`357AC55D-...` iOS 26.2)와 mismatch로 signal abrt 가능. CI/원격 시 `DEST` 환경변수 override 필요.
- [x] BabyCareTests.swift:479-502 AdExperimentVariant orphan 테스트 3개 제거 (AdMob 폐기 ddb63d1 후속 cleanup) — TODO 1 스코프 외이나 `make test` 컴파일 통과 위해 필수
