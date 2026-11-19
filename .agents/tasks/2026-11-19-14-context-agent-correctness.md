2026-11-19-14-context-agent-correctness
# Task: make `ainish-coder --context` a real self-improving context agent

- lane: now
- branch: `feat/context-agent-correctness`
- status: done (380 assertions pass; merged below)
- plan: `.agents/plans/2026-11-19-14-context-agent-correctness.md`
- scope: `bin/ainish-coder`, `bin/ainish-rag`, `AGENTS.md`, `.agents/canonical/AGENTS.md`,
  `src/rag/rag.py`, `src/rag/context_harness.py`, `scripts/test-pqc-dist.sh`, `llms.txt`,
  `.agents/wiki/`, `research/context-priming-master/probe_corpus.py`
- objective: Make `ainish-coder --context "<input>"` the single entry point any agent harness calls
  after reading `AGENTS.md`, backed by a corpus it actually indexes, a gate that can actually accept,
  a wiki it can actually edit, and one self-editing skill surface separate from `.agents/skills/`.

## What was wrong, and what it is now

| Was | Now |
|---|---|
| `BASE_PROFILE` capped artifacts at 2 while the engine constant said unlimited, so **60 of 167 corpus files** were indexed | caps are `0` (= all), `base_settings()` derives from `BASE_PROFILE` so they cannot diverge again; **164 files**, 411 nodes |
| Unbounded shared-vocabulary edges: **42,216 edges / 102 per node** at full corpus | bounded to `GRAPH_MAX_EDGES_PER_NODE = 24` → **4,220 edges / 10 per node** |
| "what does the contract say" ranked a research transcript first | `KIND_INTENT` boosts the layer the task NAMES; contract sections now rank 1-2 |
| A rules question could route to `skip_retrieval` and return **no rules at all** | a task naming a layer forces retrieval |
| Acceptance needed commit-subject overlap; **5/10 real task objectives** reachable, and the spawned learner passed a query whose commit could not exist | primary referent is a task record at `status: done`; `--task-record` and `--outcome ok\|fail\|unknown` added; `unknown` refuses |
| `history/`, `EXPERIENCE.md`, `prime-profile.json` had **never existed** here | generation 0 seeded, one cycle accepted generation 1, rollback verified |
| Rollback restored the profile only, leaving the newer generation's skill staged | a generation is profile + `.skills` snapshot; rollback moves both |
| Learner could propose `max_wiki_pages: 0 -> 5` and silently un-index the corpus | `_coverage_loss_guard` refuses any narrowing |
| `--refresh-wiki` refused on every real vault | the Python generator emits vault frontmatter + wikilinks; a SIGNED ledger still refuses |
| Two disjoint skill surfaces | one: `.agents/context-harness/skills/`, indexed by the graph and surfaced by the prime |
| Provenance hardcoded `distinct-model` then downgraded itself | three honest states: `distinct-model`, `fresh-context` (verdict PROVISIONAL), `refused` |
| `weights` validated and reported but never read; `0.0` silently replaced by `or` | weights applied per kind; presence tested, not truthiness |
| `--rag` was dead: `deploy_commands.sh` clobbered `SCRIPT_DIR` | `AINISH_BIN_DIR` (readonly) used by every exec; `--rag` and `--rules` seeding work |
| `context-seed` written from a worktree landed in the MAIN checkout | learned-state verbs resolve the worktree root; shared caches keep the canonical root |

## Deliberate deviations

- `MAX_LIVE_SKILLS` raised 3 → 8. Six real, distinct lessons already existed; a cap of 3 would have
  meant deleting three to satisfy a number. The cap still bounds growth and skills remain on-demand.
- `status: done` is accepted as the referent even when landing cannot be corroborated, and the
  generation records `corroborated: false`. All four historical task records name merge shas that no
  longer exist (history was rebased across machines), so requiring a verifiable sha would have made
  the gate refuse forever — a control that can never pass is not a control.

## Verification run

- `scripts/test-pqc-dist.sh` — **380 assertions pass** (354 at baseline, 26 net new).
- `wc -l AGENTS.md` — 160, every non-negotiable greps present; `.agents/canonical/AGENTS.md` synced.
- `./bin/ainish-coder --context "..."` — returns the rules line, the gate line, and contract sections.
- `context-seed` → `context-learn --outcome ok` → `accepted generation 1` →
  `context-rollback 0` → fingerprint `4e02eea77ff7f9d9`, `staged skills: none`.
- `probe_corpus.py` — expected kind present in top-5 rises 4/11 (narrow) → **10/11** (widened+bounded).
