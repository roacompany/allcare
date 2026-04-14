#!/bin/bash
# Harness Engineering: S3(아키텍처 경계 강제)
# Views must not import Services directly, Models must not import Views
# Usage: bash scripts/arch_test.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VIOLATIONS=0

echo "▸ Checking architecture boundaries..."

# Rule 1: Views/ must not directly reference Service classes (except via ViewModel)
while IFS= read -r file; do
    # FirestoreService, AuthService 등 직접 참조 탐지
    MATCHES=$(grep -n 'FirestoreService\|AuthService\|StorageService\|NotificationService\|CatalogService\|SoundLibraryService\|ExportService\|PDFReportService\|HospitalReportService' "$file" 2>/dev/null | grep -v '//.*Service' | grep -v 'ViewModel' || true)
    if [ -n "$MATCHES" ]; then
        while IFS= read -r match; do
            LINE=$(echo "$match" | cut -d: -f1)
            BASENAME=$(basename "$file")
            echo "  ❌ $BASENAME:$LINE: Views should use ViewModel, not Service directly"
            ((VIOLATIONS++)) || true
        done <<< "$MATCHES"
    fi
done < <(find "$PROJECT_DIR/BabyCare/Views" -name '*.swift' 2>/dev/null)

# Rule 2: Models/ must not import Views
while IFS= read -r file; do
    MATCHES=$(grep -n 'import SwiftUI\|View\b' "$file" 2>/dev/null | grep -v '//\|Codable\|Hashable\|Identifiable\|preview\|Preview' || true)
    if [ -n "$MATCHES" ]; then
        while IFS= read -r match; do
            LINE=$(echo "$match" | cut -d: -f1)
            BASENAME=$(basename "$file")
            echo "  ❌ $BASENAME:$LINE: Models should not reference Views"
            ((VIOLATIONS++)) || true
        done <<< "$MATCHES"
    fi
done < <(find "$PROJECT_DIR/BabyCare/Models" -name '*.swift' 2>/dev/null)

# 기존 위반 기준선: 17건 (2026-04-14)
# 새 위반이 늘어나면 실패, 줄어들면 성공
BASELINE=0

if [ "$VIOLATIONS" -gt "$BASELINE" ]; then
    echo "❌ Architecture test FAILED: $VIOLATIONS violation(s) (baseline: $BASELINE)"
    echo "   새 위반이 추가됨. 기존 위반 수를 넘지 않도록 수정하세요."
    exit 1
elif [ "$VIOLATIONS" -gt 0 ]; then
    echo "⚠️  Architecture: $VIOLATIONS existing violation(s) (baseline: $BASELINE)"
    echo "   기존 위반은 점진적으로 해결. 새 위반 추가 금지."
else
    echo "✅ Architecture test PASSED (0 violations)"
fi
