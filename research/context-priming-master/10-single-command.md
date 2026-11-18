---
date: 2026-11-18
topic: one command — the contract as corpus, and learning on the hot path
status: implemented
---

# 10 — One command: what changed, and why it overrules two earlier decisions

Operator direction, 2026-11-18: *"the whole system when working with the AGENTS.md rules should only
utilize a single command for the context system to work and then output back to the agent after reading
our rules so we have a continuously improving context system."*

That is three requirements in one sentence, and two of them reverse decisions recorded in
[`09-as-built.md`](09-as-built.md). Both reversals are justified below rather than quietly applied.

## 1. The contract is now corpus (was: absent from retrieval)

**The defect.** Before this change `AGENTS.md` was **not in the retrieval graph at all**. `_graph_sources`
enumerated the wiki vault plus `.agents/{comms,memories,plans,suggestions,tasks}` and nothing else.
Measured directly on this repository: `any('AGENTS' in n['path'] for n in graph['nodes'])` returned
`False`. So the one command an agent is told to call could report the branch, the dirty tree and the last
COMMS line, but could not answer "what are the rules here?" — the agent had to read the contract
separately, which is exactly the two-step flow the operator asked to remove.

**The fix.** `GRAPH_CONTRACT_FILES = ("AGENTS.md", "llms.txt")` joins the source set as a new
`contract` kind, split at `##` headings the way wiki pages are, so each section is its own node. Verified:
`AGENTS.md` now contributes 20 nodes and is the **top hit at score 1.00** for "what does the contract say
about worktrees and plans", returning `## The context call` and `## Non-negotiables`.

A second bug surfaced while fixing it: the node-building loop stamped `"kind": "wiki"` on every
heading-split source regardless of origin, so contract nodes were indistinguishable from wiki pages. Now
the real kind is carried through, which also keeps graph-edge bookkeeping honest.

## 2. Learning is now on the hot path — detached (was: separate verb only)

**The earlier decision.** `09-as-built.md` argued learning must never run inside `--context`, because a
context call must never block the task that asked for it, and a learning pass costs a model session.

**Why it is now reversible rather than wrong.** Both things can be true: the *answer* must not wait, and
the *system* must still improve without a second command. The resolution is a detached child process —
`subprocess.Popen` with `start_new_session=True`, `stdout`/`stderr` at `DEVNULL`, launched **after** the
prime is fully assembled. The agent's block is already built when the spawn happens, so latency is
unchanged and the answer cannot be affected. Measured: a prime with the pass spawned returned in the same
time as one with it throttled (~17s, dominated by the EGM drivers, not the spawn).

**Guards, because an unguarded spawn is a way to burn a model session on every keystroke:**

| Guard | Value | Why |
|---|---|---|
| Minimum interval | 6h | a repo nobody touched does not need re-tuning |
| Minimum new commits | 1 | ties the loop to *activity*, which is also what the outcome signal needs |
| Lock | `.learn.lock` | a manual `context-learn` cannot be clobbered by a spawned one |
| `--retrieval-only` | skips the spawn | the caller explicitly asked for no model calls |
| Attempt recorded in `finally` | always | a consistently failing learner must not respawn on every call |

Throttle state lives in `.agents/rag/context-harness-autolearn.json` — gitignored on purpose, because it
is per-machine bookkeeping, not learned state, and two machines should each get their own pass without
arguing about a committed timestamp. It is reported on every call as `provenance.harness.autolearn`, so a
repo whose loop has stalled says why: `"last pass 2m ago; next eligible in 357m"`.

## 3. Orientation always states the rules (was: retrieval only)

**The defect.** Routing can decide `skip_retrieval` — a self-contained question needs no corpus — and in
that case the prime contained **zero** mention of the contract. An agent could then work a whole task
never told which rules governed it. Observed directly on a trivial probe task.

**The fix.** `render_orientation_section` now reports two lines that are never skipped and cost no model
call:

```
- rules: `AGENTS.md` @ 174387417daf (the contract this session is bound by)
- gate: GREEN but for commit 400994e, not HEAD (stale verdict)
```

The digest makes "which contract am I bound by" checkable against the file. The gate line reports the
repo's own compliance verdict and **names a stale one explicitly** rather than repeating a GREEN that no
longer applies to HEAD — which is what it did on this repository the first time it ran, correctly
reporting that the cached gate belonged to `400994e` and not to HEAD.

## 4. The contract now says so

`AGENTS.md` gained one paragraph under *## The context call*, stating that one command is the whole system,
that the rules are answerable from the prime, that a throttled background pass tunes the repo afterwards,
and that an agent must never call a second command to prime itself. **It was paid for, not appended to:**
the file was at its hard 160-line gate, and it is still exactly 160 after the edit. The cost came from
merging two Start-here steps, reflowing four paragraphs, and tightening the Worktrees section. Every
existing non-negotiable was verified still present afterwards (`Plan first`, `pqc-secrets`, `co-author`,
`machine-sync`, `context-harness` each grep to their original count).

## Verified

- `scripts/test-pqc-dist.sh` — **340 assertions pass** (331 before this change, 9 new).
- `AGENTS.md` — exactly 160 lines, gate green, every rule intact.
- Contract retrievable — 20 nodes; top hit at 1.00 for a rules question; `## Non-negotiables` returned.
- Orientation reports rules + gate on **every** call, including when routing skips retrieval.
- Single command spawns learning — `provenance.harness.autolearn.spawned = true`, prime unaffected.
- Throttle holds — a second call reports `"last pass 2m ago; next eligible in 357m"` and spawns nothing.
- Background child completes — generation advanced / rejection recorded after the prime was returned.
- `--retrieval-only` correctly reports `"--retrieval-only makes no model calls"`.

## What is still not honest to claim

- **The background pass is best-effort.** If the machine sleeps or the process is killed, that pass is
  simply lost; the next eligible call starts another. There is no queue and no retry — deliberately, since
  a durable queue for a 6-hourly optimisation is more machinery than the thing is worth.
- **A `skip_retrieval` route still means no corpus.** Orientation now guarantees the *rules*, not the
  *corpus*. An agent asking a question the router judges self-contained gets no wiki sections, which is
  the router working as designed — but it is a real limit on "one command answers everything".
- **The outcome signal is unchanged** and still weak in the way `09-as-built.md` describes. Making the
  loop run more often does not make its gate more trustworthy; the human-auditable, reversible generation
  history remains the actual control.
