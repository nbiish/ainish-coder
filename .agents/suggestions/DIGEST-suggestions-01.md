---
format: ainish/context-digest/v1
folder: suggestions
period: 2026-11+
records_consolidated: 3
consolidated_at: 2026-11-21T15:19:57.837441+00:00
sources:
  - 2026-11-20-16-contract-deploy-followups.md
  - 2026-11-20-17-contract-internals-followups.md
  - 2026-11-20-21-consolidation-followups.md
---

# Digest — `.agents/suggestions`, 2026-11+

This digest replaces 3 record(s) from 2026-11+. Each one is still recoverable
from git history; the `sources:` list above names them exactly. Anything not said here is not
in the folder any more, so treat the omissions as deliberate rather than absent.
## Accomplished

The three records are follow-up lists, so what landed is the work each round belongs to. The checkable state it leaves behind:

- **The contract/identity deploy landed.** Both contract files are `uchg`-locked. Rule 4 states the identity rule, and the contract no longer names where the tooling lives — discovery of the identity table now depends on the repo tree and `.agents/llms.txt`. `--rules` copies the table into `.agents/bin/` and a re-run refreshes it; identity hooks install via `_ainish_rules_target_hooks_dir`, which resolves inside a git checkout. [2026-11-20-16-contract-deploy-followups.md]
- **The contract-internals cleanup landed.** `AGENTS.md` now says only what an agent must DO; the engine internals (DecisionEngine, DriverEngine, the decision chain, the context envelope) moved out of it. The contract is 159 lines against a `<= 160` gate; the rewrite freed exactly one line. [2026-11-20-17-contract-internals-followups.md]
- **The consolidation work landed as a manual verb**, with a fallback that keeps partial digests under one heading when the merge fails. Across three real runs the chunk calls succeeded and the merge call returned nothing twice. It has run on `.agents/suggestions` twice; both runs were restored. [2026-11-20-21-consolidation-followups.md]

## Unfinished

Twelve open items; each names what would settle it ("Settled by:" in the sources) — operator judgements, small unwritten code, or a measurement or watch-condition:

- Contract edit path: whether `ainish-coder --edit-rules` should be the only documented way to edit the contract, and whether a stale mtime-vs-intent check is possible at all. At minimum the `uchg` lock's error should name the unlock command. [2026-11-20-16-contract-deploy-followups.md]
- Deployed identity scripts go stale: nothing reports a target running an older table than its installer, and a new harness entry reaches targets only when someone re-runs `--rules`. Planned fix: stamp the table with the source commit and have `--rules-doctor` compare. [2026-11-20-16-contract-deploy-followups.md]
- Non-git targets get no identity hooks (`_ainish_rules_target_hooks_dir` returns nothing outside a git checkout), and the message conflates "auto-sync not installed" with "identity hooks not installed". Planned fix: split the warning so a non-git target says the identity hooks need a `.git`. Rare path — the operator almost always uses a git repo. [2026-11-20-16-contract-deploy-followups.md]
- Whether an agent ever needs to find the tooling from the contract alone; if one does, `.agents/llms.txt` is the right place to name it, not `AGENTS.md`. [2026-11-20-16-contract-deploy-followups.md]
- `.agents/rag/` keeps the retired name while still holding engine machine-local state (graph cache, sessions, autolearn throttle, gate status). Planned fix: rename to `.agents/state/` or `.agents/cache/` with a one-release read-both fallback — it touches ~10 call sites and the gitignore. [2026-11-20-17-contract-internals-followups.md]
- The contract's single line of headroom: undecided whether a rule is ever added without something being cut; if that happens, revisit whether 160 is the right number. [2026-11-20-17-contract-internals-followups.md]
- `llms.txt` still documents DecisionEngine, DriverEngine, the decision chain, and the context envelope's internals. Undecided whether it is documentation (fine as-is) or prompt context (needs the same treatment the contract just got); the answer depends on whether agents actually open it. [2026-11-20-17-contract-internals-followups.md]
- Nothing verifies the contract is still true: the last three `AGENTS.md` rewrites were verified only by greps for phrases. Planned fix: one assertion per named folder and per named command (`--context` still exists, `.agents/llms.txt` still present, the named folders real), so a contract that drifts fails the suite. [2026-11-20-17-contract-internals-followups.md]
- Merge reliability: retry the merge with the same terse system prompt the chunks use and measure the success rate over ~10 runs rather than one. [2026-11-20-21-consolidation-followups.md]
- Consolidation is not on the `--context` path — it is a manual verb and nothing triggers it. Its natural neighbour is the autolearn throttle, which itself has not fired since 2026-11-19. Open design decision: whether the same background pass spawns both, with consolidation on its own interval. [2026-11-20-21-consolidation-followups.md]
- Production consolidation has not happened: only `.agents/suggestions` was run (twice, restored both times); the other four folders (136 files total, ~150K tokens) are untouched. The first production run should go one folder at a time on `main` with the operator watching, because the digest replaces sources and the only backup is git. [2026-11-20-21-consolidation-followups.md]
- `--cap` warns but does not enforce: an over-cap folder names the unsummarised records and nothing fails (deliberate — failing would block a commit over housekeeping), but "never more than 5" was an operator requirement and may need to become a gate. Settled by whether a folder ever drifts over the cap and stays there. [2026-11-20-21-consolidation-followups.md]

## Insights

- **A refused contract edit is invisible.** Both contract files are `uchg`; an edit through an editor that does not clear the flag fails with `operation not permitted`, the file stays byte-identical, and nothing indicates the intent was lost. This has already happened once. [2026-11-20-16-contract-deploy-followups.md]
- **The merge step fails more often than the chunks, even though its input is smaller** — so the failure is probably the instruction shape, not size. The fallback is faithful but reads as batches under one heading rather than one digest. [2026-11-20-21-consolidation-followups.md]
- **The 160-line gate is doing design work**: it forced the internal description out of the contract, and the next rule has to pay for itself in compression. [2026-11-20-17-contract-internals-followups.md]
- **Keeping script paths out of the contract is an intended trade** — the contract is read on every task and paths are implementation detail — but it leaves an agent unable to find the identity table from the contract alone. [2026-11-20-16-contract-deploy-followups.md]
- **The `.agents/rag/` problem is perceptual, not functional**: the directory is engine-internal and the rename is safe, but an agent listing `.agents/` may assume a retrieval system it should reason about. [2026-11-20-17-contract-internals-followups.md]

## Recurring

- **Nothing makes divergence a failure — the same gap in all three records.** A refused `uchg` edit loses intent invisibly [2026-11-20-16-contract-deploy-followups.md]; a deployed target's identity table goes stale with no report [2026-11-20-16-contract-deploy-followups.md]; a contract that drifts from behaviour is caught by no test [2026-11-20-17-contract-internals-followups.md]; `--cap` warns loudly but still lets the folder sit over the cap [2026-11-20-21-consolidation-followups.md]. The recurring lesson: the mechanism lands, but when reality diverges nothing fails — at most it warns.
- **Every follow-up names what would settle it, and the settlements span three kinds.** Twelve "Settled by:" items across the three records: operator judgements (is 160 the right contract size, is `llms.txt` documentation or prompt context, should consolidation ride the background pass), small unwritten code (stamp the identity table and compare in `--rules-doctor`, contract-drift assertions, split the non-git warning, rename `.agents/rag/` with a read-both fallback), and measurements or watch-conditions (measure merge success over ~10 runs; whether a folder drifts over the cap and stays; whether a stale mtime-vs-intent check is possible at all). [2026-11-20-16-contract-deploy-followups.md] [2026-11-20-17-contract-internals-followups.md] [2026-11-20-21-consolidation-followups.md]
