2026-11-22-14-federation-profile-cleanup
# Task: decouple hermes from --rules and federate the tool repo bidirectionally

- lane: now
- branch: `main` (PR #7 `chore/tooling-federation-release` and PR #8 `fix/watcher-no-autocommit`, both merged; worktrees removed)
- status: done
- plan: `.agents/plans/2026-11-22-14-federation-profile-cleanup.plan.md`
- scope: `src/deploy_rules_sync.sh`, `src/machine_watch.sh`, `.agents/no-watcher-autocommit`, `bin/security_gate.py`, global `links.txt`, Windows checkout, PR delivery
- objective: hermes profiles are used by `--context` only; the tool repo is federated both ways; tooling stops interfering with updates.

## What changed

- Removed `_ainish_rules_provision_consolidation_profiles()` and its call: `--rules` no longer inspects or creates hermes host config. `--context` still uses the existing `consolidate-*` profiles.
- `links.txt`: removed `local-router` (it failed every watcher cycle, starved other repos, and auto-committed mid-write); added `ainish-coder` → `windows-128gb` / `D:/Code/ainish-coder-macclone`.
- Windows `ainish-coder` re-cloned from Mac via a bundle of the pushed Mac ref. The original checkout is intact at `D:\Code\ainish-coder` (backup; Windows refused the rename), signer key and `.claude` config preserved in the new clone.
- `src/machine_watch.sh`: a repo carrying `.agents/no-watcher-autocommit` is synced with `--both` but never `--auto-commit`. Added the marker here, so watcher `wip(Mac)` commits no longer land on `main` mid-task.
- `bin/security_gate.py`: CI gate now parses the digest from `sha256sum` format, and the unsanitized-path rule no longer false-positives on `os.open` atomic locks.

## Verification

- PR #7 and PR #8 both **MERGED** into `origin/main`; all four CI checks pass on each (PQC/containment, secret scan, two Rust audits).
- `bash scripts/test-pqc-dist.sh` → PASS 441 assertions. `ainish-context gate --summary` → GREEN.
- `ainish-coder --rules-status` → 11 current, 0 stale, 0 missing.
- `ainish-coder --machine-sync --both` → Windows checkout fast-forwarded; Mac and Windows `main` both at `21517fa`. A Windows-side commit had previously arrived on Mac, proving reverse direction.
- No hermes provisioning references remain in `src`/`bin`; `git status` clean; single worktree.

## Deliberately not done

- Windows-only commits (915) were not migrated into Mac history — they remain in the intact backup checkout, per operator decision.
- The original Windows directory was not deleted (rename was denied by Windows); it is retained as the backup.
- No remote force-push or history rewrite.
