---
task_format: ainish/task/v1
slug: rules-mandatory-skills-sync
date: 2026-11-27
status: done
branch: fix/rules-mandatory-skills-sync
plan: .agents/plans/2026-11-27-20-rules-mandatory-skills-sync.md
operator: nanoboozhoo
---

# Task: Track Mandatory Skills (`computer-use`, `browser-use`, etc.) in `--rules-status` and `--rules-sync`

## Scope
- `src/deploy_rules_sync.sh`
- `scripts/test-pqc-dist.sh`

## Progress
- [x] Diagnosed why `--rules-status` reported 13 targets `CURRENT` without `computer-use` (`source_pack_sha256` only hashed `pqc-secrets`, and existing `.agents/bin/ainish-rules-sync` refreshers skipped refresh).
- [x] Added `source_mandatory_skills_sha256` to `_ainish_rules_manifest_write()`, `rules_status()`, and the generated POSIX `sh` refresher, plus `_ainish_rules_refresher_needs_upgrade()` in `rules_sync_target()` and `rules_sync_all()`.
- [x] Added 9 regression assertions in `scripts/test-pqc-dist.sh` — verified 9/9 pass (including byte-for-byte digest parity between bash and POSIX `sh` refresher).
- [x] Committed, pushed `fix/rules-mandatory-skills-sync`, and opened PR to `main`.
