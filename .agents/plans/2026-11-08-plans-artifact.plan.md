---
plan_format: ainish/plan/v1
slug: plans-artifact
date: 2026-11-08
status: done
branch: feat/agents-plans-artifact
worktree: D:\Code\ainish-coder-plans
task_record: .agents/tasks/2026-11-08-plans-artifact-task.md
operator: question-me
---

# Plan: Make `question-me` produce a `.plan.md` per project

## 1. Problem

`question-me` interviews the operator well and then throws the result away. Its end-of-session
artifact is a design record in `.agents/tasks/`, which is also where branch, lane, status, and
verdict live — two different lifetimes sharing one file. There is no artifact an implementing agent
can pick up and work from, and no place where the operator's answers are recorded alongside what
they cost. Every run re-derives context that a previous run already established.

## 2. Anchor Facts

- `question-me` writes `.agents/tasks/{date}-question-me-{slug}.md` at close — from
  `.agents/skills/question-me/SKILL.md` §6.
- Task records are coordination state (`- lane:`, `- branch:`, `- status:`, `- scope:`) — from the
  existing files in `.agents/tasks/`.
- `docs/` already holds a forward-looking proposal (`rag-context-system-plan.md`) that no agent
  executes — from root `llms.txt` § structure table.
- Deployment scaffolds four `.agents` subdirectory sets — from `bin/ainish-coder:273`,
  `src/deploy_agents.sh:121`, `src/deploy_skills.sh:47`, `src/verify_skills.sh:466`.
- The engine is stdlib-only: `rag.py` imports no third-party module — from `src/rag/rag.py:8-29`.
- `scripts/test-pqc-dist.sh:631` asserts the deploy loop as a literal string, so changing the loop
  breaks the gate unless updated in the same commit — from the file itself.
- The contract is signed and canonical-snapshotted — from `.agents/canonical/AGENTS.md.sha256` and
  `snapshot_canonical_contract` in `src/agents_protection.sh:157`.
- Contract must stay under 120 lines — from the gate at `scripts/test-pqc-dist.sh:626`.

## 3. Plan

### Goals

- One committed plan per task at `.agents/plans/{YYYY-MM-DD}-{slug}.plan.md`.
- The plan carries three things the operator asked for: the agent's plan, the clarification ledger,
  and the todos derived from those combined.
- The plan is readable by tooling without a dependency, and visible in retrieval orientation.

### Non-goals

- No `plan-check.sh` linter — the failure modes are not yet known well enough to encode.
- No migration of historical task records — rewriting them would invent decisions.
- No `--question-me` CLI verb — the skill is agent-invoked.

### Constraints and invariants

- `rag.py` stays stdlib-only; frontmatter parsing is line-based.
- `.agents/canonical/AGENTS.md` must equal `AGENTS.md` byte-for-byte after the change, and its
  ML-DSA-65 signature must verify.
- `AGENTS.md` must stay ≤120 lines.
- Plans are committed; only `.agents/comms/*-team.live.txt` is gitignored.
- Unknown `status` values are read as `designing` — fail closed, never assume progress.

### Proposed architecture

```
question-me: Phase 0 opens plan -> Phase 2 appends §4 per answer -> Phase 3 derives §5, sets ready
                                                    |
                                                    v
        .agents/plans/{date}-{slug}.plan.md  <---- plan: line ----  .agents/tasks/{date}-{slug}-task.md
                    |
                    v
   render_orientation_section (rag.py) + plan_state (context-packet.sh)
```

The plan owns reasoning and checkbox progress; the task owns coordination state. They reference each
other by relative path and neither restates the other.

### Interfaces and data

- New file format: YAML-ish frontmatter with eight fixed keys, then seven `## N.` sections.
- New reader: `read_plan_frontmatter(path) -> Dict[str, str]` and
  `count_plan_todos(text) -> Tuple[int, int]` in `rag.py`.
- New orientation lines: `- newest plan: \`{name}\` (status: {status})` plus a `todos:` count line.
- New packet section: `--- plan_state ---` with `status:`, `branch:`, `task_record:`, and todo counts.
- Deploy loop gains `templates/llms.txt`, `templates/plan.md`, `plans/llms.txt`.

### Files and symbols

- `.agents/templates/plan.md` — new; the canonical shape.
- `.agents/plans/llms.txt` — new; DOX contract for the directory.
- `.agents/skills/question-me/SKILL.md` — pillar 6, Phase 0, Phase 2 rule 6, Phase 3, §6, §7, §8.
- `.agents/skills/question-me/references/plan-artifacts.md` — new.
- `src/rag/rag.py:5382` — `render_orientation_section` plus the two helpers above it.
- `src/rag/tests/test_context_injection.py:639` — `OrientationSectionTest` fixture and five cases.
- `scripts/test-pqc-dist.sh:629` — deploy-map literal, index-existence check, plan assertions.
- `bin/ainish-coder:273,281`, `bin/context-packet.sh:54`, `src/deploy_*.sh`, `src/verify_skills.sh`.
- `AGENTS.md:74,80`, `llms.txt:315,319`, `.agents/llms.txt`, `.agents/templates/llms.txt`,
  `README.md:78,262`, `src/help.sh:311`.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Extend the task record with the three sections | Task records are read by every agent at every orient; growing them into design documents makes the cheap read expensive. |
| Keep plans in `docs/` | `docs/` is forward-looking proposals, and its own contract says plans there are not contracts. A plan an agent executes must be distinguishable from a proposal nobody committed to. |
| Free-prose plans with no frontmatter | Nothing can then report status or open-todo count, and the operator cannot see at a glance whether a plan is locked. |
| YAML frontmatter parsed with PyYAML | `rag.py` is stdlib-only by design; one field is not worth the dependency or the arbitrary-YAML tolerance. |
| Todo list inside the task record | Duplication: two lists drift the moment either is edited. §5 is the single list, and the task record points at it. |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| A plan is written but no agent reads it | Orientation names the newest plan and its open-todo count on every `--context` call; the packet fallback does too. |
| Frontmatter drifts from the template and readers misreport | Readers accept only known keys and treat unknown/absent `status` as `designing`; malformed-frontmatter test asserts this. |
| Deploy gate breaks on the changed loop string | The literal in `test-pqc-dist.sh` was updated in the same commit; the gate is part of verification. |
| Contract edit leaves canonical and root out of parity | Snapshot regenerated, re-signed, `audit verify` 16/16, hash compared both ways. |
| Target repos receive `plans/llms.txt` but no directory | Both are in the same deploy loop, and the scratch deploy asserts all three artifacts land. |

## 4. Clarifications

### 4.1 Plans and task records

- **Question:** How should the new `.plan.md` relate to the existing task record?
- **Options:** 1. (Recommended) Both, with distinct roles — plan holds design/clarifications/todos, task holds coordination and links to the plan; 2. Plans replace the question-me task artifact entirely; 3. Task record remains primary, plan optional.
- **Selected:** Both, with distinct roles.
- **Trade-off accepted:** Two files per task, and the `plan:` pointer must be maintained. Accepted because coordination reads are cheap and frequent while design reads are deep and occasional; folding them makes the frequent path pay for the rare one.
- **asked:** operator
- **resolved by:** —

### 4.2 Wiring depth

- **Question:** How deep should `.agents/plans/` be wired into the repo?
- **Options:** 1. (Recommended) Full wiring — directory, DOX index, README tree, deploy mkdir, and RAG orientation; 2. Docs and skill only; 3. Skill document only.
- **Selected:** Full wiring.
- **Trade-off accepted:** Touches the signed contract, four deploy call sites, and the RAG engine, so the change is larger than a document edit. Accepted because a skill writing into a directory no target receives fails silently.
- **asked:** operator
- **resolved by:** —

### 4.3 Schema

- **Question:** Should the plan file be machine-parseable or operator-facing prose?
- **Options:** 1. (Recommended) YAML frontmatter plus stable headings and GitHub checkboxes; 2. Plain prose with fixed headings; 3. Strict template validated by a future gate.
- **Selected:** YAML frontmatter, stable `##` headings, `- [ ]` checkboxes.
- **Trade-off accepted:** The frontmatter keys are now a parsing contract that future edits must respect. Accepted because status and todo counts are worth reporting automatically, and a checkbox list is the only progress mechanism that survives being edited in place.
- **asked:** operator
- **resolved by:** —

### 4.4 Where the plan section lives in the skill

- **Question:** Does the plan get produced at Phase 3 only, or written throughout?
- **Options:** 1. (Recommended) Opened at Phase 0 and appended at every answer; 2. Compiled in one pass at Phase 3.
- **Selected:** Written throughout — resolved from code, not asked.
- **Trade-off accepted:** More small edits to one file during the interview, which costs a little time per question and saves the whole session if context compacts mid-walk.
- **asked:** resolved from code
- **resolved by:** `.agents/skills/question-me/SKILL.md` pillar 6 already required a *living* artifact updated per answer; only its path and shape changed.

## 5. Todos

- [x] **T1** Create `.agents/templates/plan.md` with the frontmatter contract and seven fixed sections.
  - from: §3 Files and symbols | done when: the file exists and declares `plan_format: ainish/plan/v1`
  - verify: `grep -q 'ainish/plan/v1' .agents/templates/plan.md`
- [x] **T2** Rewrite `.agents/skills/question-me/SKILL.md` around plan compilation (pillar 6, Phase 0, Phase 2 rule 6, Phase 3, §6, §7, §8).
  - from: §3 Files and symbols | done when: the skill names `.agents/plans/{YYYY-MM-DD}-{slug}.plan.md` and no longer writes a design record to `.agents/tasks/`
  - verify: `grep -c 'task-question-me' .agents/skills/question-me/SKILL.md` returns 0
- [x] **T3** Add `.agents/skills/question-me/references/plan-artifacts.md`.
  - from: §3 Files and symbols | done when: todo-derivation rules, split thresholds, and closeout are documented
  - verify: `test -f .agents/skills/question-me/references/plan-artifacts.md`
- [x] **T4** Create `.agents/plans/llms.txt` and register it in `.agents/llms.txt`, root `llms.txt`, and `.agents/templates/llms.txt`.
  - from: §3 Files and symbols | done when: the `.agents` child index lists `plans/llms.txt` and the file exists
  - verify: `test -f .agents/plans/llms.txt && grep -q 'plans/llms.txt' .agents/llms.txt`
- [x] **T5** Scaffold `.agents/plans` and copy `templates/plan.md` plus both index files in `bin/ainish-coder`, `src/deploy_agents.sh`, `src/deploy_skills.sh`, `src/verify_skills.sh`.
  - from: §3 Interfaces and data | done when: a scratch `--rules` target contains all three artifacts
  - verify: `bash bin/ainish-coder --rules /tmp/plans-target --headless -y && test -f /tmp/plans-target/.agents/plans/llms.txt`
- [x] **T6** Update `scripts/test-pqc-dist.sh`: deploy-map literal, child-index existence with a non-vacuous parse guard, and plan-artifact assertions.
  - from: §2 Anchor Facts | done when: the gate passes with the new literal and the index check reports non-zero entries
  - verify: `bash scripts/test-pqc-dist.sh` shows "child index entries were found to check" ok
- [x] **T7** Add `read_plan_frontmatter`, `count_plan_todos`, and plan reporting to `render_orientation_section`.
  - from: §3 Interfaces and data | done when: orientation names the newest plan with status and todo counts
  - verify: `ainish-rag --context --task "plan check"` in a repo with a plan
- [x] **T8** Add a `plan_state` section to `bin/context-packet.sh`.
  - from: §3 Interfaces and data | done when: the packet reports plan status and counts
  - verify: `bash bin/context-packet.sh --task test | sed -n '/plan_state/,/masters/p'`
- [x] **T9** Add orientation test fixtures and five cases (reporting, mtime ordering, absent dir, malformed frontmatter, unknown status).
  - from: §6 Verification | done when: the suite passes with 172 tests
  - verify: `py -m unittest discover -s src/rag/tests`
- [x] **T10** Update `AGENTS.md` planning rule and "Where everything else lives"; refresh the canonical snapshot and re-sign.
  - from: §3 Constraints and invariants | done when: canonical hash matches root and `audit verify` is 16/16
  - verify: `ainish-rag audit verify` and hash comparison
- [x] **T11** Update `README.md` (skill row, tree) and `src/help.sh`; correct the `docs/` row in root `llms.txt`.
  - from: §3 Files and symbols | done when: every surface describing question-me mentions the plan artifact
  - verify: `grep -n 'plan.md' README.md src/help.sh`
- [x] **T12** Run the full verification set and record the outcome in the task record and COMMS.
  - from: §6 Verification | done when: every gate below is green or its failure is proven pre-existing
  - verify: §6

## 6. Verification

- `py -m unittest discover -s src/rag/tests` — 172 pass.
- `bash scripts/test-pqc-dist.sh` — 150 assertions pass; the 14 failures are the pre-existing
  WSL-host `pqc-install`/`pqc-status` set, proven identical on a detached baseline at `663da33`.
- `ainish-rag audit verify` — 16/16 receipts verified after the contract re-sign.
- `bash bin/ainish-coder --rules /tmp/plans-target --headless -y` — target receives `.agents/plans/`,
  `templates/plan.md`, `plans/llms.txt`.
- `ainish-rag --context --task "plan check"` in that target — reports the plan's status and todo
  counts; exits 0 with no plan line when the directory is absent.

## 7. Open Decisions

- Whether a `bin/plan-check.sh` gate is worth writing — settled by seeing which fields real plans
  actually get wrong after a few have been authored.
- Whether `docs/rag-context-system-plan.md` should be split into per-phase plans under the new
  contract — settled by whether its remaining phases are still being worked.
