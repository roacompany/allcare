#!/usr/bin/env python3
"""pregnancy-weeks.json 데이터 sanity check.

H-4 자동 검증: 4-40 연속, 필수 필드, disclaimerKey 유효, 한국어 충실성.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path


REQUIRED_FIELDS = {"week", "fruitSize", "milestone", "tip", "disclaimerKey"}
VALID_DISCLAIMER_KEYS = {
    "pregnancy.disclaimer.general",
    "pregnancy.disclaimer.kick",
    "pregnancy.disclaimer.labor",
}
EXPECTED_WEEKS = set(range(4, 41))  # 4-40 inclusive


def main() -> int:
    project = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
    weeks_file = project / "BabyCare" / "Resources" / "pregnancy-weeks.json"
    if not weeks_file.exists():
        print(f"❌ 파일 없음: {weeks_file}")
        return 1

    print("▸ pregnancy-weeks.json sanity check...")
    data = json.loads(weeks_file.read_text())
    errors: list[str] = []
    warnings: list[str] = []

    if not isinstance(data, list):
        print("❌ 최상위는 배열이어야 함")
        return 1

    weeks_found: set[int] = set()
    for idx, entry in enumerate(data):
        # 필수 필드
        missing = REQUIRED_FIELDS - set(entry.keys())
        if missing:
            errors.append(f"[{idx}] 필수 필드 누락: {missing}")
            continue

        week = entry["week"]
        if not isinstance(week, int) or week < 1 or week > 42:
            errors.append(f"[{idx}] week 범위 이상: {week}")
            continue

        if week in weeks_found:
            errors.append(f"[{idx}] week 중복: {week}")
        weeks_found.add(week)

        # disclaimerKey 화이트리스트
        if entry["disclaimerKey"] not in VALID_DISCLAIMER_KEYS:
            errors.append(f"[week {week}] 알 수 없는 disclaimerKey: {entry['disclaimerKey']}")

        # 한국어 텍스트 비어있지 않음 (fruitSize는 한 글자도 허용 — 예: "쌀")
        if not isinstance(entry["fruitSize"], str) or len(entry["fruitSize"].strip()) == 0:
            errors.append(f"[week {week}] fruitSize 비어있음")
        for field in ("milestone", "tip"):
            value = entry[field]
            if not isinstance(value, str) or len(value.strip()) < 5:
                errors.append(f"[week {week}] {field} 너무 짧음 또는 비어있음")

        # tip이 의학 판단 텍스트 포함 여부 (safety 룰)
        forbidden_terms = ["정상", "비정상", "위험합니다", "안전합니다", "치료"]
        for term in forbidden_terms:
            if term in entry["tip"] or term in entry["milestone"]:
                warnings.append(f"[week {week}] 의학 판단 의심 단어 '{term}' 포함")

    # 4-40 연속 확인
    missing_weeks = EXPECTED_WEEKS - weeks_found
    extra_weeks = weeks_found - EXPECTED_WEEKS
    if missing_weeks:
        errors.append(f"누락 주차 (4-40 연속 필요): {sorted(missing_weeks)}")
    if extra_weeks:
        warnings.append(f"예상 범위 외 주차: {sorted(extra_weeks)}")

    # 결과
    if errors:
        print("❌ 오류:")
        for e in errors:
            print(f"  - {e}")
    if warnings:
        print("⚠️  경고:")
        for w in warnings:
            print(f"  - {w}")

    if errors:
        return 1

    print(f"✅ Sanity PASSED — {len(weeks_found)}개 주차, "
          f"4-40 연속, 필수 필드 OK, disclaimerKey 유효")
    if warnings:
        print(f"   ({len(warnings)}건 경고는 검토 권장)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
