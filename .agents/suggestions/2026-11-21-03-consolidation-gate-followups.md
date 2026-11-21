2026-11-21-03-consolidation-gate-followups
# Follow-ups the specialist-pair work surfaced

## 1. A half-digested period writes a partial digest

`tasks` split into 2 chunks; chunk 1 failed review twice, chunk 2 passed, so a digest was written
covering 1 of 16 records and 13 originals stayed. The folder is now both over cap AND carrying a digest
whose `records_consolidated: 1` understates the period.

**Options:** (a) all-or-nothing per period — no digest unless every chunk passes; (b) one call per
period, relying on hermes being able to take 40K (measured: it can); (c) keep partials but rename the
digest to name the chunk range it covers.

**Settled by:** whether hermes can reliably take a whole period in one call. If yes, (b) removes the
whole class.

## 2. The reviewer fails on real omissions, which means the drafter prompt is under-specified

Two live runs, two genuine catches (an escalated design question; a 24-key secrets-store incident). Both
are exactly the kind of fact the prompt asks for under "Unfinished". The draft is not ignoring the
instruction; it is dropping specific items while summarising a large batch.

**Settled by:** giving the drafter an explicit checklist pass ("list every unresolved item in the
sources by filename before writing prose"), which is a prompt change, not a code change.

## 3. The pair does not yet learn

The operator's ask was that the pair "recursively self improve via their separate skills". The profiles
exist and carry memory, but nothing writes a lesson back when the reviewer catches something twice.

**Settled by:** feeding `rejected/` back into the next draft for the same folder, which is the same
mechanism `context-learn` uses and the cheapest form of self-improvement here.

## 4. The main checkout is on a feature branch the operator did not create

`feat/fleet-sync-reliability` appeared while consolidating, created by the machine-watch auto-commit
machinery. Worktree operations keyed on `main` then behaved unexpectedly. The watcher should not create
or switch branches in the checkout the operator is working in.

**Settled by:** checking whether `--auto-commit` uses `git checkout -b` anywhere, and whether the
watcher should refuse to act when the tree is mid-task.
