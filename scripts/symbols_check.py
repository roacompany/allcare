#!/usr/bin/env python3
"""SF Symbols 이름 검사 — 앱·위젯 코드의 아이콘 이름이 실제로 있고, 앱이 지원하는 가장 낮은 iOS 에서도 있나.

왜: 없는 이름이나 지원 판보다 나중에 생긴 이름은 오류 없이 **빈칸**으로 그려진다(빌드·시험 모두 초록).
2026-11-14: 후기 이유식 `bowl.fill`(어느 판에도 없음) · iOS 18 에서 생긴 이름 4개(iOS 17 기기에서 빈칸 — 건강 줄·
일기 「작년 오늘」·울음 분석 줄·임신 보관함) · 임신 카드 `figure.maternity`(없음).

기준(이 검사는 이름을 적지 않는다 — 맥의 SF Symbols 목록과 project.yml 에서 읽는다):
  - 이름 목록 = /System/Library/CoreServices/CoreGlyphs.bundle/.../name_availability.plist(이 맥의 SF Symbols)
  - 지원 판 = project.yml `deploymentTarget.iOS`
  - 지원 판보다 새 이름은 `SFSymbolFallback.prefer("새 이름", else: "옛 이름")` 안에서만 — 옛 이름이 지원 판에 있어야 한다.

사용: python3 scripts/symbols_check.py   (통과 0 · 위반 1 · 맥이 아니라 목록이 없으면 2)
"""
import pathlib
import plistlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCES = [ROOT / "BabyCare", ROOT / "BabyCareWidget"]
GLYPHS = pathlib.Path("/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources/name_availability.plist")

NAMED = re.compile(r'(?:systemName|systemImage|icon|systemImageName|symbol|image)\s*:\s*"([a-z0-9][a-z0-9.]*)"')
CASE_RETURN = re.compile(r'case\s+[^:\n]+:\s*(?:return\s+)?"([a-z0-9][a-z0-9.]*\.[a-z0-9.]*)"')
FALLBACK = re.compile(r'SFSymbolFallback\.prefer\(\s*"([a-z0-9.]+)"\s*,\s*else:\s*"([a-z0-9.]+)"\s*\)')


def version(text: str) -> tuple:
    return tuple(int(part) for part in text.split("."))


def main() -> int:
    if not GLYPHS.exists():
        print("⚠️  SF Symbols 목록이 없다(맥이 아님?) — 검사를 건너뛴다")
        return 2
    glyphs = plistlib.load(open(GLYPHS, "rb"))
    symbols, releases = glyphs["symbols"], glyphs["year_to_release"]
    target_match = re.search(r'deploymentTarget:\s*\n\s*iOS:\s*"?([0-9.]+)"?', (ROOT / "project.yml").read_text())
    target = version(target_match.group(1)) if target_match else (17, 0)

    def introduced(name):
        year = symbols.get(name)
        ios = releases.get(year, {}).get("iOS") if year is not None else None
        return version(ios) if ios else None

    problems = []
    checked = 0
    for source in SOURCES:
        for path in sorted(source.rglob("*.swift")):
            rel = path.relative_to(ROOT)
            for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
                code = line.split("//", 1)[0]
                fallback_new = set()
                for newer, older in FALLBACK.findall(code):
                    fallback_new.add(newer)
                    checked += 2
                    if introduced(newer) is None:
                        problems.append(f"{rel}:{line_no}: 「{newer}」 은 SF Symbols 에 없다")
                    older_at = introduced(older)
                    if older_at is None:
                        problems.append(f"{rel}:{line_no}: 대신 쓸 「{older}」 이 SF Symbols 에 없다")
                    elif older_at > target:
                        problems.append(f"{rel}:{line_no}: 대신 쓸 「{older}」 도 iOS {'.'.join(map(str, older_at))} 부터라 "
                                        f"iOS {'.'.join(map(str, target))} 에서 빈칸")
                for name in NAMED.findall(code) + CASE_RETURN.findall(code):
                    if name in fallback_new:
                        continue
                    checked += 1
                    at = introduced(name)
                    if at is None:
                        problems.append(f"{rel}:{line_no}: 「{name}」 은 SF Symbols 에 없다 — 어느 판에서도 빈칸")
                    elif at > target:
                        problems.append(f"{rel}:{line_no}: 「{name}」 은 iOS {'.'.join(map(str, at))} 부터 — "
                                        f"iOS {'.'.join(map(str, target))} 기기에서 빈칸(SFSymbolFallback.prefer 로 옛 이름을 같이)")
    if problems:
        print(f"❌ SF Symbols 이름 검사 실패 — 빈칸으로 그려지는 아이콘 {len(problems)}곳:")
        for problem in problems:
            print("  " + problem)
        return 1
    print(f"✅ SF Symbols 이름 검사 통과 (이름 {checked}곳 · 지원 판 iOS {'.'.join(map(str, target))})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
