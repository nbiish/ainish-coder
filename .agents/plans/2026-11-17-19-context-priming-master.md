---
plan_format: ainish/plan/v1
slug: context-priming-master
date: 2026-11-17
status: ready
branch: feat/context-priming-master
worktree: /Users/nbiish/code/context-priming-master
task_record: .agents/tasks/2026-11-17-19-context-priming-master.md
operator: question-me
---

# Plan: a per-repo self-improving context harness inside `ainish-rag --context`

## 1. Problem

Every `ainish-rag --context` call runs the same hand-tuned pipeline on every repository. The retrieval
constants (`GRAPH_MAX_WIKI_PAGES`, `GRAPH_CHAPTER_CHARS`, `GRAPH_HOP_BONUS`, the 0.55/0.45 recency
split, the section caps) were chosen by hand for *this* repository and are shipped frozen to every repo
that `ainish-coder --rules` deploys into. Nothing measures whether an assembled prime was useful, so
nothing can improve it. The operator asked for a singular context-priming master system that adapts per
repo and improves itself, seeded at `--rules` time, using the state of the art — and chose to let the
improver write real skill files and scripts, as harness² does, not just numeric knobs.

## 2. Anchor Facts

- `--context` has no learnable state: all ranking constants are module-level literals —
  `src/rag/rag.py:3489` (`CONTEXT_SECTION_CAPS`), `:3591–3594` (`GRAPH_MAX_ARTIFACTS`,
  `GRAPH_MAX_WIKI_PAGES`, `GRAPH_CHAPTER_CHARS`, `GRAPH_HOP_BONUS`), `:3857` (the `0.55 + 0.45 ×
  recency` weighting), `:3787` (`len(shared) >= 3`).
- `run_context_command` is the whole pipeline (`src/rag/rag.py:4945`); `assemble_injection` (`:4715`)
  enforces an ordered degradation ladder that never exceeds the budget and always reports.
- Section shares are fixed at 12/54/20/14 % of a ~4000-token default budget (`src/rag/rag.py:3489`), so
  any new content must fit inside an existing share — established by reading the cap arithmetic at `:4996`.
- Refining a harness without a reference execution and a library is a measurable regression — Harness²
  §4, `research/context-priming-master/sources/arxiv-2610.14224v1.md` (~line 878): Code 73.4 → 63.2,
  Web 69.9 → 65.0.
- Harness² ablation, same file: library −3.1/−1.8, scoped editors −2.9/−3.7, composition −1.6/−1.9.
- A recursive harness can match a frozen three-tool harness exactly (S1 round 1), and its dominant
  failure is self-bloat (round 3: the growing `before_done` checklist consumed 100% of the savings) —
  `research/context-priming-master/sources/video1-XaJi7a0UChs-transcript.txt`.
- `AGENTS.md` sits at exactly its 160-line cap (`scripts/test-pqc-dist.sh:722` and `:878`; `wc -l
  AGENTS.md` = 160).
- `.agents/rag/*` is gitignored except `bench-baseline.json` (`.gitignore:175,178`); `git check-ignore`
  confirms `.agents/context-harness/` is **not** ignored.
- `.agents/skills/` is standing prompt surface for every agent harness in a repo —
  `.agents/skills/llms.txt`, "Selection" section.
- `src/deploy_skills.sh:181–198` sweeps target skill dirs absent from source only when
  `skills_selection_has_entry` returns true, so a learned `learned-*` pack survives today by accident.
- `_skill_mandatory` (`src/skills_selection.sh:94`) is the precedent for a one-place predicate that
  every path consults.
- `bin/ainish-coder` has **no** `--init` verb; the operator's "--rules init" is `deploy_rules_bundle`
  (`bin/ainish-coder:231`), which already scaffolds `.agents/{tasks,plans,suggestions,rag,audit,wiki,memories}`.
- `src/rag/rag.py` is stdlib-only (`:10–28`, no third-party imports), 7,854 lines.
- `ORIENT_PRIMER` is wiki-generated and guarded against clobbering a vault by `generate_wiki`
  (`src/rag/rag.py:1183`).

## 3. Plan

### Goals

- A `PrimeProfile` per repo that changes retrieval selection, validated against hard bounds, stored at a
  tracked path, and reported in `provenance.harness` on every `--context` call.
- A learner (`--context-learn`) that proposes harness edits — profile values **and** staged
  skill/script files — probes them, and accepts only through a deterministic gate, recording
  `KEEP_BASE` as a first-class outcome.
- Generation 0 written idempotently by `ainish-coder --rules`, so every target has a frozen baseline to
  contrast against.
- Learned skills land **staged**, never in `.agents/skills/`, until an operator explicitly promotes one.
- Expiry, immutable history, and one-command rollback.

### Non-goals

- Learning on the `--context` path — it would double latency on every call, and the contract says a
  context call must never block the task.
- Editing `AGENTS.md` — it is at its 160-line cap and this work needs no contract change.
- A new injection section — it would change the budget arithmetic and break existing envelope parsers.
- Reintroducing embeddings or a vector store — the no-dependency property is what makes this run on
  every host.
- Cross-repo library transfer — Harness² measured it at +0.6/+0.5/+2.9, real but small; not worth the
  coupling before the single-repo loop is proven.
- A sandbox for learned scripts — we have no OS-level isolation, so the surface is bounded statically
  instead. This is recorded as a downgrade, not a design.

### Constraints and invariants

- `--context` with no profile present must produce **byte-identical** output to today.
- `src/rag/rag.py` stays stdlib-only.
- `AGENTS.md` stays ≤ 160 lines.
- The budget ladder in `assemble_injection` is untouched; learned content rides inside the existing
  retrieval share.
- Nothing learned is executable without an operator action, and nothing learned is auto-discovered by
  other harnesses until promoted.
- One writer per mutation boundary: `--context-learn` takes an exclusive lock and re-checks the
  generation on write.
- A failed learner run exits non-zero and writes nothing — it must never be indistinguishable from
  `KEEP_BASE`.

### Proposed architecture

```
ainish-coder --rules <dir>
  └─ seed: generate wiki (if absent) → calibrate → write generation 0 (frozen, idempotent)

ainish-rag --context --task "..."
  ├─ load_prime_profile()  → (profile, source ∈ learned|baseline|absent|invalid:<why>)
  ├─ resolve settings = base defaults ⊕ profile     (one resolution point)
  ├─ retrieval / orientation / drivers run as today, against resolved settings
  ├─ surface up to 2 matching STAGED skills as retrieval hits (inside existing cap)
  └─ provenance.harness = {generation, source, tuning}      (no new section)

ainish-rag --context-learn            (separate verb, opt-in, off the hot path)
  ├─ lock
  ├─ sample task → render prime under live profile and one candidate
  ├─ propose  (one improver session, evidence served as files + pointer)
  ├─ probe    (five mechanical signals on both renders)
  ├─ gate     (deterministic: bounds, caps, static checks, citation, net non-negative)
  └─ store    accepted → generation+1 + history/ + EXPERIENCE.md
              refused  → rejected/ with the failing gate
```

Two tiers for skills, because `.agents/skills/` is standing prompt surface:

```
.agents/context-harness/skills/<name>/     STAGED    — reached only through the prime
.agents/skills/learned-<name>/             PROMOTED  — standing prompt surface, operator action only
```

### Interfaces and data

- `PRIME_PROFILE_FORMAT = "ainish-rag/prime-profile/v1"`; `HARNESS_FORMAT = "ainish-rag/context-harness/v1"`.
- `PRIME_BOUNDS` — the bounds table from `05-design.md` §4.2 plus `05b` §3.2, as data.
- `load_prime_profile(repo_root) -> Tuple[Dict, str]` — never raises into `--context`.
- `validate_prime_profile(profile) -> List[str]` — every problem, joined for one error.
- `validate_harness_tree(root) -> List[str]` — the skill/script checks from `05b` §3.2.
- `resolve_settings(profile) -> Settings` — the single place constants and profile meet.
- `ainish-rag --context-learn [--task T] [--dry-run] [--json]` — exit 0 accepted-or-kept, 2 refused, 1 error.
- `ainish-rag --context-status [--json]`, `--context-rollback <gen>`, `--context-promote <name>`.
- `ainish-rag --context-seed [--json]` — generation 0, idempotent, refused if one exists.
- `provenance.harness = {generation, profile, source, tuning, staged_skills}` — additive only.

### Files and symbols

- `src/rag/rag.py` — `PRIME_BOUNDS`, `resolve_settings`, `load_prime_profile`,
  `validate_prime_profile`, `validate_harness_tree`, `apply_prime_profile`, signal functions
  (`_sig_coverage`, `_sig_concentration`, `_sig_freshness`, `_sig_redundancy`, `_sig_cost`),
  `assert_no_acceptance_leakage`, `seed_prime_profile`, `run_context_learn`,
  `run_context_status`, `run_context_rollback`, `run_context_promote`; `graph_retrieve` and
  `render_retrieval_section` gain a `settings` parameter; `assemble_injection` provenance gains
  `harness`; argparse gains the five verbs; `--help` gains one paragraph.
- `bin/ainish-coder` — `deploy_rules_bundle` calls `--context-seed` after the `.agents/` scaffold,
  guarded by `AINISH_SEED_CONTEXT_HARNESS` (default on).
- `src/skills_selection.sh` — `_skill_learned`, beside `_skill_mandatory`.
- `src/deploy_skills.sh` — the sweep at `:181` consults `_skill_learned` and refuses to delete a
  learned pack; a source-pack name collision warns.
- `.agents/context-harness/README.md` — rollback in three lines.
- `scripts/test-pqc-dist.sh` — assertions for every gate in §6.

### Alternatives considered

| Alternative | Why rejected |
|---|---|
| Learn only numeric knobs (first draft) | Operator chose explicit skills; and a skill is on-demand, so it is the *cheaper* form than always-on prose |
| Let the improver write straight into `.agents/skills/` | That directory is standing prompt surface for every harness in the repo; a self-improving loop must not silently enlarge it |
| Learn inline during `--context` | Doubles latency on every call and makes the prime depend on a write succeeding |
| Multi-candidate k>1 recursion | Cost and one local model; revisit only if Phase 0 shows strong signal separation |
| A new "learned" injection section | Changes budget arithmetic and breaks envelope parsers; provenance carries the same information |
| Embedding-based contrast signals | Reintroduces the retired vector dependency that the whole engine is built to avoid |

### Risks and mitigations

| Risk | Mitigation |
|---|---|
| Contrast signals are meaningless, so the gate approves useless edits (R7) | Phase 0 tests separation on real tasks and can stop the project before production code |
| Learner degrades primes (R1) | Frozen generation 0, separate verb, net-non-negative gate, immutable history |
| Improver writes prompt text that games its own gate (R3) | Improver never sees the signals; `assert_no_acceptance_leakage` refuses matching tokens |
| Injection via repository content becomes a write primitive (R4) | Staged tier, static checks, labelled surfacing, mandatory evidence citation |
| Promoted skill becomes permanent prompt surface (R12) | Promotion is operator-only, `learned-*` named, one directory to delete |
| `--rules` sweep deletes learned packs (R13) | `_skill_learned` predicate in the sweep, beside `_skill_mandatory` |
| Self-bloat (R2) | Skills are on-demand; no always-on text added; ≤3 live skills; body/script size caps |
| Learned state dies on clone (R5) | Tracked `.agents/context-harness/`; provenance reports `absent` rather than pretending |
| Concurrent learners clobber (R9) | Exclusive lock plus generation re-check on write |

## 4. Clarifications

### 4.1 How far the learnable surface extends

- **Question:** Should the improver be restricted to bounded numbers and short token lists, or allowed to write skill files and scripts as harness² does?
- **Options:** 1. Keep it narrow — numbers and tokens only, no prose or code, because self-bloat and injection are the dominant risks; 2. Allow a small bounded prose component later, with its own cap and evidence requirement; 3. Go as far as harness² does — let the improver write skill files and scripts.
- **Selected:** 3 — go as far as harness² does, letting the improver write skill files and scripts.
- **Trade-off accepted:** A skill body is prompt text that reaches a model, so injection and gate-gaming move from "useless to attempt" to "real, bounded by tiering and static checks". Self-bloat risk actually *decreases*, because a skill is on-demand rather than always-on.
- **asked:** operator
- **resolved by:** n/a

### 4.2 Where a learned skill lands

- **Question:** `.agents/skills/` is auto-discovered by every agent harness in a repo and treated as standing prompt surface; should learned skills be written there directly, or staged elsewhere until an operator promotes them?
- **Options:** 1. (Recommended) Stage at `.agents/context-harness/skills/` and promote only on an explicit operator command — keeps the blast radius inside the prime; 2. Write directly to `.agents/skills/learned-*` so every harness picks them up immediately — maximum reach, permanent prompt surface from an unreviewed generator; 3. Stage, and auto-promote after N accepted generations — a middle path with a time-bomb property.
- **Selected:** Stage by default, promote only on an explicit operator command.
- **Trade-off accepted:** A learned skill helps only through `--context` until promoted, so its reach is smaller than harness²'s, which has a runtime that can dispatch. Recorded as a deliberate divergence: we have a prime that can only point.
- **asked:** resolved from code
- **resolved by:** `.agents/skills/llms.txt` ("agent harnesses auto-discover `**/.agents/skills` and treat every pack found there as standing prompt surface") and `src/deploy_skills.sh:181`.

### 4.3 Where the learned state is stored

- **Question:** Should the profile live under `.agents/rag/` with the other engine state, or at a tracked path?
- **Options:** 1. (Recommended) `.agents/context-harness/`, tracked, so it survives a clone and is reviewable in a PR; 2. `.agents/rag/context-harness/`, ignored, consistent with other engine state but silently lost on clone; 3. `~/.config/ainish-coder/`, per-machine, never shared between checkouts.
- **Selected:** `.agents/context-harness/`, tracked.
- **Trade-off accepted:** Learned state appears in diffs and must be committed deliberately; an operator who does not want it committed can gitignore it themselves, and provenance will then report `absent` on a fresh clone.
- **asked:** resolved from code
- **resolved by:** `.gitignore:175,178` and `git check-ignore` confirming the path is not ignored.

### 4.4 Whether Phase 0 gates the whole project

- **Question:** The five contrast signals are unvalidated. Should implementation proceed, or must a cheap experiment first show they separate anything?
- **Options:** 1. (Recommended) Phase 0 first — a throwaway script over 8 real tasks; if the signals do not separate, do not build the loop; 2. Build the loop and validate afterwards — faster to demo, but risks ~800 lines of unexercised code; 3. Skip signal-based gating and rely on operator review of each accepted generation.
- **Selected:** Phase 0 first, and it can stop the project.
- **Trade-off accepted:** Roughly an afternoon spent before any production code, and a real possibility the answer is "the loop should not be built". Harness² Figure 7 and S1 round 1 both say a naive loop is a regression generator, so this is the cheapest possible insurance.
- **asked:** resolved from code
- **resolved by:** `research/context-priming-master/sources/arxiv-2610.14224v1.md` (§4, Figure 7) and `06-risk-register.md` R7.

## 5. Todos

- [ ] **T1** Run Phase 0: render retrieval for 8 real tasks under base/wide/narrow profiles and compute all five signals.
  - from: §4.4 | done when: a table of 24 cells exists and the separation question is answered in writing | verify: `python3 research/context-priming-master/phase0.py`
- [ ] **T2** Decide gate on Phase 0 outcome: proceed, or stop and record the finding in `.agents/suggestions/`.
  - from: §4.4 | done when: either Phases 1+ are greenlit with numbers, or a suggestion file explains why not | verify: `ls .agents/suggestions/*context-priming*`
- [ ] **T3** Add `PRIME_PROFILE_FORMAT`, `HARNESS_FORMAT`, `PRIME_BOUNDS`, and `validate_prime_profile` to `src/rag/rag.py`.
  - from: §3 Interfaces | done when: a profile with any out-of-bounds field returns named errors | verify: `python3 -c "import sys; sys.path.insert(0,'src/rag'); import rag; print(rag.validate_prime_profile({...}))"`
- [ ] **T4** Add `load_prime_profile` + `resolve_settings`, and route `graph_retrieve`/`render_retrieval_section`/`assemble_injection` through `settings`.
  - from: §3 Constraints | done when: `--context` with no profile is byte-identical to pre-change output | verify: golden-file diff in `scripts/test-pqc-dist.sh`
- [ ] **T5** Add `provenance.harness` on every context call, reporting generation/source/tuning.
  - from: §3 Interfaces | done when: `--context --json` carries the block with `source: "absent"` when no profile exists | verify: `./bin/ainish-rag --context --task test --json | python3 -c "import json,sys; print(json.load(sys.stdin)['provenance']['harness'])"`
- [ ] **T6** Add `--context-seed` (generation 0, idempotent, refused if present) with calibration measurements.
  - from: §3 | done when: running it twice leaves the profile byte-identical | verify: `scripts/test-pqc-dist.sh` seed assertion
- [ ] **T7** Hook seeding into `deploy_rules_bundle` behind `AINISH_SEED_CONTEXT_HARNESS`.
  - from: §3 | done when: `--rules` on a scratch repo writes generation 0, and `AINISH_SEED_CONTEXT_HARNESS=off` does not | verify: `scripts/test-pqc-dist.sh` rules-seed assertion
- [ ] **T8** Add `validate_harness_tree` implementing every check in `05b` §3.2, including the static network/secret/import checks.
  - from: §3 | done when: a skill with a bad frontmatter name, a missing script, an uncompilable helper, or a URL each returns a named error | verify: `scripts/test-pqc-dist.sh` validator assertions
- [ ] **T9** Add `assert_no_acceptance_leakage` and wire it into both the profile and tree validators.
  - from: §3 Risks R3 | done when: a `domain_prior` term or skill body naming an acceptance signal is refused | verify: `scripts/test-pqc-dist.sh` leakage assertion
- [ ] **T10** Implement the five signal functions as pure functions of `(hits, task, settings)`.
  - from: §3 Interfaces | done when: they reproduce Phase 0's numbers exactly on the same inputs | verify: comparison against the Phase 0 table
- [ ] **T11** Implement `--context-learn`: lock, sample, probe, propose, gate, store, with `--dry-run`.
  - from: §3 | done when: `--dry-run` prints candidate + signal table and writes nothing; a real run either advances the generation or writes a `rejected/` entry | verify: `scripts/test-pqc-dist.sh` learner assertions
- [ ] **T12** Implement `--context-status`, `--context-rollback <gen>`, and `--context-promote <name>`.
  - from: §3 | done when: rollback to generation 0 restores byte-identical output; promote copies a staged skill to `.agents/skills/learned-<name>/` and refuses a non-staged name | verify: `scripts/test-pqc-dist.sh` lifecycle assertions
- [ ] **T13** Add `_skill_learned` and consult it in the `deploy_skills.sh` sweep so learned packs are never swept or overwritten.
  - from: §3 Risks R13 | done when: `--rules` over a repo with a promoted `learned-*` pack leaves it intact and warns on a source name collision | verify: `scripts/test-pqc-dist.sh` sweep assertion
- [ ] **T14** Implement `domain_prior` expiry after M unsupported generations, surfaced in `EXPERIENCE.md`.
  - from: §3 Risks R8 | done when: a hint unsupported for M generations is dropped and the drop is recorded | verify: `scripts/test-pqc-dist.sh` expiry assertion
- [ ] **T15** Advertise: one paragraph in `ainish-rag --help` (paid for by trimming the retired-vector paragraph), an `llms.txt` section, and a `scripts/test-pqc-dist.sh` grep assertion.
  - from: §3 | done when: `ainish-rag --help | grep -c context-learn` ≥ 1 and `wc -l AGENTS.md` is still 160 | verify: `./bin/ainish-rag --help | grep -c context-learn; wc -l < AGENTS.md`

## 6. Verification

- `scripts/test-pqc-dist.sh` — all pre-existing assertions pass at their recorded baseline, plus the new ones; 306 passing today.
- `./bin/ainish-rag --context --task "probe" > /tmp/after.txt` against a stashed pre-change build — byte-identical when no profile exists.
- `python3 research/context-priming-master/phase0.py` — reproduces the Phase 0 table.
- `./bin/ainish-rag --context --json --task "probe"` — `provenance.harness.source` present and honest (`absent` / `baseline` / `learned` / `invalid: <reason>`).
- `AINISH_SEED_CONTEXT_HARNESS=off ./bin/ainish-coder --rules <scratch>` — no profile written; running without the override twice — byte-identical profile.
- `wc -l < AGENTS.md` — still 160, unchanged by this work.
- `./bin/ainish-rag --context-learn --dry-run` — prints a candidate and signal table, writes nothing (`git status --short` clean).
- Two concurrent `--context-learn` runs — the second exits non-zero naming the lock holder.
- `./bin/ainish-rag --context-rollback 0` — output byte-identical to no-profile.

## 7. Open Decisions

- Whether the five signals are the right five — settled by Phase 0's numbers, before any production code.
- What `M` should be for `domain_prior` expiry — settled by observing how often a hint is re-supported across the first real generations. Start at 5 and revisit.
- Whether promotion should be reachable from `ainish-coder` as well as `ainish-rag` — settled after the first promoted skill exists and its natural invocation point is observed.
- Whether the ≤3-live-skills cap is too tight — settled by whether the gate rejects useful proposals purely on count.
