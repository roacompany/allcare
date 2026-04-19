#!/usr/bin/env bash
# 테스트 pregnancy 문서 정리 (P0 #1 보조).
# 사용자 uid를 받아 활성 임신 문서를 삭제. TestFlight 60 설치가 어려운 경우 대안.
#
# Usage: bash scripts/cleanup_test_pregnancy.sh <user_uid>
#
# 💡 본인 uid 확인 방법:
#   1. App Store Connect → TestFlight → 내 앱 → 크래시 로그에 uid가 보임
#   2. 또는 Firebase Console → Authentication → Users 에서 이메일로 검색
#   3. 또는 앱 내 설정 → 계정 정보 (있을 경우)

set -euo pipefail

PROJECT="babycare-allcare"
UID_VAL="${1:-}"

if [ -z "$UID_VAL" ]; then
    echo "Usage: $0 <user_uid>"
    echo ""
    echo "사용자 uid를 모를 때:"
    echo "  - Firebase Console → https://console.firebase.google.com/project/$PROJECT/authentication/users"
    echo "  - 이메일 또는 Apple ID로 검색해서 uid 복사"
    exit 1
fi

echo "⚠️  다음 경로의 모든 임신 문서를 삭제합니다:"
echo "    projects/$PROJECT/databases/(default)/documents/users/$UID_VAL/pregnancies"
echo ""
echo "    이 작업은 되돌릴 수 없습니다. 하위 서브컬렉션 (kickSessions, prenatalVisits,"
echo "    pregnancyChecklists, pregnancyWeights, pregnancySymptoms)도 cascade 삭제됩니다."
echo ""
read -p "계속하시겠습니까? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "취소됨."
    exit 0
fi

echo "▸ firebase firestore:delete 실행 중..."
firebase firestore:delete "users/$UID_VAL/pregnancies" \
    --recursive \
    --project "$PROJECT" \
    --force

echo ""
echo "✅ 임신 문서 정리 완료 (uid=$UID_VAL)"
echo "   앱 재실행 시 임신 모드 onboarding으로 되돌아갑니다."
