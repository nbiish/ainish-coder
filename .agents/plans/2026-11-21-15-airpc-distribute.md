---
plan_format: ainish/plan/v1
slug: airpc-distribute
date: 2026-11-21
status: done
branch: skill/airpc-distribute
worktree: /Users/nbiish/code/ainish-coder-airpc4
task_record: .agents/tasks/2026-11-21-15-airpc-distribute.md
operator: direct (Nanoboozhoo, Orca/omp harness)
---

# Plan: move aiRPC into the distributed skills payload

## 1. Problem

The operator wants the aiRPC skill to ship with the rest of the `ainish-coder --skills` tooling:
move it from `.agents/skills/` (this repo's curated standing prompt surface) into
`skills-to-distribute/skills/` (the distributable payload).

## 2. Anchor Facts

- `.agents/llms.txt`: the packs this tool distributes live in `skills-to-distribute/skills/` on
  purpose; `src/deploy_skills.sh` deploys that payload into a target project's `.agents/skills/`.
- `.agents/skills/llms.txt` and `skills-to-distribute/skills/llms.txt` are byte-identical
  (`diff` clean, same 2591 bytes) and already list `aiRPC/`; they are kept in sync outside this
  task. The index also lists packs that exist only in the payload (`typesafe-jev/`,
  `specialized-agents/`, `wtf-is-going-on-mcp/`), so the entry stays correct after the move —
  established from the two files and both directory listings.
- Payload skill links are written for the deployed position (`.agents/skills/<name>/`):
  `skills-to-distribute/skills/question-me/SKILL.md` links `../../templates/plan.md` — the aiRPC
  links (`../../llms.txt`, `../../../AGENTS.md`, `../ainish-security/SKILL.md`) follow the same
  convention and need no change.
- `scripts/test-pqc-dist.sh` is the distribution gate (the suite that passed 440 assertions on the
  last task) and requires every skill named in the surface docs to exist in
  `skills-to-distribute/skills/<name>/` **or** `.agents/skills/<name>/` — established from lines
  528-541 of that script.
- The demo server is stopped (pid 38656 gone, port 7331 free, verified this session).

## 3. Plan

### Goals

- `aiRPC/` lives at `skills-to-distribute/skills/aiRPC/` (SKILL.md + references/), and no longer
  at `.agents/skills/aiRPC/`; it deploys to consumer repos with `ainish-coder --skills` tooling.

### Non-goals

- No changes to the shared `llms.txt` indexes (both already list the pack; keeping them identical
  is another owner's sync).
- No distribution-policy changes: whether aiRPC deploys everywhere stays with the existing
  `deploy_skills.sh` behavior.

### Constraints and invariants

- Clean cutover: `git mv`, no copy left behind in `.agents/skills/`; relative links stay written
  for the deployed position (existing payload convention).
- `scripts/test-pqc-dist.sh` must pass at its 440-assertion baseline.

### Files and symbols

- `.agents/skills/aiRPC/` → `skills-to-distribute/skills/aiRPC/` (git mv, all four files).

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Copy and keep both | Two homes for one skill drift; the operator said move. |
| Rewrite links for the payload tree | Would break at deploy time; the payload convention is links for `.agents/skills/<name>/`. |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| The dist test asserts a fixed pack list that excludes aiRPC | Run the test; a failure names the assertion and the fix follows it. |
| This repo's own agents lose the standing prompt surface | Intended by the operator ("move"); deployment back into `.agents/skills/` is `deploy_skills.sh`'s job. |

## 4. Clarifications

### 4.1 Move semantics

- **Question:** Move (not copy) the pack into the payload, leaving the indexes alone?
- **Options:** 1. (Recommended) `git mv`, indexes untouched — the operator said "move"; the shared
  index convention already lists payload-only packs; 2. copy and keep a local stub — drift.
- **Selected:** Option 1.
- **Trade-off accepted:** This repo's agents see the pack only after a deploy pass.
- **asked:** operator ("move that skill to the distributed skills folder")

## 5. Todos

- [x] **T1** `git mv .agents/skills/aiRPC skills-to-distribute/skills/aiRPC` in a worktree.
  - from: §3 | done when: four files at the payload path, none left in `.agents/skills/` | verify: ls both paths
- [x] **T2** `scripts/test-pqc-dist.sh` passes at baseline.
  - from: §2 | done when: suite output shows no failures | verify: the run itself
- [x] **T3** Merge, remove worktree, close records.
  - from: AGENTS.md | done when: `git log main..<branch>` empty, records committed | verify: git log

## 6. Verification

- `bash scripts/test-pqc-dist.sh` — no failures at the 440-assertion baseline.
- `ls` both skill paths — payload has `aiRPC/`, `.agents/skills/` does not.

## 7. Open Decisions

- None.
