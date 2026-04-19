#!/usr/bin/env bash
# Harness Engineering: Firestore composite index 누락 조기 탐지
# 복합 쿼리(.whereField + .order(by:))가 있는 컬렉션이 firestore.indexes.json에 등록되어 있는지 확인
# Silent failure (PERMISSION_DENIED / FAILED_PRECONDITION) 재발 방지
# Usage: bash scripts/index_check.sh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
exec python3 "$PROJECT_DIR/scripts/index_check.py" "$PROJECT_DIR"
