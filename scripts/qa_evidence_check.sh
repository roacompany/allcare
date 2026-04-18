#!/usr/bin/env bash
# make deploy 직전 — 현재 버전에 대한 QA evidence 파일이 존재하는지 확인
#
# 규약:
#   .dev/qa-evidence/v{MARKETING_VERSION}-build{BUILD_NUMBER}.md 또는
#   .dev/qa-evidence/v{MARKETING_VERSION}.md (최소 1개)
# 파일 내용에 "PASS" 문자열이 있어야 통과.
#
# 3-Agent QA 수행 후 사람이 해당 파일을 생성/업데이트하는 것이 의도.
# 자동 생성 피하고 "실제 검증했다"는 명시적 서명 역할.
#
# 종료 코드: 0=PASS, 1=FAIL

set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

VERSION=$(grep 'MARKETING_VERSION:' project.yml | head -1 | sed 's/.*: *"*\([0-9.]*\)"*/\1/')
BUILD=$(grep 'CURRENT_PROJECT_VERSION:' project.yml | head -1 | sed 's/.*: *"*\([0-9]*\)"*/\1/')

if [ -z "$VERSION" ]; then
    echo "❌ MARKETING_VERSION 추출 실패 (project.yml)"
    exit 1
fi

mkdir -p .dev/qa-evidence

# 후보 경로 (우선순위 순)
CANDIDATES=(
    ".dev/qa-evidence/v${VERSION}-build${BUILD}.md"
    ".dev/qa-evidence/v${VERSION}.md"
)

FOUND=""
for cand in "${CANDIDATES[@]}"; do
    if [ -f "$cand" ]; then
        FOUND="$cand"
        break
    fi
done

if [ -z "$FOUND" ]; then
    echo "❌ QA evidence 파일 없음."
    echo ""
    echo "   다음 중 1개를 생성 후 다시 실행:"
    for cand in "${CANDIDATES[@]}"; do
        echo "     $cand"
    done
    echo ""
    echo "   파일에 최소 'PASS' 문자열이 포함되어야 함."
    echo "   템플릿: scripts/qa_evidence_template.md 참고"
    exit 1
fi

if ! grep -q "PASS" "$FOUND"; then
    echo "❌ QA evidence에 'PASS' 마커 없음: $FOUND"
    echo "   3-Agent QA 수행 후 파일에 'PASS' 추가 필요."
    exit 1
fi

echo "✅ QA evidence: $FOUND"
exit 0
