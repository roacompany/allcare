# Feature Enhancement Rollout (Master Plan)

> 목적: feature-enhancement-report.md (2026-04-14) 잔여 9개 항목을 하네스 엔지니어링 6축 순환에 따라 순차 실행
> 작성: 2026-04-15

## Harness 6축 적용 원칙

각 항목마다:
1. **Planning**: 해당 기능의 mini-plan(범위 + 파일 + 검증) 작성
2. **Execution**: hoyeon:worker 또는 직접 구현 (단일 책임)
3. **Verification**: `make verify` (build+lint+arch-test+test+design) + hoyeon:code-reviewer (critical 이슈 시)
4. **Compound**: 커밋 + .dev/learnings/ append (3번 반복 시 Skill화)
5. **Context**: CLAUDE.md harness-score / Active TODO 갱신
6. **Scaffolding**: 신규 서비스 파일은 Services/ 또는 ViewModels/, arch-test baseline 0 유지

## 실행 순서 (보고서 추천 순서 유지, 완료/병행 제외)

| # | 기능 | Tier | 작업량 | 핵심 파일 |
|---|------|------|--------|-----------|
| 4 | 대시보드 인사이트 카드 | T1 | 2-3일 | DashboardView+Summary.swift, DashboardComponents.swift |
| 5 | 수면 분석 + 퇴행 감지 | T2 | 2일 | PatternAnalysisService, PatternReport+Sleep, PatternModels |
| 6 | 예방접종 알림 강화 | T3 | 1-2일 | HealthViewModel, VaccinationListView, NotificationService, DashboardView+Summary |
| 7 | 할일/루틴 자동화 | T2 | (검증) | done/todo-routine-automation 검증만 |
| 8 | 일기 자동 요약 | T2 | 2-3일 | DiaryViewModel, DiaryView |
| 9 | 알레르기 추적 강화 | T3 | 2-3일 | HealthViewModel, SolidFoodSection, AllergyListView |
| 10 | 병원 리포트 강화 | T2 | 2-3일 | HospitalReportViewModel, PDFReportService, AnalysisEngine |
| 11 | 제품 추천 | T3 | 2-3일 | ProductViewModel, CatalogService, CoupangAffiliateService |
| 12 | 위젯 강화 | T3 | 2-3일 | BabyCareWidget/, WidgetDataStore |

## 진행 규칙 (Must)

- 각 항목 완료 → 원자적 커밋 (하네스 X3 구조화 출력)
- arch-test baseline 0 유지 (신규 위반 0)
- SwiftLint warning ↑ 금지
- 신규 모델 필드는 optional (Codable 호환)
- 공유 아기 데이터: babyVM.dataUserId() 사용
- Localizable.strings 키 사용 (하드코딩 한국어 지양)

## Must NOT

- AIGuardrailService 금지어 수정 금지
- 외부 차트 라이브러리 도입 금지 (Apple Charts만)
- 백분위 의학적 판단 텍스트 추가 금지
- 새 Firestore 컬렉션은 FirestoreCollections 상수 + 보안 규칙 동시 추가

## 검증 게이트

각 항목 완료 시점:
- ✅ make verify PASS
- ✅ arch-test 0 violations
- ✅ Localizable 키 추가 (한국어 raw 금지)
- ✅ 단위 테스트 +N개 (가능한 영역)
- 🟡 critical 위험 시 hoyeon:code-reviewer 호출

## 완료 후

- CLAUDE.md "Recent Changes (v2.7)" 섹션 신설 + 모든 기능 요약
- harness-score 재측정
- .dev/specs/feature-enhancement-rollout/ → done/ 이동
- feature-enhancement-report.md 상태 표 갱신
