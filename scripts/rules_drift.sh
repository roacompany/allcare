#!/usr/bin/env bash
# 배포본 Firestore 규칙 ↔ 레포 firestore.rules 대조 (읽기 전용).
# 같으면 exit 0, 다르면 diff 출력 + exit 1. (gcloud 로그인 필요)
# 왜: deploy-rules 는 재배포 시 덮어쓴다 — 콘솔에서 직접 고친 라이브 변경이 조용히 사라질 수 있다.
#     "파일이 프로덕션보다 낡을 수 있다" 를 배포 전에 잡는다.
set -euo pipefail

PROJECT="${FIREBASE_PROJECT:-babycare-allcare}"
REPO_RULES="$(cd "$(dirname "$0")/.." && pwd)/firestore.rules"

TOKEN="$(gcloud auth print-access-token 2>/dev/null || true)"
[ -n "$TOKEN" ] || { echo "❌ gcloud 토큰 없음 — 'gcloud auth login' 후 재실행"; exit 2; }

hdr=(-H "Authorization: Bearer $TOKEN" -H "x-goog-user-project: $PROJECT")
RS="$(curl -s "${hdr[@]}" "https://firebaserules.googleapis.com/v1/projects/$PROJECT/releases/cloud.firestore" \
  | python3 -c 'import sys,json; d=json.load(sys.stdin); print(d.get("rulesetName") or d.get("release",{}).get("rulesetName") or "")')"
[ -n "$RS" ] || { echo "❌ 배포본 ruleset 조회 실패(권한/프로젝트 확인)"; exit 2; }

LIVE="$(curl -s "${hdr[@]}" "https://firebaserules.googleapis.com/v1/$RS" \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["source"]["files"][0]["content"])')"

if diff <(printf '%s' "$LIVE" | sed 's/[[:space:]]*$//') <(sed 's/[[:space:]]*$//' "$REPO_RULES") >/dev/null 2>&1; then
  echo "✅ 배포본 = 레포 firestore.rules (drift 없음)"
  exit 0
else
  echo "⚠️  배포본과 레포 firestore.rules 가 다릅니다 (< 배포본 / > 레포):"
  diff <(printf '%s' "$LIVE") "$REPO_RULES" || true
  exit 1
fi
