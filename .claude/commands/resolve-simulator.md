---
description: Resolve simulator UDID deterministically and patch Makefile DEST.
argument-hint: "[device-name] [preferred-os-prefix]"
---

# /resolve-simulator

시뮬레이터 이름(예: `iPhone 17 Pro`)만으로는 다중 iOS 버전 설치 환경에서 선택이 예측불가 — 이 명령은 deterministic UDID를 확보하여 `Makefile` `DEST` 변수를 `id=<UDID>` 형식으로 패치한다.

## 사용

```
/resolve-simulator "iPhone 17 Pro" "iOS 18"
/resolve-simulator "iPhone 17 Pro"          # 최신 안정 버전 자동 선택
/resolve-simulator                           # 현재 Makefile DEST 값 그대로 UDID 해석
```

인자 `$1` = device name (기본: Makefile DEST에서 파싱)
인자 `$2` = preferred OS prefix (예: `iOS 26.4`, `iOS 18.2`. 없으면 최신 안정 우선)

## 동작

1. `xcrun simctl list devices available -j` 로 이용 가능한 시뮬레이터 목록 조회 (JSON)
2. `$1` 이름으로 필터
3. `$2` OS prefix가 있으면 해당 runtime의 device 선택. 없으면:
   - 복수 매칭 시 "iOS 26" 계열 중 `mkstemp` 이슈 있는 26.2 제외하고 최신 선택 (26.4 우선)
   - iOS 18 계열 중 18.2 우선 (GitHub Actions macos-15 runner 기본 탑재)
4. UDID 획득 → `sed -i ''` 로 `Makefile` 의 `DEST =` 행을 `DEST = 'platform=iOS Simulator,arch=arm64,id=<UDID>'` 로 패치
5. 결과 출력: `Patched DEST → id=<UDID> (device=<name>, runtime=<os>)`
6. (권장) 변경된 Makefile을 git status로 확인, 필요 시 commit 제안

## 실행 스크립트 (임플레이드)

```bash
#!/bin/bash
set -euo pipefail

DEVICE="${1:-}"
OS_PREFIX="${2:-}"

# Device name 기본값: Makefile에서 파싱
if [ -z "$DEVICE" ]; then
  DEVICE=$(grep -E '^DEST *=' Makefile | head -1 | sed -E "s/.*name=([^,']+).*/\1/")
fi

xcrun simctl list devices available -j > /tmp/_sims.json

# Python으로 파싱 (JSON이 복잡하므로)
python3 <<'PY'
import json, os, re, sys, subprocess
data = json.load(open('/tmp/_sims.json'))
device_name = os.environ.get('DEVICE', '')
os_prefix = os.environ.get('OS_PREFIX', '')

candidates = []
for runtime, devices in data.get('devices', {}).items():
    # runtime 예: com.apple.CoreSimulator.SimRuntime.iOS-26-4 → "iOS 26.4"
    m = re.search(r'iOS-(\d+)-(\d+)', runtime)
    if not m: continue
    ver = f"iOS {m.group(1)}.{m.group(2)}"
    for d in devices:
        if device_name and device_name not in d.get('name', ''): continue
        candidates.append((ver, d['udid'], d['name']))

# OS prefix 필터
if os_prefix:
    candidates = [c for c in candidates if c[0].startswith(os_prefix)]

# 26.2 제외 (mkstemp 이슈), 최신 우선
candidates = [c for c in candidates if c[0] != 'iOS 26.2']
candidates.sort(key=lambda c: c[0], reverse=True)

if not candidates:
    print(f"ERROR: no simulator matching device='{device_name}' os='{os_prefix}'", file=sys.stderr)
    sys.exit(1)

ver, udid, name = candidates[0]
print(f"Selected: {name} ({ver}) UDID={udid}")

# Makefile 패치
import subprocess
subprocess.run(['sed', '-i', '', f"s|^DEST = .*|DEST = 'platform=iOS Simulator,arch=arm64,id={udid}'|", 'Makefile'], check=True)
print(f"Patched Makefile DEST → id={udid}")
PY
```

## 주의

- Makefile은 **수정됨** (uncommitted) — 커밋할지 로컬 전용으로 유지할지 사용자 결정.
- CI는 `name=iPhone 16,OS=18.2` 같은 형식을 쓰므로 로컬/CI 분리 권장.
- `xcrun simctl shutdown all && xcrun simctl erase all` 로 시뮬레이터 상태 리셋하는 방법도 있지만 파괴적이므로 사용 주의.

## 참조

- `.claude/rules/simulator-targets.md`
- pregnancy-mode-v2 learnings: iOS 26.2 mkstemp signal-kill 사례
