---
plan_format: ainish/plan/v1
slug: rules-computer-browser-skills
date: 2026-11-27
status: done
branch: feat/rules-computer-browser-skills
worktree: /Users/nbiish/code/ainish-coder-worktrees/feat-rules-computer-browser-skills
task_record: .agents/tasks/2026-11-27-16-rules-computer-browser-skills.md
integration: new-pr
operator: nanoboozhoo
---

# Plan: Ship `computer-use` & `browser-use` Always-On in `--rules` and in Repo `.agents/skills/`

## 1. Objective

1. Make `browser-use` (`Browser MCP 2.x` + CDP fallback) and `computer-use` (`vercel-labs/agent-desktop`) mandatory packs in `_skill_mandatory()` (`src/skills_selection.sh`) so every `ainish-coder --rules` and `--rules-sync --all` deployment ships them automatically to every project.
2. Add byte-identical copies of `computer-use/` and `browser-use/` into `ainish-coder`'s own `.agents/skills/` (5 total local packs, within the `<= 6` curated subset invariant) so both Mac and Windows `ainish-coder` checkouts expose them natively alongside `~/.agents/skills/`.
3. Add a cross-machine `--machine-run` + `agent-desktop` recipe to `computer-use/SKILL.md`, update `src/help.sh` and `scripts/test-pqc-dist.sh`, merge cleanly, sync Mac/Windows/fleet, and live-verify controlling the Windows machine from macOS via `--machine-run` + `agent-desktop`.

## 2. Threat Model & Constraints

- **Assets:** Desktop GUI surfaces on macOS & Windows, logged-in browser profiles, PQC secrets store, and enrolled target repositories.
- **Controls:** Headless accessibility actions by default (`--headed` only when explicitly authorized), untrusted UI/web text treated as data not instruction, zero plaintext secrets, human takeover for CAPTCHA/2FA, and byte-parity pinned between `skills-to-distribute/skills/` and `.agents/skills/`.

## 3. Checklist

- [x] Install `agent-desktop` (`1.3.1`) and verify `@browsermcp/mcp@latest` (`2.5.0`) on both macOS and Windows.
- [x] Add `browser-use|computer-use` to `_skill_mandatory()` in `src/skills_selection.sh`.
- [x] Add cross-machine `--machine-run` section to `computer-use/SKILL.md` and mirror `computer-use/` + `browser-use/` into `.agents/skills/`.
- [x] Update `src/help.sh` and `scripts/test-pqc-dist.sh`.
- [x] Verify hermetic `ainish-coder --rules` deployment, open PR, verify CI, merge, sync Mac/Windows/fleet, and prove live cross-machine Windows desktop control via `--machine-run`.
