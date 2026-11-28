---
task_format: ainish/task/v1
slug: selectable-browser-computer-skills
date: 2026-11-28
status: done
branch: feat/selectable-browser-computer-skills
plan: .agents/plans/2026-11-28-14-selectable-browser-computer-skills.md
operator: nanoboozhoo
---

# Task: Make `browser-use` and `computer-use` Toggleable in `ainish-coder --skills`

## Scope
- `src/skills_selection.sh`
- `src/help.sh`
- `src/deploy_rules_sync.sh`
- `scripts/test-pqc-dist.sh`

## Progress
- [x] Narrowed `_skill_mandatory()` to `pqc-secrets|ainish-security`.
- [x] Updated `src/help.sh`, `src/deploy_rules_sync.sh` fallbacks, and `scripts/test-pqc-dist.sh`.
- [x] Verified `--skills-list` and 20/20 assertions across selection-guard and mandatory-drift tests.
- [x] Pushed `feat/selectable-browser-computer-skills` and opened PR to `main`.
