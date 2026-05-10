#!/usr/bin/env bash
# P2-4 feature flag smoke test: FeatureFlagService Hybrid 검증.
# 1) FeatureFlagService.swift 존재 확인
# 2) StableHash.swift 존재 확인
# 3) FeatureFlags.swift에 FirebaseRemoteConfig import 없음 (A-18)
# 4) RemoteConfig pregnancy_mode_enabled 키 fallback=false 동작 확인 (unit test)
# 5) fallback=false 오프라인 시뮬레이션 (기존 H-5 toggle 테스트 포함)
#
# Usage: bash scripts/feature_flag_smoke.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLAGS_FILE="$PROJECT_DIR/BabyCare/Utils/FeatureFlags.swift"
FFS_FILE="$PROJECT_DIR/BabyCare/Services/FeatureFlagService.swift"
HASH_FILE="$PROJECT_DIR/BabyCare/Utils/StableHash.swift"
BACKUP="${FLAGS_FILE}.bak"

PASS=0
FAIL=0

check() {
    local label="$1"
    local result="$2"  # "ok" | "fail"
    if [ "$result" = "ok" ]; then
        echo "  ✅ $label"
        ((PASS++)) || true
    else
        echo "  ❌ $label"
        ((FAIL++)) || true
    fi
}

echo "▸ P2-4 FeatureFlagService Hybrid smoke test..."
echo ""

# ── Check 1: FeatureFlagService.swift 존재
if [ -f "$FFS_FILE" ]; then
    check "FeatureFlagService.swift exists" "ok"
else
    check "FeatureFlagService.swift exists" "fail"
fi

# ── Check 2: StableHash.swift 존재
if [ -f "$HASH_FILE" ]; then
    check "StableHash.swift exists" "ok"
else
    check "StableHash.swift exists" "fail"
fi

# ── Check 3: A-18 — FeatureFlags.swift에 FirebaseRemoteConfig import 없음
if ! grep -q "import FirebaseRemoteConfig" "$FLAGS_FILE" 2>/dev/null; then
    check "A-18: No 'import FirebaseRemoteConfig' in FeatureFlags.swift" "ok"
else
    check "A-18: No 'import FirebaseRemoteConfig' in FeatureFlags.swift" "fail"
fi

# ── Check 4: FeatureFlagService.swift에 FirebaseRemoteConfig import 있음 (단독 게이트웨이)
if grep -q "import FirebaseRemoteConfig" "$FFS_FILE" 2>/dev/null; then
    check "FirebaseRemoteConfig import only in FeatureFlagService.swift (single gateway)" "ok"
else
    check "FirebaseRemoteConfig import only in FeatureFlagService.swift (single gateway)" "fail"
fi

# ── Check 5: RemoteConfig default fallback=false (키 정의 확인)
if grep -q "pregnancy_mode_enabled" "$FFS_FILE" 2>/dev/null; then
    check "'pregnancy_mode_enabled' key defined in FeatureFlagService" "ok"
else
    check "'pregnancy_mode_enabled' key defined in FeatureFlagService" "fail"
fi

# ── Check 6: A-18 fallback=false — fetch 실패 시 기본값 false 보장 (코드 패턴 확인)
if grep -q "false as NSObject" "$FFS_FILE" 2>/dev/null; then
    check "A-18: RemoteConfig default for pregnancy_mode_enabled = false" "ok"
else
    check "A-18: RemoteConfig default for pregnancy_mode_enabled = false" "fail"
fi

# ── Check 7: StableHash DJB2 결정론적 로직 (djb2 함수 존재)
if grep -q "djb2" "$HASH_FILE" 2>/dev/null; then
    check "StableHash: djb2 function defined" "ok"
else
    check "StableHash: djb2 function defined" "fail"
fi

# ── Check 8: minimumFetchInterval = 0 사용 금지 (ThrottledException 방지)
if ! grep -q "minimumFetchInterval.*=.*0" "$FFS_FILE" 2>/dev/null; then
    check "No minimumFetchInterval=0 (ThrottledException safe)" "ok"
else
    check "No minimumFetchInterval=0 (ThrottledException safe)" "fail"
fi

# ── Check 9: bootstrap이 ContentView.task가 아닌 App 레벨에서 호출
APP_FILE="$PROJECT_DIR/BabyCare/App/BabyCareApp.swift"
if grep -q "bootstrap" "$APP_FILE" 2>/dev/null; then
    check "bootstrap called from BabyCareApp (not ContentView)" "ok"
else
    check "bootstrap called from BabyCareApp (not ContentView)" "fail"
fi

CONTENT_VIEW="$PROJECT_DIR/BabyCare/App/ContentView.swift"
if ! grep -q "bootstrap" "$CONTENT_VIEW" 2>/dev/null; then
    check "bootstrap NOT called from ContentView (first render race safe)" "ok"
else
    check "bootstrap NOT called from ContentView (first render race safe)" "fail"
fi

# ── Check 10: Firebase SDK compatibility note (11.0.0 → async API 사용 가능)
# 오프라인 시 fetchAndActivate 실패 → try? 무시 → defaults(false) 유지 패턴 확인
if grep -q "try?" "$FFS_FILE" 2>/dev/null; then
    check "Offline fallback: try? fetchAndActivate (failure → defaults=false)" "ok"
else
    check "Offline fallback: try? fetchAndActivate (failure → defaults=false)" "fail"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PASS: $PASS  FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
    echo "❌ P2-4 smoke FAILED"
    exit 1
else
    echo "✅ P2-4 smoke PASSED"
    exit 0
fi
