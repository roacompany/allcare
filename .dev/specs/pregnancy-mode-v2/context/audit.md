# pregnancy-mode-v2 Audit Trail

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

