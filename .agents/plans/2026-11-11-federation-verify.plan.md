---
plan_format: ainish/plan/v1
slug: federation-verify
date: 2026-11-11
status: done
branch: feat/federation-verify
worktree: /Users/nbiish/code/federation-verify
task_record: .agents/tasks/2026-11-11-federation-verify-task.md
operator: question-me
---

# Plan: Make federation predictive, and prove a peer is usable after it syncs

## 1. Problem

`--machine-sync` delivers refs reliably, but it cannot tell an operator whether the peer will actually
be *usable* afterward. A dry run reports only "would sync both"; a real run reports "synced" even when
the peer's working tree never advanced. Both machines in the registry can also describe the same
checkout as two different peers.

## 2. Anchor Facts

- Transport works: `refs/remotes/mac-18gb/main = 7f4f725` arrived on the peer — established by
  `git for-each-ref refs/remotes/mac-18gb/` over SSH.
- A real sync fast-forwards only when the peer tree is clean; one staged `.bak` add blocked both
  registry entries for days — established by `git status --porcelain` on the peer showing `AD`, then
  advancing to `7f4f725` the moment it was cleared.
- `windows-128gb` (`D:/Code`) and `wsl-94gb` (`/mnt/d/Code`) are **the same NTFS checkout** — established
  by identical `git rev-parse --show-toplevel`, the same dirty path, and the same HEAD before and after.
- `--dry-run` prints only `would sync both with <path>` (`src/machine_sync.sh`), with no commit counts
  and no checkout-blocked prediction — established by running it.
- `--status` reported `windows-128gb/main e2f5cc73` while the tree's real HEAD was already `7f4f725` —
  established by comparing the status block to `git rev-parse --short HEAD` on the peer.

## 3. Plan

1. **Predictive `--dry-run`:** per peer, report commits ahead/behind for the branch being synced, and
   name the exact paths that would block a fast-forward. A dry run that cannot predict the outcome is
   a connectivity check wearing a plan's clothes.
2. **Post-sync smoke check:** after a peer syncs, run a bounded read-only probe on that peer —
   `ainish-coder --version`, `--plan-check`, and `--rules-status --json` — and report per machine. This
   is the "works across architectures" half: a ref that arrives but cannot execute is not a delivery.
3. **Duplicate-tree detection:** when two registry entries resolve to the same checkout, say so once and
   sync only one, instead of reporting the same tree twice as two successes.

## 4. Clarification Ledger

| # | Question | Answer |
|---|---|---|
| 1 | Clear the stale peer state or report only? | Clear it, then fast-forward — done; peers are now at `7f4f725`. |
| 2 | What does the smoke check cover? | `--version`, `--plan-check`, `--rules-status --json`. Bounded, read-only, no builds. |
| 3 | Make `--dry-run` predictive? | Yes — commit counts plus the blocking paths. |

## 5. Todos

- [x] 5.1 Dry run: commits ahead/behind per peer for the synced branch.
- [x] 5.2 Dry run: name the paths blocking a fast-forward, or state "clean; would fast-forward".
- [x] 5.3 Post-sync smoke probe per peer, reported per machine, never failing the sync on its own.
- [x] 5.4 Detect two registry entries resolving to one checkout; sync once and label them.
- [x] 5.5 Gate the behaviors in `scripts/test-pqc-dist.sh`, each proven to fail first.

## 6. Verification Gates

1. `bash -n src/machine_sync.sh` and the suite green.
2. A dry run against a deliberately dirty peer prints the blocking path.
3. A dry run against a clean peer prints the commit delta and predicts a fast-forward.
4. After a real sync, the smoke block shows `--version` and `--plan-check` per peer.
5. Two entries on one checkout are reported as one machine.

## 7. Risks

- **The smoke probe runs commands on a peer.** It must be read-only and fail soft: a peer that answers
  no probe is reported as unverified, never as failed delivery, or a missing toolchain reads as a
  broken sync.
- **Commit-count reporting costs a round trip per peer.** Acceptable: `--dry-run` already enumerates
  refs over SSH, so the delta rides the same connection.
- **Same-disk peers are legitimate in principle** (a WSL view of a Windows checkout is how an operator
  works). Detecting them must not *refuse* to sync; it de-duplicates and labels.
