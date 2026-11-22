---
branch: chore/fast-rules-tooling
status: ready
---

# Plan: fast, system-wide rules tooling and harness-agnostic authorship

## Objective

- All harnesses commit as `Nanoboozhoo embodied by: {agent harness}` (no hardcoded cursor).
- The latest contract is reflected in every live tooling reference and deployed to every registered target and global copy.
- Keep SHA-256 + ML-DSA-65 signing, but remove the friction that made iteration slow.

## Scope

- `scripts/commit-identity-guard.sh`, `scripts/test-pqc-dist.sh`, `AGENTS.md`
- `src/context/engine.py`, `src/agents_protection.sh`, `src/deploy_rules_sync.sh`, `src/machine_sync.sh`
- `.agents/jobs/sync-fleet.md`, canonical artifacts
- Runtime: registry cleanup, fleet sync, global copies (outside the worktree)

## Steps

1. Change identity prefix to `Nanoboozhoo embodied by:` in the guard; drop the old-prefix "already normalised" exemption. Update contract rule 4 and all live tooling/doc references.
2. Make the dist-suite identity assertion harness-independent: clear all harness env markers, force one known marker, assert the new exact form.
3. Fix `run_eval_patch` (missing function crash in `ainish-context gate`) with a fast deterministic local evaluator that preserves credential-leak refusal.
4. Fix SHA-file parsing in engine `zt_hash_ok` and `agents_protection.sh` (strip the `  AGENTS.md` filename, not just whitespace).
5. Fix `snapshot_canonical_contract` so it unlocks canonical artifacts before signing and surfaces a signing failure instead of suppressing it.
6. Make the root post-commit rules-sync hook skip when the commit touched no managed rules content, so ordinary commits are fast.
7. Re-sign canonical, run the full dist suite and gate, clean junk registry entries, sync all real targets, refresh global copies, verify read-back.

## Verification

- `bash scripts/test-pqc-dist.sh` → 441/441.
- `ainish-context gate --summary` emits a verdict (no NameError).
- `ainish-coder --rules-status` → all real targets CURRENT.
- Root/canonical SHA-256 match; global copies match root.
