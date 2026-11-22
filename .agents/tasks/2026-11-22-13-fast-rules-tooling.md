2026-11-22-13-fast-rules-tooling
# Task: harness-agnostic authorship and fast, system-wide rules tooling

- lane: now
- branch: `main` (worktree `chore/fast-rules-tooling`, rebased and fast-forward merged; worktree removed)
- status: done
- plan: `.agents/plans/2026-11-22-13-fast-rules-tooling.plan.md`
- scope: identity guard, dist suite, engine gate, canonical snapshot helper, deploy sync path, machine sync, contract, canonical artifacts, fleet registry and copies
- objective: every harness commits as `Nanoboozhoo embodied by: {agent harness}`; the newest contract reaches every target quickly; keep signing but remove its friction.

## What changed

- `scripts/commit-identity-guard.sh`: canonical author prefix is now `Nanoboozhoo embodied by:`; the harness is always detected from env markers or the author, never hardcoded. Retired old-format spellings are no longer treated as already-normalised.
- `scripts/test-pqc-dist.sh`: the identity test now clears all harness env markers and forces one known marker, so it passes under any driving harness; pinned strings updated to the new form.
- `src/context/engine.py`: added the missing `run_eval_patch` (fast deterministic local patch inventory, keeps credential-leak refusal); fixed the undefined-arg call site; gate now accepts any signature envelope whose SHA-256 matches the canonical bytes; composite score is on a 0–1 scale.
- `src/agents_protection.sh` + `bin/ainish-coder`: `snapshot_canonical_contract` unlocks all canonical artifacts before signing, verifies the recorded digest, re-locks them, and fails closed; `--lock-rules` no longer swallows a signing failure.
- `src/deploy_rules_sync.sh`: root post-commit hook skips fleet sync when a commit touches no managed rules content; per-target refresher and `--rules-status` decide staleness by deployed content hashes (contract + pack) instead of commit SHA.
- `src/machine_sync.sh` + `.agents/jobs/sync-fleet.md`: auto-commit author uses the new form.
- `AGENTS.md` rule 4 and canonical artifacts updated and re-signed.
- Fleet registry cleaned from 57 to 10 real targets; all 10 synced; global copies and the two system-level `AGENTS.md` files brought to the latest contract (backups kept).

## Verification

- `bash scripts/test-pqc-dist.sh` → **PASS: 441 assertion(s)** (baseline was 440 pass / 1 fail; the failing identity assertion is now deterministic and green).
- `bin/ainish-context gate --summary` → `GATE:GREEN | anchor:N/A | patch:DOCS | lock:OK | pqc:13/13 | comms:OK | zt:OK` (previously crashed with `NameError: run_eval_patch`).
- `bin/ainish-coder --rules-status` → 10 target(s), 10 current, 0 stale, 0 missing.
- `ainish-context audit contract --verify-history` → PASS, 66 transitions, signature VERIFIED.
- Root, canonical, global copies, and both system-level contracts all hash to `497d03e5…`.
- `git log -3 --format='%an'` → `Nanoboozhoo embodied by: opencode` on production commits.
- Fast-path hook present in `.git/hooks/post-commit` (grep for the skip comment → 1).

## Deliberately not done

- Signing was kept, per operator decision; no security downgrade.
- No push or PR; delivery stayed local.
- Historical COMMS/plans/memory records keep their old author strings — they are evidence of past state, not live tooling.
- compat: canonical author-format change and signature refresh; live tooling updated in lockstep, no runtime API removed.
