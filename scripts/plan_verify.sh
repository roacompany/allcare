#!/usr/bin/env bash
# PLAN.md ↔ 실제 코드 1:1 검증 — 하네스 핵심
#
# 검증 항목:
#  1. backticked Swift 파일 경로(`.swift`)가 실제 존재
#  2. backticked SwiftUI View/Service/ViewModel/Manager 심볼이
#     - 정의(struct/class/enum) 되어 있고
#     - 호출 callsite 1개 이상 존재 (정의 외부에서)
#
# 사용법:
#   bash scripts/plan_verify.sh [PLAN.md 경로 ...]
#   bash scripts/plan_verify.sh                 # .dev/specs/**/PLAN.md 전수
#
# 종료 코드: 0=PASS, 1=FAIL

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# 인자 → 검증 대상 목록 (bash 3.2 호환)
PLANS=()
if [ $# -gt 0 ]; then
    for arg in "$@"; do
        PLANS+=("$arg")
    done
else
    while IFS= read -r line; do
        PLANS+=("$line")
    done < <(find .dev/specs -name PLAN.md ! -path '*/done/*' 2>/dev/null)
fi

if [ ${#PLANS[@]:-0} -eq 0 ]; then
    echo "ℹ️  검증할 PLAN.md 없음 (.dev/specs/**/PLAN.md, done/ 제외)"
    exit 0
fi

FAILS=0
TOTAL_FILES=0
TOTAL_SYMBOLS=0

for plan in "${PLANS[@]}"; do
    if [ ! -f "$plan" ]; then
        echo "❌ PLAN 파일 없음: $plan"
        FAILS=$((FAILS + 1))
        continue
    fi

    echo "▸ $plan"

    # ── 1. backticked .swift 파일 경로 추출 ──
    file_paths=$(grep -oE '`[^`]*\.swift`' "$plan" | tr -d '`' | sort -u)
    while IFS= read -r path; do
        [ -z "$path" ] && continue
        # 와일드카드 포함된 경로는 검증 생략 (예: FirestoreService+*.swift)
        if [[ "$path" == *"*"* ]]; then
            continue
        fi
        TOTAL_FILES=$((TOTAL_FILES + 1))
        # PLAN의 "(신규)", "(수정)" 등 주석 제거
        clean=$(echo "$path" | sed 's/ *(신규)//; s/ *(수정)//; s/ *(삭제)//')
        # 1차: exact path
        if [ -f "$clean" ]; then
            continue
        fi
        # 2차: basename으로 find — PLAN 경로 drift 허용 (단, 1건 이상 매치되어야 함)
        base="$(basename "$clean")"
        match_count=$(find BabyCare BabyCareWidget BabyCareTests BabyCareUITests \
            -name "$base" -type f 2>/dev/null | wc -l | tr -d ' ')
        if [ "$match_count" -eq 0 ]; then
            echo "  ✘ 파일 없음: $clean"
            FAILS=$((FAILS + 1))
        fi
    done <<< "$file_paths"

    # ── 2. backticked SwiftUI/Service/ViewModel/Manager 심볼 추출 ──
    # 패턴: 대문자 시작 + (View|Service|ViewModel|Manager|Presenter|Evaluator)로 끝나는 backticked identifier
    symbols=$(grep -oE '`[A-Z][A-Za-z0-9_+]*(View|Service|ViewModel|Manager|Presenter|Evaluator)`' "$plan" \
        | tr -d '`' | sort -u)
    while IFS= read -r sym; do
        [ -z "$sym" ] && continue
        TOTAL_SYMBOLS=$((TOTAL_SYMBOLS + 1))

        # `+`이 포함된 심볼은 Swift extension 파일명 (예: ActivityViewModel+Save) — 정의/호출 룰 적용 안 함
        if [[ "$sym" == *+* ]]; then
            continue
        fi

        # 정의: struct|class|enum|extension {Sym}
        def_count=$(grep -rE "(struct|class|enum|extension)\s+${sym}\b" \
            BabyCare BabyCareWidget BabyCareTests --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$def_count" -eq 0 ]; then
            echo "  ✘ 심볼 정의 없음: $sym"
            FAILS=$((FAILS + 1))
            continue
        fi

        # 호출: 어디선가 ${sym}( 또는 ${sym}. 패턴
        # — 정의 라인 자체는 grep으로 제외 안 하고, 단순 카운트로 충분 (보통 정의 1개 + 호출 N개)
        usage_count=$(grep -rhE "\b${sym}\s*[\(\.\:]" \
            BabyCare BabyCareWidget --include="*.swift" 2>/dev/null \
            | grep -vE "(struct|class|enum|extension)\s+${sym}\b" \
            | wc -l | tr -d ' ')
        if [ "$usage_count" -eq 0 ]; then
            echo "  ⚠ 심볼은 정의됐지만 호출 0건 (orphan): $sym"
            FAILS=$((FAILS + 1))
        fi
    done <<< "$symbols"
done

echo ""
echo "──────────────────────────────────"
echo "  검증 대상: $TOTAL_FILES 파일, $TOTAL_SYMBOLS 심볼"
if [ "$FAILS" -gt 0 ]; then
    echo "  ❌ FAIL ($FAILS 건)"
    exit 1
fi
echo "  ✅ PASS"
exit 0
