---
plan_format: ainish/plan/v1
slug: single-command-context
date: 2026-11-18
status: implementing
branch: feat/single-command-context
worktree: /Users/nbiish/code/single-command-context
task_record: .agents/tasks/2026-11-18-14-single-command-context.md
operator: direct-instruction
---

# Plan: one command that reads the rules and keeps improving

## 1. Problem

The context system required two commands to work: `--context` to prime, and `--context-learn` to
improve. Worse, `AGENTS.md` was not in the retrieval corpus at all, so the prime an agent received could
report the branch and the last COMMS line but never the rules governing the session. The operator asked
for a single command that reads our rules, returns them to the agent, and keeps the system improving.

## 2. Anchor Facts

- `AGENTS.md` was absent from the retrieval graph — `_graph_sources` enumerated only the wiki vault and
  `.agents/{comms,memories,plans,suggestions,tasks}`; `any('AGENTS' in n.path ...)` returned `False`.
- The node loop stamped `"kind": "wiki"` on every heading-split source, so a contract node could not be
  distinguished from a wiki page.
- `DecisionEngine.route` can return `skip_retrieval`, in which case the prime contained zero mention of
  the contract — observed on a trivial probe task.
- `AGENTS.md` sits at a hard 160-line gate (`scripts/test-pqc-dist.sh:722`, `:878`), so any addition must
  be paid for.
- `pi_agent_call` runs with `--no-tools`, so evidence must be inline rather than file-pointered.
- The learning gate refuses without an external outcome signal (Phase 0, `08-phase0-findings.md`).

## 3. Plan

### Goals

- One `--context` call surfaces the rules, the corpus, both reviews, and starts a throttled background
  pass that tunes the repo from its own history.
- The contract reports the digest it is bound by and the repo's own gate verdict, on every call.
- No second command is required for priming or for improvement to happen.

### Non-goals

- Making the background pass durable across a machine sleeping or the process being killed.
- Reworking the outcome signal, which remains as weak as `09-as-built.md` states.
- Raising the `AGENTS.md` gate.

### Constraints and invariants

- The prime must be assembled **before** the spawn, so no answer can be affected by a learning pass.
- A spawn must never write to the caller's stdout or stderr.
- `--retrieval-only` must make no model calls, so it must not spawn.
- Throttle state is per-machine and gitignored; learned state is tracked.
- `AGENTS.md` stays at exactly 160 lines with every non-negotiable intact.

### Proposed architecture

```
ainish-rag --context --task "..."
  ├─ orientation   (never skipped)  branch, tree, COMMS, task, plan
  │                                 + rules digest, + gate verdict
  ├─ retrieval     contract sections (AGENTS.md / llms.txt) now in corpus
  ├─ elephant + goldfish
  ├─ assemble the prime  ──────────────────── agent gets its answer here
  └─ spawn detached context-learn --background   (throttled: 6h AND >=1 new commit)
```

### Interfaces and data

- `GRAPH_CONTRACT_FILES = ("AGENTS.md", "llms.txt")`; new node kind `contract`.
- `spawn_autolearn(repo_root, task) -> {"spawned", "reason"}`.
- `provenance.harness.autolearn` on every call.
- `context_harness.should_autolearn` / `record_autolearn`, state at
  `.agents/rag/context-harness-autolearn.json`.
- `context-learn --background` (internal flag for the detached child).

### Files and symbols

- `src/rag/rag.py` — `GRAPH_CONTRACT_FILES`; `_graph_sources`; `build_wiki_graph` kind; `spawn_autolearn`;
  `run_context_command`; `render_orientation_section`; `--help` text.
- `src/rag/context_harness.py` — `learn_state_path`, `should_autolearn`, `record_autolearn`, `_commit_count`.
- `AGENTS.md` — one paragraph, paid for by compression.
- `research/context-priming-master/10-single-command.md`.

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Spawned pass delays the prime | Assembled before the spawn; detached with DEVNULL stdio; measured |
| A model session on every keystroke | 6h interval AND ≥1 new commit, plus the lock |
| A failing learner respawns forever | Attempt recorded in `finally`, so the throttle measures attempts |
| Contract edit silently drops a rule | Every non-negotiable grepped after the edit; net line count unchanged |

## 4. Clarifications

### 4.1 Where learning runs

- **Question:** Learning was a separate verb because a context call must never block the task. Does the single-command requirement override that?
- **Options:** 1. Keep the separate verb; 2. Run learning inline before returning the prime; 3. (Chosen) Keep the answer synchronous and spawn learning detached after it.
- **Selected:** 3.
- **Trade-off accepted:** The background pass is best-effort — if the machine sleeps it is simply lost.
- **asked:** operator
- **resolved by:** n/a

### 4.2 What "reads our rules" means

- **Question:** Should the contract be retrieval corpus, an always-present orientation line, or both?
- **Options:** 1. Corpus only; 2. Orientation only; 3. (Chosen) Both.
- **Selected:** 3 — corpus so the rules are *retrievable in detail*, orientation so they are *always named*.
- **Trade-off accepted:** Two lines of orientation budget; retrieval can be skipped by routing, which is why orientation carries the digest.
- **asked:** resolved from code
- **resolved by:** observed `skip_retrieval` returning a prime with no mention of the contract.

## 5. Todos

- [x] **T1** Add `AGENTS.md` and `llms.txt` to the graph as `contract` kind, split at `##`.
  - from: §3 | done when: 20 contract nodes exist and a rules question retrieves them | verify: retrieval of "worktrees and plans" returns `AGENTS.md:L19`
- [x] **T2** Carry the real source kind onto heading-split nodes.
  - from: §3 | done when: `kinds` includes `contract` | verify: `build_wiki_graph` census
- [x] **T3** Add `spawn_autolearn` and wire it after prime assembly.
  - from: §3 | done when: a full call reports `spawned: true` and returns the prime unchanged | verify: `provenance.harness.autolearn`
- [x] **T4** Add the throttle and its state file.
  - from: §3 | done when: a second call within 6h spawns nothing and says why | verify: `"next eligible in ..."`
- [x] **T5** Record the attempt in `finally` so a failing learner cannot respawn forever.
  - from: §3 | done when: two `record_autolearn` call sites exist | verify: assertion
- [x] **T6** Report rules digest and gate verdict in orientation.
  - from: §3 | done when: both lines appear even when retrieval is skipped | verify: `--retrieval-only` probe
- [x] **T7** State the single-command rule in `AGENTS.md`, paid for by compression.
  - from: §3 | done when: the file is still 160 lines and every non-negotiable is present | verify: `wc -l` + greps
- [x] **T8** Update `--help` and the dossier; add 9 assertions.
  - from: §3 | done when: suite passes above the 331 baseline | verify: `scripts/test-pqc-dist.sh`

## 6. Verification

- `scripts/test-pqc-dist.sh` — 340 assertions pass.
- `wc -l < AGENTS.md` — exactly 160.
- `ainish-rag context --task "what does the contract say about worktrees"` — orientation names the rules digest and the gate verdict.
- `ainish-rag context --task "..."` (full) — `provenance.harness.autolearn.spawned` is true, and the prime is byte-identical to a call where it is throttled apart from that field.
- Second call within 6h — spawns nothing, reason names the remaining minutes.
- `ainish-rag context --retrieval-only` — reports `--retrieval-only makes no model calls`.

## 7. Open Decisions

- Whether the 6h interval is right — settled by whether operators see a stale profile between long working sessions. Start at 6h; it is one constant.
- Whether orientation should carry more than the digest and gate — settled by whether agents actually read it.
