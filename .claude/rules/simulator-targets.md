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

## CI destination

- **`OS=latest` 주의**: runner image drift 시 `OS=latest`가 미설치 OS를 가리키면 xcodebuild 에러. 예: macos-15 + Xcode 16.3에 iPhone 16 Pro + OS:latest → iOS 18.4 미설치 에러.
- **OS 버전 명시 권장**: `OS=18.2` 같이 runner image에 확실히 있는 버전 사용.
- **xcrun simctl list**: 로컬에서 simulator 확인하려면 `xcrun simctl list devices available` / `xcrun simctl list devices booted`.

## 참조

- pregnancy-mode-v2 `.dev/specs/pregnancy-mode-v2/context/learnings.md` 의 P1-2/P1-3/P2-3 섹션.
- `.github/workflows/ci.yml` destination 수정 시 Makefile과 일치 여부 확인.
