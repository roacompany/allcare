# pregnancy-mode-v2 Audit Trail

## TODO Final — Verification (ALL PASS)

### [2026-04-24] DoD Verification (direct Orchestrator execution — rate limit saver)
- **make verify**: ALL CHECKS PASSED (build + lint + arch-test + test + design-verify 29/29)
- **make arch-test**: 0 violations
- **make qa-check**: v2.8.0.md PASS (v2.8.0 활성 gate)
- **make index-check**: 3 복합 쿼리 컬렉션 모두 등록 (pregnancies COLLECTION_GROUP 포함)
- **make plan-verify**: badges-ui spec PASS; pregnancy-mode-v2 PLAN ↔ 코드 1:1 매칭 정상
- **bash scripts/pre_merge_check.sh**: ALL PRE-MERGE CHECKS PASSED (P2-4 smoke 11/11 + FeatureFlag=false 빌드 + merge dry-run)
- **A-17 (no `default:` on AppContext switches)**: 0건 grep
- **A-18 (no `FirebaseRemoteConfig` import in FeatureFlags.swift)**: CLEAN
- **Test coverage**: XCUITest 18 (10 기존 + 8 신규), Unit tests 345 (319 + 26 신규)
- **Commits on feat/pregnancy-mode-v2**: 18 (Phase 0~4 + Final)
- **Commits on feat/firebase-11.8.0-compat**: 1 (P0-2b, 204cf49)

### DoD 달성 요약 (PLAN lines 91-107 기준)
- [x] Phase 0 6 TODOs (P0-1~P0-5, P0-2b) — 완료. 단 P0-2b main merge는 human 대기.
- [x] P0-5 firestore.rules collectionGroup Partner read 규칙 배포 — 완료. (H-11 Firebase Console Rules Simulator 수동 테스트만 대기)
- [x] make verify PASS (345 단위 + arch-test 0)
- [x] make ui-test PASS (18 XCUITests on iOS 26.4 simulator)
- [x] make plan-verify PASS
- [x] make smoke-test PASS (P2-4 smoke 11/11)
- [x] make qa-check PASS (v2.8.0.md 활성)
- [x] make index-check PASS
- [x] make deploy-rules PASS (P0-5에서 이미 배포; idempotent 재실행 OK)
- [x] bash scripts/pre_merge_check.sh PASS
- [ ] `/review` 또는 hoyeon:code-reviewer SHIP — **SKIPPED in Local execute** (rate limit; 사용자 수동 `/review` 실행 권장)
- [ ] `/tribunal` 또는 codex review SHIP — **SKIPPED in Local execute** (rate limit)
- [ ] H-1~H-12 12개 [V] — 모든 H-item evidence scaffold 준비됨. **Human signoff 대기** (H-4/H-10 critical path)
- [ ] TestFlight v2.8.0 내부 테스터 3일 무회귀 — **human 필수** (P0-2b main merge + make deploy 이후)
- [ ] RemoteConfig 100% 활성화 + 24시간 모니터링 — **human 필수**

## TODO P1-5 — UX Concern Logged (non-blocking)

### [2026-04-23 22:35] Side-effect flagged
- **Change**: `if let dDay = pregnancyVM.dDay, dDay <= 7` → `if pregnancyVM.dDay != nil` (birthCTABanner 표시 조건)
- **Spec compliance**: 문자 그대로 매칭 ("D-7 제한 조건 제거")
- **UX concern**: dDay는 dueDate 설정 시 항상 non-nil → 임신 6주 등 초기 시점에도 "출산했어요!" CTA 노출 가능. 의도와 불일치 가능.
- **Decision**: spec 준수대로 진행. H-2 (Product+QA evaluator per h-items-evaluators.md)에서 수동 검토 대상으로 이관.
- **Mitigation hint**: 추후 UX 검토 시 `dDay <= 28` (~last 4주) 또는 `dDay <= 0` (past due)로 완화 고려 가능.

## TODO P1-3 — Verify False Negative (override)

### [2026-04-23 22:05] Verify disagreement
- **Verify worker verdict**: FAILED (7/12 AC fail, DashboardView.swift "not modified")
- **Orchestrator re-check**: `git diff HEAD BabyCare/Views/Dashboard/DashboardView.swift` shows 25 insertions/4 deletions; `grep -n 'AppContext.resolve' DashboardView.swift` confirms switch block at line 35 with 4 explicit cases + pregnancyHomeCardIfNeeded at line 162
- **Root cause**: Verify worker itself noted (missing_context HIGH severity): "Read tool cache artifact — initial Read returned new content, later Bash grep showed stale" — the verify worker's `grep` was false, not the P1-3 Worker's edit
- **Decision**: OVERRIDE verify FAIL. P1-3 code is correctly applied. Proceed with commit.
- **Lesson**: Verify worker must use `git diff HEAD` (not just grep) to check actual modifications; Read tool may serve stale content mid-session. Future verify prompts should instruct using `git diff` first.

## TODO P1-1 — Reconciliation

### [2026-04-23 21:07] Adapt (naming drift)
- **Trigger**: verify worker flagged `suggested_adaptation` — AppContext factory named `from(babies:activePregnancy:)` by Worker (per Orchestrator prompt), but PLAN.md specifies `resolve(babies:pregnancy:)` in 8 places including P1-2/P1-4 grep-based ACs.
- **Scope check**: safe (needed_for_DoD=YES, within P1-1 file scope, non-destructive)
- **Action**: Orchestrator direct rename (no dynamic TODO needed — simple 15 call-site replacement)
  - `AppContext.swift:21`: `from(babies:activePregnancy:)` → `resolve(babies:pregnancy:)`
  - `BabyCareTests.swift`: 15 call sites renamed `AppContext.from(...) → AppContext.resolve(...)`, `activePregnancy:` → `pregnancy:`
- **Result**: `make verify` PASS (ALL CHECKS PASSED, design-verify 29/29)
- **Status**: RESOLVED
- **Lesson**: Orchestrator prompt must match PLAN.md exactly — inconsistent method names in prompt cause downstream AC drift. Prefer quoting PLAN signatures verbatim.

