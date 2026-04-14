#!/bin/bash
# Harness Engineering: I1(가비지 컬렉션) — 미사용 코드 탐지
# Usage: bash scripts/dead_code.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "▸ Scanning for potentially unused types..."

FOUND=0

# Swift 파일에서 선언된 class/struct/enum 중 1번만 참조되는 것 탐지
for type in $(grep -roh 'class \w\+\|struct \w\+\|enum \w\+' BabyCare/Models/ BabyCare/Services/ BabyCare/Utils/ 2>/dev/null | \
              awk '{print $2}' | sort -u | grep -v '^_'); do
    count=$(grep -r "$type" --include='*.swift' BabyCare/ 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -le 1 ]; then
        # 선언만 있고 사용 없음
        FILE=$(grep -rl "class $type\|struct $type\|enum $type" --include='*.swift' BabyCare/ 2>/dev/null | head -1)
        if [ -n "$FILE" ]; then
            LINE=$(grep -n "class $type\|struct $type\|enum $type" "$FILE" 2>/dev/null | head -1 | cut -d: -f1)
            echo "  ⚠️  $(basename "$FILE"):${LINE:-?}: $type (referenced $count time)"
            ((FOUND++)) || true
        fi
    fi
done

echo ""
if [ "$FOUND" -gt 0 ]; then
    echo "⚠️  $FOUND potentially unused type(s) found"
    echo "   Review manually before removing"
else
    echo "✅ No obviously unused types detected"
fi

# Periphery 권장
if ! command -v periphery &>/dev/null; then
    echo ""
    echo "💡 For deeper analysis: brew install periphery && periphery scan"
fi
