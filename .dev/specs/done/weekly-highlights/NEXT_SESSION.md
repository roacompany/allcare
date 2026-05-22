# Weekly Highlights — 새 세션 핸드오프

> 작성: 2026-05-11 | Status: PLAN approved (plan-reviewer OKAY), 실행 대기
> Spec: `.dev/specs/weekly-highlights/PLAN.md`

---

## 한 줄 요약

**대시보드 "이번 주 하이라이트" 풀스코프 시각화** — 자동 롤링 티커 + AI 요약 bottom sheet + 4 카드 Sparkline 그리드. **v2.8.3 출시 목표**, Phase 1 ML(`InsightScoringService`) 활용, Firebase Functions Claude API 프록시.

---

## 새 세션 시작 시 첫 5분

```bash
# 1. 현재 상태 파악
cd /Users/roque/BabyCare
git status                    # working tree clean 상태 확인
git log --oneline -5          # main HEAD = ddb63d1 (AdMob 제거)
cat .dev/specs/weekly-highlights/PLAN.md | head -50   # PLAN 개요

# 2. App Store 상태 확인 (v2.8.2 READY_FOR_SALE 가정)
python3 -c "
import jwt, time, requests
from pathlib import Path
key_id = '2LSXRAHPW7'
issuer_id = 'b70eb6de-e25a-47a1-8021-28872df65d61'
key_path = Path.home() / '.appstoreconnect/private_keys/AuthKey_2LSXRAHPW7.p8'
now = int(time.time())
token = jwt.encode({'iss': issuer_id, 'iat': now, 'exp': now + 1200, 'aud': 'appstoreconnect-v1'},
    key_path.read_text(), algorithm='ES256', headers={'kid': key_id, 'typ': 'JWT'})
r = requests.get('https://api.appstoreconnect.apple.com/v1/apps/6759935352/appStoreVersions?limit=3',
    headers={'Authorization': f'Bearer {token}'})
for v in r.json()['data']:
    print(v['attributes']['versionString'], v['attributes']['appStoreState'])
"
```

---

## 진입 트리거 (사용자 입력 후보)

| 의도 | 입력 |
|---|---|
| 그대로 실행 | `/execute weekly-highlights` |
| 격리 worktree에서 실행 | `/worktree create weekly-highlights` 후 worktree로 이동 → `/execute weekly-highlights` |
| Draft PR 먼저 생성 | `/open weekly-highlights` |
| Pre-work 진행 (Functions 셋업) | "Firebase Functions 셋업부터 도와줘" |
| PLAN 재검토 / 수정 | "PLAN을 다시 보고 수정할 점이 있는지 검토해줘" |

**권장 진입**: `/worktree create weekly-highlights` (Phase 1 ML 안정성 보존)

---

## Pre-work (Blocking — 모두 user action 필요)

다음 4건은 코드 작업 시작 전 반드시 완료:

1. **v2.8.2 App Store READY_FOR_SALE 확인** ✅ (2026-05-10 통과 완료)
2. **Firebase Functions 초기화** — `babycare-admin` repo (`/Users/roque/babycare-admin`)
   ```bash
   cd /Users/roque/babycare-admin
   firebase init functions --project com.roacompany.allcare
   # TypeScript 선택, ESLint 활성
   # region: asia-northeast3 (서울) 권장
   ```
3. **Anthropic API Key Functions secret 등록**
   ```bash
   firebase functions:secrets:set ANTHROPIC_API_KEY
   # 프롬프트에 Anthropic Console에서 발급한 키 붙여넣기
   # iOS 앱에 키 번들 절대 금지 (의료앱 보안)
   ```
4. **Functions 배포 권한 확인** — Firebase Console IAM → `roles/cloudfunctions.developer`

Optional:
- Anthropic Console에서 Tier 1 한도 확인 (claude-haiku-4-5 RPM 50 / ITPM 50K)
- claude-haiku-4-5 가격 인지: $1/MTok input, $5/MTok output (prompt caching 활성 시 cache hit $0.10/MTok)

---

## TODO 실행 순서 요약 (PLAN.md 상세)

```
TODO 1 (인프라 P0) → TODO 2 (Firestore 캐시) → TODO 3 (InsightService 확장)
   ↓
   ├─ TODO 4 (Ticker)  ┐
   ├─ TODO 5 (Sheet)   ├─ Group A 병렬
   ├─ TODO 7 (Grid)    ┘
   ├─ TODO 6 (AI + Functions)  ← Group B 병렬 (별도 repo)
   ↓
TODO 8 (Dashboard XOR 통합)
   ↓
TODO 9 (사전 캐시 워커)
   ↓
TODO 10 (회귀 가드: 단위 14 + XCUITest 5 + a11y + QA)
   ↓
TODO Final (Verification: make verify + plan-verify + arch + index + smoke)
```

**작업 규모**: 10 work TODOs + 1 verification, 단위 +14 / XCUITest +5 / 신규 파일 약 9개

---

## 절대 잊지 말 것 (Must NOT)

PLAN.md "Must NOT Do (Guardrails)" 섹션 20개 룰 중 가장 회귀 위험 큰 5건:

1. **iOS 앱에 Anthropic API Key 번들 금지** — Firebase Functions 프록시만
2. **AppContext switch에 `default:` case 추가 금지** — 빌드 58 회귀 방지
3. **`weeklyInsightsCard`를 `.opacity(0)` / `if false` 처리 금지** — XOR 게이트 1곳 (`FeatureFlagService.isHighlightV2Enabled`)
4. **AI payload에 baby.name/birthDate/일기/임신 데이터 포함 금지** — allowlist 4 카테고리 metricKey + 집계 수치만
5. **Analytics 파라미터에 weekKey/babyId 포함 금지** — 준개인정보 (출산일 역산)

---

## Key Decisions (Interview 합의)

- 옵션 Y 풀스코프 (시각 임팩트 우선, X/Z 옵션 거부)
- Path A (AI 포함) + Path C (v2.8.2 승인 후 시작)
- AI 키 = Firebase Functions 프록시 (의료앱 보안)
- weeklyInsightsCard RC fallback 공존 (kill switch)
- 임신 격리 = allowlist 필터 + 단위 테스트
- RC 7개 → 2개로 축소 (`highlight_enabled`, `highlight_ticker_pct`)
- 사전 캐시 워커 = 주 1회 + pull-to-refresh (scenePhase hook 제거)
- Sparkline 데이터 = `fetchWeeklyMetricSnapshots(limit:4)` 사용
- WeeklyHighlight ViewModel = `InsightService` 확장 (신규 클래스 0)

---

## 회귀 방지 (임신 v2 5빌드 회귀 교훈 적용)

| 빌드 회귀 | 적용 가드 |
|---|---|
| 빌드 56 orphan | 신규 섹션은 DashboardView XOR 게이트 단일 위치만 |
| 빌드 58 silent gating | AppContext switch 4 case exhaustive, default 금지 |
| 빌드 59 UIView single-parent | TimelineView 사용 (UIView Representable 미사용) |
| 빌드 60 단독 체크 | `InsightService.topHighlights(for: AppContext)` 4-state 분기 |
| 빌드 61 가족 격리 | `babyVM.dataUserId()` 패턴, `authVM.currentUserId` 직접 사용 금지 |

---

## 참고 파일 (PLAN 작성 시 사용된 핵심 레퍼런스)

- `BabyCare/Services/Insights/InsightProvider.swift:53-55` — 프로토콜
- `BabyCare/Services/Insights/InsightScorer.swift:13-15` — Scorer 3종
- `BabyCare/Services/Insights/InsightScoringService.swift:18-30` — selectTopN
- `BabyCare/Models/WeeklyMetricSnapshot.swift:9-23` — Codable 패턴
- `BabyCare/Services/FirestoreService+Insights.swift:9-31` — CRUD 패턴
- `BabyCare/Services/FeatureFlagService.swift:1-99` — Hybrid 게이팅
- `BabyCare/Utils/AppContext.swift:1-31` — 4-state enum
- `BabyCare/Views/Dashboard/DashboardView.swift:35-72` — 섹션 순서 + 4-state switch
- `BabyCare/Views/Dashboard/DashboardView+Shortcuts.swift:6-72` — weeklyInsightsCard 기존
- `BabyCare/Views/Growth/GrowthView+Charts.swift:1-80` — Apple Charts 패턴
- `BabyCare/ViewModels/AIAdviceViewModel.swift:12-69` — AI 호출 패턴 (참조만, 신규 작성)

---

## Verification (recap)

- A: 31 (Tier 1 단위 19 + Tier 3 XCUITest 5 + 정적/빌드 7)
- H: 10 (실기기 a11y / 의료 감수 25 샘플 / Firestore audit / Functions 배포 / 비용 모니터링)
- S: 0 (Tier 4 sandbox 부재, 정상)

---

## 외부 의존성 (대기 user action)

| 항목 | 위치 | 명령 |
|---|---|---|
| Firebase Functions 신규 | `/Users/roque/babycare-admin/functions/` | `firebase init functions` |
| Anthropic API Key | Firebase Functions secret | `firebase functions:secrets:set ANTHROPIC_API_KEY` |
| Firestore rules 배포 | `make deploy-rules` | post-work (구현 후) |
| RC 2 키 등록 | Firebase Console | post-work |
| Functions 배포 | `firebase deploy --only functions:summarizeHighlight` | post-work |

---

## 비고

- plan-reviewer가 OKAY 반환했으나 advisory 3건 (non-blocking):
  1. A-22 매핑 표기 명확화 (TODO 9 logic + TODO 10 author)
  2. `/review` 또는 `hoyeon:code-reviewer` 스케줄링 권장 (TODO 6/9 commit 후 — 새 서비스 클래스)
  3. TODO 6 iOS + Functions 통합 (수용)

- 이번 세션 다른 작업 (참고):
  - feat/pregnancy-mode-v2 → main 머지 완료 (PR #4, `82f6127`)
  - `fix/last-accessed-at` + v2 브랜치 정리 완료
  - AdMob 완전 제거 (`ddb63d1`) — `FeatureFlags.adsEnabled`, AdBannerView, SKAdNetworkItems 43, app-ads.txt 삭제, privacy.html 수정
  - 백업 tag: `backup/main-pre-v2-merge`
