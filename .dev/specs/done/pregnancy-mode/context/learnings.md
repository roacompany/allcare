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
