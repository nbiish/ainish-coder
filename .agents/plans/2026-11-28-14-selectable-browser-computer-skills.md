---
plan_format: ainish/plan/v1
slug: selectable-browser-computer-skills
date: 2026-11-28
status: active
branch: feat/selectable-browser-computer-skills
operator: nanoboozhoo
---

# Plan: Make `browser-use` and `computer-use` Selectable in `ainish-coder --skills`

## Threat Model
- **Asset:** Per-repo skill selection (`src/skills_selection.sh`), CLI help (`src/help.sh`), and mandatory-skill tracking (`src/deploy_rules_sync.sh`).
- **Threat:** Removing `browser-use` and `computer-use` from `_skill_mandatory()` must never weaken the mandatory status of `pqc-secrets` or `ainish-security` (which `AGENTS.md` and secret resolution depend on), nor break `source_mandatory_skills_sha256` parity.
- **Mitigation:** Keep `pqc-secrets` and `ainish-security` in `_skill_mandatory()`, update fallback lists in `src/deploy_rules_sync.sh`, update help text, and assert both mandatory protection (`pqc-secrets`, `ainish-security`) and selector visibility (`browser-use`, `computer-use`) in `scripts/test-pqc-dist.sh`.

## Changes
1. `src/skills_selection.sh`: Narrow `_skill_mandatory()` to `pqc-secrets|ainish-security`.
2. `src/help.sh`: Remove `[mandatory]` tags from `browser-use/` and `computer-use/`.
3. `src/deploy_rules_sync.sh`: Update fallback mandatory pack list to `ainish-security pqc-secrets`.
4. `scripts/test-pqc-dist.sh`: Assert `browser-use` and `computer-use` appear in `skills_selection_list`, while `ainish-security` and `pqc-secrets` remain mandatory.
