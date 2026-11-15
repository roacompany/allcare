#!/usr/bin/env bash
# 관리자 콘텐츠 스냅숏(BabyCareTests/Fixtures/app-content.json)을 다시 쓴다 — 시뮬레이터 없이 맥에서.
# 앱 이유식 가이드 · 발달 콘텐츠 글(또는 관리자가 보여 주는 화면 글)을 바꾸면 AdminContentSnapshotTests 가 이 도구를 안내한다.
#
# 하는 일: 앱의 진짜 모델 파일 둘(BabyFoodGuide.swift · DevelopmentContent.swift)과 진짜 시험 파일을 임시 Swift 패키지에 링크해
#   ① 기록 모드로 한 번(늘 「새로 썼습니다」 실패로 끝난다) ② 보통 모드로 한 번(초록이어야 한다) 돌린다.
# 판정은 내용 대조라, 여기(맥)서 쓴 파일을 CI(아이폰 시뮬레이터)가 견줘도 된다.
# iOS 시뮬레이터 시험이 도는 맥이면 `TEST_RUNNER_RECORD_ADMIN_CONTENT_SNAPSHOT=1 make test` 와 같다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/Sources/BabyCare" "$TMP/Tests/BabyCareTests" "$ROOT/BabyCareTests/Fixtures"
ln -s "$ROOT/BabyCare/Models/BabyFoodGuide.swift" "$ROOT/BabyCare/Models/DevelopmentContent.swift" "$TMP/Sources/BabyCare/"
ln -s "$ROOT/BabyCareTests/BabyCareTests+AdminContentSnapshot.swift" "$TMP/Tests/BabyCareTests/"
cat > "$TMP/Package.swift" <<'SWIFT'
// swift-tools-version:5.9
import PackageDescription
let package = Package(
    name: "AdminContentSnapshot",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "BabyCare", path: "Sources/BabyCare"),
        .testTarget(name: "BabyCareTests", dependencies: ["BabyCare"], path: "Tests/BabyCareTests"),
    ]
)
SWIFT

cd "$TMP"
echo "① 기록(늘 「새로 썼습니다」 실패로 끝난다)"
RECORD_ADMIN_CONTENT_SNAPSHOT=1 swift test --filter 'AdminContentSnapshotTests/test_snapshot_matchesAppContent' > "$TMP/record.log" 2>&1 || true
if ! grep -q '스냅숏을 새로 썼습니다' "$TMP/record.log"; then
  cat "$TMP/record.log"
  echo "기록하지 못했습니다 — 위 기록을 보세요." >&2
  exit 1
fi

echo "② 확인(보통 모드)"
if ! swift test --filter AdminContentSnapshotTests > "$TMP/check.log" 2>&1; then
  cat "$TMP/check.log"
  echo "다시 쓴 스냅숏이 시험을 통과하지 못했습니다 — 위 기록을 보세요." >&2
  exit 1
fi
grep -E 'Executed [0-9]+ tests?' "$TMP/check.log" | tail -1
echo "다시 썼습니다: BabyCareTests/Fixtures/app-content.json — 커밋하고, 관리자(babycare-admin)에서 npm run content:sync"
