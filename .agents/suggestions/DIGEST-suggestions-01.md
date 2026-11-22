---
format: ainish/context-digest/v1
folder: suggestions
period: 2026-11+
records_consolidated: 3
consolidated_at: 2026-11-21T15:22:30.756561+00:00
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

The period was a hardening-and-verification phase: the contract and identity layer was deployed and its internals cleaned up (landed), while the consolidation tooling was built and exercised in test runs that were restored — nothing has digested a production folder yet.

- The contract/identity deploy work landed: `--rules` copies the identity table into `.agents/bin/` and a re-run refreshes it, and the contract files themselves are `uchg`-locked (2026-11-20-16-contract-deploy-followups.md).
- The contract-internals cleanup landed: `AGENTS.md` was rewritten down to what an agent must DO (internal tooling description removed), and the contract now stands at 159 lines against a `<= 160` gate — the budget forced the internal description out (2026-11-20-17-contract-internals-followups.md §2).
- Consolidation tooling was built and exercised — in test runs only, restored both times: three real runs in which the chunk calls succeeded and the merge call returned nothing twice, with the fallback keeping partial digests under one heading (2026-11-20-21-consolidation-followups.md §1, §3).
- `context-consolidate` exists as a manual verb, and `--cap` warns and names the unsummarised records instead of failing — deliberately, so a commit is never blocked over housekeeping (2026-11-20-21-consolidation-followups.md §2, §4).

## Unfinished

- A refused contract edit is invisible (2026-11-20-16-contract-deploy-followups.md §1): an editor that does not clear `uchg` fails with `operation not permitted`, the file stays byte-identical, and the intent is silently lost — this has already happened once. Three things are still open: (a) whether `ainish-coder --edit-rules` should be the ONLY documented way to edit the contract, (b) whether a stale mtime-vs-intent check is possible at all, and (c) at minimum the lock's error should name the unlock command.
- Deployed targets' identity scripts can go stale with nothing reporting it: a new harness entry reaches targets only when someone re-runs `--rules`. Proposed but not built: stamp the table with the source commit and have `--rules-doctor` compare (2026-11-20-16-contract-deploy-followups.md §2).
- Non-git targets get no identity hooks (`_ainish_rules_target_hooks_dir` returns nothing outside a git checkout), and the warning conflates "auto-sync not installed" with "identity hooks not installed". Proposed: split the warning so a non-git target says the identity hooks need a `.git`. Rare path — the operator almost always works in a git repo (2026-11-20-16-contract-deploy-followups.md §3).
- The contract no longer names where the tooling lives: discovery of the identity table now depends on the repo tree and `.agents/llms.txt`. Unsettled: whether an agent ever needs to find the table from the contract alone; if one does, `.agents/llms.txt` — not `AGENTS.md` — is the place to name it (2026-11-20-16-contract-deploy-followups.md §4).
- `.agents/rag/` keeps the retired name although the contract no longer mentions it; it is where the engine writes machine-local state (graph cache, sessions, autolearn throttle, gate status). Proposed: rename to `.agents/state/` or `.agents/cache/` with a one-release read-both fallback; safe because it is engine-internal, but it touches ~10 call sites and the gitignore (2026-11-20-17-contract-internals-followups.md §1).
- The contract has one line of headroom (159 of 160). Unsettled: whether a rule is ever added without something being cut — if that happens, revisit whether 160 is still the right number (2026-11-20-17-contract-internals-followups.md §2).
- `llms.txt` still describes `DecisionEngine`, `DriverEngine`, the decision chain, and the context envelope internals. Unsettled: whether `llms.txt` is documentation (fine as-is) or context (needs the same treatment the contract got) — the answer depends on whether agents actually open it (2026-11-20-17-contract-internals-followups.md §3).
- Nothing verifies that the contract is still true: the recent `AGENTS.md` rewrites were checked only by greps for phrases. Proposed: a small assertion per named folder and per named command (`--context` still exists, `.agents/llms.txt` still present, the folders named are real) so drift fails the suite (2026-11-20-17-contract-internals-followups.md §4).
- The merge step fails more often than the chunks: across three real runs the chunks succeeded but the merge returned nothing twice, and the fallback digest reads as batches rather than one digest. Suspected cause is instruction shape, not size (the merge input is smaller than a chunk input). Proposed: run the merge with the same terse system prompt the chunks use and measure success over ~10 runs (2026-11-20-21-consolidation-followups.md §1).
- Consolidation is not on the `--context` path — it is a manual verb and nothing triggers it, so the operator's ask that context agents do this is not yet met. Unsettled: whether consolidation should be spawned by the same background pass as learning, with its own interval — one design decision with the autolearn throttle, which itself has not fired since 2026-11-19 (2026-11-20-21-consolidation-followups.md §2).
- Real folders have not been consolidated: only `.agents/suggestions` was run (twice, restored both times); the other four — 136 files, ~150K tokens — are untouched. The first production run should go one folder at a time on `main` with the operator watching and each digest checked by eye before the next, because the digest replaces the source files and git is the only backup (2026-11-20-21-consolidation-followups.md §3).
- `--cap` warns but does not enforce: an over-cap folder is reported and the unsummarised records named, but nothing fails. Unsettled: whether "never more than 5" (the operator's requirement) must become a gate — settled by whether a folder ever drifts over the cap and stays there (2026-11-20-21-consolidation-followups.md §4).

## Insights

- The `uchg` lock loses intent without any signal: the file stays byte-identical after a refused edit, so only an editor error the operator happens to read reveals the loss (2026-11-20-16-contract-deploy-followups.md §1).
- The contract deliberately traded away discoverability: it is read on every task and script paths are implementation detail, which is why it no longer names where the identity table lives (2026-11-20-16-contract-deploy-followups.md §4).
- `.agents/rag/` is engine-internal state, not a retrieval system an agent should reason about — but its name invites exactly that misreading (2026-11-20-17-contract-internals-followups.md §1).
- `llms.txt` is returned by the context call and may be opened by an agent, so its PRD-level engine detail doubles as prompt surface whether or not that was intended (2026-11-20-17-contract-internals-followups.md §3).
- Grep-for-phrases verification proves a phrase exists, not that behaviour matches the contract's claims (2026-11-20-17-contract-internals-followups.md §4).
- The merge call is smaller than the chunk call yet fails more often — so on this evidence size is unlikely to be the failure driver, and the instruction shape probably is (2026-11-20-21-consolidation-followups.md §1).
- The partial-digest fallback is faithful but not readable: it preserves the content while making the result read like batches instead of one digest (2026-11-20-21-consolidation-followups.md §1).
- A consolidation digest replaces its source files and git is the only backup, so the first production run of each folder deserves an operator watching (2026-11-20-21-consolidation-followups.md §3).

## Recurring

- Work is lost or degraded without a loud failure: the refused `uchg` edit leaves a byte-identical file (2026-11-20-16-contract-deploy-followups.md §1); a stale identity table on a deployed target is never reported (same file, §2); the merge call silently returns nothing and the fallback absorbs it (2026-11-20-21-consolidation-followups.md §1); `--cap` names the excess and fails nothing (same file, §4). The shared lesson: a condition that matters should fail or report loudly, not degrade quietly.
- Drift between a claim and reality goes unmeasured: contract claims verified only by phrase greps (2026-11-20-17-contract-internals-followups.md §4), and the deployed identity table is never compared against its installer (2026-11-20-16-contract-deploy-followups.md §2). The shared lesson: assertions must compare the stated source of truth against actual behaviour.
- Leftover names and wording misdirect readers: `.agents/rag/` retains a retired name (2026-11-20-17-contract-internals-followups.md §1); the non-git warning conflates two different absences (2026-11-20-16-contract-deploy-followups.md §3); the contract no longer names where the tooling lives (same file, §4).
- Features that depend on someone remembering to run them drift: targets get new harness entries only on a manual `--rules` re-run (2026-11-20-16-contract-deploy-followups.md §2); consolidation is a manual verb with no trigger (2026-11-20-21-consolidation-followups.md §2); the autolearn throttle has not fired since 2026-11-19 (same file, §2).
