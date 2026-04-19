#!/usr/bin/env bash
# H-5 자동 검증: FeatureFlags.pregnancyModeEnabled = false 빌드 검증.
# 임신 UI를 무력화한 상태에서 빌드/test가 통과하는지 확인 (회귀 방지).
# Usage: bash scripts/feature_flag_smoke.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLAGS_FILE="$PROJECT_DIR/BabyCare/Utils/FeatureFlags.swift"
BACKUP="${FLAGS_FILE}.bak"

if [ ! -f "$FLAGS_FILE" ]; then
    echo "❌ $FLAGS_FILE 부재"
    exit 1
fi

cleanup() {
    if [ -f "$BACKUP" ]; then
        mv "$BACKUP" "$FLAGS_FILE"
        echo "▸ FeatureFlags.swift 복원 완료"
    fi
}
trap cleanup EXIT

echo "▸ H-5: FeatureFlags.pregnancyModeEnabled = false 빌드 검증..."

# 1. 백업 + toggle
cp "$FLAGS_FILE" "$BACKUP"
sed -i '' 's/pregnancyModeEnabled: Bool = true/pregnancyModeEnabled: Bool = false/' "$FLAGS_FILE"

# 2. 변경 확인
if ! grep -q "pregnancyModeEnabled: Bool = false" "$FLAGS_FILE"; then
    echo "❌ FeatureFlag toggle 실패"
    exit 1
fi
echo "▸ FeatureFlag toggled to false"

# 3. 빌드
cd "$PROJECT_DIR"
if xcodebuild build \
    -project BabyCare.xcodeproj \
    -scheme BabyCare \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -quiet 2>&1 | tail -5; then
    echo ""
    echo "✅ H-5 PASSED — FeatureFlag=false 빌드 정상"
else
    echo ""
    echo "❌ H-5 FAILED — FeatureFlag=false 빌드 실패"
    exit 1
fi
