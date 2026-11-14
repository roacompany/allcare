#!/usr/bin/env python3
"""Firestore 지우기 범위 검사 — 앱이 쓰는 컬렉션 이름이 `FirestoreCollections` 의 **맞는** 범위 목록에 선언됐나.

왜: 아기 삭제·계정 삭제는 하위 컬렉션을 손으로 적은 목록으로 지웠고, 새 기능이 컬렉션을 더할 때마다 빠졌다
(2.8.13 여행 trips · 임신 v3 vitals·contractions·moods · 계정 삭제 13개 중 4개는 규칙 없는 이름 — 2026-11-14).
Firestore 는 문서를 지워도 그 아래를 지우지 않으므로, 빠진 이름의 기록은 지운 뒤에도 서버에 남는다.
아기 삭제는 babyChildren 만, 계정 삭제는 각 부모의 목록만 본다 — 이름이 「어느 목록에든」 있는 것으로는 모자란다
(아기 밑 컬렉션을 userChildren 에 적으면 둘 다 놓친다 · 2026-11-14 교차 검토).

규칙(이 검사는 이름을 적지 않는다 — 코드와 선언에서 읽는다):
  1. `.collection(FirestoreCollections.X)` · `.collectionGroup(FirestoreCollections.X)` 의 X 는 범위 목록
     (topLevel · scopeParents · userChildren · babyChildren · pregnancyChildren · unreachableLegacy) 중 하나에 있어야 한다.
  2. 부모를 알 수 있으면 그 부모의 목록에 있어야 한다:
       users/{u}/X → userChildren(또는 scopeParents·unreachableLegacy) · babies/{b}/X → babyChildren ·
       pregnancies/{p}/X → pregnancyChildren ·
       db.collection(X) → topLevel(또는 unreachableLegacy) · 그 밖의 부모 아래 → 지우기 범위에 없는 자리.
     부모를 아는 길: 바로 앞 `.collection(P).document(…)` · 경로 도우미 `xRef(…)`(몸통의 마지막 collection) ·
     그 자리 앞의 가장 가까운 `let 이름 = ….collection(P).document(…)`.
     부모를 못 읽은 `.collection` 은 빨강 — 잴 수 없는 곳을 초록으로 두지 않는다(collectionGroup 만 이름으로 잰다 · 2026-11-14 재검토).
  3. `babyChildPath(…, collection: FirestoreCollections.X)` 의 X 는 babyChildren — 이름을 넘겨받아 부르는 함수
     (`func f(…, collection: String)` 안에서 `babyChildPath(…, collection: collection)`)는 f 를 부르는 쪽의 값을 잰다.
  4. `.collection("글자")` 처럼 이름을 글자로 쓰지 않는다(CLAUDE.md 「컬렉션명 하드코딩 금지」).
  여러 줄로 나눠 쓴 호출도 잰다(줄 단위가 아니라 파일 전체에서 찾는다).

사용: python3 scripts/data_layout_check.py [레포 뿌리]   (통과 0 · 위반 1 · 뿌리를 주면 그 사본을 잰다 — 깨뜨린 사본 시험용)
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parent.parent
APP = ROOT / "BabyCare"
CONSTANTS = APP / "Utils" / "Constants.swift"
SCOPE_LISTS = ["topLevel", "scopeParents", "userChildren", "babyChildren", "pregnancyChildren", "unreachableLegacy"]

ARGS = r"\((?:[^()]|\([^()]*\))*\)"  # 괄호 안 — 한 겹 중첩까지
COLLECTION = re.compile(r"\.(collection|collectionGroup)\(\s*FirestoreCollections\.(\w+)\s*\)")
LITERAL = re.compile(r"\.(?:collection|collectionGroup)\(\s*\"([^\"]+)\"\s*\)")
BABY_CHILD_PATH = re.compile(r"babyChildPath" + ARGS)


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


def code_of(path: pathlib.Path) -> str:
    """주석을 지운 코드 — 줄 번호를 지키려고 줄 수는 그대로 둔다."""
    return "\n".join(line.split("//", 1)[0] for line in path.read_text(encoding="utf-8").splitlines())


def line_of(code: str, pos: int) -> int:
    return code.count("\n", 0, pos) + 1


def last_collection(expr: str):
    found = re.findall(r"\.collection\(\s*FirestoreCollections\.(\w+)\s*\)", expr)
    return found[-1] if found else None


def ref_helpers(codes: dict) -> dict:
    """`func xRef(…) -> CollectionReference { … }` → 그 도우미가 돌려주는 컬렉션(몸통의 마지막 collection)."""
    helpers = {}
    for code in codes.values():
        for match in re.finditer(r"func (\w+)\([^)]*\)\s*->\s*CollectionReference\s*\{", code):
            body = code[match.end():match.end() + 600].split("}", 1)[0]
            parent = last_collection(body)
            if parent:
                helpers[match.group(1)] = parent
    return helpers


def doc_assignments(code: str) -> list:
    """`let 이름 = ….collection(P).document(…)` 들 → [(자리, 이름, P)] — 쓰는 자리 앞의 가장 가까운 것으로 푼다
    (같은 파일의 다른 함수가 같은 이름을 다른 부모로 쓸 수 있다)."""
    found = []
    for match in re.finditer(r"\blet\s+(\w+)\s*=\s*([^\n]*(?:\n\s*\.[^\n]*)*)", code):
        expr = match.group(2).strip()
        if re.search(r"\.document" + ARGS + r"\s*\Z", expr):
            parent = last_collection(expr)
            if parent:
                found.append((match.start(), match.group(1), parent))
    return found


def parent_of(code: str, start: int, helpers: dict, assignments: list):
    """`.collection(X)` 바로 앞의 부모 — ('child', P) · ('top', None) · (None, None)=모름."""
    before = code[max(0, start - 600):start]
    direct = re.search(r"\.collection\(\s*FirestoreCollections\.(\w+)\s*\)\s*\.document" + ARGS + r"\s*\Z", before)
    if direct:
        return "child", direct.group(1)
    helper = re.search(r"\b(\w+)" + ARGS + r"\s*\.document" + ARGS + r"\s*\Z", before)
    if helper and helper.group(1) in helpers:
        return "child", helpers[helper.group(1)]
    if re.search(r"(?:\bdb|Firestore\.firestore\(\))\s*\Z", before):
        return "top", None
    variable = re.search(r"\b(\w+)\s*\Z", before)
    if variable:
        earlier = [parent for pos, name, parent in assignments if name == variable.group(1) and pos < start]
        if earlier:
            return "child", earlier[-1]
    return None, None


def enclosing_function(code: str, pos: int):
    found = list(re.finditer(r"\bfunc\s+(\w+)\s*\(", code[:pos]))
    return found[-1].group(1) if found else None


def main() -> int:
    constants_text = CONSTANTS.read_text(encoding="utf-8")
    lists = declared_lists(constants_text)
    missing_lists = [name for name in SCOPE_LISTS if name not in lists]
    if missing_lists:
        print(f"❌ Constants.swift 에 범위 목록이 없다: {', '.join(missing_lists)}")
        return 1
    every_declared = set().union(*lists.values())
    children_of = {
        # unreachableLegacy = 규칙 없는 옛 자리(옛 → 새 이전 코드가 읽기만 한다 · 서버에서 지운다)
        "users": lists["userChildren"] | lists["scopeParents"] | lists["unreachableLegacy"],
        "babies": lists["babyChildren"],
        "pregnancies": lists["pregnancyChildren"],
    }
    top_allowed = lists["topLevel"] | lists["unreachableLegacy"]

    codes = {path: code_of(path) for path in sorted(APP.rglob("*.swift")) if path != CONSTANTS}
    helpers = ref_helpers(codes)
    violations = []
    scoped = name_only = 0
    forwarders = {}  # 함수 이름 → 이름을 넘겨받는 인자 이름표

    for path, code in codes.items():
        rel = path.relative_to(ROOT)
        assignments = doc_assignments(code)
        for match in COLLECTION.finditer(code):
            kind, name = match.group(1), match.group(2)
            where = f"{rel}:{line_of(code, match.start())}"
            if name not in every_declared:
                violations.append(f"{where}: FirestoreCollections.{name} 가 지우기 범위 목록 어디에도 없다")
                continue
            if kind == "collectionGroup":
                name_only += 1
                continue
            place, parent = parent_of(code, match.start(), helpers, assignments)
            if place == "top":
                scoped += 1
                if name not in top_allowed:
                    violations.append(f"{where}: 최상위 컬렉션 {name} 가 topLevel 에 없다")
            elif place == "child":
                scoped += 1
                allowed = children_of.get(parent)
                if allowed is None:
                    violations.append(f"{where}: {parent} 아래에 {name} 를 둔다 — 지우기 범위에 그런 자리가 없다")
                elif name not in allowed:
                    want = {"users": "userChildren", "babies": "babyChildren", "pregnancies": "pregnancyChildren"}[parent]
                    violations.append(f"{where}: {parent} 아래에 쓰는 {name} 가 {want} 에 없다(그 삭제가 놓친다)")
            else:
                violations.append(f"{where}: {name} 의 부모를 못 읽었다 — 지우기 범위를 잴 수 없다 "
                                  "(….collection(P).document(…) 사슬 · xRef 도우미 · let 이름 = ….document(…) 로 쓸 것)")
        for match in BABY_CHILD_PATH.finditer(code):
            where = f"{rel}:{line_of(code, match.start())}"
            arg = re.search(r"collection:\s*([\w.]+)", match.group(0))
            if not arg:
                continue
            value = arg.group(1)
            if value.startswith("FirestoreCollections."):
                name = value.split(".", 1)[1]
                if name not in lists["babyChildren"]:
                    violations.append(f"{where}: 아기 아래에 쓰는 {name} 가 babyChildren 에 없다")
            else:
                function = enclosing_function(code, match.start())
                if function:
                    forwarders[function] = value
                else:
                    violations.append(f"{where}: babyChildPath 의 컬렉션({value})을 잴 수 없다 — FirestoreCollections 상수로")
        for literal in LITERAL.finditer(code):
            violations.append(f"{rel}:{line_of(code, literal.start())}: 컬렉션 이름을 글자(\"{literal.group(1)}\")로 썼다 — "
                              "FirestoreCollections 상수로")

    # 3. 이름을 넘겨받아 babyChildPath 에 넣는 함수 — 부르는 쪽이 넘기는 값을 잰다
    for function, label in forwarders.items():
        calls = 0
        for path, code in codes.items():
            rel = path.relative_to(ROOT)
            for call in re.finditer(r"(?<!func )\b" + re.escape(function) + ARGS, code):
                arg = re.search(re.escape(label) + r":\s*([\w.]+)", call.group(0))
                if not arg:
                    continue
                calls += 1
                where = f"{rel}:{line_of(code, call.start())}"
                value = arg.group(1)
                if not value.startswith("FirestoreCollections."):
                    violations.append(f"{where}: {function} 에 넘긴 컬렉션({value})을 잴 수 없다 — FirestoreCollections 상수로")
                elif value.split(".", 1)[1] not in lists["babyChildren"]:
                    violations.append(f"{where}: {function} 로 아기 아래에 쓰는 {value.split('.', 1)[1]} 가 babyChildren 에 없다")
        if calls == 0:
            violations.append(f"{function}: babyChildPath 에 이름을 넘기는데 부르는 곳을 못 찾았다 — 잴 수 없다")

    if violations:
        print("❌ Firestore 지우기 범위 검사 실패 — 빠진 이름의 기록은 아기·계정을 지워도 서버에 남는다:")
        for violation in violations:
            print("  " + violation)
        print("  → BabyCare/Utils/Constants.swift 의 범위 목록(babyChildren·userChildren·…)에 더할 것")
        return 1
    counts = " · ".join(f"{name} {len(lists[name])}" for name in SCOPE_LISTS)
    print(f"✅ Firestore 지우기 범위 검사 통과 ({counts})")
    print(f"   잰 곳: 부모까지 {scoped} · 이름만 {name_only}(collectionGroup — 부모가 없다) · 넘겨받는 함수 {len(forwarders)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
