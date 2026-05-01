---
name: worker-verify-commit
description: Execute one PLAN.md TODO end-to-end — implement (worker) → verify (make verify + git diff ground truth) → context save (outputs.json/learnings/issues/PLAN checkbox) → scope-selective commit via git-master. Use during /execute orchestration loops to standardize the 4-step pattern. Trigger when user says "execute TODO N", "implement and commit", or during /execute orchestration sub-steps.
---

# Worker-Verify-Commit Loop

pregnancy-mode-v2 `/execute` 세션에서 ~20번 반복된 4단계 패턴을 하나의 스킬로 표준화. Orchestrator가 각 TODO를 개별적으로 조합하는 대신 이 스킬을 invoke하면 loop 규약이 자동 적용된다.

## 트리거

- "execute TODO {N}" 또는 "implement and commit {feature}"
- `/execute` orchestration 내부에서 각 TODO를 이 스킬로 위임

## Dependencies

- `make verify` 정상 동작하는 프로젝트
- `PLAN.md` 존재 (`.dev/specs/{name}/PLAN.md`)
- Git repo + git-master agent 이용 가능

## Phases

### Phase 1 — Implement (worker agent)

- Sub-agent: `hoyeon:worker` 또는 프로젝트 고유 worker agent
- Input: TODO 본문 + `context/outputs.json` (previous TODO 결과 주입)
- **프롬프트 원칙** (pregnancy-mode-v2 학습):
  - PLAN.md의 메서드/타입 signature를 **verbatim** 인용 (paraphrase 금지 — drift 위험)
  - "MUST DO" / "MUST NOT DO" 섹션 PLAN에서 복사
  - Output 기대 형식 JSON으로 명시

### Phase 2 — Verify (stale-read guard)

- 명령: `make verify`
- **Ground truth 프로토콜** (pregnancy-mode-v2 P1-3 learnings):
  1. `git diff HEAD --stat` 로 실제 변경 파일 목록 확인 (Read tool 신뢰 금지)
  2. `git diff HEAD -- <file>` 로 파일별 실제 diff 확인
  3. Read tool 결과와 git diff 불일치 → git diff 채택
- 실패 시 최대 2회 재시도 (Phase 1 failure detail 전달)

### Phase 3 — Context Save

- `context/outputs.json` 에 TODO-{N} 결과 append (Worker output JSON)
- `context/learnings.md` 에 새 패턴 append (worker "learnings" 필드)
- `context/issues.md` 에 unresolved "issues" append
- `PLAN.md` 의 TODO checkbox: `[ ]` → `[x]` (coded 단계)

### Phase 4 — Commit (scope-selective via git-master)

- Sub-agent: `hoyeon:git-master`
- **Scope-selective staging**: Phase 1에서 변경한 파일 목록만 명시 stage. `git add -A` 금지.
- **Commit message 형식**: `{type}({scope}): {TODO title} [TODO N]`
  - type: feat / fix / chore / docs / test / refactor
  - scope: 프로젝트 도메인 (예: pregnancy-v2, firestore)
- **Do NOT stage**:
  - 다른 TODO가 건드린 파일
  - `.dev/NEXT_SESSION.md` (사용자 pre-existing)
  - Xcodeproj 자동 생성물
  - Pre-existing untracked files

## Output

```json
{
  "todo_n": <N>,
  "commit_sha": "<sha>",
  "files_committed": [...],
  "tests_added": <count>,
  "verify_status": "PASS|FAIL",
  "pushed": false,
  "learnings_added": <count>,
  "issues_added": <count>
}
```

## Gotchas

- Firebase SDK cross-branch merge 후 DerivedData clean 필요 (see `.claude/rules/build-gotchas.md`).
- iOS 26.2 시뮬레이터 불안정 — `id=<UDID>` 형식 권장 (see `.claude/rules/simulator-targets.md`).
- 병렬 verify 시 시뮬레이터 경합 — serial 권장.

## 참조

- pregnancy-mode-v2 `.dev/specs/pregnancy-mode-v2/context/learnings.md` (모든 phase 실사례).
- `hoyeon:worker` / `hoyeon:git-master` agent 사양.
