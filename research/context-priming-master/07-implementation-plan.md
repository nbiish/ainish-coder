# 07 — Implementation plan

Smallest-first, with a gate that must pass before the next phase starts. Phase 0 exists to kill the
idea cheaply if the contrast turns out to be meaningless (risk R7).

Nothing here is started. Phases are ordered by *evidential value per line of code*, not by
architectural tidiness.

---

## Phase 0 — Prove the contrast means something (before any production code)

**Goal:** decide whether five mechanical signals can distinguish a good prime from a bad one on *this*
repository, using throwaway analysis.

**Work:**

1. Pick 8 real tasks from `.agents/tasks/` and `.agents/plans/` — a mix of domains, since
   `DecisionEngine.route` already assigns `target_domain`.
2. For each, render the retrieval section under three deliberately-different profiles:
   - `base` (current constants)
   - `wide` (`max_wiki_pages=16`, `max_artifacts=6`, `chapter_chars=2400`)
   - `narrow` (`max_wiki_pages=3`, `max_artifacts=1`, `chapter_chars=600`)
3. Compute the five signals for each of the 24 cells, by hand in a scratch script.
4. Answer three questions:
   - Do the signals separate `wide`/`narrow` from `base` **at all**? If not, the loop cannot work.
   - Is `base` already near-optimal on this repo? If so, KEEP_BASE is the honest product and the loop
     should ship as "detect regressions", not "improve".
   - Which signals are correlated so tightly they are redundant? Drop them; five is a ceiling.

**Gate:** a written answer to all three, with the numbers. **If the signals do not separate, stop —
do not build Phases 1–5.** Record the finding in `.agents/suggestions/`.

**Estimated:** a scratch script and an afternoon. No production code, no tests, no commit needed
beyond the finding.

---

## Phase 1 — `PrimeProfile`: schema, bounds, load, apply

**Goal:** the profile exists, is validated, and changes retrieval — with learning still absent.

**Work:**

1. `PRIME_PROFILE_FORMAT = "ainish-rag/prime-profile/v1"` beside `CONTEXT_FORMAT`.
2. `PRIME_BOUNDS` — the table from [`05-design.md`](05-design.md) §4.2, as data.
3. `load_prime_profile(repo_root) -> Tuple[Dict, str]` returning `(profile, source)` where source is
   `"learned" | "baseline" | "absent" | "invalid: <reason>"`. **Invalid never raises into `--context`**;
   it reports in provenance and falls back to base, matching the existing "never block the task" rule.
4. `validate_prime_profile(profile) -> List[str]` — every problem, harness2 style, joined for one
   error.
5. `apply_prime_profile(profile)` — the *one* place that maps profile fields onto the module
   constants. Implemented by replacing direct reads of `GRAPH_MAX_WIKI_PAGES` etc. with a resolved
   settings object, so there is no path that reads a constant and a profile separately.
6. `provenance["harness"] = {"generation", "profile", "source", "tuning"}`.
7. `render_orientation_section` / `retrieve_context` / `render_retrieval_section` take the resolved
   settings; `CONTEXT_SECTION_CAPS` becomes the profile's `section_caps` with the current dict as the
   default.

**Gate:**
- `--context` output is **byte-identical** to today when no profile file exists. This is the single
  most important assertion in the whole plan; it proves the refactor changed nothing.
- A profile with an out-of-bounds value is refused, reported in provenance, and base defaults apply.
- A profile is not read on any path that does not go through `load_prime_profile`.

**Estimated:** ~150 lines + tests. No new dependencies.

---

## Phase 2 — Seeding at `--rules` (generation 0)

**Goal:** a fresh target repo gets a frozen baseline.

**Work:**

1. `ainish-rag --context-seed [--json]` — calibrate and write generation 0, or refuse if one exists
   (idempotent, per R11).
2. Calibration is measurement, not opinion: corpus node count, page count, artifact count, and the
   term-overlap distribution over probes drawn from `llms.txt` headings + newest plan titles.
3. Hook into `deploy_rules_bundle` in `bin/ainish-coder` after the `.agents/` scaffold step, guarded
   by `AINISH_SEED_CONTEXT_HARNESS` (default on) and skipped in a non-repo target.
4. Write `.agents/context-harness/{prime-profile.json,EXPERIENCE.md}`.
5. Add `.agents/context-harness/history/` and `rejected/` scaffolding with a `README.md` explaining
   the rollback procedure in three lines.

**Gate:**
- `--rules` twice against a scratch directory leaves the profile byte-identical.
- A target with no `.agents/wiki/` gets one generated first, or seeding reports it could not
  calibrate and writes nothing (fail closed, not a zeroed profile).
- `scripts/test-pqc-dist.sh` still passes, including the 160-line `AGENTS.md` gate.

**Estimated:** ~120 lines of Python + ~15 lines of bash.

---

## Phase 3 — The learner: propose, probe, gate, store

**Goal:** `--context-learn` can produce one candidate and accept or reject it.

**Work:**

1. `ainish-rag --context-learn [--task "<text>"] [--dry-run] [--json]`.
2. **Sample**: take `--task`, else the newest task record's objective.
3. **Probe**: render the retrieval section under the live profile and under one candidate.
4. **Signals**: the five from the design, each a small pure function of `(hits, task, settings)`.
   Pure so Phase 0's numbers can be reproduced exactly.
5. **Propose**: one improver session. Input is a `context/` tree — task, both rendered primes, the hit
   metadata, and the current profile — plus a short mission pointer. Output is `<edits>`, `<why>`,
   `<kept>` in the harness2 tag grammar.
6. **Gate**: the six conditions from §5.3, in code, each with its own refusal reason.
7. **Store**: accepted → generation+1 profile + `EXPERIENCE.md` + `history/` entry; refused →
   `rejected/` entry with the failing condition and the raw proposal.
8. **Lock**: exclusive `.learn.lock`, generation re-checked on write (R9).

**Gate:**
- `--dry-run` shows the candidate and the signal table without writing anything.
- A proposal with an out-of-bounds field is refused, and the refusal names the field and the bound.
- A proposal with a `domain_prior` term matching an acceptance marker is refused (R3).
- With the improver unavailable, the verb exits non-zero with a reason and writes nothing — a failed
  learning run must never look like a KEEP_BASE.
- Two concurrent runs: the second refuses, naming the lock holder.

**Estimated:** ~350 lines. The largest phase, and the one to split if it grows.

---

## Phase 4 — Experience, expiry, and rollback

**Goal:** the learned state stays honest over months.

**Work:**

1. `ainish-rag --context-status [--json]` — generation, source, age of each `domain_prior` entry,
   history size, last N rejections with reasons.
2. `ainish-rag --context-rollback <generation>` — copy a history entry to live, refuse if the target
   generation does not exist, record the rollback in `EXPERIENCE.md` as its own event.
3. **Expiry**: a `domain_prior` entry unsupported for `M` generations is dropped by the gate (R8).
4. `EXPERIENCE.md` renders the age of every live hint so drift is visible without a diff.

**Gate:**
- Rollback to generation 0 restores byte-identical behaviour to no-profile.
- An expired hint is dropped and the drop appears in `EXPERIENCE.md`.
- `--context-status` on a repo with no profile says so plainly and exits 0.

**Estimated:** ~180 lines.

---

## Phase 5 — Discoverability and documentation

**Goal:** an agent learns this exists without being told. This repo already paid for that lesson once
(the federation task).

**Work:**

1. A short paragraph in `ainish-rag --help`, **paid for by trimming the retired-vector paragraph**,
   never by touching `AGENTS.md`.
2. `llms.txt` gains a section — it is the per-repo PRD and is the right home for depth.
3. `.agents/suggestions/{date}-{HH}-context-harness.md` so the next context call retrieves it.
4. `scripts/test-pqc-dist.sh` assertions: the verb is named in help (same pattern as the federation
   assertions at :866–:876), the profile path is not gitignored, and `--context` with no profile is
   byte-identical to the pre-change output.

**Gate:** the measured grep counts, and the full test suite green including the pre-existing baseline.

---

## What the whole plan deliberately does not do

| Not doing | Why |
|---|---|
| Learning on the `--context` path | Doubles latency for every call; contract says never block the task |
| Letting the improver write prose or code | Injection write-primitive; bloat vector; no budget for it |
| Multi-candidate (k>1) recursion | Cost, and one local model. Revisit only if Phase 0 shows strong signal separation |
| Cross-repo library transfer | Paper shows +0.6/+0.5/+2.9 — real but small; not worth the coupling yet |
| Training, embeddings, a vector store | Stdlib-only engine; the no-dependency property is load-bearing on every host |
| Touching `AGENTS.md` | At its 160-line cap, and this work needs no contract change |
| A new injection section | Changes the budget arithmetic and breaks existing parsers for no gain |

## Ordering rationale

Phase 0 is first because R7 is the risk that kills the feature, and it costs almost nothing to test.
Phase 1 is second because it is pure refactor with a byte-identical gate — the safest possible way to
introduce the concept of a profile. Phase 2 before Phase 3 because a learner with no baseline to
compare against is the exact configuration the paper measured as a **regression**. Phase 3 is the
feature. Phase 4 exists because a learning loop without expiry and rollback is a slow-motion incident.
Phase 5 exists because this repo already learned that unadvertised capability is dead capability.
