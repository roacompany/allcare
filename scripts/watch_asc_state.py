#!/usr/bin/env python3
"""App Store 심사 상태를 폴링해 **상태가 바뀔 때마다** 한 줄 낸다. 종료 상태에 닿으면 종료.

  python3 scripts/watch_asc_state.py            # project.yml 의 MARKETING_VERSION 을 본다
  python3 scripts/watch_asc_state.py 2.8.10     # 버전 직접 지정
  python3 scripts/watch_asc_state.py 2.8.10 300 # 폴링 간격(초) 지정

⚠️ **승인만 잡으면 안 된다.** 거절·무효도 잡아야 「조용함」이 「승인됨」으로 오독되지 않는다.
   승인만 감시하면 거절당한 화면과 아직 심사 중인 화면이 똑같이 조용하다.

🔑 버전을 코드에 박지 않는다 — 인자가 없으면 `project.yml` 에게 묻는다.
   박아 두면 다음 릴리스에 **조용히 옛 버전을 감시**한다(그리고 영영 안 바뀐다).
"""
import re
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / 'scripts'))
from asc_status import load_config, make_token, http_get   # noqa: E402

APP_ID = '6759935352'
DEFAULT_POLL_SECONDS = 900          # 15분 — 심사는 12~48h 단위로 움직인다

# 더 기다려도 안 바뀌는 상태들. 여기 닿으면 감시를 끝낸다.
TERMINAL = {
    'READY_FOR_SALE', 'PENDING_DEVELOPER_RELEASE',
    'REJECTED', 'METADATA_REJECTED', 'DEVELOPER_REJECTED',
    'INVALID_BINARY', 'DEVELOPER_REMOVED_FROM_SALE',
}


def marketing_version() -> str:
    """project.yml 의 MARKETING_VERSION — 릴리스마다 저절로 따라간다."""
    text = (REPO / 'project.yml').read_text(encoding='utf-8')
    match = re.search(r'MARKETING_VERSION:\s*"([^"]+)"', text)
    if not match:
        raise SystemExit('project.yml 에서 MARKETING_VERSION 을 못 찾았다')
    return match.group(1)


def current_state(version: str):
    cfg = load_config()
    token = make_token(cfg)
    data = http_get(
        f'https://api.appstoreconnect.apple.com/v1/apps/{APP_ID}/appStoreVersions'
        f'?filter[versionString]={version}&limit=1'
        f'&fields[appStoreVersions]=versionString,appStoreState', token)
    rows = data.get('data') or []
    return rows[0]['attributes']['appStoreState'] if rows else None


def main() -> None:
    version = sys.argv[1] if len(sys.argv) > 1 else marketing_version()
    poll = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_POLL_SECONDS

    last = None
    while True:
        try:
            state = current_state(version)
        except Exception as error:      # 일시 실패로 감시가 죽지 않게
            print(f'⚠️ 조회 실패(계속 감시): {error}', flush=True)
            time.sleep(poll)
            continue

        if state != last:
            print(f'v{version} 상태: {last or "?"} → {state}', flush=True)
            last = state

        if state in TERMINAL:
            print(f'종료 상태 도달: {state}', flush=True)
            return
        time.sleep(poll)


if __name__ == '__main__':
    main()
