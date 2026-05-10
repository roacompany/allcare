---
description: Audit CI workflow destination against GitHub macos-15 runner availability.
---

# /ci-simulator-check

`.github/workflows/*.yml`의 xcodebuild `-destination` 값을 GitHub-hosted `macos-15` runner의 실제 사용 가능 시뮬레이터와 대조하여 drift 리스크를 미리 감지한다.

## 배경

- GitHub Actions `macos-15` runner는 정기적으로 이미지가 갱신되며, 사전 설치된 iOS simulator runtime 목록이 변경된다.
- `name=iPhone 16 Pro` 처럼 OS 버전 핀 없이 지정하면 runner 이미지 변경 시 "destination not found" 실패 (pregnancy-mode-v2 PR #3에서 실제 발생: iOS 18.4 not installed).
- 사용자는 CI 실패를 push 후에야 알게 되고, admin-merge 우회로 CI 게이트가 약화된다.

## 동작

1. `.github/workflows/*.yml` 에서 `-destination 'platform=iOS Simulator,...'` 문자열 추출
2. 각 destination에 대해:
   - `name=`만 있고 `OS=` 없는 경우 → HIGH RISK (drift 발생 시 실패)
   - `OS=<X>` 가 있는 경우 → `OS=X` 가 macos-15 runner에서 사용 가능한지 확인 (https://github.com/actions/runner-images 의 macos-15 README 파싱)
3. 출력: table with destination / pin-status / risk-level / recommendation

## 출력 예시

```
.github/workflows/ci.yml:37
  destination: 'platform=iOS Simulator,name=iPhone 16 Pro'
  pin-status: NO OS PIN
  risk:       HIGH
  recommendation: add ,OS=18.2 or switch to generic/platform=iOS

.github/workflows/ci.yml:51
  destination: 'platform=iOS Simulator,name=iPhone 16,OS=18.2'
  pin-status: OK (OS=18.2 verified in macos-15 image v20250110)
  risk:       LOW
```

## 실행 스크립트 (임플레이드)

```bash
#!/bin/bash
set -euo pipefail

grep -rn "destination 'platform=iOS Simulator" .github/workflows/ | while read -r line; do
  file_ln=$(echo "$line" | cut -d: -f1-2)
  dest=$(echo "$line" | grep -oE "'platform=iOS Simulator[^']*'")
  if echo "$dest" | grep -q "OS="; then
    echo "$file_ln: [OK PIN] $dest"
  else
    echo "$file_ln: [HIGH RISK] $dest  → add OS=18.2 or use generic/platform=iOS"
  fi
done
```

## 참조

- `.claude/rules/simulator-targets.md` CI destination 섹션.
- https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md — runner image 사전 설치 software 목록.
