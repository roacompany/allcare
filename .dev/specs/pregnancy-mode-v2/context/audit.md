# pregnancy-mode-v2 Audit Trail

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

