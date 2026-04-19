# 다음 세션 핸드오프 — 임신 모드 재설계 (2026-04-19)

## 현황

- TestFlight v2.7.1 (빌드 62) 업로드 완료, **임신 모드 FeatureFlag=false (hidden)**
- Delivery UUID `34d596a2-fecc-4a4d-9f2b-98c6969c79df`
- 빌드 56-61에 걸친 5회귀 누적으로 사용자가 "쓰레기 같다" 평가 → b 옵션 선택(임시 hide + 재설계)
- 코드는 main에 그대로 (제거 안 함). FeatureFlag만 토글하면 부활 가능
- Firestore 데이터 보존 (모든 사용자 임신 기록 유지)

## 재설계 시 반드시 다룰 결함 (5빌드 회귀 + 검증 공백)

### 빌드 56-61 회귀 패턴 (재발 방지)

| 빌드 | 회귀 | 근본 원인 | 재설계 invariant |
|---|---|---|---|
| 56 | AddBabyView 임신 진입점 orphan | UI 진입점이 spec에 명시 안 됨 | 모든 진입점을 spec에 enumerate + XCUITest 강제 |
| 58 | ContentView gating 조건 누락 | `babies.isEmpty AND !activePregnancy` 한쪽만 체크 | 2x2 상태 조합표를 spec에 첨부 (4 cells 모두 명시) |
| 59 | Firestore composite index silent failure | 신규 복합 쿼리 시 indexes.json 업데이트 누락 | `make index-check` 게이트 (이미 추가, 재설계 시 CI 강제) |
| 59 | 광고 UIView single-parent 위반 | UIViewRepresentable 인스턴스 공유 | swift-conventions.md 룰 (이미 추가) |
| 60 CRITICAL | baby/pregnancy 우선순위 | 3 View가 `activePregnancy != nil` 단독 체크 | 단일 `shouldShowPregnancyUI(babies, pregnancy)` helper로 일원화 (현재 흩어짐) |
| 61 | H-4 가족 공유 배지 격리 | `babyVM.dataUserId()` 전달이 배지 isolation 깸 | "데이터 path vs 부여 대상" 분리를 모델 레벨로 격리 (단순 파라미터 추가는 fragile) |
| 61 | H-8 a11y XXXL 진입점 | 큰 글자에서 layout truncate | 모든 진입점 ViewThatFits 표준 (또는 별도 a11y XCUITest) |

### 검증되지 않은 영역 (현재 spec/test 부재)

- **출산 전환** (Pregnancy → Baby): WriteBatch atomic 단위 4개만. 실 시나리오:
  - transitionState=pending 중 앱 종료 → 재실행 시 복구
  - WriteBatch 실패 시 부분 commit 방어
  - 같은 baby로 두 번 transition 시도
  - sharedWith 파트너가 baby 페이지 접근
- **HealthKit**: opt-in 토글만 검증. 실기기 권한 거부 → grace fallback
- **위젯 visual**: 다크/라이트, 홈/잠금, AccessibilityXXXL
- **pregnancy-weeks 콘텐츠**: 37주 agent 자동 생성. 의료 전문가(산부인과 전문의) 스팟체크 필수
- **태동 (KickSession)**: 햅틱 강도 / 2시간+ 긴 세션 / 백그라운드 → 포그라운드 복귀 / 화면 잠금 중 동작
- **출산 전환 축하 애니메이션**: spring/timing 시각 검증

### 데이터 isolation invariant (가족 공유)

배지/임신/활동 각각 어디에 저장되고 누가 보는지 명시 필요:

| 데이터 | 저장 path | 본인 화면에 노출 | 파트너 화면에 노출 |
|---|---|---|---|
| Activity (수유/수면) | `users/{owner}/babies/{baby}/activities` | 본인이 owner면 OK | 파트너 OK (의도) |
| Badge | `users/{본인}/badges` (currentUserId 강제) | 본인 path만 | 별도 격리 (서로 안 보임) |
| Pregnancy | `users/{owner}/pregnancies` | 본인 OK | sharedWith read-only |
| KickSession 등 임신 하위 | pregnancy 하위 wildcard | 본인 OK | sharedWith read-only |

H-4 회귀는 "Badge가 owner path에 저장되어 파트너에게 노출"이 핵심. 이 isolation을 spec 표로 명시 + 단위 테스트 강제.

## 권장 재설계 절차

1. `/specify pregnancy-mode-v2 --autopilot` 또는 인터랙티브 `/specify pregnancy-mode-v2`
2. spec에 위 회귀 패턴 + 검증 공백을 invariant로 첨부
3. `/plan-eng-review` + `/tribunal` 통과 후 구현
4. H-items 자동 검증 layer를 처음부터 강제 (KickSession/PregnancyDateMath 등 기존 자동 layer는 재사용)
5. 의료 전문가 스팟체크는 user action — pregnancy-weeks.json 검증
6. 단계적 부활: 작은 사용자 그룹 → 전체

## 살릴 수 있는 자산 (재설계 시 재사용)

코드:
- `BabyCare/Models/Pregnancy.swift` 등 6 모델 — 데이터 모델 자체는 OK
- `BabyCare/Utils/PregnancyDateMath.swift` — pure helper, 단위 검증 11개 PASS
- `KickSessionTests` 6 단위 + `PregnancyOutcomeContractTests` 4 단위
- `firestore.rules` pregnancy match 블록 + `firestore.indexes.json` 활성 indexes
- `BabyCareUITests/PregnancyFlowTests.swift` 10 XCUITest (a11y 포함)
- `BadgeFirestoreProviding` + `MockBadgeFirestore` (격리 검증용)

문서/스킬:
- `.dev/specs/done/pregnancy-mode/context/learnings.md` — 회귀 교훈
- `.dev/qa-evidence/v2.7.1.md` — H-items 검증 layer 결과
- `.claude/skills/firestore-collection/SKILL.md` — indexes.json + deploy-rules 게이팅
- `.claude/agents/bug-triage.md` — Layer 0→3 진단

자동화 layer:
- `make index-check` (composite index 누락 silent failure 예방)
- `scripts/pregnancy_weeks_sanity.py` (콘텐츠 schema/연속성/의학 단어 검출)
- `scripts/feature_flag_smoke.sh` (FeatureFlag toggle 빌드 검증)
- `scripts/pre_merge_check.sh` (5 게이트 통합)

## 즉시 잔여 작업 (이번 세션)

- [x] FeatureFlag=false + 빌드 62 push + TestFlight 업로드
- [x] CLAUDE.md / CHANGELOG / 본 핸드오프
- [ ] 사용자: TestFlight 62 설치 → 임신 UI 안 보이는지 확인
- [ ] 사용자: 임신 데이터 보존 확인 (Firebase Console에서 자기 pregnancies 문서 그대로 있는지)

## 정리 완료 (over-engineering)

- ~~`scripts/cleanup_test_pregnancy.sh`~~ 제거 완료 (2026-04-19) — 사용자 데이터 삭제 위험 도구. 진짜 fix는 빌드 60+ gating으로 해결.
- 그 외 검증 layer (index_check / pregnancy_weeks_sanity / feature_flag_smoke / pre_merge_check)는 재설계 시 재사용 가능

## 사용자 피드백 (2026-04-19)

> "임신모드 제대로 개발안된 것 같아... 지금 개 쓰레기 같아."

Memory feedback 저장:
- `feedback_no_data_deletion.md` — 사용자 데이터 자동 삭제 권유 금지
- 추가로: 임신 모드 v2 spec 작성 시 회귀 history를 must-not-do로 첨부

## 임신 모드 외 살아있는 작업

배포된 v2.7.1 (빌드 62)에서 임신 모드 외 모든 기능 정상:
- 배지 시스템 (Phase 2 UI + H-4 fix)
- Feature Enhancement Rollout 9개 (대시보드 인사이트/수면 분석/예방접종/일기/식품 안전/병원 리포트/제품 추천/위젯)
- 울음 분석 stub (FeatureFlag=true, 실모델 v2.7+)
- 자동 검증 harness (make verify ALL CHECKS PASSED, 281+ 단위 + 10 XCUITest)
