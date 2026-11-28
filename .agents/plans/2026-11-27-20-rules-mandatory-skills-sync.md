---
plan_format: ainish/plan/v1
slug: rules-mandatory-skills-sync
date: 2026-11-27
status: active
branch: fix/rules-mandatory-skills-sync
operator: nanoboozhoo
---

# Plan: Track All Mandatory Skills in `--rules-status` and `--rules-sync`

## Threat Model
- **Asset:** Fleet rules/skills distribution (`src/deploy_rules_sync.sh`, `.agents/ainish-deploy.json`, `.agents/bin/ainish-rules-sync`) and mandatory skill packs (`ainish-security`, `browser-use`, `computer-use`, `pqc-secrets`) in enrolled repositories.
- **Threat:** Silent fleet drift — when a mandatory skill (`computer-use`, `browser-use`) is added or updated without touching `AGENTS.md` or `pqc-secrets`, `--rules-status` falsely reports `CURRENT` and `--rules-sync --all` exits 0 as a no-op via pre-upgrade refreshers. Secondary risk: breaking `source_pack_sha256` attestation verified by `src/pqc_dist.sh` and `--rules-verify`.
- **Mitigation:** Preserve `source_pack_sha256` untouched; add `source_mandatory_skills_sha256` covering every pack matched by `_skill_mandatory()`; check it in `rules_status()` and the generated POSIX `sh` refresher; upgrade pre-existing refreshers in `rules_sync_target()` and `rules_sync_all()`.

## Changes
1. `src/deploy_rules_sync.sh`:
   - Add `_ainish_rules_mandatory_skills_digest()` hashing all `_skill_mandatory()` packs in deterministic sorted order.
   - Stamp `"source_mandatory_skills_sha256"` in `_ainish_rules_manifest_write()`.
   - Update generated `.agents/bin/ainish-rules-sync` to compute the identical POSIX `sh` digest over `_skill_mandatory()` packs and trigger refresh when missing or changed.
   - Update `rules_status()` to mark targets `STALE` when `source_mandatory_skills_sha256` is missing or mismatched.
   - Add `_ainish_rules_refresher_needs_upgrade()` so `rules_sync_target()` and `rules_sync_all()` upgrade pre-existing refreshers and deploy missing mandatory skills (`computer-use`, upgraded `browser-use`).
2. `scripts/test-pqc-dist.sh`:
   - Add focused regression checks for `source_mandatory_skills_sha256`, stale detection on pre-upgrade targets, refresher upgrade deploying `computer-use`, and POSIX `sh` vs bash digest parity.

## Verification
- Run `bash scripts/test-pqc-dist.sh` in the worktree.
- Verify read-back on a real target or temp target showing `STALE` -> `--rules-sync` -> `CURRENT` with `.agents/skills/computer-use/SKILL.md` present.
