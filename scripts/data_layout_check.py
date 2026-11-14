#!/usr/bin/env python3
"""Firestore 지우기 범위 검사 — 앱이 쓰는 컬렉션 이름이 전부 `FirestoreCollections` 의 범위 목록에 선언됐나.

왜: 아기 삭제·계정 삭제는 하위 컬렉션을 손으로 적은 목록으로 지웠고, 새 기능이 컬렉션을 더할 때마다 빠졌다
(2.8.13 여행 trips · 임신 v3 vitals·contractions·moods · 계정 삭제 13개 중 4개는 규칙 없는 이름 — 2026-11-14).
Firestore 는 문서를 지워도 그 아래를 지우지 않으므로, 빠진 이름의 기록은 지운 뒤에도 서버에 남는다.

규칙(이 검사는 이름을 적지 않는다 — 코드와 선언에서 읽는다):
  1. `.collection(FirestoreCollections.X)` · `.collectionGroup(FirestoreCollections.X)` 의 X 는
     Constants.swift 의 범위 목록(topLevel · scopeParents · userChildren · babyChildren · pregnancyChildren ·
     unreachableLegacy) 중 하나에 있어야 한다.
  2. `babyChildPath(..., collection: FirestoreCollections.X)` 의 X 는 babyChildren 에 있어야 한다.
  3. `.collection("글자")` 처럼 이름을 글자로 쓰지 않는다(CLAUDE.md 「컬렉션명 하드코딩 금지」).

사용: python3 scripts/data_layout_check.py   (통과 0 · 위반 1)
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP = ROOT / "BabyCare"
CONSTANTS = APP / "Utils" / "Constants.swift"
SCOPE_LISTS = ["topLevel", "scopeParents", "userChildren", "babyChildren", "pregnancyChildren", "unreachableLegacy"]


def declared_lists(text: str) -> dict:
    """Constants.swift 의 `static let 이름: [String] = [ ... ]` 를 읽는다(원소는 상수 이름)."""
    lists = {}
    for name in SCOPE_LISTS:
        match = re.search(rf"static let {name}: \[String\] = \[(.*?)\]", text, re.S)
        if not match:
            continue
        body = re.sub(r"//[^\n]*", "", match.group(1))
        lists[name] = {item.strip() for item in body.split(",") if item.strip()}
    return lists


def main() -> int:
    constants_text = CONSTANTS.read_text(encoding="utf-8")
    lists = declared_lists(constants_text)
    missing_lists = [name for name in SCOPE_LISTS if name not in lists]
    if missing_lists:
        print(f"❌ Constants.swift 에 범위 목록이 없다: {', '.join(missing_lists)}")
        return 1
    every_declared = set().union(*lists.values())

    violations = []
    for path in sorted(APP.rglob("*.swift")):
        if path == CONSTANTS:
            continue
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        for line_no, line in enumerate(text.splitlines(), start=1):
            code = line.split("//", 1)[0]
            for kind, name in re.findall(r"\.(collection|collectionGroup)\(\s*FirestoreCollections\.(\w+)\s*\)", code):
                if name not in every_declared:
                    violations.append(f"{rel}:{line_no}: FirestoreCollections.{name} 가 지우기 범위 목록 어디에도 없다")
            for name in re.findall(r"babyChildPath\([^)]*collection:\s*FirestoreCollections\.(\w+)", code):
                if name not in lists["babyChildren"]:
                    violations.append(f"{rel}:{line_no}: 아기 아래에 쓰는 {name} 가 babyChildren 에 없다")
            for literal in re.findall(r"\.(?:collection|collectionGroup)\(\s*\"([^\"]+)\"\s*\)", code):
                violations.append(f"{rel}:{line_no}: 컬렉션 이름을 글자(\"{literal}\")로 썼다 — FirestoreCollections 상수로")

    if violations:
        print("❌ Firestore 지우기 범위 검사 실패 — 빠진 이름의 기록은 아기·계정을 지워도 서버에 남는다:")
        for violation in violations:
            print("  " + violation)
        print("  → BabyCare/Utils/Constants.swift 의 범위 목록(babyChildren·userChildren·…)에 더할 것")
        return 1
    counts = " · ".join(f"{name} {len(lists[name])}" for name in SCOPE_LISTS)
    print(f"✅ Firestore 지우기 범위 검사 통과 ({counts})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
