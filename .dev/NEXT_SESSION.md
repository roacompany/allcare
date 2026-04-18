# 다음 세션 핸드오프 (2026-04-18 세션 마무리)

현재 브랜치: `feat/pregnancy-mode` (latest: `9cf0666`)
마지막 배포: TestFlight v2.7.1 (빌드 60) — Delivery UUID `6f22b4f7-31c3-46bd-aff2-d9805d2e0090`

## ⚠️ 첫 할 일 (블로커)

### 1. 사용자의 잘못된 pregnancy 문서 정리 [P0 / 5분]
이번 세션 중 "하윤이 데이터 있는데 임신모드 노출" 사고 발생. pregnancy Firestore 문서가 사용자 계정에 남아있을 가능성. 확인/삭제 필요.

**옵션 A (TestFlight 60 설치 후)**: 설정 → 임신 관리 → **활성 임신 삭제** 버튼
**옵션 B (Firebase Console)**:
- https://console.firebase.google.com/project/babycare-allcare/firestore
- `users/{uid}/pregnancies` 컬렉션 → 활성 문서 삭제

### 2. feat/pregnancy-mode → main 머지 [P0 / 실기기 QA 완료 후]
- main은 빌드 57까지만. feat/pregnancy-mode는 빌드 60.
- 머지 전제: H-items 실기기 QA (아래 #3) 완료

### 3. H-items 실기기 QA (TestFlight 60) [P0 / 1-2시간]
`.dev/qa-evidence/v2.7.1.md`의 `[ ]` 항목 실기기 검증:
- H-1 태동 세션 UX / H-2 출산 전환 / H-4 pregnancy-weeks 스팟체크
- H-5 FeatureFlag=false 빌드 / H-7 D-day 위젯 엣지 / H-8 Accessibility Large
- 완료 후 `[V]`로 업데이트

## 📌 이번 세션 성과 (커밋 16개)

```
9cf0666 bump 59→60 (CRITICAL fix)
920b908 fix: baby>pregnancy 우선순위 + 임신 삭제 escape
818b5d3 bump 58→59
8e8034b fix: Firestore index + 광고 per-instance
12d4dee bump 57→58
fc10961 test: 단위 +19 + XCUITest +3
8133777 harness: XCUITest 5개 회귀 방지
53f6338 harness: smoke-test + QA evidence + 완성 3단계
9f84888 harness: plan-verify + rules 자동 deploy
c1bf748 fix(pregnancy): 7개 버그 전수 점검
c0c2142 fix(ads): 프리로드 + 재시도
9a79414 bump 56→57
600cfd3 merge main (배지 백필 통합)
ef77e32 fix: AddBabyView 임신 진입점
(main) 3848050 fix(badges): backfill robustness
(main) fbee8bc fix(badges): 기존 기록 백필
```

## 🔨 Quick Wins — 30분 안에 전부 [P1]

다음 항목 전부 main 브랜치(또는 feat/pregnancy-mode) CLAUDE.md + rules 파일 직접 편집.

### A. CLAUDE.md `Build & Deploy` 블록 갱신 (5 명령어 추가)
```bash
make plan-verify  # PLAN ↔ 코드 1:1 검증
make smoke-test   # 시뮬레이터 런치 + 크래시 체크
make qa-check     # QA evidence 파일 게이트
make ui-test      # XCUITest (PregnancyFlowTests 9개)
make deploy-rules # Firestore rules + indexes 자동 배포
```

### B. CLAUDE.md Current Status 갱신 (worktree + main 양쪽)
- **Version**: v2.7.1 (빌드 60) — 임신 모드 P0 + 배지 백필 + 광고 + 하네스 보강
- **TestFlight**: v2.7.1 (빌드 60) — baby/pregnancy 우선순위 fix 포함
- **테스트**: 252 단위 + 9 XCUITest PASS
- **규모**: 276+ Swift 파일, 29개 Firestore 컬렉션 (+5 pregnancy)

### C. CLAUDE.md Architecture 임신 모드 bullet 끝에 추가
```
baby > pregnancy UI 우선순위: `babies.isEmpty`가 false이면 무조건 baby UI
(DashboardView/HealthView/RecordingView 3곳 동일 패턴). `activePregnancy != nil`
단독 체크 금지.
```

### D. `.claude/rules/safety.md`에 새 섹션 추가
```markdown
## 임신 모드 전용

- 임신 데이터를 Firebase Analytics/Crashlytics custom params에 포함 금지
- KickEvent 별도 서브컬렉션 생성 금지 (KickSession.kicks 배열 임베딩)
- EDD 덮어쓰기 금지 (eddHistory append 강제)
- 출산 전환을 단일 write로 처리 금지 (WriteBatch + transitionState 필수)
- Pregnancy 위젯 데이터를 기존 WidgetDataStore에 병합 금지
- baby > pregnancy UI gating: babies.isEmpty가 false이면 pregnancy UI 노출 금지
```

### E. `.claude/rules/swift-conventions.md`에 추가
```
- UIView는 단일 parent만 가능 — 여러 SwiftUI 컨텍스트에서 동일 UIView 인스턴스
  공유 금지. UIViewRepresentable은 per-instance로 만들어야 함 (BannerAdManager
  per-instance 패턴 참조). 빌드 59 회귀 원인.
```

### F. learnings.md 4가지 교훈 append
`.dev/specs/done/pregnancy-mode/context/learnings.md` 끝에:
```markdown
## UIView는 single-parent (2026-04-18)
BannerAdManager shared UIView를 탭 간 공유 → reparent로 blank/refresh 사이클.
per-instance 구조로 해결.

## Firestore composite index 누락은 silent failure (2026-04-18)
fetchActivePregnancy (outcome + createdAt DESC) index 없으면 PERMISSION_DENIED/
FAILED_PRECONDITION. 신규 복합 쿼리 → firestore.indexes.json 즉시 업데이트 +
make deploy-rules 필수.

## baby > pregnancy gating 우선순위 (2026-04-18)
activePregnancy != nil 단독 체크는 baby 사용자에게 pregnancy UI를 노출시키는
회귀. 항상 `babies.isEmpty && activePregnancy != nil` 패턴.

## Firestore index 배포의 숨겨진 side effect (2026-04-18)
쿼리 실패로 숨어있던 문서가 index 배포 후 갑자기 surface. 배포 전 "기존
데이터 있으면 어떻게 노출될지" 사이드이펙트 점검 필수.
```

## 🤖 자동화 2건 [P1 / 1-2시간]

### /firestore-add-collection command
**위치**: `.claude/commands/firestore-add-collection.md`
**목적**: Firestore 컬렉션 추가 시 `Constants.swift` 상수 + `FirestoreService+{Name}.swift` 스켈레톤 + `firestore.indexes.json` + rules 코멘트 자동 scaffold. deploy-rules 강제 게이팅.
**동기**: 이번 세션 pregnancy index 누락 사고 재발 방지.

### bug-triage agent
**위치**: `.claude/agents/bug-triage.md`
**목적**: 버그 신고 시 Layer 0(Firestore: rules/index/permission) → 1(Gating/FeatureFlags) → 2(아키텍처: arch-test/SwiftUI-UIKit 경계) → 3(로직) 순서로 체계적 진단.
**동기**: "7개 잠재 fix" 후에도 root cause(index)를 놓친 반복 방지.

자세한 스펙은 doc-updater / automation-scout agent 분석 결과 참고 (이번 세션 wrap 중).

## 📋 Medium Priority — 이번 주 [P1-P2]

### pregnancy-weeks.json 40주 완성 [P1]
현재 10주치만 (4, 8, 12, 16, 20, 24, 28, 32, 36, 40).
`BabyCare/Resources/pregnancy-weeks.json` — ACOG + 대한산부인과학회 기반 중간 주차 30개 추가. 의료 전문가 스팟체크 의뢰.

### Firestore index 자동 체크 [P1]
`scripts/arch_test.sh` 확장 또는 별도 `make index-check` —
`FirestoreCollections` 상수 수 ↔ `firestore.indexes.json` 등록 컬렉션 수 비교, 누락 시 경고.

### FirestoreService protocol + mock [P1]
`FirestoreServiceProtocol.swift` 도입 → `BadgeEvaluator.backfillIfNeeded` 통합 테스트 가능해짐. 현재는 mock 불가로 순수 로직만 검증 중.

### badges-ui H-items QA [P1]
`.dev/specs/badges-ui/PLAN.md` H-items 5개 미완료. 임신 QA와 병행.

### Privacy Policy 갱신 [P2]
임신/HealthKit 민감 건강 데이터 수집 항목 명시. App Store 제출 전 필수.
`/Users/roque/allcare/` repo 갱신.

### 증상 일지 구현 [P2]
`PregnancyRecordingSheets.swift` L98/L131의 `TODO 10` — `PregnancySymptom` 모델 + Firestore 연동.

### CHANGELOG / 릴리즈 노트 [P2]
CLAUDE.md Active TODO에 있으나 미착수. v2.7.1 섹션 한국어/영어 작성.

### v2.6.2 심사 완료 후 firestore.rules 배포 [P2]
CLAUDE.md 조건부 — v2.6.2 (빌드 52) WAITING_FOR_REVIEW 상태 확인 후.

## 🗂 Low Priority [P3]

- CryAnalysisViewModel phase 전이 단위 테스트 (v2.7 flip 전 필수)
- 로컬라이제이션 1,631개 한국어 하드코딩 추출 (배지 UI 선행 완료, 화면 단위 점진)

## 🧠 반드시 기억할 원칙 (이번 세션 학습)

1. **완성의 3단계**: coded [x] / verified [V] / shipped [S] — TODO done ≠ 완성. 진입점 grep 확인 필수.
2. **진단 순서**: Layer 0 (Firestore rules/index/permission) → 1 (Gating/FeatureFlags) → 2 (아키텍처) → 3 (로직). 코드 수정 전 Layer 0-2 먼저.
3. **UIView는 single-parent** — SwiftUI에서 UIView 인스턴스 공유 금지. UIViewRepresentable은 per-instance.
4. **composite index는 silent failure** — 신규 `whereField + orderBy` 조합은 `firestore.indexes.json` 즉시 업데이트 + `make deploy-rules`.
5. **index 배포 = 숨겨진 데이터 노출 트리거** — 기존 문서 사이드이펙트 사전 점검.
6. **두 상태 공존 방어** — 신규 상태 변수 추가 시 기존 상태와 2x2 조합표 작성, 각 조합 UI 명시.
7. **make verify PASS ≠ 사용자 플로우 동작** — P0 기능은 XCUITest + smoke + QA evidence 필수.
8. **불확실 시 honest 표시** — plausible explanation을 definitive answer로 포장 금지.

## 🔗 파일 Quick Index

| 목적 | 경로 |
|---|---|
| 이 문서 | `.dev/NEXT_SESSION.md` (worktree) |
| QA evidence | `.dev/qa-evidence/v2.7.1.md` |
| 하네스 스크립트 | `scripts/plan_verify.sh`, `smoke_test.sh`, `qa_evidence_check.sh` |
| Firestore 구조 | `firestore.rules`, `firestore.indexes.json`, `BabyCare/Utils/Constants.swift` |
| Gating 3곳 | `Views/Dashboard/DashboardView.swift:31`, `Views/Health/HealthView.swift:15`, `Views/Recording/RecordingView.swift:68` |
| 광고 per-instance | `Views/Ads/AdBannerView.swift`, `Services/BannerAdManager.swift` |
| 임신 등록 | `Views/Pregnancy/PregnancyRegistrationView.swift`, `ViewModels/PregnancyViewModel.swift` |
| 임신 삭제 escape | `Views/Settings/SettingsView.swift` (activePregnancy 조건부 Button) |
| XCUITest | `BabyCareUITests/PregnancyFlowTests.swift` (9 tests) |
| 단위 테스트 | `BabyCareTests/BabyCareTests.swift` (252 tests) |

## 💾 이번 세션 미완 작업 (clean state로 종료)

없음 — 작업 중간 상태 파일 없이 clean. `.dev/local.json`은 untracked (무시 가능).
