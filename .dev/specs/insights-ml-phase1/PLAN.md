# Insights ML — Phase 1 (Statistical Anomaly Detection)

## Goal
주간 인사이트 알고리즘을 "유동적(adaptive)"으로 전환. 본인 아기 history 기반 Z-score로 "이 아기에겐 평소와 다름"을 surface. 미래 ML 모델 swap을 위한 인터페이스 골격 + 데이터 파이프라인 셋업.

## Non-goals (Phase 2/3로 연기)
- CoreML 모델 도입 (합성 데이터 baseline)
- 서버 학습 + RC weight push
- 사용자 engagement 기반 supervised learning

## Architecture

### Pluggable Scorer Pattern

```
                 ┌────────────────────────────────┐
                 │ InsightContext                 │
                 │  + current PatternReport       │
                 │  + previousActivities          │
                 │  + metricHistory: [String:[Double]]  ← NEW
                 │  + weights (RC)                │
                 └────────────────┬───────────────┘
                                  │
        ┌─────────────┬───────────┼───────────┬──────────────┐
        ↓             ↓           ↓           ↓              ↓
   FeedingProvider   Diaper      Sleep      Health     (future Provider)
        │             │           │           │              │
        └─────────────┴───────────┼───────────┴──────────────┘
                                  ↓
                          [InsightCandidate]
                          + currentValue (NEW — 점수화 입력)
                                  │
                                  ↓
               ┌──────────────────────────────────────┐
               │  InsightScoringService.dispatch()    │
               │   ↳ scorerMode (RC: heuristic|anomaly|hybrid)
               └──────────────────────────────────────┘
                          │              │
                          ↓              ↓
                  HeuristicScorer   StatisticalAnomalyScorer
                  (legacy rule)     (Z-score per baby)
```

### Cold-start Fallback Chain
```
candidate.history.count >= minSamples (default 4)?
  YES → StatisticalAnomalyScorer (Z-score × medicalWeight)
  NO  → HeuristicScorer (|Δ%| × medicalWeight × min(sample/7,1))
```
4주 history 누적되기 전까지는 기존 휴리스틱 동작 유지 → 신규 사용자 회귀 0.

### Data Persistence

**WeeklyMetricSnapshot** (Firestore)
- 경로: `users/{uid}/babies/{bid}/weeklyMetrics/{weekKey}` (예: `weekKey="2026W19"`)
- 필드:
  ```swift
  struct WeeklyMetricSnapshot: Codable {
      let weekStartDate: Date
      let metrics: [String: Double]  // metric_key → value
  }
  ```
- 쓰기 시점: 주간 인사이트 로드 후 (weekly compute 1회)
- 읽기 시점: 인사이트 계산 전 (last K=8 weeks)
- Idempotent (같은 weekKey 덮어쓰기)

### InsightCandidate 확장
```diff
 struct InsightCandidate {
     let category: InsightCategory
     let metricKey: String
+    /// 이번 주 metric 값 (Z-score 계산 입력)
+    let currentValue: Double
     let title: String
     let detail: String
     let changePercent: Double
     let trend: Trend
     let medicalWeight: Double
     let sampleSize: Int
 }
```

## RC Parameters (신규)

| Key | Type | Default | 설명 |
|---|---|---|---|
| `insight_scorer_mode` | STRING | `"hybrid"` | `heuristic` / `anomaly` / `hybrid` (cold-start fallback) |
| `insight_min_history_weeks` | NUMBER | `4` | anomaly scorer 활성 최소 주차 |
| `insight_history_weeks` | NUMBER | `8` | fetch 윈도우 |

## Analytics Events (신규 — Phase 2 ML 학습용)

| Event | Params |
|---|---|
| `insight_generated` | category, metricKey, score, scorerMode, historyWeeks |
| `insight_shown` | category, metricKey, position |
| `insight_tapped` | category, metricKey, position |

## File Plan

신규:
- `BabyCare/Models/WeeklyMetricSnapshot.swift`
- `BabyCare/Services/FirestoreService+Insights.swift` — save/fetch snapshots
- `BabyCare/Services/Insights/InsightScorer.swift` — protocol + dispatch
- `BabyCare/Services/Insights/HeuristicScorer.swift` — 현재 rule 추출
- `BabyCare/Services/Insights/StatisticalAnomalyScorer.swift` — Z-score
- `.dev/specs/insights-ml-phase1/PLAN.md` (this file)

수정:
- `BabyCare/Services/Insights/InsightProvider.swift` — Candidate에 currentValue
- `BabyCare/Services/Insights/InsightScoringService.swift` — 디스패치
- `BabyCare/Services/Insights/InsightWeights.swift` — RC 신규 키
- `BabyCare/Services/Insights/{Feeding,Diaper,Sleep,Health}InsightProvider.swift` — currentValue 채움
- `BabyCare/Services/WeeklyInsightService.swift` — metricHistory 컨텍스트 빌드
- `BabyCare/ViewModels/ActivityViewModel.swift` — snapshot 저장 + history 로드
- `BabyCare/Services/AnalyticsEvents.swift` — 신규 이벤트
- `BabyCare/Utils/Constants.swift` — `weeklyMetrics` 컬렉션 상수
- `firestore.rules` — 기존 wildcard로 커버됨 확인
- `remoteconfig.template.json` — 신규 RC 키
- `CLAUDE.md` — Architecture 섹션 인사이트 v3 반영

테스트:
- Provider별 currentValue 테스트
- HeuristicScorer / StatisticalAnomalyScorer 단위
- Cold-start fallback 시나리오
- WeeklyMetricSnapshot encode/decode

## Verification

- [x] make verify PASS (lint 0 error / arch 0 violations / 단위 테스트 PASS / design 100%)
- [x] arch-test 0 violations
- [x] firestore rules wildcard `babies/{babyId}/{subcollection}/{docId}`로 weeklyMetrics 커버 (rules 코멘트 명시)
- [x] 신규 RC 파라미터 deploy 완료 (firebase deploy --only remoteconfig, REST_API origin)
- [x] HybridScorer 단위 테스트로 4주 미만 history → Heuristic 동일 결과 검증 (회귀 0)
- [x] StatisticalAnomalyScorer Z-score 수식 검증 (history=[4,5,6,5], current=10 → ~14.14)
- [x] WeeklyMetricSnapshot Codable round-trip + weekKey ISO 형식

## Phase 2 Hooks (이번에 안 함, 인터페이스만)

- `InsightScorer` 프로토콜 = CoreML 모델 swap 지점
- `metricHistory` 데이터 구조 = 학습/추론 입력
- Analytics 이벤트 = 미래 supervised label
