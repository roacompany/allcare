#!/bin/bash
# Harness Engineering: S3(아키텍처 경계 강제)
# - Rule 1: Views → Services 직접 참조 금지 (allowlist 기반)
# - Rule 2: Models → Views 참조 금지
# - Rule 3: Firestore.firestore() 직접 호출은 FirestoreService(+extensions)에서만
#   → narrow protocol(BadgeFirestoreProviding 등) 패턴으로 mock 가능하도록 강제
# Usage: bash scripts/arch_test.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

RULE1_VIOLATIONS=0
RULE2_VIOLATIONS=0
RULE3_VIOLATIONS=0

echo "▸ Checking architecture boundaries..."

# Rule 1: Views/ must not directly reference Service classes (except via ViewModel)
while IFS= read -r file; do
    MATCHES=$(grep -n 'FirestoreService\|AuthService\|StorageService\|NotificationService\|CatalogService\|SoundLibraryService\|ExportService\|PDFReportService\|HospitalReportService' "$file" 2>/dev/null | grep -v '//.*Service' | grep -v 'ViewModel' || true)
    if [ -n "$MATCHES" ]; then
        while IFS= read -r match; do
            LINE=$(echo "$match" | cut -d: -f1)
            BASENAME=$(basename "$file")
            echo "  ❌ [R1] $BASENAME:$LINE: Views should use ViewModel, not Service directly"
            ((RULE1_VIOLATIONS++)) || true
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
            echo "  ❌ [R2] $BASENAME:$LINE: Models should not reference Views"
            ((RULE2_VIOLATIONS++)) || true
        done <<< "$MATCHES"
    fi
done < <(find "$PROJECT_DIR/BabyCare/Models" -name '*.swift' 2>/dev/null)

# Rule 3: Firestore.firestore() 직접 호출은 FirestoreService(+extensions) 에서만
# 허용: BabyCare/Services/FirestoreService*.swift, BabyCare/App/BabyCareApp.swift (앱 초기화 settings)
# 차단: ViewModels / 그 외 Services / Views 등에서의 직접 호출
#   → narrow protocol(BadgeFirestoreProviding 등) 패턴으로 강제
while IFS= read -r file; do
    REL_PATH="${file#$PROJECT_DIR/}"
    case "$REL_PATH" in
        BabyCare/Services/FirestoreService*.swift) continue ;;
        BabyCare/App/BabyCareApp.swift) continue ;;
    esac
    MATCHES=$(grep -n 'Firestore\.firestore()' "$file" 2>/dev/null | grep -Ev ':[[:space:]]*(//|\*)' || true)
    if [ -n "$MATCHES" ]; then
        while IFS= read -r match; do
            LINE=$(echo "$match" | cut -d: -f1)
            BASENAME=$(basename "$file")
            echo "  ❌ [R3] $BASENAME:$LINE: Firestore.firestore() 직접 호출 — narrow protocol(*FirestoreProviding) 패턴 사용"
            ((RULE3_VIOLATIONS++)) || true
        done <<< "$MATCHES"
    fi
done < <(find "$PROJECT_DIR/BabyCare" -name '*.swift' 2>/dev/null)

# 베이스라인 (점진적 감축 — 새 위반만 차단)
BASELINE_R1=0
BASELINE_R2=0
# Rule 3 (Firestore.firestore() 직접): 0건 — 모든 호출은 FirestoreService(+extensions) 경유
# 이력: 10 → 8 (Cry, 2026-05-17) → 5 (AuthMigration, 2026-05-17) → 0 (FCMToken/Catalog/Sound/Analysis/OfflineQueue, 2026-05-17)
# 신규 컬렉션 추가 시: FirestoreCollections.X 상수 + FirestoreService+X.swift + XFirestoreProviding + MockX 패턴 적용
BASELINE_R3=0

TOTAL_VIOLATIONS=$((RULE1_VIOLATIONS + RULE2_VIOLATIONS + RULE3_VIOLATIONS))
TOTAL_BASELINE=$((BASELINE_R1 + BASELINE_R2 + BASELINE_R3))

FAIL=0
if [ "$RULE1_VIOLATIONS" -gt "$BASELINE_R1" ]; then
    echo "❌ Rule 1 (Views→Services) FAIL: $RULE1_VIOLATIONS > baseline $BASELINE_R1"
    FAIL=1
fi
if [ "$RULE2_VIOLATIONS" -gt "$BASELINE_R2" ]; then
    echo "❌ Rule 2 (Models→Views) FAIL: $RULE2_VIOLATIONS > baseline $BASELINE_R2"
    FAIL=1
fi
if [ "$RULE3_VIOLATIONS" -gt "$BASELINE_R3" ]; then
    echo "❌ Rule 3 (Firestore.firestore() 직접) FAIL: $RULE3_VIOLATIONS > baseline $BASELINE_R3"
    echo "   새 위반 추가됨. narrow protocol 패턴(BadgeFirestoreProviding 등)을 사용하세요."
    FAIL=1
fi

if [ "$FAIL" -eq 1 ]; then
    exit 1
fi

if [ "$RULE3_VIOLATIONS" -lt "$BASELINE_R3" ]; then
    echo "🎉 Rule 3 위반 감소: $RULE3_VIOLATIONS < baseline $BASELINE_R3"
    echo "   ⚠️  scripts/arch_test.sh 의 BASELINE_R3 을 $RULE3_VIOLATIONS 로 갱신해 같은 PR 에 함께 커밋하세요"
    echo "   (갱신 안 하면 다음 회귀가 silent 통과)"
fi

if [ "$TOTAL_VIOLATIONS" -eq 0 ]; then
    echo "✅ Architecture test PASSED (R1=0 R2=0 R3=0)"
else
    echo "⚠️  Architecture: R1=$RULE1_VIOLATIONS/$BASELINE_R1 R2=$RULE2_VIOLATIONS/$BASELINE_R2 R3=$RULE3_VIOLATIONS/$BASELINE_R3 (within baseline)"
fi
