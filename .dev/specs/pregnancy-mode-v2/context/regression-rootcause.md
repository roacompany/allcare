# v1 임신 모드 5빌드 회귀 근본 원인 분석

> 기준: v2.7.1 빌드 56-61 (2026-04-17~19) + CLAUDE.md `v2.7.1 임신 모드 회귀 이력` + `.dev/specs/done/pregnancy-mode/context/learnings.md`
> 목적: v2 설계가 각 회귀의 근본 원인을 구조적으로 제거하는지 1:1 검증

---

## 빌드 56

**현상**: AddBabyView에 임신 모드 진입점 누락 (orphan UI)

**회귀 유발 커밋**: `ef77e32 fix(pregnancy): AddBabyView에 임신 모드 진입점 추가` — 이 커밋이 fix인 것은 곧 빌드 56 업로드 당시 이 fix가 포함되지 않았음을 의미. 초기 임신 모드 구현(TODO 1-12)에서 AddBabyView 진입점을 누락한 채 빌드 56 배포.

**근본 원인**:
- 임신 등록 플로우 진입점이 `AddBabyView` 한 곳이지만, 구현 시 TODO 체크리스트에 해당 진입점 명시가 없어 grep으로도 탐지 불가
- "완성 = 코드 작성"으로 착각 — 사용자 플로우 전수 검증 없이 배포
- 진입점 누락은 `make verify`(build+lint+arch-test)에서 탐지 불가

**분류**: (b) 프로세스 버그 — 진입점 전수 체크 없는 배포 gate

**v2 해결책**:
- `AppContext` 4-state enum 도입 → 진입점이 enum case로 명시화되어 `switch` exhaustive 강제
- Phase 1 착수 전 `additive card` 설계에서 모든 진입점을 사전 specced (ContentView / Dashboard card / AddBabyView 버튼)
- H-items에 "임신 진입점 3곳 전부 tappable" XCUITest 포함 (H-items 전부 [V] gate 필수)
- `make plan-verify` — PLAN 항목과 코드 1:1 대조 (진입점 누락 시 FAIL)

---

## 빌드 58

**현상**: ContentView gating 조건 누락 — baby가 있는 사용자에게도 임신 온보딩 노출

**회귀 유발 커밋**: `12d4dee chore(release): bump build 57 → 58` 포함 번들에서 ContentView의 `babies.isEmpty && activePregnancy != nil` 복합 조건 대신 `activePregnancy != nil` 단독 체크로 구현됨. 빌드 57에서 신규 테스트 19개 + XCUITest 3개 추가했음에도 이 케이스를 커버하지 못함.

**근본 원인**:
- 두 상태(baby 보유 / activePregnancy 존재) 공존 시나리오를 2×2 조합표로 설계하지 않고 "임신만 있는 사용자"만 상정
- `activePregnancy != nil` 단독 체크는 기존 baby 사용자에게 pregnancy UI를 노출하는 silent regression
- `make verify` + 19개 신규 테스트 모두 단일 상태 가정 — 공존 케이스 테스트 없음

**분류**: (a) 구조 버그 — gating 로직 분산 + 공존 상태 미설계

**v2 해결책**:
- `AppContext` enum 4-state (`babyOnly` / `pregnancyOnly` / `both` / `neither`) 로 gating 일원화 — View 레벨에서 `activePregnancy != nil` 직접 참조 금지
- `AppContext.swift` static factory에서 `babies.isEmpty && activePregnancy != nil` 복합 조건이 유일 진입점
- `AppContext` switch에 `default:` 금지 → 신규 케이스 추가 시 컴파일러가 모든 switch를 강제 알림
- XCUITest: `both` 케이스 (아기 있는 사용자 + 활성 임신 동시) 시나리오 커버

---

## 빌드 59

**현상 1**: Firestore composite index 누락 → `fetchActivePregnancy` silent failure (PERMISSION_DENIED / FAILED_PRECONDITION)
**현상 2**: AdMob BannerView UIView single-parent 위반 → 광고 blank/refresh 사이클

**회귀 유발 커밋**: `8e8034b fix: 임신 등록 Firestore index + 광고 per-instance 복원` 이 빌드 59의 fix → 빌드 58-59 구간에서 두 독립 회귀 동시 발생

**근본 원인 1 (Firestore index)**:
- `fetchActivePregnancy`에 `outcome == "ongoing"` + `createdAt DESC` 복합 쿼리 사용했으나 `firestore.indexes.json`에 해당 index 미등재
- Firestore composite index 누락은 에러 메시지 대신 `PERMISSION_DENIED` 또는 쿼리 무응답으로 silent failure — 로그 없으면 원인 파악 불가
- `make verify`는 Firestore 쿼리 실행을 검증하지 않음

**근본 원인 2 (UIView single-parent)**:
- `BannerAdManager` shared UIView 인스턴스를 여러 탭(Dashboard, Health 등)에서 재사용
- SwiftUI는 View 마운트/언마운트 시 UIView를 reparent → blank 화면 + 무한 refresh 사이클
- UIViewRepresentable 재사용 패턴이 UIKit 제약(`UIView는 single-parent`)을 위반

**분류**: (c) external + (a) 구조 버그 — Firestore index는 external infra, UIView는 UIKit 아키텍처 제약 위반

**v2 해결책 (Firestore index)**:
- `make index-check` 타겟 도입 — 신규 `whereField + orderBy` 조합 추가 시 `firestore.indexes.json` 미동기화 탐지
- `make deploy-rules` gate — Firestore 관련 변경 PR 시 `deploy-rules` PASS 필수
- `firestore-collection` skill이 신규 컬렉션 scaffold 시 indexes.json 자동 추가 강제
- P0-5: collectionGroup 쿼리 규칙 선배포 game plan

**v2 해결책 (UIView single-parent)**:
- `.claude/rules/swift-conventions.md`에 "UIView는 단일 parent — UIViewRepresentable per-instance 강제" 룰 등재 (빌드 59 이후 codified)
- v2 AdBannerView: per-instance 구조 유지, `BannerAdManager`는 state 추적만
- 아키텍처 위반은 `arch-test`가 아닌 code review gate + rules 파일로 방어

---

## 빌드 60

**현상**: baby 보유 사용자에게 pregnancy UI 노출 CRITICAL — DashboardView / HealthView / RecordingView 3곳에서 gating 일관성 없음 + 임신 삭제 escape hatch 부재

**회귀 유발 커밋**: `920b908 fix(CRITICAL): baby와 pregnancy 공존 시 baby UI 우선 + 임신 삭제 escape hatch`

**근본 원인**:
- 빌드 58에서 ContentView gating 수정 후 3개 하위 View(Dashboard/Health/Recording)는 각자 독립 조건으로 gating → 일부는 `activePregnancy != nil` 단독 체크 잔존
- 상태 공존 케이스(`babies.isEmpty == false && activePregnancy != nil`)에서 3곳 중 일부가 pregnancy UI를 노출
- 실제 사용자("하윤이 데이터 있는데 임신모드 노출") 사고 → P0 critical
- `make verify` + XCUITest는 단일 View 시나리오만 커버, 3-View 연계 케이스 미포함
- 임신 Firestore 문서가 계정에 남아있어 escape path 없음 (삭제 UI 부재)

**분류**: (a) 구조 버그 — gating 로직이 3개 View에 분산, 중앙 집중 부재

**v2 해결책**:
- `AppContext` 단일 진실 소스: `DashboardView`, `HealthView`, `RecordingView` 모두 `AppContext` switch로 분기 — `activePregnancy != nil` 직접 체크 절대 금지 (Must NOT Do에 명시)
- `AppContext.current(babies: babies, pregnancy: activePregnancy)` static factory가 유일 진입점 → 3-View 간 일관성 보장
- XCUITest `both` 케이스 시나리오 3개 View 전수 검증 추가
- Resume UI (pending orphan 처리) + Settings 임신 삭제 escape는 v1 fix 유지, v2에서도 필수

---

## 빌드 61

**현상 1**: H-4 가족 공유 시 owner 배지 경로 혼동 — 파트너 활동이 owner 배지에 누적, 파트너 화면에 owner 배지 노출
**현상 2**: H-8 AccessibilityXXXL Dynamic Type에서 AddBabyView 임신 진입점 hit 불가 (화면 밖으로 push)

**회귀 유발 커밋**:
- `163ed7b fix(badges): H-4 가족 공유 시 owner 배지 격리 — currentUserId 강제`
- `36560ea fix(a11y): AccessibilityXXXL에서 임신 진입점 노출 — H-8 회귀 fix`

**근본 원인 1 (H-4 배지 격리)**:
- `BadgeEvaluator.evaluateBadgesIfNeeded`가 `babyVM.dataUserId()`(= owner uid)를 배지 저장 경로로 사용 → 가족 공유 시 파트너가 활동 기록해도 owner에게 배지 부여
- `BadgeViewModel.load`도 `resolvedUserId(=owner)` 사용 → 파트너 화면에 owner 배지 노출
- 단위 테스트가 단일 사용자 시나리오만 커버, 가족 공유 path 테스트 없음

**근본 원인 2 (H-8 a11y)**:
- AddBabyView 임신 진입점 HStack layout이 AccessibilityXXXL 폰트 크기에서 화면 밖으로 overflow
- `make verify` / XCUITest (초기)가 기본 Dynamic Type만 검증, `accessibilityXXXL` 케이스 skip
- 빌드 56 fix가 레이아웃 유연성 없이 고정 HStack 구조 사용

**분류**:
- H-4: (a) 구조 버그 — 가족 공유 path에서 `dataUserId` vs `currentUserId` 불일치
- H-8: (b) 프로세스 버그 — 접근성 Dynamic Type 시나리오 테스트 부재

**v2 해결책 (H-4)**:
- `BadgeFirestoreProviding` narrow protocol + `MockBadgeFirestore` — 배지 경로 테스트 격리
- v2에서도 동일 패턴 유지: 배지 부여는 반드시 `currentUserId`, 데이터 조회는 `dataUserId()` (구분 명시)
- H-4 시나리오 단위 테스트 (`BadgePrivacyPassThroughTests`) v2에서도 유지

**v2 해결책 (H-8)**:
- AddBabyView 임신 진입점 `ViewThatFits(in: .horizontal)` — normal/XXXLarge 자동 분기
- XCUITest `test_a11y_extraLarge_pregnancyEntry_stillTappable` 정식 포함 (XCTSkip 제거)
- H-items 정의에 "AccessibilityXXXL 진입점 검증" 명시

---

## 요약 매핑 표

| 빌드 | 현상 | 분류 | 근본 원인 키워드 | v2 해결책 |
|------|------|------|-----------------|-----------|
| 56 | AddBabyView 진입점 orphan | (b) 프로세스 | 진입점 전수 체크 부재 | `AppContext` 4-state 명시 + `make plan-verify` + H-items XCUITest gate |
| 58 | ContentView gating 조건 누락 | (a) 구조 | `activePregnancy != nil` 단독 체크, 공존 상태 미설계 | `AppContext` enum 일원화 + `default:` 금지 + `both` 케이스 XCUITest |
| 59 | Firestore index silent failure + UIView single-parent | (c) external + (a) 구조 | index 누락 silent / UIKit reparent 제약 | `make index-check` + `deploy-rules` gate + per-instance UIView 룰 |
| 60 | baby/pregnancy 3-View gating 불일치 CRITICAL | (a) 구조 | gating 로직 3곳 분산, 중앙 집중 부재 | `AppContext` switch 단일 진실 소스 + 3-View 연계 XCUITest |
| 61 | 가족 공유 배지 격리 + a11y XXXLarge 진입점 | (a) 구조 + (b) 프로세스 | `dataUserId` vs `currentUserId` 혼용 / a11y 테스트 미포함 | `BadgeFirestoreProviding` protocol + `ViewThatFits` + a11y XCUITest |

---

## v2 미해결 항목

다음 회귀 유발 원인은 v2 설계에서 **부분 해결 또는 외부 의존**으로 완전 제거 불가:

1. **pregnancy-weeks.json 의료 검증 공백** (검증 안 된 영역)
   - v2에서 산부인과 전문의 스팟체크를 H-item으로 포함하지만, 전문가 외부 의존
   - 37주치 콘텐츠는 agent 자동 생성 — 오류 가능성 잔존

2. **HealthKit 실기기 동작 미검증** (검증 안 된 영역)
   - v2에서도 HealthKit은 실기기만 검증 가능, 시뮬레이터 불가
   - `make verify` 게이트 외부 — H-items 실기기 QA 의존

3. **위젯 visual 다크/라이트/잠금화면** (검증 안 된 영역)
   - XCUITest로 위젯 내부 UI 검증 불가
   - 실기기 QA + screenshot evidence 필수 (자동화 불가)

4. **Firestore index 배포 side effect** (외부 인프라)
   - index 배포 시 기존 "쿼리 실패로 숨어있던 문서"가 갑자기 surface
   - `make index-check`는 누락 탐지만, 사이드이펙트 사전 점검은 수동 검토 필요
   - learnings.md에 등재: "index 배포 전 기존 데이터 노출 시나리오 점검 필수"

5. **출산 전환 실 시나리오** (검증 안 된 영역)
   - 단위 4개만 — WriteBatch + transitionState 완전성은 실기기 검증 필요
   - `orphan pending` 복구 시나리오(Resume UI)는 v2 신규 설계이므로 v2에서 XCUITest 추가 예정이나, 실환경 테스트 불가 (실제 orphan 생성 어려움)

---

*작성: 2026-04-23 | P0-1 Task*
*출처: CLAUDE.md `v2.7.1 임신 모드 회귀 이력` + `.dev/specs/done/pregnancy-mode/context/learnings.md` + `.dev/NEXT_SESSION.md` + git log `feat/pregnancy-mode` (2026-04-17~20)*
