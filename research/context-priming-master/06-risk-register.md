# 06 — Risk register

Each risk states the failure, the evidence it is real, the mitigation, and **how we would find out**.

## R1 — The learner makes primes worse

**Failure.** Accepted profile generations degrade retrieval on this repository, and every agent
inherits it.

**Evidence.** Harness² §4 Figure 7: "directly refining the base execution harness without access to
reference executions, candidate probes, or the improvement library degrades performance on Code and
Web. Code drops from 73.4 to 63.2, Web from 69.9 to 65.0."

**Mitigation.** Generation 0 baseline is mandatory and frozen. Learning is a separate verb. The
acceptance gate requires non-negative net change on all five signals. `history/` is immutable so
rollback is a file copy.

**Discovery.** `ainish-rag --context --explain-harness` on a real task; and a benchmark that renders
the same probe task under generation N and generation 0 and reports the five signals in a table.

**Residual.** Signals are noisy on one sample. A profile can be non-negative on all five and still be
worse for what the agent actually needed. This is irreducible without labels, and is the reason the
feature is opt-in.

---

## R2 — Self-bloat returns

**Failure.** The learned surface grows until the prime is mostly learned text and the savings vanish —
S1's exact trap: the `before_done` checklist ate 100% of the parser's savings.

**Evidence.** S1 round 3, second evolving harness.

**Mitigation.** `ALWAYS_ON_CAP` — a single character budget on the profile's prose contribution,
checked in the validator, with the reason stored beside it. `domain_prior` is capped at 12 terms ×
32 chars per domain. Scalar fields have no growth path at all. There is no prose field to expand.

**Discovery.** The cap is a refusal, so this cannot happen silently — it can only be hit, and hitting
it is recorded in `rejected/`.

**Residual.** An operator could raise `ALWAYS_ON_CAP`. That is a deliberate, reviewable change to one
constant — which is the correct place for that decision.

---

## R3 — Criterion leakage / the improver games the gate

**Failure.** The improver writes retrieval hints that raise the measured signals without improving the
prime — S1's `before_done` checks copying hidden check names from the task description.

**Evidence.** S1 round 3, third failure mode.

**Mitigation.** Two independent layers:
1. **The improver is never told the signals.** Its prompt contains two rendered primes, the task, and
   the evidence tree; it is asked which better equips an engineer and why.
2. **`assert_no_acceptance_leakage`** refuses any `domain_prior` term matching an acceptance marker or
   close variant, by name. Code backstop, not prompt request.

**Discovery.** Rejected proposals carry the leaked term in `rejected/`. A reviewer scanning that
directory sees it.

**Residual.** A term that is not literally a marker name but correlates with one could pass. Bounded by
the 12-term cap and by the fact that a hint can only *promote* existing corpus nodes, so it cannot
invent evidence.

---

## R4 — Prompt injection through repository content

**Failure.** A `.agents/` artefact or wiki page contains text that steers the improver into writing a
harmful profile. Retrieved text is already evidence-not-instruction for the *drivers*, but the improver
writes files.

**Evidence.** This repo's own security contract treats all external text as data; the risk is inherent
to any system where retrieved content reaches a model that has write intent.

**Mitigation.**
1. The improver's write surface is **a JSON object with bounded numeric fields and short token lists**.
   There is no free-text field an injected instruction could occupy, and no code field at all.
2. `domain_prior` terms are validated against `[a-z0-9_-]{1,32}`, so prose cannot pass.
3. The improver session runs with an explicit environment allowlist (`pqc-secrets` contract), never
   `os.environ` minus a denylist.
4. Retrieved evidence is wrapped in `<DATA>` enclosures, per this repo's existing convention.

**Discovery.** The validator refuses anything that is not a token; a successful injection could at
most reorder retrieval priorities, which the acceptance gate must still approve.

**Residual.** A numeric-field-only surface makes injection *useless* rather than *impossible* to
attempt. That is an acceptable ceiling; the alternative — an improver that writes prompt files — is
strictly worse.

---

## R5 — Learned state doesn't survive a clone

**Failure.** `.agents/rag/` is gitignored except `bench-baseline.json`. If the profile lives there, two
machines diverge silently and a fresh clone starts from scratch with no explanation.

**Evidence.** `.gitignore:175` ignores `.agents/rag/*`; `:178` re-includes only `bench-baseline.json`.

**Mitigation.** The profile lives at `.agents/context-harness/`, a normal tracked path. Absent the
file, the engine uses base defaults and **says `source: "absent"` in provenance** rather than
pretending it has a profile.

**Discovery.** Provenance field. A test asserts the path is not gitignored.

**Residual.** An operator may choose not to commit it. Then this repo's behaviour is local-only, which
is stated in provenance and is their call.

---

## R6 — Cost and latency creep on the hot path

**Failure.** `--context` gets slower or more expensive because of learning-related work.

**Evidence.** `--context` is called at the start of essentially every task. A doubling of latency is
felt every time.

**Mitigation.** Learning is a **separate verb**. `--context` does exactly one extra thing: read a small
JSON file and apply bounded values. If the file is absent or invalid, base defaults are used and
provenance says so. No model call is added to the hot path.

**Discovery.** A test that times `--context` with and without a profile present, asserting the delta is
within a small bound.

---

## R7 — The contrast is meaningless (garbage signals)

**Failure.** The five signals turn out not to correlate with "a good prime", so the gate approves
changes that do not help and rejects changes that would.

**Evidence.** Harness² states plainly that its own contrasts "inform subsequent composition rather than
verify task correctness, as execution stochasticity and shared model biases limit the reliability of
the evidence." Our signals are weaker still: no trajectory, no deliverable.

**Mitigation.** This is the strongest argument for keeping the surface **narrow and reversible**. We do
not claim the signals measure quality; we claim they detect *regressions in mechanical properties*.
A profile that passes is not known to be better — it is known not to have reduced coverage,
concentration, freshness, or redundancy. That is a much weaker claim, and it is the honest one.

**Discovery.** Before shipping, run the loop for N generations on this repo and inspect whether the
accepted edits are ones a human would endorse. If they are not, the signals are wrong and the loop
should not ship — the `KEEP_BASE`-only behaviour is still useful.

**This is the risk most likely to kill the feature.** It should be the first thing tested, and the
implementation plan front-loads it.

---

## R8 — Drift: optimising for last week

**Failure.** The profile encodes the task distribution of one sprint. Six weeks later every prime
promotes artefacts that are stale.

**Evidence.** `graph_retrieve` already applies recency weighting for exactly this reason. A learned
`domain_prior` has no such decay.

**Mitigation.** `domain_prior` entries carry a `last_supported` generation and are **dropped after M
unsupported generations** (harness2 lists "expiring stale experience" as its own future work — we
should not defer it, because our surface is small enough to do it properly). Also: every accepted
generation records what it replaced, so drift is visible as a diff.

**Discovery.** `EXPERIENCE.md` shows the age of each hint; a profile with all-stale hints is visibly
degenerate.

---

## R9 — Two writers, one profile

**Failure.** Two agents learn concurrently in one repo and one clobbers the other — violating the
contract's "one writer per mutation boundary".

**Evidence.** `.agents/rules-sync.lock/` exists in this repo precisely because concurrent rules writes
were a real problem.

**Mitigation.** `--context-learn` takes an exclusive lock file (`.agents/context-harness/.learn.lock`)
and refuses with a clear message if held. Reading the profile needs no lock. Generation numbers are
re-checked on write: if the on-disk generation moved, the write is refused, not merged.

**Discovery.** Lock file present with a stale pid; refusal message names the holder.

---

## R10 — We build this and nobody uses it

**Failure.** The learner is opt-in, operators never opt in, and we have added 800 lines of unexercised
code.

**Evidence.** The federation-discoverability task in this repo's own history exists because
capabilities that agents never learn about are dead weight.

**Mitigation.** Two surfaces at ship time: a pointer in `ainish-rag --help` (paid for by trimming
something else in that description, never by touching `AGENTS.md`'s 160-line cap), and a
`.agents/suggestions/` note so the next context call retrieves it. If a repo has a profile, provenance
names it on every `--context` call, which is continuous, zero-effort discoverability.

**Discovery.** `grep -c context-learn` against the help text, and provenance `harness.source` in a real
call — the same measurement this repo used for the federation work.

---

## R11 — `--rules` seeding writes to repos we don't own

**Failure.** `--rules <target>` is used against third-party repos. Seeding writes files there.

**Evidence.** `deploy_rules_bundle` already writes `AGENTS.md`, `.gitignore`, `.agents/**` and git
hooks into whatever target it is given.

**Mitigation.** Seeding writes only `.agents/context-harness/prime-profile.json` at generation 0 and is
**idempotent** — it never overwrites an existing profile. It performs no model call and no network
access. It is skippable (`AINISH_SEED_CONTEXT_HARNESS=off`) for operators who want the old behaviour
exactly.

**Discovery.** Run `--rules` twice against a scratch dir; assert byte-identical profile.

---

## Ranked: what to worry about, in order

1. **R7 — the contrast is meaningless.** Most likely, most fatal, cheapest to test first.
2. **R1 — the learner makes primes worse.** Mitigated structurally, but only if generation 0 is truly
   frozen.
3. **R2 — self-bloat.** Fully mitigated by the cap; cannot happen silently.
4. **R5 — learned state dies on clone.** Silent divergence is the nasty part; provenance fixes it.
5. **R3 — criterion leakage.** Two layers, one of them code.
6. **R10 — nobody uses it.** Real, and cheap to fix.
7. The rest are bounded by structure.
