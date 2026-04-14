# 성장 차트 강화 (Growth Chart v2)

> 기본 차트에 WHO 백분위 밴드 통합, 성장 속도 트렌드 차트, "또래 상위 XX%" 강화
> Mode: standard/autopilot

## Assumptions

| Decision Point | Assumed Choice | Rationale | Source |
|---------------|---------------|-----------|--------|
| 기본 차트 백분위 밴드 | 기존 확장 차트(expandedChart)의 밴드를 기본 차트에 통합 | 확장 토글 제거 → 항상 밴드 표시 | lower-risk |
| 차트 높이 | 기본 180px → 240px (밴드 포함 시 더 읽기 쉽도록) | 기존 확장 280px 보다 작게, 기본보다 크게 | lower-risk |
| 성장 속도 차트 | 최근 3개 이상 측정값의 percentile 변화 LineMark | 기존 growthVelocity는 2개만 비교 — 3개월 트렌드 표시 | codebase-pattern |
| "또래 상위 XX%" 표시 | 기존 capsule badge 강화 → "상위 XX%" 텍스트 + 색상 | 현재 백분위 숫자만 표시 — "상위" 표현이 직관적 | UX |
| 확장 차트 유지 여부 | 제거 — 기본 차트가 밴드 포함하므로 중복 | 기능 간소화 | lower-risk |

> **Note**: Not confirmed by user — re-run with --interactive to override.

## Verification Summary

### Agent-Verifiable (A-items)
| ID | Criterion | Method | Related TODO |
|----|-----------|--------|-------------|
| A-1 | 기본 차트에 WHO 밴드 표시 | `make build` + 코드 검증 | TODO 1 |
| A-2 | 성장 속도 트렌드 차트 존재 | `make build` | TODO 2 |
| A-3 | "상위 XX%" 텍스트 표시 | `make build` | TODO 1 |
| A-4 | 빌드 성공 | `make build` | TODO Final |
| A-5 | SwiftLint 0 warnings | `make lint` | TODO Final |
| A-6 | arch-test 0 violations | `make arch-test` | TODO Final |
| A-7 | make verify 통과 | `make verify` | TODO Final |
| A-8 | 단위 테스트 통과 | `make test` | TODO Final |

### Human-Required (H-items)
| ID | Criterion | Reason |
|----|-----------|--------|
| H-1 | 차트 시각적 가독성 | 밴드 색상/투명도, 데이터 포인트 구분 |
| H-2 | Dynamic Type 대응 | 큰 텍스트에서도 레이아웃 정상 |

### Verification Gaps
- Apple Charts 렌더링은 시뮬레이터에서만 확인 가능 (실 디바이스 권장)

## External Dependencies Strategy

(none)

## Context

### Original Request
GrowthView+Charts에 WHO 3/15/50/85/97 백분위 밴드 오버레이, 아기 데이터 성장 곡선, 성장 속도 트렌드 차트, "또래 상위 XX%" 한눈에 표시.

### Research Findings
- **이미 구현됨**: 확장 차트(expandedChart)에 WHO 밴드 + 아기 데이터 오버레이 존재 (GrowthView+Charts.swift:109-201)
- **PercentileCalculator API 완비**: `referenceValue(percentile:ageMonths:gender:metric:)`, `percentile(value:ageMonths:gender:metric:)`, `growthVelocity(records:metric:gender:birthDate:)`
- **GrowthRecord 구조**: date, height?, weight?, headCircumference? (metric별 필드)
- **현재 기본 차트**: LineMark + PointMark, 180px, catmullRom interpolation, 백분위 badge (숫자만)
- **Apple Charts**: import Charts, LineMark, PointMark, AreaMark 사용 가능

## Work Objectives

### Core Objective
성장 차트를 WHO 백분위 밴드 통합 + 성장 속도 트렌드 + "또래 상위 XX%" 표시로 업그레이드.

### Concrete Deliverables
- 기본 차트에 WHO 백분위 밴드 (AreaMark) 통합
- "또래 상위 XX%" 표시 강화
- 성장 속도 트렌드 차트 (percentile 변화 LineMark)
- 확장 차트 제거 (기본에 통합)

### Definition of Done
- [ ] `make verify` → ALL CHECKS PASSED
- [ ] 기본 차트에 WHO 밴드 표시
- [ ] "상위 XX%" 텍스트 표시
- [ ] 성장 속도 트렌드 차트 존재 (3개+ 측정값 시)

### Must NOT Do
- 외부 차트 라이브러리 금지 (Apple Charts만)
- PercentileCalculator LMS 테이블 수정 금지
- 의학적 판단 텍스트 금지 ("정상"/"비정상" 등)
- GrowthRecord Firestore 스키마 변경 금지
- git 명령 실행 금지

---

## Orchestrator

### Task Flow

```
TODO-1 (기본 차트 + 백분위 밴드 통합 + "상위 XX%") ─┐
TODO-2 (성장 속도 트렌드 차트)                       ─┤ 병렬
                                                      ↓
TODO-Final (Verification)
```

### Dependency Graph

| TODO | Requires | Produces | Type |
|------|----------|----------|------|
| 1 | - | `charts_updated` (bool) | work |
| 2 | - | `trend_chart_added` (bool) | work |
| Final | all | - | verification |

### Parallelization

| Group | TODOs | Reason |
|-------|-------|--------|
| A | TODO 1, TODO 2 | TODO 2는 새 @ViewBuilder 함수 추가. TODO 1의 VStack에 삽입은 최소 — 병렬 가능 |

> 주의: TODO 2가 차트를 삽입할 위치(GrowthView.swift 또는 GrowthView+Charts.swift)에서 TODO 1과 경미한 충돌 가능. 최종 통합은 Orchestrator가 해결.

### Commit Strategy

| After TODO | Message | Condition |
|------------|---------|-----------|
| 1 | `feat(growth): integrate WHO percentile bands into base chart + top XX% label` | always |
| 2 | `feat(growth): add growth velocity trend chart` | always |

### Error Handling

| Scenario | Action |
|----------|--------|
| work fails | Retry up to 2 times → Fix Task |
| verification fails | Analyze → report |

### Runtime Contract

| Aspect | Specification |
|--------|---------------|
| Working Directory | /Users/roque/BabyCare |
| Network Access | Denied |
| Package Install | Denied |
| Max Execution Time | 10 minutes per TODO |
| Git Operations | Denied |

---

## TODOs

### [x] TODO 1: 기본 차트에 WHO 밴드 통합 + "상위 XX%"

**Type**: work

**Required Tools**: (none)

**Inputs**: (none)

**Outputs**:
- `charts_updated` (bool): true

**Steps**:
- [ ] Read `BabyCare/Views/Growth/GrowthView+Charts.swift` 전체
- [ ] Read `BabyCare/Services/PercentileCalculator.swift` — referenceValue API
- [ ] 기본 `chartSection()` 수정:
  - 차트 높이 180px → 240px
  - WHO 밴드 AreaMark 추가 (expandedChart의 참조 데이터 생성 루프(월별 referenceValue 호출) 재사용, AreaMark 밴드 렌더링은 신규 구현):
    - 3rd-15th 밴드: 연한 빨강 (opacity 0.1)
    - 15th-50th 밴드: 연한 노랑 (opacity 0.1)
    - 50th-85th 밴드: 연한 초록 (opacity 0.1)
    - 85th-97th 밴드: 연한 노랑 (opacity 0.1)
    - 50th 기준선: dashed LineMark
  - 아기 데이터: 기존 LineMark + PointMark 유지 (밴드 위에 표시)
  - X축: 월령 (0-24), Y축: 측정값 (kg/cm)
- [ ] 백분위 badge 강화:
  - 기존: "75th" capsule
  - 변경: "또래 상위 25%" 텍스트 (100 - percentile)
  - 색상: 3-15th 빨강, 15-85th 초록, 85-97th 파랑
- [ ] 확장 차트 제거 + 호출자 정리:
  - `GrowthView+Charts.swift`: `expandedChart()` 함수 제거, `chartSection()`에서 `isExpanded: Binding<Bool>` 파라미터 제거, expand 토글 버튼 제거
  - `GrowthView.swift`: `@State var expandedWeight/expandedHeight/expandedHead` 3개 프로퍼티 제거
  - `GrowthView.swift`: 3개 `chartSection()` 호출에서 `isExpanded:` 인자 제거
  - 기존 `expandedChart` 내 WHO 면책문구 유지 (GrowthView.swift 상단에 이미 존재하므로 별도 추가 불필요)
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

**Must NOT do**:
- PercentileCalculator 수정 금지
- GrowthRecord 수정 금지
- 외부 차트 라이브러리 금지
- 의학적 판단 텍스트 금지
- git 명령 실행 금지

**References**:
- `BabyCare/Views/Growth/GrowthView+Charts.swift:8-104` — chartSection 전체 (기본차트 + expand toggle)
- `BabyCare/Views/Growth/GrowthView+Charts.swift:109-201` — expandedChart (참조 데이터 생성 루프 재사용)
- `BabyCare/Views/Growth/GrowthView.swift:22-25` — @State expandedWeight/Height/Head
- `BabyCare/Views/Growth/GrowthView.swift:50-89` — chartSection 호출 3곳 (isExpanded 인자)
- `BabyCare/Views/Growth/GrowthView+Charts.swift:127-143` — referenceValue 호출 루프
- `BabyCare/Services/PercentileCalculator.swift:284-313` — referenceValue API
- `BabyCare/Services/PercentileCalculator.swift:324-348` — percentile API

**Acceptance Criteria**:

*Functional:*
- [ ] 기본 차트에 WHO 밴드 (AreaMark) 표시
- [ ] "또래 상위 XX%" 텍스트 표시
- [ ] 확장 차트 토글 제거됨

*Static:*
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

*Runtime:*
- [ ] `make test` → 0 failures

---

### [x] TODO 2: 성장 속도 트렌드 차트

**Type**: work

**Required Tools**: (none)

**Inputs**: (none — 독립적으로 새 @ViewBuilder 함수 생성)

**Outputs**:
- `trend_chart_added` (bool): true

**Steps**:
- [ ] Read `BabyCare/Views/Growth/GrowthView+Charts.swift` — 현재 차트 구조 확인
- [ ] Read `BabyCare/Services/PercentileCalculator.swift` — percentile, growthVelocity API
- [ ] 성장 속도 트렌드 차트 추가 (각 metric 차트 아래):
  - 조건: 해당 metric의 측정값 3개 이상일 때만 표시
  - X축: 측정 날짜 (기존 차트와 동일)
  - Y축: 백분위 값 (0-100)
  - LineMark: 각 측정 시점의 percentile 연결 (catmullRom)
  - PointMark: 각 측정 포인트
  - 기준선: 50th percentile dashed 가로선
  - 차트 높이: 120px (메인 차트보다 작게)
  - 헤더: "백분위 추이" 텍스트
  - Y축 라벨: "3rd", "15th", "50th", "85th", "97th" 참조선
- [ ] percentile 계산: 각 GrowthRecord의 date에서 `Calendar.current.dateComponents([.month], from: birthDate, to: record.date).month` → ageMonths → `PercentileCalculator.percentile(value:ageMonths:gender:metric:)`
- [ ] 3개 미만 측정값 시 "측정 기록이 3개 이상이면 백분위 추이를 볼 수 있어요" placeholder
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

**Must NOT do**:
- PercentileCalculator 수정 금지
- TODO 1에서 생성한 WHO 밴드 차트 수정 금지
- 의학적 판단 텍스트 금지
- git 명령 실행 금지

**References**:
- `BabyCare/Views/Growth/GrowthView+Charts.swift` — TODO 1에서 수정된 차트 구조
- `BabyCare/Services/PercentileCalculator.swift:324-348` — percentile API
- `BabyCare/Models/Baby.swift:6` — birthDate
- `BabyCare/Models/GrowthRecord.swift:6` — date 필드

**Acceptance Criteria**:

*Functional:*
- [ ] 3개+ 측정값 시 트렌드 차트 표시
- [ ] 3개 미만 시 placeholder 텍스트
- [ ] 50th percentile 기준선 존재

*Static:*
- [ ] `make build` → exit 0
- [ ] `make lint` → 0 warnings

*Runtime:*
- [ ] `make test` → 0 failures

---

### [x] TODO Final: Verification

**Type**: verification

**Required Tools**: make, swiftlint, bash

**Inputs**:
- `trend_chart_added` (bool): `${todo-2.outputs.trend_chart_added}`

**Outputs**: (none)

**Steps**:
- [ ] `make verify` → ALL CHECKS PASSED
- [ ] `make lint` → 0 warnings
- [ ] `make arch-test` → 0 violations
- [ ] `make test` → 0 failures

**Must NOT do**:
- Edit/Write 금지
- git 명령 실행 금지

**Acceptance Criteria**:

*Functional:*
- [ ] `make verify` → "━━━ ALL CHECKS PASSED ━━━"

*Static:*
- [ ] `make lint` → "0 violations"

*Runtime:*
- [ ] `make test` → 0 failures
