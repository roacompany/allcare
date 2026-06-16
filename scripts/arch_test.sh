#!/bin/bash
# Harness Engineering: S3(아키텍처 경계 강제)
# - Rule 1: Views → Services 직접 참조 금지 (allowlist 기반)
# - Rule 2: Models → Views 참조 금지
# - Rule 3: Firestore.firestore() 직접 호출은 FirestoreService(+extensions)에서만
#   → narrow protocol(BadgeFirestoreProviding 등) 패턴으로 mock 가능하도록 강제
# - Rule 4: designSystemV2Preview dual-mode 분기 점진 제거 (DS2 정본화 → V1 dead, 9→0 ratchet)
#   → 컴파일타임 static let=true 플래그라 런타임 테스트 불가, dead V1 재유입을 grep으로 차단
# Usage: bash scripts/arch_test.sh [--update-baseline]
#   --update-baseline: 위반이 baseline 미만(감축)일 때 BASELINE_RX 을 현재값으로 자동 하향 갱신.
#                      회귀(위반 > baseline)는 플래그와 무관하게 FAIL — 가릴 수 없음.

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

UPDATE_BASELINE=0
for arg in "$@"; do
    case "$arg" in
        --update-baseline) UPDATE_BASELINE=1 ;;
        *) echo "Unknown arg: $arg (usage: bash scripts/arch_test.sh [--update-baseline])" >&2; exit 2 ;;
    esac
done

# 위반이 baseline 미만(감축)일 때만 동작: --update-baseline 면 스크립트의 BASELINE_RX 을
# 현재값으로 자동 하향(ratchet-down) 갱신, 아니면 수동 갱신 넛지. 상향(회귀 은폐)은 불가.
maybe_update_baseline() {
    local rule="$1" current="$2" baseline="$3" varname="$4"
    [ "$current" -lt "$baseline" ] || return 0
    if [ "$UPDATE_BASELINE" -eq 1 ]; then
        local tmp; tmp="$(mktemp)"
        sed -E "s/^${varname}=[0-9]+/${varname}=${current}/" "$SCRIPT_PATH" > "$tmp" && mv "$tmp" "$SCRIPT_PATH"
        echo "✅ ${rule} baseline 자동 갱신: ${baseline} → ${current} (${varname}, --update-baseline)"
    else
        echo "🎉 ${rule} 위반 감소: ${current} < baseline ${baseline}"
        echo "   ⚠️  --update-baseline 로 ${varname} 을 ${current} 로 갱신(또는 수동 편집)해 같은 PR 에 커밋하세요"
        echo "   (갱신 안 하면 다음 회귀가 silent 통과)"
    fi
}

RULE1_VIOLATIONS=0
RULE2_VIOLATIONS=0
RULE3_VIOLATIONS=0
RULE4_VIOLATIONS=0

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

# Rule 4: FeatureFlags.designSystemV2Preview 분기 점진 제거 (Track A)
# DS2가 정본(2026-06-08)이고 플래그는 컴파일타임 static let=true → 모든 V1 else 분기가 dead.
# 제외: FeatureFlags.swift(선언), /DesignSystemV2/(doc-comment), 주석 라인.
# 각 dual-mode 사이트를 인라인(V2 고정)할 때마다 카운트가 baseline 미만 → ratchet 갱신.
RULE4_VIOLATIONS=$(grep -rn 'designSystemV2Preview' "$PROJECT_DIR/BabyCare" --include='*.swift' 2>/dev/null \
    | { grep -v 'FeatureFlags.swift' || true; } \
    | { grep -v '/DesignSystemV2/' || true; } \
    | { grep -v '//' || true; } \
    | wc -l | tr -d ' ')

# 베이스라인 (점진적 감축 — 새 위반만 차단)
BASELINE_R1=0
BASELINE_R2=0
# Rule 3 (Firestore.firestore() 직접): 0건 — 모든 호출은 FirestoreService(+extensions) 경유
# 이력: 10 → 8 (Cry, 2026-05-17) → 5 (AuthMigration, 2026-05-17) → 0 (FCMToken/Catalog/Sound/Analysis/OfflineQueue, 2026-05-17)
# 신규 컬렉션 추가 시: FirestoreCollections.X 상수 + FirestoreService+X.swift + XFirestoreProviding + MockX 패턴 적용
BASELINE_R3=0
# Rule 4 (designSystemV2Preview 분기): Track A 완료. 9 → 0 달성.
# 이력: 9 (2026-06-09 가드 설치) → 6 (Phase 2a: ContentView/LoginView 인라인 + SettingsView #if DEBUG)
#       → 0 (Phase 2b: DashboardView 인라인 + DashboardView+Shortcuts cascade 삭제)
# BASELINE_R4=0: 모든 dead V1 dual-mode 분기 제거 완료. 재유입 시 Rule 4 FAIL.
BASELINE_R4=0

TOTAL_VIOLATIONS=$((RULE1_VIOLATIONS + RULE2_VIOLATIONS + RULE3_VIOLATIONS + RULE4_VIOLATIONS))
TOTAL_BASELINE=$((BASELINE_R1 + BASELINE_R2 + BASELINE_R3 + BASELINE_R4))

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
if [ "$RULE4_VIOLATIONS" -gt "$BASELINE_R4" ]; then
    echo "❌ Rule 4 (designSystemV2Preview 분기) FAIL: $RULE4_VIOLATIONS > baseline $BASELINE_R4"
    echo "   dead V1 dual-mode 분기가 재유입됨. DS2(V2)가 정본 — V1 경로를 추가하지 마세요."
    FAIL=1
fi

if [ "$FAIL" -eq 1 ]; then
    exit 1
fi

# Ratchet: 위반이 baseline 미만(감축)이면 --update-baseline 로 자동 하향, 아니면 갱신 넛지.
# 회귀(위반 > baseline)는 위 FAIL 게이트에서 이미 exit 1 — 여기 도달 못 함.
maybe_update_baseline "Rule 1 (Views→Services)"    "$RULE1_VIOLATIONS" "$BASELINE_R1" "BASELINE_R1"
maybe_update_baseline "Rule 2 (Models→Views)"      "$RULE2_VIOLATIONS" "$BASELINE_R2" "BASELINE_R2"
maybe_update_baseline "Rule 3 (Firestore 직접호출)"  "$RULE3_VIOLATIONS" "$BASELINE_R3" "BASELINE_R3"
maybe_update_baseline "Rule 4 (designSystemV2 분기)" "$RULE4_VIOLATIONS" "$BASELINE_R4" "BASELINE_R4"

if [ "$TOTAL_VIOLATIONS" -eq 0 ]; then
    echo "✅ Architecture test PASSED (R1=0 R2=0 R3=0 R4=0)"
else
    echo "⚠️  Architecture: R1=$RULE1_VIOLATIONS/$BASELINE_R1 R2=$RULE2_VIOLATIONS/$BASELINE_R2 R3=$RULE3_VIOLATIONS/$BASELINE_R3 R4=$RULE4_VIOLATIONS/$BASELINE_R4 (within baseline)"
fi
