---
plan_format: ainish/plan/v1
slug: hour-stamped-coordination
date: 2026-11-12
status: done
branch: fix/hour-stamped-coordination
worktree: /Users/nbiish/code/ainish-coder-hourcoord
task_record: .agents/tasks/2026-11-12-hour-stamped-coordination-task.md
---

# Hour-stamped coordination records (`.agents/{dirs}/{date}-{HH}-slug.md`)

**Goal:** coordination artifacts gain a UTC-hour segment so multiple tasks in one day stop
colliding into one date bucket, and every coordination record becomes markdown.

**Operator decisions (clarified 2026-11-12):**
1. Comms stays ONE ledger per UTC date — renamed to `{date}-team.md`; hour stamps apply to
   tasks/plans/memories/suggestions only.
2. Hour clock is UTC, zero-padded two digits (`{date}-{HH}`), so names sort chronologically as
   text on every machine (macOS + WSL).
3. Grandfather everything existing — old names stay put; the convention applies from cutover.
4. Type suffixes drop: `{date}-{HH}-slug.md` for all four hour-stamped dirs; the type is carried
   by frontmatter (`plan_format: ainish/plan/v1` etc.), which the hook and RAG already parse.

**Layout decision (delegated to the agent, decided):** FLAT files with the hour in the name —
NOT `{date}/` subdirectories. The retrieval model's core invariant is "the newest file in each of
`.agents/{comms,memories,plans,suggestions,tasks}`"; flat + zero-padded HH keeps that invariant
exact (newest file == latest hour) with zero depth changes in the engine, the plan-gate hook, or
sync tooling. Date subdirectories would force depth-2 walks in every consumer for an ergonomics
win that prefix globs (`ls .agents/tasks | grep ^2026-11-12`) already provide.

**Target patterns (cutover onward):**

| dir | new name | was |
|---|---|---|
| comms | `{YYYY-MM-DD}-team.md` (live board `-team.live.md`) | `{date}-team.txt` / `.live.txt` |
| memories | `{YYYY-MM-DD}-{HH}-memory.md` | `{date}-memory.txt` |
| plans | `{YYYY-MM-DD}-{HH}-{slug}.md` | `{date}-{slug}.plan.md` |
| suggestions | `{YYYY-MM-DD}-{HH}-{slug}.md` | `{date}-{slug}.txt` |
| tasks | `{YYYY-MM-DD}-{HH}-{slug}.md` | `{date}-{slug}-task.md` |

Grandfathered names remain valid everywhere: retrieval is by mtime/newest, the plan-gate accepts
them, the engine matches both suffixes. This task's own plan/task/comms records stay
old-convention (the cutover is part of this task; the next task is the first to use hour stamps).

## 1. Why this is a correctness task, not a renaming task

The plan as first drafted scoped the engine work to `src/rag/` (the Rust crate). Verified against
the live tree on 2026-11-12, that is the wrong engine and the wrong assumption:

1. **The Python engine is what serves `ainish-rag` on this host.** `bin/ainish-rag:69` hard-codes
   `PY_ONLY_SUBCOMMANDS=" context secrets "`, so `context` is force-routed to `rag.py` by design.
   No `bin/ainish-rag-darwin`, `-linux`, or `.exe` exists, so `NATIVE_BIN` is always empty and the
   compiled `src/rag/target/release/ainish-rag` is never selected. The context call that opened
   this task emitted `[rag:index] WARNING:` and `EmbeddingGemma-2 GGUF not found in` — strings
   that exist only in `rag.py` (`1816`, `1863`), never in the crate.
2. **Name-sorted "newest" is already wrong under grandfathering.** Every discovery site that
   claims "newest wins" sorts by *filename*, not mtime: `rag.py:5564` (memories), `rag.py:5870`
   (tasks), `main.rs:3637-3640` (memories). With both schemes present in one UTC day,
   `2026-11-12-09-memory.md` sorts **before** `2026-11-12-memory.txt` (`0` < `m`), so the
   grandfather file is returned as "newest". Grandfathering is precisely the window where both
   exist, so this lands on cutover day.
3. **Dropping `.plan.md` blinds plan discovery.** `rag.py:5897` globs `*.plan.md`, `plan_gate.sh:63`
   globs `-name '*.plan.md'`, `bin/context-packet.sh:70` globs `*.plan.md`. After decision 4 the
   new plans match none of them: orientation reports no plan of record, the hook refuses every
   commit, and the gate that guards this very change cannot see it.

So the acceptance property is not "new files are named correctly" — it is **both schemes resolve
to the correct newest file, and no discovery path silently matches nothing.**

## 2. Anchor facts

| Fact | Established by |
|---|---|
| `context` is force-routed to Python | `bin/ainish-rag:69,84-87` |
| No native rag binary exists in `bin/` | `ls bin/ainish-rag-darwin …` → No such file (x3) |
| Warning/error strings are rag.py-only | `rag.py:1816,1863`; absent from `src/rag/src/` |
| Plan discovery globs `.plan.md` (3 sites) | `rag.py:5897`, `plan_gate.sh:63`, `context-packet.sh:70` |
| "Newest" sorts by name (3 sites) | `rag.py:5564,5870`, `main.rs:3637-3640` |
| Comms suffix is hard-matched in 4 places | `rag.py:5845,7148`, `main.rs:3355`, `bin/security_gate.py:108`, `bin/git-context.sh:63` |
| `_read_today_task_record` is already dead | `rag.py:7257` looks for `{date}-task.md`; no such file has ever existed under the old `{date}-{slug}-task.md` scheme → always `""` |
| `--rules` exits 1 on this host, pre-existing | `.agents/suggestions/2026-11-12-rules-signing-anchor-mismatch.txt` (signer `69e7233d…` vs anchor `d98405ea…`) |
| `AGENTS.md` is 158 lines against a 160 gate | `wc -l AGENTS.md` |

## 3. Tasks

### 3.1 Rules of record first
- `AGENTS.md` — NN1 plan path → `.agents/plans/{date}-{HH}-{slug}.md`; NN8 + Close suggestions
  → `.agents/suggestions/{date}-{HH}-{slug}.md`; one line stating the convention (UTC hour,
  zero-padded, grandfathered names stay valid, comms remains daily). **Must stay ≤160 lines** —
  the change is net-zero-words or it costs a line elsewhere.
- `.agents/plans/llms.txt` — naming table and verification snippets must cover BOTH patterns;
  document frontmatter-carries-type and the comms daily rule.
- `.agents/templates/plan.md` — copy-target line and `task_record:` placeholder.
- `.agents/skills/question-me/SKILL.md` AND `skills-to-distribute/skills/question-me/SKILL.md`
  (must stay byte-identical) — every `.plan.md` mention → new pattern, noting both valid during
  grandfathering.
- `.agents/llms.txt`, `.agents/templates/llms.txt`, `.agents/memories/llms.txt`, root `llms.txt`,
  `README.md`, `src/README.md` — naming prose.
- `src/templates/AGENTS.COMMS.md:2,13` — the protocol template `--rules` deploys.
- `.gitignore:164` — live board: cover `*-team.live.md` alongside legacy `*.live.txt`.

### 3.2 Shell tooling
- `src/plan_gate.sh` — glob `'*.plan.md'` → all `.md` except `llms.txt` (dir holds only plans +
  that index); error text (`104`, `138`) shows the new path.
- `src/deploy_agents_comms.sh` — dest `{today}-team.md`; fallback globs `${today}*-team.md` AND
  legacy `${today}*-team.txt`; header comment.
- `src/scroll_integrity.sh:62-66,83-86` — same dual-suffix resolution.
- `bin/git-context.sh:63` — `*-team.txt` → both suffixes, newest by mtime.
- `bin/security_gate.py:108` — `endswith("-team.txt")` → both.
- `bin/context-packet.sh:70` — `*.plan.md` → all `.md` except `llms.txt`, newest by mtime.
- `bin/ainish-coder:268`, `src/help.sh:42,145,413` — confirmation prose.

### 3.3 Engine — `src/rag/rag.py` (the live engine)
- `2370` memory cross-link glob, `5564` memory discovery, `5870`/`3969` task discovery,
  `5897` plan discovery, `5845` today's comms, `7148` comms harness check: match both schemes.
- **Every "newest" becomes mtime-ordered**, not name-ordered (§1.2).
- `7257` `_read_today_task_record`: repair to glob today's task files by mtime (it is dead today).
- `2467-2468` created memory file → `{today}-{HH}-memory.md`, header pairs with `-team.md`.
- `2547` generated wiki sentence; `7785` help text.
- `4918-4929` `_graph_sources` already takes `.txt`+`.md` by mtime — verify, do not rewrite.

### 3.4 Engine — `src/rag/src/` (Rust mirror, kept in step)
- `wiki.rs:363` sentence, `635` memory suffix, `745-749` created memory file + header.
- `main.rs:3355` comms suffix, `3632-3640` memory discovery (switch to mtime), `176` doc comment.
- `main.rs:5227` / `5195` tests for both suffixes.
- `cargo build --release` + `cargo test` green.

### 3.5 Tests
- `scripts/test-pqc-dist.sh` — update pins (`848` contract plan path, comms template/`--rules`
  probes); keep `858-862` grandfathered probes AND add a new-scheme plan probe proving the hook
  accepts `2026-01-01-09-gated.md` and still refuses it while `status: designing`.
- `src/rag/tests/*.py` — 8 pins on `team.txt`/`memory.txt`/`plan.md`; add a mixed-scheme
  newest-wins regression (the §1.2 defect) and a both-scheme plan-discovery regression.
- New assertions: `deploy_agents_comms.sh` writes `-team.md` with legacy fallback; `AGENTS.md`
  names the hour convention.

## 4. Gates

- **Grandfathering is verified, not assumed:** after the glob change, plan-gate must still find
  THIS task's own `.plan.md` — the branch commits under it, so a broken gate blocks the task that
  broke it.
- **No discovery path matches nothing:** a new-scheme plan, task, and memory file must each be
  found by `ainish-rag --context` in a probe repo.
- **Mixed-scheme newest-wins:** given one grandfather and one new-scheme file in the same day,
  discovery returns the newer by mtime regardless of name collation.
- `AGENTS.md` ≤160 lines; question-me copies byte-identical.
- `bash -n` on every touched script; `cargo test` green; `pytest src/rag/tests` green.

## 5. Verification

- `bash scripts/test-pqc-dist.sh` green. **Baseline first** so the pre-existing `--rules`
  signing-anchor failure (§2) is not misread as a regression from this task: record the failing
  count before the change and prove the delta is zero after.
- Hermetic probe repo: `--rules` writes `.agents/comms/{today}-team.md`; plan-gate accepts a
  new-scheme plan, refuses it while `status: designing`, and still accepts a grandfathered one.
- `ainish-rag --context` on this repo names the right newest plan/task/memory after cutover.
- Wiki regenerated so rendered pages carry the new conventions.
- Probe trees deleted by literal path.

## 6. Open

- `deploy_agents_comms.sh` computes "today" with local `date +%F` while docs say UTC (EST evening
  skew). Pre-existing; fixing it changes deployed filenames for every host, so it stays out of
  scope and gets recorded as a suggestion.
- The Rust crate is a mirror that does not serve requests on this host. Keeping it in step is
  maintenance hygiene, not a functional requirement of this task — but leaving it behind
  guarantees the next native build silently regresses, so §3.4 is in scope.
