#!/usr/bin/env bash
# 머지 전 전체 검증 (feat/pregnancy-mode → main).
# Iron Law: 하나라도 FAIL이면 머지 금지.
#
# Usage: bash scripts/pre_merge_check.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

FAILURES=()

run_check() {
    local name="$1"
    shift
    echo ""
    echo "━━━ $name ━━━━━━━━━━━━━━━━━━━━━━━━"
    if "$@"; then
        echo "  ✅ $name PASSED"
    else
        echo "  ❌ $name FAILED"
        FAILURES+=("$name")
    fi
}

echo "▸ Pre-merge verification (feat/pregnancy-mode → main)"
echo "  Project: $(basename $(git rev-parse --show-toplevel 2>/dev/null || echo '.'))"
echo "  Branch: $(git branch --show-current)"
echo "  Commits ahead: $(git rev-list --count origin/main..HEAD 2>/dev/null || echo '?')"

# 1. make verify (빌드 + 린트 + arch + test + design)
run_check "make verify" bash -c "make verify 2>&1 | tail -3 | grep -q 'ALL CHECKS PASSED'"

# 2. make index-check (Firestore composite index 누락)
run_check "make index-check" make index-check

# 3. H-4 pregnancy-weeks sanity
run_check "pregnancy-weeks sanity" python3 scripts/pregnancy_weeks_sanity.py "$PROJECT_DIR"

# 4. H-5 FeatureFlag=false 빌드
run_check "FeatureFlag=false 빌드" bash scripts/feature_flag_smoke.sh

# 5. Git: main과 clean rebase/merge 가능한지
run_check "merge dry-run" bash -c "
  git fetch origin main 2>/dev/null
  git merge-tree \$(git merge-base HEAD origin/main) HEAD origin/main > /tmp/merge-preview.txt
  if grep -q '^<<<<<<<' /tmp/merge-preview.txt; then
    echo '  ⚠️ 충돌 예상:'
    grep -A 1 '^<<<<<<<' /tmp/merge-preview.txt | head -10
    exit 1
  fi
"

# 6. 결과
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ ${#FAILURES[@]} -eq 0 ]; then
    echo "✅ ALL PRE-MERGE CHECKS PASSED"
    echo "   머지 준비 완료. H-items 실기기 QA 완료했는지 최종 확인 후 머지."
    exit 0
else
    echo "❌ ${#FAILURES[@]}건 FAIL:"
    for f in "${FAILURES[@]}"; do
        echo "  - $f"
    done
    echo ""
    echo "   위 검증 실패 해결 후 머지 재시도."
    exit 1
fi
