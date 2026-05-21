#!/usr/bin/env python3
"""ASC version status query.

Usage:
  python3 scripts/asc_status.py            # 최근 5 버전
  python3 scripts/asc_status.py 2.8.3      # 특정 버전 + 빌드 정보

Env (모두 기본값 있음):
  ASC_API_KEY       (default: 2LSXRAHPW7)
  ASC_API_ISSUER    (default: b70eb6de-...)
  ASC_KEY_PATH      (default: ~/.appstoreconnect/private_keys/AuthKey_{KEY}.p8)
  APP_ID            (default: 6759935352, com.roacompany.allcare)

train closed 자동 감지: appStoreState=READY_FOR_SALE + submission=None 조합 시
다음 patch bump 권고 출력 (build-gotchas.md code 90186/90062).
"""
import os
import sys
import json
import time
import urllib.request
import urllib.error
from pathlib import Path

import jwt  # PyJWT >= 2.0


def load_config() -> dict:
    api_key = os.environ.get("ASC_API_KEY", "2LSXRAHPW7")
    return {
        "api_key": api_key,
        "issuer": os.environ.get("ASC_API_ISSUER", "b70eb6de-e25a-47a1-8021-28872df65d61"),
        "key_path": os.environ.get(
            "ASC_KEY_PATH",
            str(Path.home() / ".appstoreconnect" / "private_keys" / f"AuthKey_{api_key}.p8"),
        ),
        "app_id": os.environ.get("APP_ID", "6759935352"),
    }


def make_token(cfg: dict) -> str:
    with open(cfg["key_path"]) as f:
        key = f.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": cfg["issuer"], "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"},
        key,
        algorithm="ES256",
        headers={"kid": cfg["api_key"], "typ": "JWT"},
    )


def http_get(url: str, token: str):
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            return json.loads(r.read())
    except urllib.error.HTTPError as e:
        print(f"[ERR] HTTP {e.code}: {e.read().decode()[:300]}", file=sys.stderr)
        return None


def fmt_version(d: dict) -> str:
    a = d["attributes"]
    v = a.get("versionString", "?")
    state = a.get("appStoreState", "?")
    release = a.get("releaseType", "-")
    created = a.get("createdDate", "")[:10]
    line = f"v{v:<8} {state:<25} releaseType={release:<14} created={created}"
    rels = d.get("relationships", {})
    b = rels.get("build", {}).get("data")
    s = rels.get("appStoreVersionSubmission", {}).get("data")
    extras = []
    if b:
        extras.append(f"build={b.get('id', '?')[:8]}...")
    if s:
        extras.append(f"submission={s.get('id', '?')[:8]}... (심사 진행)")
    else:
        extras.append("submission=None (train closed)")
    return line + "  " + " | ".join(extras)


def fmt_build(inc: dict) -> str:
    a = inc.get("attributes", {})
    return (
        f"  build {inc['id'][:8]}...  v={a.get('version')}  "
        f"state={a.get('processingState')}  expired={a.get('expired')}  "
        f"uploaded={a.get('uploadedDate', '')[:19]}"
    )


def detect_train_closed(d: dict) -> str | None:
    """READY_FOR_SALE + submission=None → 다음 patch bump 권고."""
    a = d["attributes"]
    if a.get("appStoreState") != "READY_FOR_SALE":
        return None
    sub = d.get("relationships", {}).get("appStoreVersionSubmission", {}).get("data")
    if sub is not None:
        return None
    v = a.get("versionString", "")
    parts = v.split(".")
    if len(parts) != 3 or not parts[2].isdigit():
        return None
    next_v = f"{parts[0]}.{parts[1]}.{int(parts[2]) + 1}"
    return (
        f"⚠️  v{v} train closed — 동일 버전 새 빌드 제출 불가. "
        f"다음 fix는 v{next_v} bump 필수 (build-gotchas.md code 90186/90062)."
    )


def main() -> int:
    cfg = load_config()
    if not Path(cfg["key_path"]).exists():
        print(f"[ERR] ASC key not found at {cfg['key_path']}", file=sys.stderr)
        return 2
    token = make_token(cfg)
    version_filter = sys.argv[1] if len(sys.argv) > 1 else None

    if version_filter:
        url = (
            f"https://api.appstoreconnect.apple.com/v1/apps/{cfg['app_id']}/appStoreVersions"
            f"?filter%5BversionString%5D={version_filter}"
            f"&include=build,appStoreVersionSubmission"
        )
        print(f"# ASC v{version_filter} (app={cfg['app_id']})\n")
    else:
        url = f"https://api.appstoreconnect.apple.com/v1/apps/{cfg['app_id']}/appStoreVersions?limit=5"
        print(f"# ASC 최근 5 버전 (app={cfg['app_id']})\n")

    data = http_get(url, token)
    if not data:
        return 1

    if not data.get("data"):
        print("(no versions found)")
        return 0

    for d in data["data"]:
        print(fmt_version(d))

    builds = [inc for inc in data.get("included", []) if inc["type"] == "builds"]
    if builds:
        print("\n# Build details")
        for inc in builds:
            print(fmt_build(inc))

    warnings = [w for w in (detect_train_closed(d) for d in data["data"]) if w]
    if warnings:
        print()
        for w in warnings:
            print(w)

    return 0


if __name__ == "__main__":
    sys.exit(main())
