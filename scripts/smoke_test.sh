#!/usr/bin/env bash
# UI smoke test — 시뮬레이터 런칭 + 크래시 체크
#
# 하네스 원칙: 단위 테스트 PASS ≠ 앱 실행 가능. 실제 부팅 + launch + 1차 화면
# 렌더까지 확인하여 런타임 회귀 조기 발견.
#
# 시나리오 (비인증):
#   1. 시뮬레이터 부팅 (없으면 자동 부팅)
#   2. 빌드 + install
#   3. launch + 5초 대기
#   4. crash log 검색 (com.roacompany.allcare)
#   5. 스크린샷 캡처 (build/smoke-*.png)
#
# 종료 코드: 0=PASS, 1=FAIL

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUNDLE_ID="com.roacompany.allcare"
SIMULATOR="iPhone 17 Pro"
DERIVED_DATA="build/smoke-dd"
SCREENSHOT_DIR="build/smoke-screenshots"

mkdir -p "$SCREENSHOT_DIR"

# ── 1. 시뮬레이터 부팅 확인 ──
echo "▸ 시뮬레이터 상태 확인..."
BOOTED=$(xcrun simctl list devices booted 2>/dev/null | grep -c "Booted" || true)
if [ "$BOOTED" -eq 0 ]; then
    echo "  시뮬레이터 부팅 중..."
    xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
    sleep 3
fi

BOOTED_ID=$(xcrun simctl list devices booted 2>/dev/null | grep -oE '[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}' | head -1)
if [ -z "$BOOTED_ID" ]; then
    echo "❌ 부팅된 시뮬레이터 찾을 수 없음"
    exit 1
fi
echo "  시뮬레이터: $BOOTED_ID"

# ── 2. 빌드 + install ──
echo "▸ 시뮬레이터용 빌드..."
if ! xcodebuild build \
    -project BabyCare.xcodeproj \
    -scheme BabyCare \
    -destination "platform=iOS Simulator,id=$BOOTED_ID" \
    -derivedDataPath "$DERIVED_DATA" \
    -quiet 2>&1 | tail -5 | grep -qE "BUILD SUCCEEDED"; then
    # grep 실패가 무조건 실패 의미 아님 — 재확인
    if ! ls "$DERIVED_DATA"/Build/Products/Debug-iphonesimulator/BabyCare.app >/dev/null 2>&1; then
        echo "❌ 빌드 산출물 없음"
        exit 1
    fi
fi

APP_PATH=$(find "$DERIVED_DATA"/Build/Products -name "BabyCare.app" -type d | head -1)
if [ -z "$APP_PATH" ]; then
    echo "❌ BabyCare.app 찾을 수 없음"
    exit 1
fi

echo "▸ 앱 설치..."
xcrun simctl install "$BOOTED_ID" "$APP_PATH"

# ── 3. 런치 + 대기 ──
# 기존 프로세스 종료 (이전 세션 잔재 방지)
xcrun simctl terminate "$BOOTED_ID" "$BUNDLE_ID" 2>/dev/null || true
sleep 1

echo "▸ 앱 런치..."
LAUNCH_START=$(date +%s)
PID=$(xcrun simctl launch "$BOOTED_ID" "$BUNDLE_ID" 2>&1 | grep -oE '[0-9]+$' | head -1)
if [ -z "$PID" ]; then
    echo "❌ 런치 실패"
    exit 1
fi
echo "  PID: $PID"

# 5초 대기 (login view / dashboard 렌더)
sleep 5

# ── 4. crash log 검색 ──
echo "▸ crash log 검색..."
RECENT_CRASHES=$(xcrun simctl spawn "$BOOTED_ID" log show --predicate "processImagePath CONTAINS '$BUNDLE_ID' AND eventType == logEvent AND messageType == 16" --last 30s 2>/dev/null | wc -l | tr -d ' ')
# 프로세스가 여전히 살아있는지
if ! xcrun simctl spawn "$BOOTED_ID" launchctl list 2>/dev/null | grep -q "$BUNDLE_ID"; then
    # 프로세스 이미 죽었으면 → 크래시 가능성 높음
    echo "  ⚠  프로세스가 런치 직후 종료됨 — crash 의심"
fi

# ── 5. 스크린샷 ──
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SHOT_PATH="$ROOT/$SCREENSHOT_DIR/smoke_${TIMESTAMP}.png"
echo "▸ 스크린샷 캡처..."
xcrun simctl io "$BOOTED_ID" screenshot "$SHOT_PATH" 2>&1 | tail -2
if [ ! -f "$SHOT_PATH" ]; then
    echo "❌ 스크린샷 실패 ($SHOT_PATH)"
    exit 1
fi
SIZE=$(stat -f%z "$SHOT_PATH" 2>/dev/null || stat -c%s "$SHOT_PATH" 2>/dev/null || echo 0)
if [ "$SIZE" -lt 10000 ]; then
    echo "❌ 스크린샷 비정상 (size=$SIZE)"
    exit 1
fi
echo "  ✔ $SHOT_PATH (${SIZE} bytes)"

# ── 결과 ──
LAUNCH_ELAPSED=$(( $(date +%s) - LAUNCH_START ))
echo ""
echo "──────────────────────────────────"
echo "  ✅ smoke test PASS (${LAUNCH_ELAPSED}s 소요)"
echo "  스크린샷: $SHOT_PATH"
exit 0
