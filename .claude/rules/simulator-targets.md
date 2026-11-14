---
globs: "**/Makefile,.github/workflows/*.yml"
---

# Simulator Targets

## DEST 지정 원칙

- **`name=iPhone 17 Pro`만 지정 금지** — 다중 iOS 버전 설치 시 예측불가 선택 (pregnancy-mode-v2 세션에서 26.2 + 26.4 둘 다 있어 26.2 선택됨).
- **`id=<UDID>` 형식 권장** — deterministic. 예: `DEST = 'platform=iOS Simulator,arch=arm64,id=E8CF2728-092B-485D-BEF7-E959ED6B9435'` (iOS 26.4 iPhone 17 Pro).
- 또는 `name=iPhone 17 Pro,OS=<버전>` 으로 명시.

## iOS 26.2 시뮬레이터 이슈

- **signal kill before bootstrapping / mkstemp 에러**: iOS 26.2 시뮬레이터는 병렬 xcodebuild 시 자주 크래시. iOS 26.4는 안정.
- **증상**: `Test crashed with signal kill before establishing connection` / `mkstemp: No such file or directory`
- **우회**: iOS 26.4 UDID 명시 또는 세션 중 `xcrun simctl shutdown all` 후 단일 부팅.

## "bless service hub" / test runner hung — 🔴 원인 = 맥 OS 가 옛 Xcode 의 DTServiceHub 실행을 막는다 (2026-11-14 확인)

- 증상: `xcodebuild test`(·`test-without-building`)가 `DTServiceHubClient failed to bless service hub` 를 세 번 찍고 「Testing started」 전에서 끝없이 멈춘다 — **빌드(`build-for-testing`)는 성공**한다.
- 🔴 원인(커널 기록): macOS **27.2** 가 Xcode **26.6** 의 `DTServiceHub` 를 「code signature validation failed fatally … disallowed without correct com.apple.private.amfi.version-restriction entitlement version」으로 **실행 자체를 막는다** — 맥 OS 판과 Xcode 판이 안 맞는 것. 11/8 재부팅 무렵 OS 가 올라가며 시작됐다(그 전 빌드 117 까지는 시험이 돌았다).
- ⛔ 안 듣는 것(11/14 전부 해 봄): 개발자 모드(`DevToolsSecurity -enable`) · 디버깅 권한 허락(`security authorize -u system.privilege.taskport`) · 시뮬 서비스 재시작(`simctl shutdown all` · `killall -9 com.apple.CoreSimulator.CoreSimulatorService`) · 26.4/26.5 시뮬 바꾸기 · 샌드박스 밖 실행 · 진단 수집·코드 범위 끄기. 판 문제라 재부팅으로 풀릴 일도 아니다(재부팅은 안 해 봄).
  🩸 11/8~14 에 「개발자 모드 꺼짐」·「재부팅 수준」으로 잘못 진단해 PO 에게 설정을 바꾸게 했다 — 증상(bless)만 보고 원인을 정했다. **커널 기록부터 볼 것.**
- 진단법: `/usr/bin/log show --start "<시각>" --end "<시각>" --style compact --predicate 'eventMessage CONTAINS "DTServiceHub"'` — ⚠️ zsh 에서 그냥 `log` 는 **셸 내장 명령**이라 아무것도 안 나온다(「0건」 = 도구 탓 · 전체 경로로 칠 것).
- 고치는 길: 맥 OS 판에 맞는 Xcode(27 이상)를 깐다(앱스토어 판은 지금 Xcode 를 덮어써 빌드 SDK 도 바뀐다 — 개발자 사이트에서 따로 받아 시험에만 `DEVELOPER_DIR` 로 쓰는 길도 있다). 단위 시험만이면 CI(PR · macos-15 + Xcode 26)가 돌린다 — 통합(에뮬레이터)·UI 시험은 CI 가 안 돈다.
- 우회: `xcodebuild build-for-testing` 으로 **컴파일 검증만** 가능.

## CI destination

- **`OS=latest` 주의**: runner image drift 시 `OS=latest`가 미설치 OS를 가리키면 xcodebuild 에러. 예: macos-15 + Xcode 16.3에 iPhone 16 Pro + OS:latest → iOS 18.4 미설치 에러.
- **OS 버전 명시 권장**: `OS=18.2` 같이 runner image에 확실히 있는 버전 사용.
- **xcrun simctl list**: 로컬에서 simulator 확인하려면 `xcrun simctl list devices available` / `xcrun simctl list devices booted`.

## 참조

- pregnancy-mode-v2 `.dev/specs/pregnancy-mode-v2/context/learnings.md` 의 P1-2/P1-3/P2-3 섹션.
- `.github/workflows/ci.yml` destination 수정 시 Makefile과 일치 여부 확인.
