#!/bin/bash
# Harness Engineering: X3(구조화된 피드백) — 파일:라인:규칙 형식 출력
# Usage: bash scripts/harness_lint.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

echo "▸ Running SwiftLint..."

if ! command -v swiftlint &>/dev/null; then
    echo "❌ SwiftLint not installed: brew install swiftlint"
    exit 1
fi

# SwiftLint 실행 (strict 없이 — warning은 허용, error만 실패)
OUTPUT=$(swiftlint lint --config .swiftlint.yml 2>/tmp/swiftlint_err.log) || true

# SourceKit 에러 체크
if grep -q 'sourcekitdInProc.framework' /tmp/swiftlint_err.log 2>/dev/null; then
    echo "⚠️  SourceKit unavailable (run: sudo xcodebuild -license accept)"
    echo "   Falling back to basic file checks..."
    echo ""

    # 기본 검사: 라인 길이, 파일 길이
    VIOLATIONS=0
    while IFS= read -r file; do
        LINES=$(wc -l < "$file" | tr -d ' ')
        if [ "$LINES" -gt 800 ]; then
            echo "  ❌ $(basename "$file"):$LINES: file_length ($LINES > 800)"
            ((VIOLATIONS++)) || true
        elif [ "$LINES" -gt 500 ]; then
            echo "  ⚠️  $(basename "$file"):$LINES: file_length ($LINES > 500)"
            ((VIOLATIONS++)) || true
        fi
    done < <(find BabyCare -name '*.swift' ! -name 'DesignSystem.generated.swift')

    if [ "$VIOLATIONS" -gt 0 ]; then
        echo ""
        echo "⚠️  Basic check: $VIOLATIONS issue(s)"
    else
        echo "✅ Basic check OK"
    fi
    exit 0
fi

if [ -n "$OUTPUT" ]; then
    echo "$OUTPUT"
fi

# 위반 수 카운트
WARNINGS=$(echo "$OUTPUT" | grep -c "warning:" || true)
ERRORS=$(echo "$OUTPUT" | grep -c "error:" || true)
WARNINGS=${WARNINGS:-0}
ERRORS=${ERRORS:-0}

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "❌ Lint FAILED: $ERRORS error(s), $WARNINGS warning(s)"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo ""
    echo "✅ Lint OK ($WARNINGS warning(s), 0 error(s))"
else
    echo "✅ Lint OK (0 violations)"
fi
