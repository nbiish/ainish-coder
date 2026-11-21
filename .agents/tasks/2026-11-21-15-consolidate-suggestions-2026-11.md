2026-11-21-15-consolidate-suggestions-2026-11
# Task: Consolidate `.agents/suggestions` period 2026-11+ into one digest

- lane: now
- branch: `feat/consolidation-panel-sequence`
- status: done (landed digest passed the 3-member panel 3/3; a concurrent background pass clobbered
  the file mid-task and was reconciled — see Findings)
- scope: `.agents/suggestions/` — 3 records (`2026-11-20-16-contract-deploy-followups.md`,
  `2026-11-20-17-contract-internals-followups.md`, `2026-11-20-21-consolidation-followups.md`) →
  `DIGEST-suggestions-01.md`
- objective: One digest a future agent reads instead of the three follow-up records — Accomplished,
  Unfinished, Insights, Recurring, with the source filename cited for anything specific.

## What changed

| Was | Now |
|---|---|
| 3 dated follow-up records | one sequence digest `DIGEST-suggestions-01.md` (`ainish/context-digest/v1`) |
| coverage boundary against `DIGEST-suggestions-2026-11.md` implicit | frontmatter `sources:` names the 3 replaced files exactly; disjoint from that digest's 17 sources (its cutoff is 2026-11-20-15) |

## Verification

Panel = the three `CONSOLIDATE_PANEL` members (`consolidate-goldfish` fidelity,
`consolidate-archivist` completeness, `consolidate-structural` coherence) run over sources + draft via
`hermes -z ... --profile`, in parallel.

- Drafter v1 (manual) failed fidelity twice — Recurring's synthesis overreached (`--cap` does warn, so
  "nothing reports drift" was wrong; several "Settled by:" lines are measurements, not decisions) —
  then passed 3/3 and was committed (`0a01084`).
- A concurrent background `context-consolidate` pass then overwrote the digest with its own draft
  (Findings 1). Checked against the same panel: fidelity pass, completeness pass, coherence FAIL —
  no period arc, and "Consolidation runs happened" read as production use when the runs were
  test-only and restored.
- The landed digest is the merge: the background draft's granularity plus the arc ("hardening and
  verification phase") and test-only framing, then one hedging fix ("payload size is not the failure
  driver" → "on this evidence size is unlikely..."). Final panel: 3/3 `VERDICT: pass`, `GAP: none`.

Deviation stated, not hidden: `run_context_consolidate`'s automated gate abandons a period after a
second failed review; this operator-directed run kept fixing and re-checking until a clean 3/3. Every
source is tracked in git (`git show 0a01084^:...` recovers each). Order held in every round: digest
written before any removal; removal limited to the exact files named in `sources:`.

## Findings

1. A background `context-consolidate` pass (engine from this worktree; per-folder children) rewrote
   `.agents/suggestions/DIGEST-suggestions-01.md` at 2026-11-21T15:22:30Z over the just-committed
   digest — same path, same `sources:`, its own prose — leaving an uncommitted clobber. One writer per
   mutation boundary does not hold between a manual run and the background pass. A sibling
   `--folder comms` child was terminated before it touched comms (it had written nothing). Recorded
   as `.agents/suggestions/2026-11-21-15-background-pass-clobber.md`.
2. Every gap the panel found was synthesis, never a misread fact — the conclusions the sources did not
   carry, not the facts, were where this digest's risk lived.
3. The 12 open follow-ups ride in the digest's Unfinished section; nothing was lost to prose.
