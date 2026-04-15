# Feature Enhancement Rollout Learnings (2026-04-15)

## 9개 항목 일괄 실행 (하네스 6축 순환)

각 항목 = specify(mini-PLAN) → execute(worker) → verify(make verify) → commit(원자적) → compound(learnings) → context(CLAUDE.md).

## 발견

### Worker 위임 패턴
- 명확한 "핵심 파일 + 제약 + Must NOT + 검증 게이트" 4-section prompt 구조가 효과적
- "다른 항목 건드리지 마세요" 명시 → 의도치 않은 cross-feature 변경 차단
- 워커가 자체 fix까지 진행하므로 1회 위임으로 verify PASS까지 도달 가능

### enum static service 패턴
- PatternAnalysisService와 같은 enum 패턴이 BabyCare 전반의 컨벤션
- @MainActor @Observable 클래스보다 actor 격리 충돌이 적음
- SleepAnalysisService/FoodSafetyService/HospitalChecklistService/ProductRecommendationService 모두 enum 채택

### SourceKit ≠ 빌드
- CWD=/ 환경에서 SourceKit이 false positive를 대량 생성
- xcodebuild make verify 결과만 신뢰
- 모든 9개 worker 위임 후 SourceKit 진단이 떠도 빌드는 통과

### Codable backward compat
- 기존 Firestore docs decode 보장: 신규 필드는 모두 optional
- 기존 필드명과 충돌 시 새 이름 사용 (예: VaccinationRecord.sideEffects vs sideEffectRecords)

### Apple Charts vs ImageRenderer
- PDF에 차트 임베드 시 ImageRenderer는 MainActor 격리 충돌
- 텍스트 기반 백분위 요약으로 우회 가능 (정보 동등)
- 위젯 타겟에서는 GeometryReader 커스텀 바 사용 (Charts import 불필요)

## 규칙화 (→ .claude/rules/ 검토)

- 신규 서비스: enum static 패턴 우선, @MainActor @Observable는 상태 보관 필요할 때만
- 모델 추가: 신규 필드 optional + Codable 보장 (기존 docs decode)
- 위젯 타겟: BabyCare 본 앱 코드 직접 import 불가 → WidgetDataStore App Group SharedDefaults 통과

## 누적

- 테스트 107 → 195 (+88)
- 커밋 11개 (feat 9 + fix 1 + docs 1)
- arch-test 0 violations
- harness-score 96% Grade A 유지
