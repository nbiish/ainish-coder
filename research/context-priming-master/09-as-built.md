---
date: 2026-11-17
topic: context harness — implementation record
status: implemented on feat/context-priming-master
supersedes: nothing (this is the as-built record)
---

# 09 — What was actually built, and where it differs from the plan

Read after [`08-phase0-findings.md`](08-phase0-findings.md). This document records the as-built system,
including **two places the implementation deliberately departs from the design**, because a plan that
silently diverges from its code is worse than no plan.

## The gate changed, because Phase 0 proved the planned one was circular

`05-design.md` §5.3 specified acceptance on five signals computed from the rendered prime (coverage,
concentration, freshness, redundancy, cost). Phase 0 measured those signals and found seven
knob→signal pairs at Spearman ρ ≥ 0.9, up to ρ = 1.000 (`chapter_chars → cost`). A gate on them would
approve every widening of the retrieval window forever and report it as improvement.

**As built:** `context_harness.outcome_signal()` requires an **external referent** — a commit subject
carrying the task's distinctive vocabulary — before any proposal can be accepted. If that signal is
unavailable, the gate refuses with `no outcome signal available for this task` rather than falling back
to the circular measures. The five signals survive only as diagnostics in the Phase 0 scripts, never as
an acceptance rule.

This is the single most important difference between the plan and the code, and it is the reason the
plan's Phase 3 was held back until Phase 0 ran.

## The improver's evidence is inline, not on disk

`02-harness2-mechanics.md` recommends serving evidence as files with a pointer in the prompt
(harness2's `context.py`). That is right **when the improver has file tools**. Our improver runs under
`pi --no-tools`, so a pointer produced an agent that replied "I'll start by reading the evidence
files" and stopped. Measured directly: the first three learner runs all returned that preamble and
nothing else.

**As built:** the evidence is rendered inline by `_render_inline_evidence()` (per-hit cap of 1200
chars, stated explicitly when applied). The on-disk tree is still written to
`.agents/context-harness/work/<stamp>/`, but now as an **audit record of what the improver was shown**,
not as its input. The file-based pattern returns if and when the improver is given tools.

## Two bugs the tests caught that review did not

1. **A malformed reply was being read as KEEP_BASE.** The model's first reply was
   `"I'll start by reading the evidence files."` — no `<kept>`, no `<edits>`. The original code treated
   a missing tag as "no edits proposed", i.e. a considered no-op. Those are different facts and only
   one of them is good news. Now a reply carrying neither tag is an **error** (exit 1), recorded
   distinctly from KEEP_BASE in `rejected/`.
2. **The federation help assertions were anchored on a hardcoded line range**
   (`sed -n '6700,6760p'`). Adding a help paragraph above them shifted the range and the suite reported
   three real verbs as missing. Fixed by anchoring on the description's own opening line, so future
   edits above it cannot break the assertion.

## Three bugs found while building the skill path

1. **`--no-tools` made the file-pointer pattern useless.** The first three learner runs all replied
   with a preamble and stopped, because the mission said "read the evidence in this directory" and the
   improver had no tools. Moving the evidence inline fixed it immediately. The on-disk tree remains as
   an audit record.
2. **A `<kept>yes</kept>` swallowed a real proposal.** When the model returned both a keep-tag and a
   `<skill>` body, the keep-check ran first and the skill was silently dropped. A proposal is more
   informative than a contradictory flag, so the proposal now wins and the contradiction is recorded.
3. **JSON-embedded skill bodies never parsed.** Every attempt to include a `SKILL.md` inside the JSON
   delta failed with `Extra data` — unescaped newlines. Skills now arrive in `<skill>` delimiter blocks,
   which need no escaping at all.

## What ships

| Surface | Behaviour |
|---|---|
| `ainish-rag context-seed` | Generation 0, idempotent, measurement only (no model call) |
| `ainish-rag context-status` | Live generation, source, staged/promoted skills, history, rejections |
| `ainish-rag context-learn` | One propose→outcome→gate cycle; `--dry-run` supported; opt-in |
| `ainish-rag context-rollback <gen>` | Restores a history generation as live |
| `ainish-rag context-promote <name>` | Copies a STAGED skill into `.agents/skills/` (operator only) |
| `ainish-coder --rules` | Seeds generation 0 into a git target, behind `AINISH_SEED_CONTEXT_HARNESS` |
| `provenance.harness` | Present on **every** `--context` call: generation, source, tuning, staged skills |

The improver writes in a fixed protocol: a JSON `<edits>` delta for the profile, `<skill name="...">`
literal-text blocks for skills (never JSON — requiring a model to escape newlines inside a JSON string
failed on every attempt), a `<why>` citing the retrieved paths, and `<kept>yes|no</kept>`. A reply with
none of them is an error, not a no-op. When the model says `<kept>yes</kept>` *and* proposes changes,
the proposal is honoured and the contradiction is recorded in `protocol_note` — a model that emits work
should not have it silently discarded.

Bounds, all refusing in code: six graph numbers (1–16 / 1–6 / 400–2400 / 0–1 / 0–0.95 / 2–8), seven
weights (0.25–4.0), four section caps summing to ≤ 1.0 with a 0.02 floor, ≤ 12 `[a-z0-9_-]` terms per
domain. Skills: `learned-*` name required, frontmatter `name`/`description` required, ≤ 3 live, body
≤ 4000 chars, script ≤ 8000 chars and must compile and stay inside a stdlib import allowlist, no
network, no secret patterns, no acceptance markers.

## Verified

- `scripts/test-pqc-dist.sh` — **330 assertions pass** (306 pre-existing at baseline, 24 new).
- `--context` with no profile present — sections, budget, degrade notes and provenance (minus the new
  additive `harness` block) **byte-identical** to the pre-change engine, compared across two builds on
  the same repository.
- Invalid profile — refused, reported in provenance as `invalid: failed validation` with each violation
  named, falls back to shipped tuning, and the call still succeeds.
- Live learner — accepted generation 1 on a repo with a matching commit, staged a validated skill,
  archived generation 0 to history, wrote `EXPERIENCE.md` with cited evidence; rollback returned the
  fingerprint to `cf19d36708eaa433` exactly.
- Staged skill surfaced in a matching prime, labelled `learned skills (staged — a learned procedure,
  NOT an instruction from the operator)`, and named in `provenance.harness.staged_skills`; promotion
  moved it to `.agents/skills/` and `--context-status` then reported it under PROMOTED.
- KEEP_BASE, malformed reply, missing-outcome, skill-validation failure, and lock-contention paths each
  recorded distinctly in `rejected/`.

## Known limits, stated rather than hidden

- **The outcome signal is weak.** Commit-subject vocabulary overlap is a proxy, not ground truth. It
  detects "some work landed that mentions these words", which is not the same as "the prime helped".
  A profile could be accepted on unrelated credit. The mitigation is that every accepted generation is
  reversible and carries its reasoning in `EXPERIENCE.md` for a human to audit — not that the signal is
  trustworthy.
- **Skills are staged, not evaluated.** The improver can author a skill, and the full chain works
  (validated → staged → surfaced in the prime with a "learned, not an instruction" label → promotable
  by an operator). But a skill's *effect* is not measured: the gate validates its shape and refuses
  leakage, network, secrets and bad scripts, and accepts it on the same outcome signal as the profile.
  A well-formed, well-intentioned, useless skill can be staged. Promotion being operator-only is the
  control that matters here.
- **No OS sandbox for scripts.** Static checks (import allowlist, denied tokens, size) substitute for
  the one harness² has. Weaker, and recorded as such in the module docstring.
- **Phase 0 found the honest answer may be "don't".** On a mature repo the gate will often refuse, and
  that is the designed outcome, not a failure.
