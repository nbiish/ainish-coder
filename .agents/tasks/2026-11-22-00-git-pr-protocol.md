2026-11-22-00-git-pr-protocol
# Task: add a Git & Pull Request Protocol to the universal agent contract

- lane: now
- branch: `main` (worktree `docs/git-pr-protocol`, merged; worktree and branch removed)
- status: done
- plan: in-session plan (Plan mode); no plan file created
- scope: `AGENTS.md` plus `.agents/canonical/*` re-sign artifacts
- objective: make the contract follow the supplied Git & Pull Request Protocol without breaking the 160-line gate or the dist suite.

## What changed

- Added `## Git & Pull Request Protocol` with four compact bullets: Branching & Sync, Scoped Changes & Security, Pull Requests, Review & CI Loop.
- Reconciled Non-negotiable #1 and `## Worktrees` to PR-based delivery (no self-merge; human approval; green CI).
- Compressed verbose prose to keep the contract under its 160-line gate; restored all test-pinned exact phrases after the first suite run caught the paraphrase.

## Verification

- `bash scripts/test-pqc-dist.sh` → 440 passed, 1 failed. The failure is environment-specific and pre-existing: the identity-guard test hardcodes `Nanoboozhoo - embodied by cursor`, while this harness is `opencode` (which the guard table already knows). The same 440/1 result reproduces at baseline commit `0727f1e` in a throwaway worktree. No regression.
- `ainish-context audit contract --verify-history` → PASS: 66 hash-chained transitions, ML-DSA-65 signature VERIFIED. Canonical SHA-256 matches root `AGENTS.md` (`1be22cf8…`).
- `wc -l AGENTS.md` = 158 (gate ≤ 160); all test-pinned contract strings present, forbidden strings absent.
- All five contract files re-locked (444 + `uchg`). Worktrees removed, branch deleted, `git status` clean.

## Pre-existing issues observed (not fixed here)

- `ainish-coder --verify-rules` reports an integrity mismatch: `AGENTS.md.sha256` carries a `  AGENTS.md` suffix that the verifier's `tr -d '[:space:]'` leaves behind. The baseline SHA file has the identical format, so this is not caused by this change.
- `ainish-context gate` crashes with `NameError: name 'run_eval_patch' is not defined` before emitting a verdict.
- `--lock-rules` calls `ainish-context audit contract` with output suppressed; it silently fails when canonical artifacts are `uchg`/444. Unlock the canonical files before re-signing.

## Deliberately not done

- No push, PR, or fleet redeploy: outward-facing actions were not authorized for this task. Delivery stayed local per the repo's existing worktree merge-back law.
- No separate plan file (the plan was conducted in Plan mode); no changes to sibling `AGENTS.md` files.
- compat: commit author format is now `Nanoboozhoo embodied by: {harness}`; contract and tooling updated together, no runtime API change.
