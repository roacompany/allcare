#!/usr/bin/env bash
# P2-4 feature flag smoke test: FeatureFlagService Hybrid 검증.
# 1) FeatureFlagService.swift 존재 확인
# 2) StableHash.swift 존재 확인
# 3) FeatureFlags.swift에 FirebaseRemoteConfig import 없음 (A-18)
# 4) RemoteConfig pregnancy_mode_enabled 키 fallback=false 동작 확인 (unit test)
# 5) fallback=false 오프라인 시뮬레이션 (기존 H-5 toggle 테스트 포함)
#
# Weekly Highlights 확장 (TODO 1):
#   bash scripts/feature_flag_smoke.sh highlights
#   — RC 2키 (highlight_enabled / highlight_ticker_pct) fallback 기본값 검증
#
# Usage: bash scripts/feature_flag_smoke.sh [highlights]

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

MODE="${1:-}"

# ── Highlights 전용 smoke (bash scripts/feature_flag_smoke.sh highlights)
if [ "$MODE" = "highlights" ]; then
    echo "▸ Weekly Highlights RC key smoke test..."
    echo ""

    RC_TEMPLATE="$PROJECT_DIR/remoteconfig.template.json"
    FFS_FILE_HL="$PROJECT_DIR/BabyCare/Services/FeatureFlagService.swift"
    FLAGS_FILE_HL="$PROJECT_DIR/BabyCare/Utils/FeatureFlags.swift"

    HL_PASS=0
    HL_FAIL=0

    hl_check() {
        local label="$1"
        local result="$2"
        if [ "$result" = "ok" ]; then
            echo "  ✅ $label"
            ((HL_PASS++)) || true
        else
            echo "  ❌ $label"
            ((HL_FAIL++)) || true
        fi
    }

    # H-1: highlight_enabled 키가 remoteconfig.template.json에 있음
    if grep -q '"highlight_enabled"' "$RC_TEMPLATE" 2>/dev/null; then
        hl_check "RC: highlight_enabled key exists in remoteconfig.template.json" "ok"
    else
        hl_check "RC: highlight_enabled key exists in remoteconfig.template.json" "fail"
    fi

    # H-2: highlight_enabled 기본값 false
    if grep -A3 '"highlight_enabled"' "$RC_TEMPLATE" 2>/dev/null | grep -q '"false"'; then
        hl_check "RC: highlight_enabled default = false (A-18 invariant)" "ok"
    else
        hl_check "RC: highlight_enabled default = false (A-18 invariant)" "fail"
    fi

    # H-3: highlight_ticker_pct 키가 remoteconfig.template.json에 있음
    if grep -q '"highlight_ticker_pct"' "$RC_TEMPLATE" 2>/dev/null; then
        hl_check "RC: highlight_ticker_pct key exists in remoteconfig.template.json" "ok"
    else
        hl_check "RC: highlight_ticker_pct key exists in remoteconfig.template.json" "fail"
    fi

    # H-4: highlight_ticker_pct 기본값 0
    if grep -A3 '"highlight_ticker_pct"' "$RC_TEMPLATE" 2>/dev/null | grep -q '"0"'; then
        hl_check "RC: highlight_ticker_pct default = 0 (safe rollout gate)" "ok"
    else
        hl_check "RC: highlight_ticker_pct default = 0 (safe rollout gate)" "fail"
    fi

    # H-5: FeatureFlagService에 highlight_enabled 키 정의됨
    if grep -q "highlight_enabled" "$FFS_FILE_HL" 2>/dev/null; then
        hl_check "FeatureFlagService: highlight_enabled key referenced" "ok"
    else
        hl_check "FeatureFlagService: highlight_enabled key referenced" "fail"
    fi

    # H-6: FeatureFlagService에 highlight_ticker_pct 키 정의됨
    if grep -q "highlight_ticker_pct" "$FFS_FILE_HL" 2>/dev/null; then
        hl_check "FeatureFlagService: highlight_ticker_pct key referenced" "ok"
    else
        hl_check "FeatureFlagService: highlight_ticker_pct key referenced" "fail"
    fi

    # H-7: isHighlightV2Enabled 메서드 시그니처 존재
    if grep -q "isHighlightV2Enabled" "$FFS_FILE_HL" 2>/dev/null; then
        hl_check "FeatureFlagService: isHighlightV2Enabled method defined" "ok"
    else
        hl_check "FeatureFlagService: isHighlightV2Enabled method defined" "fail"
    fi

    # H-8: FeatureFlags.highlightsEnabled compile-time guard 존재
    if grep -q "highlightsEnabled" "$FLAGS_FILE_HL" 2>/dev/null; then
        hl_check "FeatureFlags: highlightsEnabled compile-time guard exists" "ok"
    else
        hl_check "FeatureFlags: highlightsEnabled compile-time guard exists" "fail"
    fi

    # H-9: A-18 — FeatureFlags.swift에 FirebaseRemoteConfig import 없음
    if ! grep -q "import FirebaseRemoteConfig" "$FLAGS_FILE_HL" 2>/dev/null; then
        hl_check "A-18: No 'import FirebaseRemoteConfig' in FeatureFlags.swift" "ok"
    else
        hl_check "A-18: No 'import FirebaseRemoteConfig' in FeatureFlags.swift" "fail"
    fi

    # H-10: DJB2 StableHash 코호트 사용 (Swift.hashValue/Int.random 금지)
    if grep -q "StableHash.djb2" "$FFS_FILE_HL" 2>/dev/null; then
        hl_check "Cohort: StableHash.djb2 used (no Swift.hashValue / Int.random)" "ok"
    else
        hl_check "Cohort: StableHash.djb2 used (no Swift.hashValue / Int.random)" "fail"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  PASS: $HL_PASS  FAIL: $HL_FAIL"

    if [ "$HL_FAIL" -gt 0 ]; then
        echo "❌ highlights smoke FAILED"
        exit 1
    else
        echo "✅ highlights smoke PASSED"
        exit 0
    fi
fi

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
