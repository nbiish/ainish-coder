# TASK.2026-09-10.browser-skill

- **Triage:** now
- **Branch:** `feat/skills-browser-skill`
- **Agent:** antigravity
- **Status:** active

## Scope

Formally package and expertly document the `browser-skill` (BrowserSkill `bsk` CLI + extension) as a first-class `.agents/skills/browser-skill` skill in `ainish-coder`.

## Changes

1. Installed `bsk` CLI v0.2.1 and browser-skill harness integrations via `bsk install-skill --yes`.
2. Verified `bsk doctor` reporting all checks `ok` with connected browser extension.
3. Created `.agents/skills/browser-skill/SKILL.md` with comprehensive agent instructions, lifecycle patterns, perception hierarchy, exact flags table, user tab borrowing rules, human-in-the-loop flows, file transfers, and error recovery.
4. Added references in `.agents/skills/browser-skill/references/` (`cli-help.txt`, `doctor-reference.txt`, `AGENT_INSTALL.md`, `README.md`).
5. Update COMMS ledger entry.

## Verification

- `bsk doctor` returns `ok` on all checks (extension connected).
- Skill files and reference documentation verified.
- Git audit clean.

## Done criteria

- Merged to main autonomously with green gates.
