#!/usr/bin/env python3
"""Firestore composite index 누락 조기 탐지.

복합 쿼리(.whereField + .order(by:))가 있는 컬렉션이 firestore.indexes.json에
등록되어 있는지 확인. Silent failure (PERMISSION_DENIED / FAILED_PRECONDITION)
재발 방지.

Usage: python3 scripts/index_check.py <PROJECT_DIR>
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


WINDOW_LINES = 20

COLL_RE = re.compile(r"\.collection\(FirestoreCollections\.([a-zA-Z]+)\)")
WHERE_RE = re.compile(r"\.whereField\(")
ORDER_RE = re.compile(r"\.order\(by:")


def indexed_collections(indexes_path: Path) -> set[str]:
    data = json.loads(indexes_path.read_text())
    return {idx["collectionGroup"] for idx in data.get("indexes", [])}


def composite_query_collections(services_dir: Path) -> set[str]:
    """체인 마지막 `.collection(FirestoreCollections.X)` 뒤에 whereField + order(by:) 동시 존재 시 X 캡처.

    체인 종료 감지: 공백 줄, 다른 `.collection(` 호출, 닫는 중괄호.
    """
    collections: set[str] = set()

    for swift_file in services_dir.rglob("*.swift"):
        text = swift_file.read_text()
        lines = text.splitlines()
        for i, line in enumerate(lines):
            for match in COLL_RE.finditer(line):
                name = match.group(1)
                has_where = False
                has_order = False

                for j in range(i, min(i + WINDOW_LINES + 1, len(lines))):
                    segment = lines[j]
                    if j == i:
                        segment = segment[match.end():]

                    stripped = segment.strip()
                    if j > i and stripped == "":
                        break
                    if j > i and COLL_RE.search(segment):
                        break
                    if j > i and stripped.startswith("}"):
                        break

                    if WHERE_RE.search(segment):
                        has_where = True
                    if ORDER_RE.search(segment):
                        has_order = True

                    if has_where and has_order:
                        collections.add(name)
                        break

    return collections


def main() -> int:
    project_dir = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    constants = project_dir / "BabyCare" / "Utils" / "Constants.swift"
    indexes = project_dir / "firestore.indexes.json"
    services = project_dir / "BabyCare" / "Services"

    if not constants.exists() or not indexes.exists() or not services.exists():
        print("❌ Constants.swift / firestore.indexes.json / Services/ 부재")
        return 1

    print("▸ Firestore index 누락 체크...")
    indexed = indexed_collections(indexes)
    composite = composite_query_collections(services)

    missing = sorted(composite - indexed)
    if not missing:
        print(f"✅ Index check PASSED — 복합 쿼리 {len(composite)}개 컬렉션 모두 등록됨")
        return 0

    print("⚠️  Composite query가 있지만 firestore.indexes.json에 등록 안 된 컬렉션:")
    for coll in missing:
        print(f"  - {coll}")
    print()
    print("   → firestore.indexes.json에 composite index 추가 + make deploy-rules 필수")
    print("   → silent failure (PERMISSION_DENIED / FAILED_PRECONDITION) 재발 방지")
    return 1


if __name__ == "__main__":
    sys.exit(main())
