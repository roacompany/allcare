---
name: changelog-to-landing-sync
description: BabyCare CHANGELOG.md의 최신 버전 블록을 읽어 GitHub Pages 랜딩 페이지(index.html, terms.html, privacy.html)의 버전 표기·featureList·새 기능 섹션을 동기화한다. "랜딩 동기화", "릴리즈 반영", "랜딩 최신화", "sync landing", "CHANGELOG 랜딩에 반영" 요청 시 사용.
version: 1.0.0
---

# Changelog → Landing Sync

BabyCare 앱의 새 버전이 나올 때마다 GitHub Pages 랜딩 페이지를 손으로 갱신하는 작업을 자동화한다.

## 입력
- `/Users/roque/BabyCare/CHANGELOG.md` (단일 진실 소스)
- 선택 인자: 버전 (예: `v2.7.0`). 생략 시 CHANGELOG의 가장 최신 `## [x.y.z]` 블록 사용.

## 영향 파일
- `/Users/roque/allcare/index.html` — softwareVersion, meta description, OG/Twitter description, featureList(JSON-LD), hero pills 버전 뱃지, "v{X} 새 기능" 섹션
- `/Users/roque/allcare/terms.html` — "최종 업데이트" 날짜
- `/Users/roque/allcare/privacy.html` — "최종 업데이트" 날짜 + 신규 데이터 수집 항목 (있을 시 사용자 검토 요청)
- `/Users/roque/allcare/sitemap.xml` — 모든 `<lastmod>`을 오늘 날짜로 갱신

## 실행 절차

### 1. CHANGELOG 파싱
```bash
# 최신 버전 블록 식별
grep -n "^## \[" /Users/roque/BabyCare/CHANGELOG.md | head -5
```
- 첫 번째 매치가 최신 버전. 다음 `## [` 직전까지가 해당 버전 블록.
- 추출 항목: 버전 문자열, 릴리즈 날짜, `### Added`, `### Changed`, `### Fixed`, `### Internal` 섹션의 bullet.

### 2. 마케팅 카피 변환 (중요)
CHANGELOG의 기술 표현을 사용자 언어로 번역한다. 예시:
- "stub, flag=true" → 표기 생략 또는 "(베타)"
- "InsightService" / "@MainActor @Observable" → 내부 구현명, 노출 금지
- "RetryHelper, OfflineQueue" → 내부, 노출 금지
- 길이: "새 기능" 섹션 bullet은 6~8개로 축약, 각 25자 이내 권장

### 3. index.html 갱신 지점 (정확한 위치)
| 위치 | 패턴 | 갱신 내용 |
|------|------|----------|
| `<title>` | 변경 없음 | - |
| `<meta name="description">` | 80~120자 한국어 요약 | 신규 핵심 기능 2~3개 포함 |
| `<meta property="og:description">` `<meta name="twitter:description">` | description과 동일 톤 | - |
| JSON-LD `softwareVersion` | `"2.7.0"` | 신 버전 |
| JSON-LD `featureList` | 콤마 구분 한국어 | 새 기능 누적 반영 |
| `.hero-pills .pill.accent` | `"✨ vX.Y.Z"` | 신 버전 |
| `<!-- NEW IN vX.Y.Z -->` 섹션 | premium-container 내부 | h3 제목 + premium-list bullet 6~8개 + premium-badge "✨ NEW" |
| `<!-- 빠른 기록 -->` `<!-- 건강 관리 -->` `<!-- 스마트 육아 -->` 카드 | 신규 기능에 해당 카드 추가/수정 | 필요 시 |

### 4. terms.html / privacy.html 날짜
- "최종 업데이트: YYYY-MM-DD" 패턴 검색 → 오늘 날짜로 교체
- privacy.html의 경우 신규 데이터 수집(예: 음성, 위치) 추가가 있는지 사용자에게 확인 후 조항 추가

### 5. sitemap.xml
- `<lastmod>` 3개 모두 오늘 날짜(YYYY-MM-DD)로 교체

### 6. 검증
- Read 도구로 변경된 모든 파일 재확인
- 버전 문자열 grep으로 누락 점검:
```bash
grep -rn "v2\." /Users/roque/allcare/*.html | grep -v "v{NEW_VERSION}"
```

### 7. 커밋 (사용자 승인 후)
```
chore: 랜딩페이지 v{VERSION} 최신화

- index.html: meta/JSON-LD/hero/새 기능 섹션 갱신
- terms.html, privacy.html: 최종 업데이트 날짜
- sitemap.xml: lastmod
```

## 주의
- **자동 push 금지**. 커밋 후 사용자에게 push 여부 확인.
- privacy.html에 신규 데이터 수집 항목 추가는 **사용자 검토 필수**.
- CHANGELOG의 `Internal` 섹션은 노출하지 않음.
- 기존 hover/animation 등 UI/UX 변경은 별도 작업으로 분리.

## 예시 호출
- "랜딩 v2.7.0 동기화"
- "CHANGELOG 최신 버전 랜딩에 반영"
- "privacy.html 날짜 갱신해줘"
